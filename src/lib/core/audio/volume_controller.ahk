; == 音量控制器 ==
; 按输出设备枚举游戏客户端音频会话，读写应用音量与静音

class VolumeController {
    ; ── 动作参数 ──
    static VOLUME_STEP := 10
    static VOLUME_MIN := 0
    static VOLUME_MAX := 100
    static VOLUME_TOLERANCE := 1
    static POLL_INTERVAL_MS := 500
    static LOG_THROTTLE_MS := 30000

    ; ── Core Audio ──
    static CLSID_MMDeviceEnumerator := "{BCDE0395-E52F-467C-8E3D-C4579291692E}"
    static IID_IMMDeviceEnumerator := "{A95664D2-9614-4F35-A746-DE8DB63617E6}"
    static IID_IAudioSessionManager2 := "{77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F}"
    static IID_IAudioSessionControl2 := "{BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D}"
    static IID_ISimpleAudioVolume := "{87CE5498-68D6-44E5-9215-6DA47EF883D8}"
    static CLSCTX_ALL := 0x17
    static EDATAFLOW_RENDER := 0
    static EROLE_CONSOLE := 0
    static DEVICE_STATE_ACTIVE := 0x1

    ; ── 运行状态 ──
    static _Initialized := false
    static _Busy := false
    static _SyncOn := false
    static _HasTarget := false
    static _TargetVolume := 0
    static _TargetMuted := false
    static _TargetPid := 0
    static _Known := Map()     ; 会话键 -> 上次 AFA 写入后的回读状态 {volume, muted}
    static _PollCallback := ""
    static _Throttle := Map()  ; 日志节流键 -> 上次输出时刻
    static _IidBuffers := ""

    ; ── 生命周期 ──

    ; 初始化
    static Init() {
        if (this._Initialized)
            return
        this._PollCallback := VolumeController._OnPoll.Bind(VolumeController)
        this._Initialized := true
    }

    ; ── 对外动作 ──

    static Increase() {
        return this._Perform("increase")
    }

    static Decrease() {
        return this._Perform("decrease")
    }

    static ToggleMute() {
        return this._Perform("mute")
    }

    ; ── 动作主流程 ──

    static _Perform(action) {
        if (this._Busy) {
            this._ThrottledWarn("busy", "音量操作被忽略：控制器正忙")
            volume := (this._HasTarget ? this._TargetVolume : 0)
            muted := (this._HasTarget ? this._TargetMuted : false)
            return this._Result(false, "failed", volume, muted, 0, 0)
        }
        this._Busy := true
        try {
            pid := this._ResolveTargetPid()
            if (pid = 0) {
                if (this._SyncOn && this._TargetPid != 0 && !this._IsGameProcess(this._TargetPid))
                    this._StopSync("目标进程不存在", true)
                return this._NoSessionResult()
            }

            switched := (pid != this._TargetPid)
            if (switched)
                this._SwitchTarget(pid)

            try {
                scan := this._Scan(pid)
            } catch Error as e {
                this._ThrottledWarn("scan", "枚举音频会话失败：" e.Message)
                volume := (this._HasTarget ? this._TargetVolume : 0)
                muted := (this._HasTarget ? this._TargetMuted : false)
                return this._Result(false, "failed", volume, muted, 0, 0)
            }

            sessions := scan.sessions
            if (sessions.Length = 0)
                return this._NoSessionResult()

            hasLastTarget := this._HasTarget && !switched
            benchmark := this._SelectBenchmark(sessions, scan.defaultDeviceId, hasLastTarget)
            if (!IsObject(benchmark))
                return this._NoSessionResult()

            targetVolume := 0
            targetMuted := false
            if (action = "mute") {
                anyUnmuted := false
                for session in sessions {
                    if (!session.muted) {
                        anyUnmuted := true
                        break
                    }
                }
                targetVolume := benchmark.volume
                targetMuted := anyUnmuted
            } else if (action = "increase") {
                targetVolume := Min(this.VOLUME_MAX, benchmark.volume + this.VOLUME_STEP)
                targetMuted := false
            } else {
                targetVolume := Max(this.VOLUME_MIN, benchmark.volume - this.VOLUME_STEP)
                targetMuted := false
            }

            successCount := 0
            known := Map()
            for session in sessions {
                readVolume := 0
                readMuted := false
                if (this._WriteSession(session.volumeObj, targetVolume, targetMuted, &readVolume, &readMuted)) {
                    successCount += 1
                    known[session.key] := {volume: readVolume, muted: readMuted}
                }
            }

            totalCount := sessions.Length
            if (successCount > 0) {
                this._HasTarget := true
                this._TargetVolume := targetVolume
                this._TargetMuted := targetMuted
                this._TargetPid := pid
                this._Known := known
                message := "目标音量=" targetVolume "% 静音=" (targetMuted ? "是" : "否")
                message .= " 成功会话=" successCount "/" totalCount
                this._StartSync(message)
            } else {
                this._Known := Map()
            }

            if (successCount = totalCount)
                return this._Result(true, "", targetVolume, targetMuted, successCount, totalCount)
            if (successCount > 0)
                return this._Result(true, "partial", targetVolume, targetMuted, successCount, totalCount)
            return this._Result(false, "failed", targetVolume, targetMuted, 0, totalCount)
        } finally {
            this._Busy := false
        }
    }

