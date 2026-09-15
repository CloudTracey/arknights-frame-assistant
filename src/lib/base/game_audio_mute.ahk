; == 游戏音频静音（按进程） ==
; base 层能力封装：把指定进程（游戏客户端）的音频会话静音 / 取消静音，不引用 core/ui。
;
; 实现方式：Windows Core Audio（WASAPI）
;   枚举全部活动渲染设备 → 逐设备 IAudioSessionManager2 枚举会话
;   → IAudioSessionControl2.GetProcessId 匹配目标进程
;   → ISimpleAudioVolume.SetMute / GetMute 写入或读取静音状态
; 因此静音只作用于游戏自己的音频流，语音软件、音乐播放器等不受影响（不同于系统级静音）。
; 对全部设备统一操作：多音频设备（耳机/音箱）切换、或静音后新插入设备时，状态保持一致。
;
; 这些 Core Audio 接口不是 IDispatch，AHK 的 ComObject 无法直接调用其方法，
; 故用 CoCreateInstance + ComCall 按 vtable 下标调用（下标见各方括号内注释，取自 Windows SDK 头文件）。

class GameAudioMute {
    ; MMDeviceEnumerator 与音频会话相关接口标识
    static CLSID_MMDeviceEnumerator := "{BCDE0395-E52F-467C-8E3D-C4579291692E}"
    static IID_IMMDeviceEnumerator := "{A95664D2-9614-4F35-A746-DE8DB63617E6}"
    static IID_IAudioSessionManager2 := "{77AA99A0-1BD6-484F-8BC7-2C654C9A9B6F}"
    static IID_IAudioSessionControl2 := "{BFB7FF88-7239-4FC9-8FA2-07C950BE9C6D}"
    static IID_ISimpleAudioVolume := "{87CE5498-68D6-44E5-9215-6DA47EF883D8}"
    static CLSCTX_ALL := 0x17
    ; eRender(0)：渲染（输出）端点；DEVICE_STATE_ACTIVE(0x1)：只枚举处于活动状态的设备
    static E_RENDER := 0
    static DEVICE_STATE_ACTIVE := 0x1
    ; 「静音维持」巡检间隔（毫秒）：静音生效后低频巡检全部设备，
    ; 新插入设备 / 切换默认设备导致出现未静音的游戏会话时自动补静音
    static WATCH_INTERVAL_MS := 500
    static _watchPid := 0
    static _watchTimer := 0

    ; 功能：解析当前要操作的游戏进程 PID
    ; 参数：无
    ; 返回：整数 PID；找不到游戏进程时返回 0
    static ResolveGamePid() {
        ; 优先使用 GameTarget 已绑定的客户端，多客户端（如同时开着官服与 B 服）时不会误操作另一个
        if (GameTarget.IsBound()) {
            pid := GameTarget.Pid()
            if (pid && ProcessExist(pid))
                return pid
        }
        ; 回退：任意一个游戏进程（与热键路径一致，宽松回退集中在 ServerProfile）
        return ProcessExist(ServerProfile.ExeName)
    }

    ; 功能：切换指定进程的静音状态（已静音则取消静音，否则静音）
    ; 参数：pid - 目标进程 PID
    ; 返回：结果对象，字段说明见 _Scan；额外带 previous 表示切换前的静音状态
    static Toggle(pid) {
        current := this._Scan(pid, "query")
        ; 查询失败或该进程没有音频会话时不再往下走，避免把"没有会话"误报成"已静音"
        if (!current.success || current.found = 0)
            return current
        result := this._Scan(pid, current.muted ? "unmute" : "mute")
        result.previous := current.muted
        return result
    }

    ; 功能：读取指定进程当前的静音状态
    ; 参数：pid - 目标进程 PID
    ; 返回：结果对象（muted = 该进程的全部音频会话是否都处于静音）
    static Query(pid) {
        return this._Scan(pid, "query")
    }

    ; 功能：把指定进程的音频会话强制设为静音或取消静音
    ; 参数：pid  - 目标进程 PID
    ;       mute - true 静音 / false 取消静音
    ; 返回：结果对象
    static SetMute(pid, mute) {
        return this._Scan(pid, mute ? "mute" : "unmute")
    }

    ; 功能：开启「静音维持」巡检（在静音生效后由动作层调用）
    ; 背景：静音只作用于按键时刻已存在的设备会话；此后新插入的设备、或游戏把声音
    ;       切到此前未出声的设备，都会以未静音状态重新出声。低频巡检全部活动渲染
    ;       设备，发现目标进程存在未静音会话时静默补静音，不打扰用户。
    ; 参数：pid - 目标进程 PID
    ; 返回：无
    static StartMuteWatch(pid) {
        this._watchPid := pid
        if (this._watchTimer)
            return
        ; SetTimer 按函数对象引用匹配，Bind 每次产生新引用，必须缓存后复用
        this._watchTimer := this._WatchTick.Bind(this)
        SetTimer(this._watchTimer, this.WATCH_INTERVAL_MS)
    }

