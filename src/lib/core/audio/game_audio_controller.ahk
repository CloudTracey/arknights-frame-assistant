class GameAudioController {
    static Actions := []
    static Timer := 0

    static Identity(pid) {
        handle := DllCall("OpenProcess", "UInt", 0x1000, "Int", false, "UInt", pid, "Ptr")
        if !handle
            return ""
        times := Buffer(32)
        try {
            if !DllCall("GetProcessTimes", "Ptr", handle, "Ptr", times.Ptr, "Ptr", times.Ptr + 8,
                "Ptr", times.Ptr + 16, "Ptr", times.Ptr + 24)
                return ""
            return Format("{:016X}", NumGet(times, 0, "UInt64"))
        } finally DllCall("CloseHandle", "Ptr", handle)
    }

    static QueueAction(pid, candidates, kind, delta, callback) {
        this.Actions.Push({pid: pid, candidates: candidates, kind: kind, delta: delta, callback: callback})
        if !this.Timer
            this.Timer := this.Tick.Bind(this)
        SetTimer(this.Timer, -1)
    }

    static Tick() {
        Thread "NoTimers"
        batch := [], targets := Map(), snapshot := 0
        try {
            Loop Min(4, this.Actions.Length) {
                action := this.Actions.RemoveAt(1)
                try {
                    selected := 0
                    for hwnd in action.candidates {
                        try {
                            pid := WinGetPID("ahk_id " hwnd)
                            if (!action.pid || action.pid = pid)
                                && StrLower(ProcessGetName(pid)) = StrLower(ServerProfile.ExeName) {
                                selected := pid
                                break
                            }
                        } catch Error {
                            continue
                        }
                    }
                    if !selected
                        throw Error("游戏窗口已关闭或改变")
                    action.pid := selected
                    action.created := this.Identity(action.pid)
                    if StrLen(action.created) = 0 || StrLower(ProcessGetName(action.pid)) != StrLower(ServerProfile.ExeName)
                        throw Error("无法确认游戏进程身份")
                    batch.Push(action)
                    targets[action.pid] := true
                } catch Error as e
                    this.Complete(action, {success: false, message: e.Message})
            }
            if !batch.Length
                return
            snapshot := GameAudioMute.Capture(targets)
            for action in batch
                this.Complete(action, this.Apply(action, snapshot))
        } finally {
            if IsObject(snapshot)
                GameAudioMute.ReleaseSnapshot(snapshot)
            if this.Actions.Length
                SetTimer(this.Timer, -1)
            Thread "NoTimers", false
        }
    }

    static Complete(action, result) {
        try action.callback.Call(action.kind, result)
        catch Error as e
            Logger.Warn("GameAudio", "音频操作回调失败：" e.Message)
    }

    static ReferenceVolume(pid, snapshot, result) {
        Loop 3 {
            priority := A_Index
            for session in snapshot.sessions {
                if session.pid != pid || session.status = 2
                    continue
                rank := session.status = 1 ? (session.device = snapshot.defaultDevice ? 1 : 2) : 3
                if rank = priority {
                    try return session.GetVolume()
                    catch Error as e
                        result.failed++, result.message := e.Message
                }
            }
        }
        return ""
    }

    static Apply(action, snapshot) {
        result := {success: false, found: 0, failed: snapshot.failed, message: snapshot.message, muted: false, volume: ""}
        try {
            if StrLen(action.created) = 0 || this.Identity(action.pid) != action.created
                throw Error("游戏进程已退出或重启，未操作旧会话")
            allMuted := true
            for session in snapshot.sessions {
                if session.pid = action.pid && session.status != 2 {
                    result.found++
                    if action.kind = "mute" {
                        try allMuted := session.GetMute() && allMuted
                        catch Error as e
                            result.failed++, result.message := e.Message
                    }
                }
            }
            if action.kind = "volume" {
                reference := this.ReferenceVolume(action.pid, snapshot, result)
                if IsNumber(reference)
                    result.volume := Min(1, Max(0, reference + action.delta))
            }
            result.muted := !allMuted
            for session in snapshot.sessions {
                if session.pid != action.pid || session.status = 2
                    continue
                if action.kind = "volume" && !IsNumber(result.volume)
                    continue
                try {
                    if this.Identity(action.pid) != action.created
                        throw Error("游戏进程身份已变化")
                    if action.kind = "mute" {
                        if session.GetMute() != result.muted
                            session.SetMute(result.muted)
                    } else {
                        session.SetVolume(result.volume)
                        if action.delta > 0 && session.GetMute()
                            session.SetMute(false)
                    }
                } catch Error as e
                    result.failed++, result.message := e.Message
            }
        } catch Error as e
            result.failed++, result.message := e.Message
        result.success := result.failed = 0
        return result
    }
}