    ; ── 目标客户端 ──

    static _ResolveTargetPid() {
        pid := GameTarget.Pid()
        if (pid != 0 && this._IsGameProcess(pid))
            return pid
        return this._ForegroundGamePid()
    }

    ; 当前前台窗口属于游戏进程时返回其 PID，否则返回 0
    static _ForegroundGamePid() {
        hwnd := DllCall("GetForegroundWindow", "Ptr")
        if (!hwnd)
            return 0
        pid := 0
        DllCall("GetWindowThreadProcessId", "Ptr", hwnd, "UInt*", &pid)
        if (pid = 0)
            return 0
        return this._IsGameProcess(pid) ? pid : 0
    }

    ; PID 当前是否仍为游戏进程
    static _IsGameProcess(pid) {
        try {
            return StrLower(ProcessGetName(pid)) = StrLower(ServerProfile.ExeName)
        } catch Error {
            return false
        }
    }

    ; 目标 PID 变化视为切换客户端
    static _SwitchTarget(pid) {
        oldPid := this._TargetPid
        wasSync := this._SyncOn
        this._StopPolling()
        this._SyncOn := false
        this._HasTarget := false
        this._TargetVolume := 0
        this._TargetMuted := false
        this._Known := Map()
        this._TargetPid := pid
        if (oldPid != 0 && wasSync)
            Logger.Info("VolumeController", "切换音量目标客户端，原 pid=" oldPid " 停止同步；新 pid=" pid)
        else
            Logger.Info("VolumeController", "设定音量目标客户端 pid=" pid)
    }

    ; ── 同步状态机 ──

    static _StartSync(message) {
        if (this._SyncOn)
            return
        this._SyncOn := true
        this._StartPolling()
        Logger.Info("VolumeController", "开启音量同步：" message)
    }

    ; 停止同步
    static _StopSync(reason, clearState := false) {
        if (this._SyncOn) {
            this._SyncOn := false
            Logger.Info("VolumeController", "停止音量同步：" reason)
        }
        this._StopPolling()
        if (clearState) {
            this._HasTarget := false
            this._TargetVolume := 0
            this._TargetMuted := false
            this._TargetPid := 0
            this._Known := Map()
        }
    }

    static _StartPolling() {
        if (!IsObject(this._PollCallback))
            this.Init()
        SetTimer(this._PollCallback, this.POLL_INTERVAL_MS)
    }

    static _StopPolling() {
        if (IsObject(this._PollCallback))
            SetTimer(this._PollCallback, 0)
    }

    ; ── 状态判定 ──

    ; 0-100 整数音量是否落在容差内
    static _WithinTolerance(volume, expectedVolume) {
        return Abs(volume - expectedVolume) <= this.VOLUME_TOLERANCE
    }

    ; 音量超出容差或静音状态不同都算偏离
    static _IsDeviated(volume, muted, expectedVolume, expectedMuted) {
        return !this._WithinTolerance(volume, expectedVolume) || muted != expectedMuted
    }

    ; 500ms 轮询
    static _OnPoll() {
        if (!this._SyncOn || this._Busy)
            return
        this._Busy := true
        try {
            pid := this._TargetPid
            if (pid = 0 || !this._IsGameProcess(pid)) {
                this._StopSync("目标进程不存在", true)
                return
            }

            scan := this._Scan(pid)
            sessions := scan.sessions
            if (sessions.Length = 0)
                return

            current := Map()
            for session in sessions
                current[session.key] := session

            missing := []
            deviated := false
            for key, known in this._Known {
                if (!current.Has(key)) {
                    missing.Push(key)
                    continue
                }
                session := current[key]
                if (this._IsDeviated(session.volume, session.muted, known.volume, known.muted)) {
                    deviated := true
                    break
                }
            }
            for key in missing
                this._Known.Delete(key)

            if (deviated) {
                this._StopSync("检测到外部修改")
                return
            }

            applied := 0
            for session in sessions {
                if (this._Known.Has(session.key))
                    continue
                readVolume := 0
                readMuted := false
                if (this._WriteSession(session.volumeObj, this._TargetVolume, this._TargetMuted, &readVolume, &readMuted)) {
                    this._Known[session.key] := {volume: readVolume, muted: readMuted}
                    applied += 1
                }
            }
            if (applied > 0)
                Logger.Info("VolumeController", "新音频会话已同步，数量=" applied)
        } catch Error as e {
            this._ThrottledWarn("poll", "轮询音频会话失败：" e.Message)
        } finally {
            this._Busy := false
        }
    }