    ; 功能：停止「静音维持」巡检（取消静音、操作失败或游戏进程退出时调用）
    ; 参数：无
    ; 返回：无
    static StopMuteWatch() {
        this._watchPid := 0
        if (this._watchTimer)
            SetTimer(this._watchTimer, 0)
    }

    ; 功能：巡检回调：目标进程的会话出现未静音状态时静默补静音；进程退出则自动停止
    ; 参数：无
    ; 返回：无
    static _WatchTick() {
        pid := this._watchPid
        ; 游戏进程已退出：会话随进程消失，静音状态自然失效，停止巡检
        if (!pid || !ProcessExist(pid)) {
            this.StopMuteWatch()
            return
        }
        state := this.Query(pid)
        ; 游戏暂无音频会话（还没出声）：等下一轮，不做任何操作
        if (state.found = 0)
            return
        if (state.muted)
            return
        ; 出现未静音会话（新设备插入、默认设备切换等）：静默补静音
        fixed := this.SetMute(pid, true)
        if (!fixed.success || !fixed.muted)
            Logger.Debug("GameAudioMute", "静音维持巡检补静音未完全成功：pid=" pid "，" fixed.message)
        else
            Logger.Debug("GameAudioMute", "静音维持巡检已补静音：pid=" pid " 会话数=" fixed.found)
    }

    ; 功能：扫描全部活动渲染设备上指定进程的音频会话并执行操作
    ; 参数：pid  - 目标进程 PID
    ;       mode - "query" 只读 / "mute" 静音 / "unmute" 取消静音
    ; 返回：{success, found, total, muted, failed, previous, message}
    ;       success  - 是否无失败项（false 时 message 为技术细节，供日志与报错展示）
    ;       found    - 命中的音频会话数（0 表示该进程当前没有音频会话，例如游戏还没出声）
    ;       total    - 全部设备上枚举到的会话总数（诊断用）
    ;       muted    - 操作后是否处于静音（found=0 时为 false）
    ;       failed   - 操作失败的会话数
    ;       previous - 切换前的静音状态（仅 Toggle 填写，其余为 false）
    ;       message  - 失败原因（HRESULT 或异常文本），正常为空字符串
    static _Scan(pid, mode) {
        stats := {found: 0, total: 0, failed: 0, mutedCount: 0,
                  deviceCount: 0, deviceFailed: 0, message: ""}
        if (!pid) {
            stats.failed++
            stats.message := "未指定目标进程"
            return this._Result(stats)
        }
        clsid := this._GuidBuffer(this.CLSID_MMDeviceEnumerator)
        enumeratorIid := this._GuidBuffer(this.IID_IMMDeviceEnumerator)
        pEnumerator := 0
        hr := DllCall("ole32\CoCreateInstance", "Ptr", clsid.Ptr, "Ptr", 0, "UInt", this.CLSCTX_ALL,
            "Ptr", enumeratorIid.Ptr, "Ptr*", &pEnumerator, "Int")
        if (hr != 0 || !pEnumerator) {
            Logger.Warn("GameAudioMute", "创建音频设备枚举器失败，HRESULT=" this._FormatHResult(hr))
            stats.failed++
            stats.message := this._FormatHResult(hr)
            return this._Result(stats)
        }
        pCollection := 0
        try {
            ; IMMDeviceEnumerator::EnumAudioEndpoints（vtable 3）：全部活动渲染设备
            hr := ComCall(3, pEnumerator, "Int", this.E_RENDER, "UInt", this.DEVICE_STATE_ACTIVE,
                "Ptr*", &pCollection, "Int")
            if (hr != 0 || !pCollection) {
                this._Fail(stats, hr, "枚举音频设备失败")
                return this._Result(stats)
            }
            try {
                ; IMMDeviceCollection::GetCount（vtable 3）
                deviceCount := 0
                hr := ComCall(3, pCollection, "UInt*", &deviceCount, "Int")
                if (hr != 0) {
                    this._Fail(stats, hr, "获取音频设备数量失败")
                    return this._Result(stats)
                }
                control2Iid := this._GuidBuffer(this.IID_IAudioSessionControl2)
                volumeIid := this._GuidBuffer(this.IID_ISimpleAudioVolume)
                Loop deviceCount {
                    pDevice := 0
                    try {
                        ; IMMDeviceCollection::Item（vtable 4）
                        hr := ComCall(4, pCollection, "UInt", A_Index - 1, "Ptr*", &pDevice, "Int")
                        if (hr = 0 && pDevice) {
                            stats.deviceCount++
                            ; 单个设备失败（被禁用、驱动异常等）不终止整体：
                            ; 其余设备上游戏会话仍可正常处理
                            try {
                                this._ScanDevice(pDevice, pid, mode, stats, control2Iid, volumeIid)
                            } catch Error as e {
                                stats.deviceFailed++
                                stats.message := e.Message
                                Logger.Info("GameAudioMute", "跳过异常音频设备：" e.Message)
                            }
                        } else if (hr != 0) {
                            stats.deviceFailed++
                            stats.message := this._FormatHResult(hr)
                            Logger.Info("GameAudioMute", "获取音频设备失败，HRESULT=" stats.message)
                        }
                    } finally {
                        if (pDevice)
                            ComCall(2, pDevice)
                    }
                }
            } finally {
                if (pCollection)
                    ComCall(2, pCollection)
            }
        } finally {
            ComCall(2, pEnumerator)
        }
        return this._Result(stats)
    }

