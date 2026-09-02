; == 键盘钩子存活探针与自愈 ==
; 背景（#340）：AFA 全部热键注册在 HotIf 回调下，
; 每次按键都要主线程求值，求值期间钩子回调阻塞。主线程若超过系统低级钩子超时
; （LowLevelHooksTimeout，未配置时默认 300ms）无法响应，系统累计 11 次后即静默摘除键盘钩子，
; 表现为「所有快捷键突然失效，必须重启或重新注册热键才恢复」，且 AHK 自身无从感知。
;
; 观测手法：用**不依赖钩子**的 GetAsyncKeyState 采样已注册热键键位的物理按下沿，
; 与**依赖钩子**的热键回调计数（NoteFire）对照。观测到物理按下却在宽限期内没有任何热键回调
; ⇒ 记一次未命中；连续多次 ⇒ 判定钩子失效，落一份完整状态快照并按需自愈。
;
; 判读要点：快照里的 idle/idleKbd/idlePhys 三值恒等，说明 A_TimeIdleKeyboard 与
; A_TimeIdlePhysical 已退化为 A_TimeIdle（文档：钩子未安装时二者等价于 A_TimeIdle），
; 即钩子确已不再被调用；三值有差异则说明钩子仍在正常区分键盘与鼠标输入。
; 注意单看 idleKbd 数值大小无法判定——纯键盘输入时两种情况都接近 0，必须看三值是否恒等。
class HookHealth {
    ; ---- 可调参数 ----
    static PollIntervalMs := 100      ; 物理按键采样间隔
    static ReportIntervalMs := 5000   ; 异常期状态快照上报间隔
    static HeartbeatMs := 60000       ; 正常期心跳快照间隔（保留基线，便于事后比对三值是否恒等）
    static PendingGraceMs := 3000     ; 物理按下后等待同键热键回调的宽限。
                                      ; 必须覆盖"完整触发路径"：失焦悬停时的 WinActivate/WaitActive(200ms)
                                      ; + 动作执行（过帧档最长的 166ms 一组）+ 采样间隔余量。
                                      ; 过短会在激活路径耗时较长时把真实触发误判为未触发。
    static MissWarnCooldownMs := 5000 ; 同键误报节流：记录"未触发"告警后，该键短时间内不再重复告警，
                                      ; 避免按住连打时按一次刷一条
    static MissThreshold := 3         ; 连续多少次未命中判定为钩子失效
    static WatchRefreshMs := 5000     ; 监视键位表刷新间隔（纯内存，无 IO）
    static RecoverCooldownMs := 5000  ; 两次自愈之间的最小间隔，避免异常持续时反复重装钩子
    static AutoRecover := true        ; 已确认故障模式为钩子被系统摘除，默认开启自愈

    ; ---- 运行时状态 ----
    static _Timer := ""
    static _WatchKeys := Map()        ; vk -> pureKey
    static _PrevDown := Map()         ; vk -> true/false
    static _Pending := Map()          ; vk -> {tick, key, idleKbd, lastWarn}
    static _FireByKey := Map()        ; pureKey -> 该键热键回调累计次数（NoteFire 递增）
    static _FireTotal := 0            ; 全部热键回调累计次数
    static _MissStreak := 0
    static _MissTotal := 0
    static _Depth := 0                ; 当前在执行的动作线程数
    static _MaxDepth := 0
    static _InFlight := Map()         ; seq -> {name, key, tick}
    static _Seq := 0
    static _NextReportTick := 0
    static _NextWatchTick := 0
    static _LastRecoverTick := 0
    static _RecoverCount := 0
    static _Suspected := false
    static _Started := false

    ; 启动探针（由 App.Bootstrap 在 HotkeyOn 之后调用，保证 ActiveHotkeys 已就绪）
    static Start() {
        if (this._Started)
            return
        this._Started := true
        this._RefreshWatchKeys()
        if (this._Timer = "")
            this._Timer := HookHealth._Poll.Bind(HookHealth)
        SetTimer this._Timer, this.PollIntervalMs
        Logger.Info("HookHealth", "钩子健康探针已启动，采样=" this.PollIntervalMs "ms，监视键位=" this._WatchKeyNames())
    }

    ; 热键回调发生（任何一次进入热键线程都应调用），供物理按下沿对照。
    ; pureKey 必须传入：判定是否"命中"只看**同键**的回调——不同键的回调不能算作本次按下的结果，
    ; 否则某键按下后恰有另一键触发就会被误记为命中，同键在宽限期后才触发则会被误判为未命中。
    static NoteFire(pureKey) {
        if (pureKey == "")
            return
        this._FireTotal++
        this._FireByKey[pureKey] := this._FireByKey.Get(pureKey, 0) + 1
        ; 同键回调既然已经真实发生，立即结算并清掉该键挂起的按键，绝不误报为未触发
        this._ClearPendingFor(pureKey)
        if (this._Suspected)
            this._NoteHit()
    }

    static FireTotal() {
        return this._FireTotal
    }