    ; ── 同步基准 ──

    static _SelectBenchmark(sessions, defaultDeviceId, hasLastTarget) {
        candidates := []
        if (hasLastTarget && this._Known.Count > 0) {
            for session in sessions {
                if (this._Known.Has(session.key))
                    candidates.Push(session)
            }
        }
        if (candidates.Length = 0) {
            for session in sessions {
                if (session.deviceId = defaultDeviceId)
                    return session
            }
            return sessions[1]
        }

        defaultCandidates := []
        deviatedCandidates := []
        for session in candidates {
            if (session.deviceId = defaultDeviceId)
                defaultCandidates.Push(session)
            if (this._IsDeviated(session.volume, session.muted, this._TargetVolume, this._TargetMuted))
                deviatedCandidates.Push(session)
        }
        for session in deviatedCandidates {
            if (session.deviceId = defaultDeviceId)
                return session
        }
        if (deviatedCandidates.Length > 0)
            return deviatedCandidates[1]
        if (defaultCandidates.Length > 0)
            return defaultCandidates[1]
        return candidates[1]
    }

    ; ── Core Audio 会话枚举与读写 ──

    ; 枚举活动播放设备上的目标进程音频会话
    static _Scan(pid) {
        result := {sessions: [], defaultDeviceId: ""}
        enumerator := ComObject(this.CLSID_MMDeviceEnumerator, this.IID_IMMDeviceEnumerator)

        try {
            defaultDevicePtr := 0
            ComCall(4, enumerator, "Int", this.EDATAFLOW_RENDER, "Int", this.EROLE_CONSOLE, "Ptr*", &defaultDevicePtr := 0)
            if (defaultDevicePtr) {
                defaultDevice := ComValue(13, defaultDevicePtr)
                defaultIdPtr := 0
                ComCall(5, defaultDevice, "Ptr*", &defaultIdPtr := 0)
                result.defaultDeviceId := this._TakeCoTaskMemString(defaultIdPtr)
            }
        } catch Error as e {
            this._ThrottledWarn("default_device", "读取默认输出设备失败：" e.Message)
        }

        collectionPtr := 0
        ComCall(3, enumerator, "Int", this.EDATAFLOW_RENDER, "UInt", this.DEVICE_STATE_ACTIVE, "Ptr*", &collectionPtr := 0)
        if (!collectionPtr)
            return result
        collection := ComValue(13, collectionPtr)
        deviceCount := 0
        ComCall(3, collection, "UInt*", &deviceCount := 0)

        iidBuffer := this._IidBuffer(this.IID_IAudioSessionManager2)
        loop deviceCount {
            deviceIndex := A_Index - 1
            try {
                devicePtr := 0
                ComCall(4, collection, "UInt", deviceIndex, "Ptr*", &devicePtr := 0)
                if (!devicePtr)
                    continue
                device := ComValue(13, devicePtr)
                deviceIdPtr := 0
                ComCall(5, device, "Ptr*", &deviceIdPtr := 0)
                deviceId := this._TakeCoTaskMemString(deviceIdPtr)
                managerPtr := 0
                ComCall(3, device, "Ptr", iidBuffer.Ptr, "UInt", this.CLSCTX_ALL, "Ptr", 0, "Ptr*", &managerPtr := 0)
                if (!managerPtr)
                    continue
                manager := ComValue(13, managerPtr)
                sessionEnumPtr := 0
                ComCall(5, manager, "Ptr*", &sessionEnumPtr := 0)
                if (!sessionEnumPtr)
                    continue
                sessionEnum := ComValue(13, sessionEnumPtr)
                sessionCount := 0
                ComCall(3, sessionEnum, "Int*", &sessionCount := 0)
                loop sessionCount {
                    sessionIndex := A_Index - 1
                    try {
                        session := this._ReadSession(sessionEnum, sessionIndex, pid, deviceId)
                        if (IsObject(session))
                            result.sessions.Push(session)
                    } catch Error as e {
                        this._ThrottledWarn("session", "读取音频会话失败：" e.Message)
                    }
                }
            } catch Error as e {
                this._ThrottledWarn("device", "枚举输出设备失败：" e.Message)
            }
        }
        return result
    }