    ; 功能：在指定渲染设备上枚举会话并处理命中目标进程的会话
    ; 参数：pDevice - IMMDevice 接口指针
    ;       pid     - 目标进程 PID
    ;       mode    - 操作模式（同 _Scan）
    ;       stats   - 累计统计对象（原地更新）
    ;       control2Iid / volumeIid - 预解析的接口 GUID（避免循环内重复解析）
    ; 返回：无；设备级失败（激活/枚举失败）记 INFO 跳过，不拖垮整体结果
    static _ScanDevice(pDevice, pid, mode, stats, control2Iid, volumeIid) {
        pManager := 0, pSessionEnum := 0
        try {
            ; IMMDevice::Activate（vtable 3）：激活 IAudioSessionManager2
            managerIid := this._GuidBuffer(this.IID_IAudioSessionManager2)
            hr := ComCall(3, pDevice, "Ptr", managerIid.Ptr, "UInt", this.CLSCTX_ALL, "Ptr", 0,
                "Ptr*", &pManager, "Int")
            if (hr != 0 || !pManager) {
                stats.deviceFailed++
                stats.message := this._FormatHResult(hr)
                Logger.Info("GameAudioMute", "音频设备激活会话管理器失败，HRESULT=" stats.message)
                return
            }
            ; IAudioSessionManager2::GetSessionEnumerator（vtable 5）
            hr := ComCall(5, pManager, "Ptr*", &pSessionEnum, "Int")
            if (hr != 0 || !pSessionEnum) {
                stats.deviceFailed++
                stats.message := this._FormatHResult(hr)
                Logger.Info("GameAudioMute", "获取音频会话枚举器失败，HRESULT=" stats.message)
                return
            }
            ; IAudioSessionEnumerator::GetCount（vtable 3）
            sessionCount := 0
            hr := ComCall(3, pSessionEnum, "Int*", &sessionCount, "Int")
            if (hr != 0) {
                stats.deviceFailed++
                stats.message := this._FormatHResult(hr)
                Logger.Info("GameAudioMute", "获取音频会话数量失败，HRESULT=" stats.message)
                return
            }
            Loop sessionCount {
                pControl := 0, pControl2 := 0, pVolume := 0
                try {
                    ; IAudioSessionEnumerator::GetSession（vtable 4）
                    hr := ComCall(4, pSessionEnum, "Int", A_Index - 1, "Ptr*", &pControl, "Int")
                    if (hr = 0 && pControl) {
                        stats.total++
                        ; QueryInterface → IAudioSessionControl2（只需它才能取进程 PID）
                        hr := ComCall(0, pControl, "Ptr", control2Iid.Ptr, "Ptr*", &pControl2, "Int")
                        if (hr = 0 && pControl2) {
                            ; IAudioSessionControl2::GetProcessId（在 IAudioSessionControl 基础上偏移，vtable 14）
                            sessionPid := 0
                            hr := ComCall(14, pControl2, "UInt*", &sessionPid, "Int")
                            if (hr != 0) {
                                ; 无法判断归属进程（已退出进程的残留会话、系统会话等），
                                ; 属预期内情况（如残留会话常态返回 0x0889000D），跳过即可：
                                ; 不计失败，用 INFO 记录，避免污染错误日志
                                Logger.Info("GameAudioMute", "跳过无法识别进程的音频会话，HRESULT="
                                    this._FormatHResult(hr))
                            } else if (sessionPid = pid) {
                                ; QueryInterface → ISimpleAudioVolume
                                hr := ComCall(0, pControl2, "Ptr", volumeIid.Ptr, "Ptr*", &pVolume, "Int")
                                if (hr = 0 && pVolume)
                                    this._ApplyToSession(pVolume, mode, stats)
                                else if (hr != 0)
                                    this._Fail(stats, hr, "获取会话音量接口失败")
                            }
                        }
                    }
                } catch Error as e {
                    stats.failed++
                    stats.message := e.Message
                    Logger.Error("GameAudioMute", "处理音频会话失败：" e.Message)
                }
                ; 每次迭代内取得的接口立即释放，避免漏引用
                if (pVolume)
                    ComCall(2, pVolume)
                if (pControl2)
                    ComCall(2, pControl2)
                if (pControl)
                    ComCall(2, pControl)
            }
        } finally {
            if (pSessionEnum)
                ComCall(2, pSessionEnum)
            if (pManager)
                ComCall(2, pManager)
        }
    }

