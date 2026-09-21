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
    static MissThreshold := 5         ; 连续多少次未命中判定为钩子失效。
                                      ; 原为 3：太少——动作本身耗时长（失焦悬停激活、触控注入段）会拉长宽限期附近的判定，
                                      ; 抬高阈值换更低的误报率；代价是真失效时多按两次键才触发自愈。
    static FireRaceWindowMs := 250    ; 按下沿与回调之间的竞态窗口：
                                      ; 探针 100ms 轮询晚于钩子回调，按下瞬间回调可能先跑、
                                      ; 探针后采样（档时快照已含本次回调计数），3000ms 后计数值不再
                                      ; 增长而误判"未触发"。窗口内已回调的按下直接视为命中、不建档。
    static WatchRefreshMs := 5000     ; 监视键位表刷新间隔（纯内存，无 IO）
    static RecoverCooldownMs := 30000 ; 两次自愈之间的最小间隔，避免异常持续时反复重装钩子。
                                      ; 原为 5s：Force 重装会**抢占其它进程已安装钩子的优先级**（见 _OnSuspected），
                                      ; 若真实原因是"输入被前置钩子吞掉"而非"钩子被摘除"，反复自愈只会把冲突搅得更乱，
                                      ; 故拉长到 30s，把抢占动作压到最低频率。
    static AutoRecover := true        ; 已确认故障模式为钩子被系统摘除，默认开启自愈

    ; ---- 运行时状态 ----
    static _Timer := ""
    static _WatchKeys := Map()        ; vk -> pureKey
    static _PrevDown := Map()         ; vk -> true/false
    static _Pending := Map()          ; vk -> {tick, key, idleKbd, fire}
    static _FireByKey := Map()        ; pureKey -> 该键热键回调累计次数（NoteFire 递增）
    static _FireTotal := 0            ; 全部热键回调累计次数
    static _LastFireTick := Map()     ; pureKey -> 该键最近一次回调时刻（按键隔离的命中判据，
                                      ; 兼作按下沿竞态窗口判定）
    static _LastUpEdge := Map()       ; pureKey -> 该键最近一次**抬起被采样到**的时刻。
                                      ; 竞态判定必须用它当基准（见 _SamplePhysicalKeys），不能用按下沿：
                                      ; 按下与热键回调几乎同时发生，而探针 100ms 才采一次，比较"谁更晚"不可靠。
    static _LastPressEdge := Map()    ; pureKey -> 该键最近一次**按下沿被采样到**的时刻。
                                      ; 竞态判定用它区分"回调属于本次按下还是上一次按下"——
                                      ; 快速连按（<250ms）时上一次的回调不应抑制本次建档
    static _LastWarnTick := Map()     ; pureKey -> 该键最近一次"未触发告警"时刻（键级持久冷却，见 _ResolvePending）
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
    ; ---- 探针自证计数（按纯键名累计，供快照 probe=[…] 与未命中 WARN 引用）----
    ; 判读式：arm ≈ cleared + miss + discard + watchDrop。
    ; 各字段含义：arm 建档 / raceSkip 因"回调已发生且尚未观测到抬起"跳过建档 / cleared 被回调清掉 /
    ; miss 超时判未触发 / discard 结算时前提失效（切窗、光标移出）/ watchDrop 该键已不在监视表。
    static _ProbeStats := Map()

    static _BumpProbe(pureKey, field) {
        if !this._ProbeStats.Has(pureKey)
            this._ProbeStats[pureKey] := {arm: 0, raceSkip: 0, cleared: 0, miss: 0, discard: 0, watchDrop: 0}
        stats := this._ProbeStats[pureKey]
        stats.%field% += 1
    }

    static _ProbeKeyStats(pureKey) {
        if !this._ProbeStats.Has(pureKey)
            return "arm=0,cleared=0"
        stats := this._ProbeStats[pureKey]
        return "arm=" stats.arm ",raceSkip=" stats.raceSkip ",cleared=" stats.cleared
            . ",miss=" stats.miss ",discard=" stats.discard ",watchDrop=" stats.watchDrop
    }

    static _ProbeSnapshot() {
        parts := ""
        for key, stats in this._ProbeStats {
            parts .= (parts = "" ? "" : " ") key "(arm=" stats.arm ",raceSkip=" stats.raceSkip
                . ",cleared=" stats.cleared ",miss=" stats.miss ",discard=" stats.discard
                . ",watchDrop=" stats.watchDrop ")"
        }
        return (parts = "" ? "(无)" : parts)
    }

    ; 该纯键名当前是否仍在监视表里（表是 vk -> pureKey，故按键名反查）
    static _IsWatchedKey(pureKey) {
        for _, watchedKey in this._WatchKeys {
            if (watchedKey = pureKey)
                return true
        }
        return false
    }

    ; 当前前台窗口句柄（建档时留档，结算时比对：换过窗口就作废该次观测）
    static _ForegroundHwnd() {
        return DllCall("GetForegroundWindow", "Ptr")
    }

    ; 启动探针（由 App.Bootstrap 在 HotkeyOn 之后调用，保证 ActiveHotkeys 已就绪）
    static Start() {
        if (this._Started)
            return
        this._Started := true
        this._RebuildWatchKeys()
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
        this._LastFireTick[pureKey] := A_TickCount
        ; 同键回调既然已经真实发生，立即结算并清掉该键挂起的按键，绝不误报为未触发
        if (this._ClearPendingFor(pureKey))
            this._BumpProbe(pureKey, "cleared")
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
        ; 立即刷新会把 _NextWatchTick 推后（见 RefreshWatchKeysNow），故用 > 0 判定是否已安排
        if (this._NextWatchTick > 0 && now >= this._NextWatchTick) {
            this._NextWatchTick := 0
            this._RebuildWatchKeys()
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
            if (!isDown) {
                ; 观测到抬起：记下来，作为"新的一次按下"的判据基准（见下面的竞态判定）
                if (wasDown)
                    this._LastUpEdge[pureKey] := now
                continue
            }
            if (wasDown)
                continue
            ; 新的物理按下沿：只在"本应触发热键"的条件下建档，避免误报
            if (!this._ShouldArm(pureKey))
                continue
            ; 按下-回调竞态窗口：探针 100ms 轮询必然晚于钩子回调，故不能比较"回调与按下沿谁更晚"。
            ; 判据改为：该键若刚发生过回调、且**自那以后我们还没见过它抬起**，说明这次按下就是那次
            ; 回调的来源，本次不该再建档（否则宽限期后无人清理，必然误报"未触发热键"）。
            ; 以"上次观测到抬起"为基准与采样快慢无关；漏掉抬起只会导致"本次不建档"（不误报），
            ; 不会削弱真失效的检测——那时回调计数长期不增长，下一次可辨识的按下仍会建档并如实报 miss。
            ; "新鲜度"边界必不可少：抬起与下一次按下都落在同一个 100ms 采样间隙内时，_LastUpEdge 会停在
            ; 旧值，单看 lastFire > lastUp 会把此后每次按下都跳过；回调若已过去很久（钩子已死、计数冻结），
            ; 那种"跳过"就会掩盖真失效。故只在回调足够新时才认定它属于本次按下。
            lastUp := this._LastUpEdge.Get(pureKey, 0)
            this._LastPressEdge[pureKey] := now
            lastFire := this._LastFireTick.Get(pureKey, 0)
            if (lastFire != 0 && lastFire > lastUp && now - lastFire < this.FireRaceWindowMs) {
                this._BumpProbe(pureKey, "raceSkip")
                continue
            }
            ; 记录按下瞬间的 idleKbd 备查。注意：钩子未安装时 A_TimeIdleKeyboard 会退化为 A_TimeIdle，
            ; 纯键盘输入下两种情况数值都接近 0，故**不能单看此值判定钩子存活**，
            ; 真正的判据是快照里 idle/idleKbd/idlePhys 三值是否恒等。
            ; fire：本次**按下时刻**该键的累计回调计数快照。结算时与之比较（而非用 Has 判断"曾触发"）——
            ; Has 会因该键历史上触发过而永远为真，导致钩子真失效后每次按下都被误判为命中、永不计 miss。
            ; fgHwnd：同步留档前台窗口，结算时比对（换过窗口则作废该次观测）。
            this._Pending[vk] := {tick: now, key: pureKey, idleKbd: A_TimeIdleKeyboard
                , fire: this._FireByKey.Get(pureKey, 0), fgHwnd: this._ForegroundHwnd()}
            this._BumpProbe(pureKey, "arm")
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
    ; 误报防护：告警冷却状态保存在键级持久表 _LastWarnTick（不随 _Pending 短生命周期销毁），
    ; 同键在冷却窗口内不再重复告警，避免按住连打时按一次刷一条。
    static _ResolvePending(now, ignorePointerPrecondition := false) {
        if (this._Pending.Count = 0)
            return
        settled := []
        for vk, info in this._Pending {
            if (now - info.tick < this.PendingGraceMs)
                continue
            ; 与按下时刻的快照相比仍有新回调 = 宽限期内确实发生过该键回调（迟到命中，
            ; 如失焦悬停激活路径的时间消耗超过监听窗口）——不记未命中，避免误报。
            ; 用计数差而非 Has：Has 只表示"该键历史上触发过"，钩子失效后不再成立将永远漏检。
            if (this._FireByKey.Get(info.key, 0) > info.fire) {
                settled.Push(vk)
                continue
            }
            ; 该键已不在监视表（热键被禁用/该分组被注销）⇒ 作废：没有回调是**正确**的，
            ; 前提已不存在。与键位集合变更时的即时刷新配套，作为第二道防线。
            if !this._IsWatchedKey(info.key) {
                this._BumpProbe(info.key, "watchDrop")
                settled.Push(vk)
                continue
            }
            if (this._Depth > 0)
                continue                    ; 同键重入被 MaxThreadsPerHotkey 正常屏蔽，不算异常
            ; 前台窗口变了 ⇒ 作废本次观测：热键是否该触发取决于前台（HotkeyContext），
            ; 建档时成立、结算时已失效的前提，不能再用来判"未触发"（否则切窗即误报）。
            if (info.HasOwnProp("fgHwnd") && info.fgHwnd != this._ForegroundHwnd()) {
                this._BumpProbe(info.key, "discard")
                settled.Push(vk)
                continue
            }
            ; 同理：鼠标键的触发前提是"光标在游戏客户区内"（HotkeyContext 的鼠标键分支）。
            ; 建档后把光标移出游戏窗口，热键同样按设计不触发——也不能记未命中。
            if (!ignorePointerPrecondition && IsMouseKey(info.key) && !IsMouseInClient()) {
                this._BumpProbe(info.key, "discard")
                settled.Push(vk)
                continue
            }
            lastWarn := this._LastWarnTick.Get(info.key, 0)
            if (lastWarn != 0 && now - lastWarn < this.MissWarnCooldownMs)
                continue                    ; 冷却期内不重复告警
            settled.Push(vk)
            this._LastWarnTick[info.key] := now
            this._MissTotal++
            this._MissStreak++
            this._BumpProbe(info.key, "miss")
            Logger.Warn("HookHealth", "物理按下未触发热键：key=" info.key
                . "，按下瞬间 idleKbd=" info.idleKbd "ms"
                . "，监听 " this.PendingGraceMs "ms 内无对应回调"
                . "，连续未命中=" this._MissStreak "，累计=" this._MissTotal
                . "，该键自证=" this._ProbeKeyStats(info.key))
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
        ; 但同一段文档也写明该动作 "has the effect of giving it precedence over any hooks previously installed by other processes"——
        ; 即自愈对"输入被前置钩子吞掉"这类冲突是**反向操作**，故日志必须把这句话说清楚，便于事后对照冲突时间线。
        Logger.Warn("HookHealth", "钩子自愈：已强制重装键盘钩子并抢占优先级（第 " this._RecoverCount " 次）"
            . "——若真实原因是输入被其它进程的前置钩子吞掉，本操作会改变钩子链优先级顺序；"
            . "连续未命中=" this._MissStreak "，冷却=" this.RecoverCooldownMs "ms，累计自愈=" this._RecoverCount)
        try {
            InstallKeybdHook(true, true)
            Logger.Warn("HookHealth", "钩子自愈完成（第 " this._RecoverCount " 次自愈），热键应即刻恢复")
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
            . ", recover=" this._RecoverCount
            . ", ctxEval=" this._FmtMs(HotkeyService._EvalMaxMs) "/" this._FmtMs(this._AvgMs(HotkeyService._EvalTotalMs, HotkeyService._EvalCount)) "ms(max/avg, n=" HotkeyService._EvalCount ")"
            . ", probe=[" this._ProbeSnapshot() "]（arm≈cleared+miss+discard+watchDrop 为正常）"
            . ", inflight=[" this._InFlightNames() "]"
            . ", SuppressUp=[" this._KeyList(KeyForward.SuppressUp) "]"
            . ", DownHandled=[" this._KeyList(KeyForward.DownHandled) "]"
            . ", Intercepted=[" this._KeyList(KeyForward.InterceptedKeys) "]"
            . ", InjectedPress=[" this._KeyList(GameKeys.InjectedPressKeys) "]"
    }

    static _AvgMs(totalMs, count) {
        return count > 0 ? totalMs / count : 0
    }

    ; 耗时统一一位小数定长输出（直接拼浮点会输出 0.30000000000000004 这类噪声；
    ; 而按整数值拼接又会时而是 "0" 时而是 "0.0"，事后解析不稳定）
    static _FmtMs(valueMs) {
        return Format("{:.1f}", valueMs)
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

    ; 键位集合刚发生变化（热键启用/禁用/分组重建）时由 HotkeyService 调用，立即重建监视表。
    ; 必须即时：定时刷新间隔是 5s，而 HotkeyOff/EnableByTab 会**立刻**清空 ActiveHotkeys；
    ; 若探针在此期间仍盯着已注销的键，就会为一次"本不该有回调"的按下建档，宽限期后误报未触发。
    static RefreshWatchKeysNow() {
        this._RebuildWatchKeys()
        this._NextWatchTick := A_TickCount + this.WatchRefreshMs
    }

    ; 监视键位表 = 当前已注册热键的纯键名（纯内存读取 HotkeyService.ActiveHotkeys，无 INI IO）
    static _RebuildWatchKeys() {
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
        for vk in stale {
            if (this._PrevDown.Has(vk))
                this._PrevDown.Delete(vk)
        }
        ; 键位下线后其抬起记录不再有意义，顺手清理，避免 Map 无界增长
        if (this._LastUpEdge.Count > 0) {
            known := Map()
            for _, pureKey in next
                known[pureKey] := true
            for key, _ in this._LastUpEdge {
                if !known.Has(key) {
                    try this._LastUpEdge.Delete(key)
                    catch UnsetItemError {
                    }
                }
            }
        }
    }
}