    ; 动作线程进入：返回句柄，调用方必须在 finally 里 ExitAction(句柄)。
    ; pureKey 供快照展示"在飞线程按的是哪个键"（观测用，不参与命中判定）。
    static EnterAction(name, pureKey) {
        this.NoteFire(pureKey)
        seq := ++this._Seq
        this._InFlight[seq] := {name: name, key: pureKey, tick: A_TickCount}
        this._Depth++
        if (this._Depth > this._MaxDepth)
            this._MaxDepth := this._Depth
        return seq
    }

    ; 动作线程退出
    static ExitAction(seq) {
        if (this._InFlight.Has(seq))
            this._InFlight.Delete(seq)
        if (this._Depth > 0)
            this._Depth--
    }

    ; 某键发生真实回调：移除该键全部挂起观测。必要时返回是否存在待结算项，
    ; 以便调用方在判定恢复的同时清理连击计数。
    static _ClearPendingFor(pureKey) {
        if (this._Pending.Count = 0)
            return false
        stale := []
        for vk, info in this._Pending {
            if (info.key = pureKey)
                stale.Push(vk)
        }
        if (stale.Length = 0)
            return false
        for vk in stale
            this._Pending.Delete(vk)
        return true
    }

    ; ---- 采样主循环 ----
    static _Poll() {
        now := A_TickCount
        if (now >= this._NextWatchTick) {
            this._NextWatchTick := now + this.WatchRefreshMs
            this._RefreshWatchKeys()
        }
        this._SamplePhysicalKeys(now)
        this._ResolvePending(now)
        if (now >= this._NextReportTick) {
            this._NextReportTick := now + (this._Suspected ? this.ReportIntervalMs : this.HeartbeatMs)
            this._Report()
        }
    }

    ; 采样物理按下沿。GetAsyncKeyState 由系统维护，不经过本进程的钩子——
    ; 这正是"钩子已死但按键仍在"能被观测到的原因。
    static _SamplePhysicalKeys(now) {
        for vk, pureKey in this._WatchKeys {
            isDown := (DllCall("GetAsyncKeyState", "Int", vk, "Short") & 0x8000) != 0
            wasDown := this._PrevDown.Has(vk) && this._PrevDown[vk]
            this._PrevDown[vk] := isDown
            if (!isDown || wasDown)
                continue
            ; 新的物理按下沿：只在"本应触发热键"的条件下建档，避免误报
            if (!this._ShouldArm(pureKey))
                continue
            ; 记录按下瞬间的 idleKbd 备查。注意：钩子未安装时 A_TimeIdleKeyboard 会退化为 A_TimeIdle，
            ; 纯键盘输入下两种情况数值都接近 0，故**不能单看此值判定钩子存活**，
            ; 真正的判据是快照里 idle/idleKbd/idlePhys 三值是否恒等。
            this._Pending[vk] := {tick: now, key: pureKey, idleKbd: A_TimeIdleKeyboard, lastWarn: 0}
        }
    }

    ; 是否把这次物理按下计入观测：
    ; - 游戏必须是前台（HotkeyContext 的键盘键放行前提）
    ; - 不是 AFA 自己注入的按键（注入按下窗口 / Up 补发抑制窗口）
    static _ShouldArm(pureKey) {
        if (!GameTarget.IsForegroundCached())
            return false
        if (GameKeys.IsInjectedPressPending(pureKey))
            return false
        if (KeyForward.SuppressUp.Has(pureKey))
            return false
        return true
    }

    ; 结算挂起的物理按下：宽限期已过且该键的回调确实没有发生才算"未触发"。
    ; 命中判定完全按键隔离（NoteFire 里已按同键即时结算），此处只处理超时未决项。
    ; 误报防护：只告警一次并记录告警时刻，同键在冷却窗口内不再重复刷（按住连打场景）。
    static _ResolvePending(now) {
        if (this._Pending.Count = 0)
            return
        settled := []
        for vk, info in this._Pending {
            if (now - info.tick < this.PendingGraceMs)
                continue
            if (this._FireByKey.Has(info.key)) {
                ; 该键在宽限期结束前至少触发过一次回调——此为迟到命中（如失焦悬停激活路径
                ; 的时间消耗超过监听窗口），不记未命中，避免把"实际已触发"误报为故障。
                settled.Push(vk)
                continue
            }
            if (this._Depth > 0)
                continue                    ; 同键重入被 MaxThreadsPerHotkey 正常屏蔽，不算异常
            if (info.lastWarn != 0 && now - info.lastWarn < this.MissWarnCooldownMs)
                continue                    ; 冷却期内不重复告警，但也别拖到下一次按下
            settled.Push(vk)
            info.lastWarn := now
            this._MissTotal++
            this._MissStreak++
            Logger.Warn("HookHealth", "物理按下未触发热键：key=" info.key
                . "，按下瞬间 idleKbd=" info.idleKbd "ms"
                . "，监听 " this.PendingGraceMs "ms 内无对应回调（若随后看到该键的 Action 执行日志，则本条为误报，可忽略）"
                . "，连续未命中=" this._MissStreak "，累计=" this._MissTotal)
            if (this._MissStreak >= this.MissThreshold)
                this._OnSuspected()
        }
        for vk in settled {
            if (this._Pending.Has(vk))
                this._Pending.Delete(vk)
        }
    }

