; == 键盘钩子健康探针（诊断用） ==
; 目的：区分"所有热键突然失效"的三种可能，仅观测不干预。
;   H1 系统静默移除低级键盘钩子（LowLevelHooksTimeout 累计超时 11 次，见 ahk_docs/lib/_HotIfTimeout.htm）
;      —— 现象：物理按键仍在（GetAsyncKeyState 可见），但热键回调完全不再发生。
;   H2 动作线程泄漏撞满 #MaxThreads（默认 10）—— 现象：_Depth / _InFlight 持续不归零。
;   H3 HotkeyContext 判定持续为 false —— 现象：钩子活着、线程也没堆积，但回调不发生。
;
; 核心手法：用**不依赖钩子**的 GetAsyncKeyState 采样已注册热键键位的物理按下沿，
; 与**依赖钩子**的热键回调计数（NoteFire）对照。观测到物理按下却在宽限期内没有任何热键回调
; ⇒ 记一次 miss；连续多次 ⇒ 判定"疑似钩子失效"并落一份完整状态快照。
;
; 约束：本类只做观测与日志，默认不做任何恢复动作（AutoRecover 置 true 才会调用
; InstallKeybdHook(true, true) —— 文档明确其可让被系统停用的钩子重新工作）。
class HookHealth {
    ; ---- 可调参数 ----
    static PollIntervalMs := 100      ; 物理按键采样间隔
    static ReportIntervalMs := 5000   ; 状态快照上报间隔（内容无变化时不落盘）
    static PressGraceMs := 800        ; 物理按下后等待热键回调的宽限（日志实测按住时长 85~590ms）
    static MissThreshold := 3         ; 连续多少次 miss 判定为疑似钩子失效
    static WatchRefreshMs := 5000     ; 监视键位表刷新间隔（纯内存，无 IO）
    static AutoRecover := false       ; 诊断版默认关闭：先取证，不要让自动恢复掩盖现场

    ; ---- 运行时状态 ----
    static _Timer := ""
    static _WatchKeys := Map()        ; vk -> pureKey
    static _PrevDown := Map()         ; vk -> true/false
    static _Pending := Map()          ; vk -> {tick, fire}
    static _FireCount := 0            ; 热键回调累计次数（由 NoteFire 递增）
    static _MissStreak := 0
    static _MissTotal := 0
    static _Depth := 0                ; 当前在执行的动作线程数
    static _MaxDepth := 0
    static _InFlight := Map()         ; seq -> {name, tick}
    static _Seq := 0
    static _NextReportTick := 0
    static _NextWatchTick := 0
    static _LastSnapshot := ""
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

    ; 热键回调发生（任何一次进入热键线程都应调用），供物理按下沿对照
    static NoteFire() {
        this._FireCount++
    }