    ; 读取单个会话
    static _ReadSession(sessionEnum, index, pid, deviceId) {
        sessionPtr := 0
        ComCall(4, sessionEnum, "Int", index, "Ptr*", &sessionPtr := 0)
        if (!sessionPtr)
            return ""
        session := ComValue(13, sessionPtr)
        control2 := ComObjQuery(session, this.IID_IAudioSessionControl2)
        sessionPid := 0
        ComCall(14, control2, "UInt*", &sessionPid := 0)
        if (sessionPid != pid)
            return ""
        instanceIdPtr := 0
        ComCall(13, control2, "Ptr*", &instanceIdPtr := 0)
        instanceId := this._TakeCoTaskMemString(instanceIdPtr)
        volumeObj := ComObjQuery(session, this.IID_ISimpleAudioVolume)
        level := 0.0
        ComCall(4, volumeObj, "Float*", &level := 0)
        muted := 0
        ComCall(6, volumeObj, "Int*", &muted := 0)
        return {
            key: deviceId "|" instanceId,
            deviceId: deviceId,
            instanceId: instanceId,
            volume: this._ToPercent(level),
            muted: (muted != 0),
            volumeObj: volumeObj
        }
    }

    ; 写入音量与静音并回读校验
    static _WriteSession(volumeObj, targetVolume, targetMuted, &readVolume, &readMuted) {
        try {
            ComCall(3, volumeObj, "Float", targetVolume / 100, "Ptr", 0)
            ComCall(5, volumeObj, "Int", (targetMuted ? 1 : 0), "Ptr", 0)
            level := 0.0
            ComCall(4, volumeObj, "Float*", &level := 0)
            muted := 0
            ComCall(6, volumeObj, "Int*", &muted := 0)
            readVolume := this._ToPercent(level)
            readMuted := (muted != 0)
            if (this._IsDeviated(readVolume, readMuted, targetVolume, targetMuted)) {
                message := "音频会话写入未生效：目标音量=" targetVolume " 回读音量=" readVolume
                message .= " 目标静音=" (targetMuted ? "是" : "否") " 回读静音=" (readMuted ? "是" : "否")
                this._ThrottledWarn("write_verify", message)
                return false
            }
            return true
        } catch Error as e {
            this._ThrottledWarn("write", "写入音频会话失败：" e.Message)
            return false
        }
    }

    ; 0-1 浮点音量转 0-100 整数百分比
    static _ToPercent(level) {
        return Min(this.VOLUME_MAX, Max(this.VOLUME_MIN, Round(level * 100)))
    }

    ; 取得 REFIID 缓冲区
    static _IidBuffer(iid) {
        if (!IsObject(this._IidBuffers))
            this._IidBuffers := Map()
        if (this._IidBuffers.Has(iid))
            return this._IidBuffers[iid]
        guidBuf := Buffer(16, 0)
        if (DllCall("ole32\CLSIDFromString", "WStr", iid, "Ptr", guidBuf.Ptr, "Int") != 0)
            throw Error("无法解析 COM 接口标识：" iid)
        this._IidBuffers[iid] := guidBuf
        return guidBuf
    }

    ; 取出 CoTaskMemAlloc 分配的宽字符串并释放
    static _TakeCoTaskMemString(ptr) {
        if (!ptr)
            return ""
        text := StrGet(ptr, "UTF-16")
        DllCall("ole32\CoTaskMemFree", "Ptr", ptr)
        return text
    }

    ; ── 结果与日志 ──

    static _NoSessionResult() {
        volume := (this._HasTarget ? this._TargetVolume : 0)
        muted := (this._HasTarget ? this._TargetMuted : false)
        return this._Result(false, "no_session", volume, muted, 0, 0)
    }

    static _Result(ok, reason, volume, muted, successCount, totalCount) {
        return {
            ok: ok,
            reason: reason,
            volume: volume,
            muted: muted,
            successCount: successCount,
            totalCount: totalCount
        }
    }

    static _ThrottledWarn(key, message) {
        now := A_TickCount
        if (this._Throttle.Has(key)) {
            elapsed := now - this._Throttle[key]
            if (elapsed >= 0 && elapsed < this.LOG_THROTTLE_MS)
                return
        }
        this._Throttle[key] := now
        Logger.Warn("VolumeController", message)
    }
}