    ; 热键回调恢复：清零连击计数；若此前已判定失效，记录恢复时刻，
    ; 便于与「热键已重建」日志或自愈记录对照，确认恢复由谁触发。
    static _NoteHit() {
        this._MissStreak := 0
        if (!this._Suspected)
            return
        this._Suspected := false
        this._NextReportTick := 0
        Logger.Warn("HookHealth", "热键回调已恢复 | " this._Snapshot())
    }

    ; 连续未命中达阈值：落一份完整现场快照，并按需自愈
    static _OnSuspected() {
        firstHit := !this._Suspected
        this._Suspected := true
        Logger.Warn("HookHealth", "键盘钩子疑似失效（连续 " this._MissStreak " 次物理按下无热键回调） | " this._Snapshot())
        if (firstHit)
            Logger.Warn("HookHealth", "判读指引：三值 idle/idleKbd/idlePhys 恒等=钩子已被系统摘除；depth/inflight 不归零=动作线程泄漏；三值有差异且残留表非空=状态残留")
        if (!this.AutoRecover)
            return
        if (this._LastRecoverTick != 0 && A_TickCount - this._LastRecoverTick < this.RecoverCooldownMs)
            return
        this._LastRecoverTick := A_TickCount
        this._RecoverCount++
        ; ahk_docs/lib/InstallKeybdHook.htm：Force=true 会卸载并重装钩子，
        ; "If the system has stopped calling the hook due to an unresponsive program, reinstalling the hook might get it working again."
        try {
            InstallKeybdHook(true, true)
            Logger.Warn("HookHealth", "已重装键盘钩子（第 " this._RecoverCount " 次自愈），热键应即刻恢复")
        } catch Error as e {
            Logger.Exception("HookHealth", e, "重装键盘钩子失败")
        }
        this._MissStreak := 0
    }

    ; ---- 周期快照 ----
    ; 正常期按心跳节奏留基线（三值是否恒等是事后判读的关键依据），
    ; 异常期与有动作在飞/状态表非空时提高到 ReportIntervalMs，保证现场完整。
    static _Report() {
        if (this._Suspected) {
            Logger.Warn("HookHealth", "现场快照 | " this._Snapshot())
            return
        }
        Logger.Debug("HookHealth", "心跳 | " this._Snapshot())
    }

    static _Snapshot() {
        return "idle=" A_TimeIdle ", idleKbd=" A_TimeIdleKeyboard ", idlePhys=" A_TimeIdlePhysical
            . ", fire=" this._FireTotal ", miss=" this._MissTotal "/" this._MissStreak
            . ", depth=" this._Depth "(max " this._MaxDepth ")"
            . ", inflight=[" this._InFlightNames() "]"
            . ", SuppressUp=[" this._KeyList(KeyForward.SuppressUp) "]"
            . ", DownHandled=[" this._KeyList(KeyForward.DownHandled) "]"
            . ", Intercepted=[" this._KeyList(KeyForward.InterceptedKeys) "]"
            . ", InjectedPress=[" this._KeyList(GameKeys.InjectedPressKeys) "]"
    }

    static _InFlightNames() {
        parts := "", now := A_TickCount
        for _, info in this._InFlight
            parts .= (parts = "" ? "" : " ") info.name "/" info.key "+" (now - info.tick) "ms"
        return parts
    }

    static _KeyList(source) {
        parts := ""
        for key, _ in source
            parts .= (parts = "" ? "" : " ") key
        return parts
    }

    static _WatchKeyNames() {
        parts := ""
        for _, pureKey in this._WatchKeys
            parts .= (parts = "" ? "" : " ") pureKey
        return parts
    }

    ; 监视键位表 = 当前已注册热键的纯键名（纯内存读取 HotkeyService.ActiveHotkeys，无 INI IO）
    static _RefreshWatchKeys() {
        next := Map()
        for _, hotkeyValue in HotkeyService.ActiveHotkeys {
            pureKey := KeyForward.PureKeyName(hotkeyValue)
            if (pureKey == "" || InStr(pureKey, "wheel"))
                continue
            vk := 0
            try {
                vk := GetKeyVK(pureKey)
            } catch Error {
                continue
            }
            if (vk = 0 || next.Has(vk))
                continue
            next[vk] := pureKey
        }
        this._WatchKeys := next
        ; 清理已下线键位的采样状态，避免 Map 无限增长
        stale := []
        for vk, _ in this._PrevDown {
            if (!next.Has(vk))
                stale.Push(vk)
        }
        for vk in stale
            this._PrevDown.Delete(vk)
    }
}
