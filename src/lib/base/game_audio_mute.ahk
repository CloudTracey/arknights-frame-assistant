; COM 接口只在单次快照内存活。
class GameAudioSession {
    __New(device, pid, status, volume) {
        this.device := device
        this.pid := pid, this.status := status, this.volume := volume
    }
    GetMute() {
        value := 0
        hr := ComCall(6, this.volume, "Int*", &value, "Int")
        if hr < 0
            throw Error(GameAudioMute._FormatHResult(hr))
        return !!value
    }
    SetMute(value) {
        hr := ComCall(5, this.volume, "Int", value, "Ptr", 0, "Int")
        if hr < 0
            throw Error(GameAudioMute._FormatHResult(hr))
        if this.GetMute() != !!value
            throw Error("音频会话静音状态回读不一致")
    }
    GetVolume() {
        value := 0.0
        hr := ComCall(4, this.volume, "Float*", &value, "Int")
        if hr < 0
            throw Error(GameAudioMute._FormatHResult(hr))
        return value
    }
    SetVolume(value) {
        if value < 0 || value > 1
            throw ValueError("音量必须在 0 到 1 之间")
        hr := ComCall(3, this.volume, "Float", value, "Ptr", 0, "Int")
        if hr < 0
            throw Error(GameAudioMute._FormatHResult(hr))
        if Abs(this.GetVolume() - value) > 0.0001
            throw Error("音频会话音量回读不一致")
    }
    Release() {
        if this.volume {
            ComCall(2, this.volume)
            this.volume := 0
        }
    }
}
class GameAudioMute {
    static CLSID_MMDeviceEnumerator := "{BCDE0395-E52F-467C-8E3D-C4579291692E}"
    static IID_IMMDeviceEnumerator := "{A95664D2-9614-4F35-A746-DE8DB63617E6}"
    static IID_IAudioSessionManager2 := "{77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F}"
    static IID_IAudioSessionControl2 := "{BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D}"
    static IID_ISimpleAudioVolume := "{87CE5498-68D6-44E5-9215-6DA47EF883D8}"
    static _GuidBuffer(text) {
        guidBuffer := Buffer(16)
        hr := DllCall("ole32\CLSIDFromString", "WStr", text, "Ptr", guidBuffer, "Int")
        if hr < 0
            throw Error(this._FormatHResult(hr))
        return guidBuffer
    }
    static _FormatHResult(hr) => Format("0x{:08X}", hr & 0xFFFFFFFF)
    static _String(control, method) {
        value := 0
        hr := ComCall(method, control, "Ptr*", &value, "Int")
        if hr < 0 || !value
            throw Error(this._FormatHResult(hr))
        try return StrGet(value, "UTF-16")
        finally DllCall("ole32\CoTaskMemFree", "Ptr", value)
    }
    static Capture(targets) {
        snapshot := {sessions: [], defaultDevice: "", failed: 0, message: ""}
        enumerator := 0, collection := 0
        try {
            clsid := this._GuidBuffer(this.CLSID_MMDeviceEnumerator)
            iid := this._GuidBuffer(this.IID_IMMDeviceEnumerator)
            hr := DllCall("ole32\CoCreateInstance", "Ptr", clsid, "Ptr", 0, "UInt", 0x17, "Ptr", iid, "Ptr*", &enumerator, "Int")
            if hr < 0
                throw Error(this._FormatHResult(hr))
            defaultDevice := 0
            try {
                hr := ComCall(4, enumerator, "Int", 0, "Int", 1, "Ptr*", &defaultDevice, "Int")
                if hr >= 0 && defaultDevice
                    snapshot.defaultDevice := this._String(defaultDevice, 5)
            } finally {
                if defaultDevice
                    ComCall(2, defaultDevice)
            }
            hr := ComCall(3, enumerator, "Int", 0, "UInt", 1, "Ptr*", &collection, "Int")
            if hr < 0
                throw Error(this._FormatHResult(hr))
            count := 0
            hr := ComCall(3, collection, "UInt*", &count, "Int")
            if hr < 0
                throw Error(this._FormatHResult(hr))
            Loop count {
                device := 0
                try {
                    hr := ComCall(4, collection, "UInt", A_Index - 1, "Ptr*", &device, "Int")
                    if hr < 0 {
                        throw Error(this._FormatHResult(hr))
                    }
                    this._Device(device, targets, snapshot)
                } catch Error as e {
                    snapshot.failed++, snapshot.message := e.Message
                } finally {
                    if device
                        ComCall(2, device)
                }
            }
        } catch Error as e {
            snapshot.failed++, snapshot.message := e.Message
        } finally {
            if collection
                ComCall(2, collection)
            if enumerator
                ComCall(2, enumerator)
        }
        return snapshot
    }
    static _Device(device, targets, snapshot) {
        deviceId := this._String(device, 5)
        manager := 0, sessions := 0
        try {
            iid := this._GuidBuffer(this.IID_IAudioSessionManager2)
            hr := ComCall(3, device, "Ptr", iid, "UInt", 0x17, "Ptr", 0, "Ptr*", &manager, "Int")
            if hr < 0
                throw Error(this._FormatHResult(hr))
            hr := ComCall(5, manager, "Ptr*", &sessions, "Int")
            if hr < 0
                throw Error(this._FormatHResult(hr))
            count := 0
            hr := ComCall(3, sessions, "Int*", &count, "Int")
            if hr < 0
                throw Error(this._FormatHResult(hr))
            controlIid := this._GuidBuffer(this.IID_IAudioSessionControl2)
            volumeIid := this._GuidBuffer(this.IID_ISimpleAudioVolume)
            Loop count {
                control := 0, control2 := 0, volume := 0
                try {
                    hr := ComCall(4, sessions, "Int", A_Index - 1, "Ptr*", &control, "Int")
                    if hr < 0
                        throw Error(this._FormatHResult(hr))
                    hr := ComCall(0, control, "Ptr", controlIid, "Ptr*", &control2, "Int")
                    if hr < 0
                        throw Error(this._FormatHResult(hr))
                    pid := 0
                    hr := ComCall(14, control2, "UInt*", &pid, "Int")
                    if hr = 0x0889000D
                        continue
                    if hr < 0 {
                        snapshot.failed++, snapshot.message := this._FormatHResult(hr)
                        continue
                    }
                    if !pid || !targets.Has(pid)
                        continue
                    status := 0
                    hr := ComCall(3, control2, "Int*", &status, "Int")
                    if hr < 0
                        throw Error(this._FormatHResult(hr))
                    if status = 2
                        continue
                    hr := ComCall(0, control2, "Ptr", volumeIid, "Ptr*", &volume, "Int")
                    if hr < 0
                        throw Error(this._FormatHResult(hr))
                    snapshot.sessions.Push(GameAudioSession(deviceId, pid, status, volume))
                    volume := 0 ; 接口所有权移交给快照
                } catch Error as e {
                    snapshot.failed++, snapshot.message := e.Message
                } finally {
                    if volume
                        ComCall(2, volume)
                    if control2
                        ComCall(2, control2)
                    if control
                        ComCall(2, control)
                }
            }
        } finally {
            if sessions
                ComCall(2, sessions)
            if manager
                ComCall(2, manager)
        }
    }
    static ReleaseSnapshot(snapshot) {
        for session in snapshot.sessions
            session.Release()
    }
}
