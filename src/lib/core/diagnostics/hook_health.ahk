; == 键盘钩子存活探针与自愈 ==
; 背景（#340，已由 afa-20260901-225024 日志实证）：AFA 全部热键注册在 HotIf 回调下，
; 每次按键都要主线程求值，求值期间钩子回调阻塞。主线程若超过系统低级钩子超时
; （LowLevelHooksTimeout，未配置时默认 300ms）无法响应，系统累计 11 次后即静默摘除键盘钩子，
; 表现为「所有快捷键突然失效，必须重启或重新注册热键才恢复」，且 AHK 自身无从感知。
;
; 观测手法：用**不依赖钩子**的 GetAsyncKeyState 采样已注册热键键位的物理按下沿，
; 与**依赖钩子**的热键回调计数（NoteFire）对照。观测到物理按下却在宽限期内没有任何热键回调
; ⇒ 记一次未命中；连续多次 ⇒ 判定钩子失效，落一份完整状态快照并按需自愈。
;
; 判读要点（实证）：快照里的 idle/idleKbd/idlePhys 三值恒等，说明 A_TimeIdleKeyboard 与
; A_TimeIdlePhysical 已退化为 A_TimeIdle（文档：钩子未安装时二者等价于 A_TimeIdle），
; 即钩子确已不再被调用；三值有差异则说明钩子仍在正常区分键盘与鼠标输入。
; 注意单看 idleKbd 数值大小无法判定——纯键盘输入时两种情况都接近 0，必须看三值是否恒等。
class HookHealth {
    ; ---- 可调参数 ----
    static PollIntervalMs := 100      ; 物理按键采样间隔
    static ReportIntervalMs := 5000   ; 异常期状态快照上报间隔
    static HeartbeatMs := 60000       ; 正常期心跳快照间隔（保留基线，便于事后比对三值是否恒等）
    static PressGraceMs := 800        ; 物理按下后等待热键回调的宽限（日志实测按住时长 85~590ms）
    static MissThreshold := 3         ; 连续多少次未命中判定为钩子失效
    static WatchRefreshMs := 5000     ; 监视键位表刷新间隔（纯内存，无 IO）
    static RecoverCooldownMs := 5000  ; 两次自愈之间的最小间隔，避免异常持续时反复重装钩子
    static AutoRecover := true        ; 已确认故障模式为钩子被系统摘除，默认开启自愈

    ; ---- 运行时状态 ----
    static _Timer := ""
    static _WatchKeys := Map()        ; vk -> pureKey
    static _PrevDown := Map()         ; vk -> true/false
    static _Pending := Map()          ; vk -> {tick, fire, key, idleKbd}
    static _FireCount := 0            ; 热键回调累计次数（由 NoteFire 递增）
    static _LastFireSeen := 0         ; 上一拍看到的回调计数，用于直接识别"回调恢复"
    static _MissStreak := 0
    static _MissTotal := 0
    static _Depth := 0                ; 当前在执行的动作线程数
    static _MaxDepth := 0
    static _InFlight := Map()         ; seq -> {name, tick}
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
        ; 回调计数增长即证明热键已能正常触发。直接在此判定恢复，不依赖建档：
        ; 旧实现只在"建档的按下被消费"时才判恢复，而恢复后的按键往往因动作正在执行
        ; 而不满足建档条件，导致恢复时刻从未被记录（首版探针实测缺陷）。
        if (this._FireCount != this._LastFireSeen) {
            this._LastFireSeen := this._FireCount
            this._NoteHit()
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
            this._Pending[vk] := {tick: now, fire: this._FireCount, key: pureKey, idleKbd: A_TimeIdleKeyboard}
        }
    }

    ; 是否把这次物理按下计入观测：
    ; - 游戏必须是前台（HotkeyContext 的键盘键放行前提）
    ; - 不是 AFA 自己注入的按键（注入按下窗口 / Up 补发抑制窗口）
    ; 注意不再因"有动作正在执行"而拒绝建档：动作执行期间其它热键本就应当能触发，
    ; 拒绝建档会连恢复判定一起挡掉；动作期间的误判改在结算时排除（见 _ResolvePending）。
    static _ShouldArm(pureKey) {
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
            ; 结算时仍有动作在执行：同键重入被 MaxThreadsPerHotkey 正常屏蔽，不算异常
            if (this._Depth > 0)
                continue
            this._MissTotal++
            this._MissStreak++
            Logger.Warn("HookHealth", "物理按下未触发热键：key=" info.key
                . "，按下瞬间 idleKbd=" info.idleKbd "ms"
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