    ; 动作线程进入：返回句柄，调用方必须在 finally 里 ExitAction(句柄)
    static EnterAction(name) {
        this.NoteFire()
        seq := ++this._Seq
        this._InFlight[seq] := {name: name, tick: A_TickCount}
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
            this._NextReportTick := now + this.ReportIntervalMs
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
            ; idleKbd = A_TimeIdleKeyboard，由**键盘钩子**维护（ahk_docs/Variables.htm）。
            ; 与 GetAsyncKeyState 观测到的这次物理按下对照，可直接区分故障层级：
            ;   idleKbd ≈ 0（≤ 采样间隔）→ 钩子看见了这次按键，问题在判定层/线程层（H2/H3）
            ;   idleKbd 远大于采样间隔      → 钩子根本没看见这次按键 = 钩子已被系统摘除（H1）
            this._Pending[vk] := {tick: now, fire: this._FireCount, key: pureKey, idleKbd: A_TimeIdleKeyboard}
        }
    }

    ; 是否把这次物理按下计入观测：
    ; - 游戏必须是前台（HotkeyContext 的键盘键放行前提）
    ; - 当前没有动作在跑（KeyWait 期间的同键重复按下本就被 MaxThreadsPerHotkey 屏蔽，非异常）
    ; - 不是 AFA 自己注入的按键（注入按下窗口 / Up 补发抑制窗口）
    static _ShouldArm(pureKey) {
        if (this._Depth > 0)
            return false
        if (!GameTarget.IsForegroundCached())
            return false
        if (GameKeys.IsInjectedPressPending(pureKey))
            return false
        if (KeyForward.SuppressUp.Has(pureKey))
            return false
        return true
    }

    ; 判定建档的物理按下是否被热键回调消费
    static _ResolvePending(now) {
        if (this._Pending.Count = 0)
            return
        settled := []
        for vk, info in this._Pending {
            if (this._FireCount > info.fire) {
                settled.Push(vk)                 ; 期间发生过热键回调 → 命中
                this._NoteHit()
                continue
            }
            if (now - info.tick < this.PressGraceMs)
                continue
            settled.Push(vk)
            this._MissTotal++
            this._MissStreak++
            Logger.Warn("HookHealth", "物理按下未触发热键：key=" info.key
                . "，按下瞬间 idleKbd=" info.idleKbd "ms（≈0 表示钩子仍看得见按键，很大表示钩子已失效）"
                . "，连续未命中=" this._MissStreak "，累计=" this._MissTotal)
            if (this._MissStreak >= this.MissThreshold)
                this._OnSuspected()
        }
        for vk in settled {
            if (this._Pending.Has(vk))
                this._Pending.Delete(vk)
        }
    }

    ; 物理按下被热键回调消费：清零连击计数；若此前已判定疑似失效，则记录"恢复时刻"
    ; ——用户"切换标签页"后热键复活的准确时间点会落在这一条上，可与重建热键日志对照。
    static _NoteHit() {
        this._MissStreak := 0
        if (!this._Suspected)
            return
        this._Suspected := false
        Logger.Warn("HookHealth", "热键回调已恢复（疑似钩子失效状态解除） | " this._Snapshot())
    }

    ; 连续未命中达阈值：落一份完整现场快照
    static _OnSuspected() {
        firstHit := !this._Suspected
        this._Suspected := true
        Logger.Warn("HookHealth", "疑似键盘钩子失效（连续 " this._MissStreak " 次物理按下无热键回调） | " this._Snapshot())
        if (firstHit)
            Logger.Warn("HookHealth", "判读指引：钩子已死=按键历史停更且本条持续出现；线程泄漏=depth/inflight 不归零；判定层为假=depth 归零且残留表为空")
        if (this.AutoRecover) {
            ; ahk_docs/lib/InstallKeybdHook.htm：Force=true 会卸载并重装钩子，
            ; "If the system has stopped calling the hook due to an unresponsive program, reinstalling the hook might get it working again."
            InstallKeybdHook(true, true)
            Logger.Warn("HookHealth", "已执行 InstallKeybdHook(true, true) 重装键盘钩子")
            this._MissStreak := 0
        }
    }

    ; ---- 周期快照 ----
    static _Report() {
        snapshot := this._Snapshot()
        ; 无异常且内容无变化时不落盘，避免刷爆日志轨
        if (!this._Suspected && this._Depth = 0 && snapshot == this._LastSnapshot)
            return
        this._LastSnapshot := snapshot
        if (this._Suspected)
            Logger.Warn("HookHealth", "现场快照 | " snapshot)
        else
            Logger.Debug("HookHealth", "快照 | " snapshot)
    }

    static _Snapshot() {
        return "idle=" A_TimeIdle ", idleKbd=" A_TimeIdleKeyboard ", idlePhys=" A_TimeIdlePhysical
            . ", fire=" this._FireCount ", miss=" this._MissTotal "/" this._MissStreak
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
            parts .= (parts = "" ? "" : " ") info.name "+" (now - info.tick) "ms"
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