    ; 功能：读取并（按需）写入单个音频会话的静音状态
    ; 参数：pVolume - ISimpleAudioVolume 接口指针
    ;       mode    - 操作模式（同 _Scan）
    ;       stats   - 累计统计对象（原地更新）
    ; 返回：无
    static _ApplyToSession(pVolume, mode, stats) {
        stats.found++
        muted := 0
        ; ISimpleAudioVolume::GetMute（vtable 6）
        hr := ComCall(6, pVolume, "Int*", &muted, "Int")
        if (hr != 0) {
            stats.failed++
            stats.message := this._FormatHResult(hr)
            return
        }
        if (mode = "query") {
            if (muted)
                stats.mutedCount++
            return
        }
        ; ISimpleAudioVolume::SetMute（vtable 5）：第二个参数是事件上下文 GUID，可为 NULL
        target := (mode = "mute") ? 1 : 0
        hr := ComCall(5, pVolume, "Int", target, "Ptr", 0, "Int")
        if (hr != 0) {
            stats.failed++
            stats.message := this._FormatHResult(hr)
            return
        }
        ; 回读确认写入结果，避免把失败的写入报成已生效
        after := 0
        hr := ComCall(6, pVolume, "Int*", &after, "Int")
        if (hr != 0) {
            ; 写入已成功但回读失败：不能把默认的 after=0 当成"未静音"报给用户
            stats.failed++
            stats.message := this._FormatHResult(hr)
            Logger.Warn("GameAudioMute", "回读静音状态失败，HRESULT=" stats.message)
            return
        }
        if (after)
            stats.mutedCount++
    }

    ; 功能：记录一次操作失败（累计计数 + 保存 HRESULT 文案 + 写日志）
    ; 参数：stats - 累计统计对象；hr - 失败的 HRESULT；what - 失败环节描述
    ; 返回：无
    static _Fail(stats, hr, what) {
        stats.failed++
        stats.message := this._FormatHResult(hr)
        Logger.Warn("GameAudioMute", what "，HRESULT=" stats.message)
    }

    ; 功能：把统计对象整理成对外结果对象
    ; 参数：stats - 累计统计对象
    ; 返回：{success, found, total, muted, failed, previous, message}
    static _Result(stats) {
        success := (stats.failed = 0)
        ; 全部设备都异常且一个会话都没命中：把设备级失败上升为整体失败，
        ; 避免被误报成"没有游戏音频会话"；只要命中过会话，单设备异常就不影响结论
        if (success && stats.found = 0 && stats.deviceCount > 0 && stats.deviceFailed = stats.deviceCount)
            success := false
        return {
            success: success,
            found: stats.found,
            total: stats.total,
            ; 全部命中的会话都处于静音才算"已静音"
            muted: (stats.found > 0 && stats.failed = 0 && stats.mutedCount = stats.found),
            failed: stats.failed,
            previous: false,
            message: stats.message
        }
    }

    ; 功能：把 GUID 字符串解析成 16 字节结构体（交给 ole32 解析，避免手写字节序）
    ; 参数：guid - 形如 "{XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX}" 的 GUID 字符串
    ; 返回：Buffer（16 字节）；解析失败抛异常
    static _GuidBuffer(guid) {
        ; 注意：变量名不能叫 buffer —— AHK 变量名大小写不敏感，会与内置类 Buffer 同名冲突，
        ; 求值 Buffer(...) 时被当作读取未赋值的局部变量而抛 UnsetError。
        guidBuffer := Buffer(16, 0)
        parseResult := DllCall("Ole32\CLSIDFromString", "WStr", guid, "Ptr", guidBuffer.Ptr, "Int")
        if (parseResult != 0)
            throw Error("GUID 解析失败：" guid)
        return guidBuffer
    }

    ; 功能：把 HRESULT 格式化成可读文本（用于日志与报错）
    ; 参数：hr - HRESULT 整数
    ; 返回：形如 "0x80070005" 的字符串
    static _FormatHResult(hr) {
        return Format("0x{:08X}", hr & 0xFFFFFFFF)
    }
}
