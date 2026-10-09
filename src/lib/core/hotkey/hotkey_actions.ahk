; == 按键透传（守卫拦截时还原原键输入） ==
class KeyForward {
    static InterceptedKeys := Map()
    static DownHandled := Map()          ; down 已被 AFA 主热键处理过的键：Up 变体据此决定是否放行补发 key up
    static SuppressUp := Map()           ; 补发 up 期间的递归抑制记录
    static GuardLogIntervalMs := 100     ; 守卫拦截日志节流
    static _GuardLogNextTick := 0
    static ReentryWindowMs := 50
    static _LastForwardTick := Map()     ; 记录每个键上一次成功补发 up 的时刻，用于识别"同一按住周期内出现极短间隔二次补发"
    static _LastForwardDownTick := Map() ; 每个键最近一次"真实按下"的时刻
    ; 判定当前时刻是否应记录守卫拦截日志
    static ShouldLogGuard() {
        if (A_TickCount < this._GuardLogNextTick)
            return false
        this._GuardLogNextTick := A_TickCount + this.GuardLogIntervalMs
        return true
    }
    ; 提取纯键名
    static PureKeyName(ThisHotkey) {
        side := ""
        if (SubStr(ThisHotkey, 1, 1) = "<")
            side := "L"
        else if (SubStr(ThisHotkey, 1, 1) = ">")
            side := "R"
        pureKey := RegExReplace(ThisHotkey, "^[~*$!^+#&<>()]+")
        pureKey := RegExReplace(pureKey, "i) Up$")
        if (pureKey == "")
            return ""
        ; 左右前缀 + 通用修饰键名 → 对应侧规范键名
        if (side != "") {
            static ModNames := Map("shift", "Shift", "ctrl", "Ctrl", "control", "Control", "alt", "Alt", "win", "Win")
            if ModNames.Has(StrLower(pureKey))
                pureKey := side ModNames[StrLower(pureKey)]
        }
        ; Hotkey 名称大小写不敏感，但 Map 键默认大小写敏感
        return StrLower(GetKeyName(pureKey))
    }
    ; 透传原热键给游戏
    static ForwardOriginalKey(ThisHotkey) {
        if (ThisHotkey == "")
            return
        if InStr(ThisHotkey, "~")
            return
        isUp := InStr(ThisHotkey, " Up", false)
        pureKey := this.PureKeyName(ThisHotkey)
        if (pureKey == "")
            return
        ; 滚轮：无 down/up 状态，直接发送完整事件
        if InStr(pureKey, "Wheel") {
            hw := 0
            if (pureKey = "WheelUp")
                hw := 0x0800, delta := 120
            else if (pureKey = "WheelDown")
                hw := 0x0800, delta := -120
            else if (pureKey = "WheelLeft")
                hw := 0x1000, delta := -120  ; MOUSEEVENTF_HWHEEL，负值=向左
            else if (pureKey = "WheelRight")
                hw := 0x1000, delta := 120   ; MOUSEEVENTF_HWHEEL，正值=向右
            else {
                Logger.Warn("KeyForward", "不支持的滚轮透传键：" pureKey)
                return
            }
            DllCall("user32\mouse_event", "UInt", hw, "UInt", 0, "UInt", 0, "Int", delta, "Ptr", 0)
            return
        }
        if isUp {
            if !this.InterceptedKeys.Has(pureKey)
                Send "{Blind}{" pureKey " Down}"
            Send "{Blind}{" pureKey " Up}"
            return
        }
        ; 长按自动重复期间只保留一组逻辑 Down/Up。
        if this.InterceptedKeys.Has(pureKey)
            return
        ; 记录真实按下时刻
        this._LastForwardDownTick[pureKey] := A_TickCount
        this.InterceptedKeys[pureKey] := true
        try {
            Send "{Blind}{" pureKey " Down}"
        } catch Error as e {
            this.InterceptedKeys.Delete(pureKey)
            Logger.Exception("KeyForward", e, "透传 Down 失败：key=" pureKey)
            throw
        }
    }
    ; Up 变体热键统一回调：结束按住周期，并给被拦截的键补发 key up
    static ActionUpForward(ThisHotkey) {
        pureKey := this.PureKeyName(ThisHotkey)
        if (pureKey == "")
            return
        HoldGuard.EndHoldMs(pureKey)
        ; 防递归
        if KeyForward.SuppressUp.Has(pureKey)
            return
        ; 迟到抬起
        if HoldGuard.WasClosedByFallback(pureKey) {
            Logger.Info("KeyForward", "迟到抬起：key=" pureKey "（该按住周期已由兜底路径收尾，跳过补发）")
            return
        }
        if GameKeys.IsInjectedPressPending(pureKey) {
            Logger.Info("KeyForward", "抑制透传 Up：key=" pureKey "（注入按下未完成，避免同帧补发吞掉注入按下）")
            return
        }
        prevTick := this._LastForwardTick.Has(pureKey) ? this._LastForwardTick[pureKey] : 0
        if (prevTick != 0 && A_TickCount - prevTick <= this.ReentryWindowMs && this._LastForwardDownTick.Has(pureKey)) {
            if (this._LastForwardDownTick[pureKey] < prevTick) {
                Logger.Info("KeyForward", "Up 补发疑似回环：key=" pureKey "，距上次补发 " (A_TickCount - prevTick) "ms"
                    . "，DownHandled=" (KeyForward.DownHandled.Has(pureKey) ? "1" : "0")
                    . "，Intercepted=" (this.InterceptedKeys.Has(pureKey) ? "1" : "0")
                    . "，A_ThisHotkey=" ThisHotkey)
            }
        }
        this._LastForwardTick[pureKey] := A_TickCount
        KeyForward.SuppressUp[pureKey] := true
        try {
            Send "{Blind}{" pureKey " Up}"
            if (this.InterceptedKeys.Has(pureKey))
                this.InterceptedKeys.Delete(pureKey)
            if (KeyForward.DownHandled.Has(pureKey))
                KeyForward.DownHandled.Delete(pureKey)
            downTick := this._LastForwardDownTick.Get(pureKey, 0)
            if (downTick != 0)
                Logger.Info("KeyForward", "透传 key=" pureKey "（按住 " (A_TickCount - downTick) "ms）")
            else
                Logger.Info("KeyForward", "透传 Up：key=" pureKey "（无配对按下记录）")
        } catch Error as e {
            Logger.Exception("KeyForward", e, "透传 Up 失败：key=" pureKey)
        } finally {
            try {
                KeyForward.SuppressUp.Delete(pureKey)
            } catch UnsetItemError {
            }
        }
    }
}

class HoldGuard {
    static PollIntervalMs := 300           ; 兜底轮询间隔
    static HoldLogIntervalMs := 3000       ; 按住周期活跃时的节流观测
    static LateUpWindowMs := 1000          ; 兜底收尾后，抑制迟到物理 up 的时间窗
    static PollHeartbeatMs := 5000         ; 轮询心跳观测间隔（诊断用）
    static SwallowDetectDelayMs := 1000    ; 结束按住周期后仍认为按下多久即判定抬起被吞（诊断用）

    static _Holds := Map()                 ; pureKey -> {tick}
    static _Tails := Map()                 ; pureKey -> 按住周期结束时执行的收尾回调
    static _PhysDown := Map()              ; pureKey -> 定时器最近一次看到的物理态
    static _ClosedTick := Map()            ; pureKey -> 最近一次由兜底路径关闭按住周期的时刻
    static _LastLogTick := Map()
    static _ClosedCycle := Map()           ; pureKey -> 结束按住周期的 tick（抬起被吞自检用）
    static _IsGatedKey := Map()            ; pureKey -> false 表示该键不参与按住去重
    static _LastHeartbeatTick := 0
    static _PollTicks := 0
    static _Timer := ""

    static Init() {
        this._Holds.CaseSense := false
        this._Tails.CaseSense := false
        this._PhysDown.CaseSense := false
        this._ClosedTick.CaseSense := false
        this._LastLogTick.CaseSense := false
        this._ClosedCycle.CaseSense := false
        this._IsGatedKey.CaseSense := false
        if (this._Timer = "") {
            this._Timer := HoldGuard.Poll.Bind(HoldGuard)
            SetTimer this._Timer, this.PollIntervalMs
            Logger.Info("HoldGuard", "兜底轮询已启动，间隔=" this.PollIntervalMs "ms（物理态校验 + 跳变自愈）")
        }
    }

    ; 清空状态（热键重建/禁用时调用）
    static Stop() {
        this._Holds.Clear()
        this._Tails.Clear()
        this._PhysDown.Clear()
        this._ClosedTick.Clear()
        this._LastLogTick.Clear()
        this._ClosedCycle.Clear()
        this._IsGatedKey.Clear()
    }

    ; 该键是否参与按住去重
    static ShouldGate(pureKey) {
        if (pureKey = "" || InStr(pureKey, "wheel"))
            return false
        return this._IsGatedKey.Get(pureKey, true)
    }

    ; _RegisterOne 登记不参与去重的键（Up 型热键等）
    static MarkUngated(pureKey) {
        if (pureKey != "")
            this._IsGatedKey[pureKey] := false
    }

    ; 该键当前是否处于按住周期（供按住型动作的物理态兜底判断）
    static IsHolding(pureKey) {
        return pureKey != "" && this._Holds.Has(pureKey)
    }

    ; 动作入口调用
    static TryBegin(pureKey) {
        if (pureKey = "")
            return false
        if (this._Holds.Has(pureKey))
            return true
        this._Holds[pureKey] := {tick: A_TickCount}
        this._LastLogTick[pureKey] := A_TickCount
        if (this._ClosedCycle.Has(pureKey))
            this._ClosedCycle.Delete(pureKey)
        return false
    }

    ; 注册按住周期结束时的收尾回调
    static RegisterTail(pureKey, fn) {
        if (pureKey = "")
            return
        this._Tails[pureKey] := fn
    }

    ; 物理抬起
    static EndHoldMs(pureKey, reason := "up") {
        if (pureKey = "" || !this._Holds.Has(pureKey))
            return 0
        held := A_TickCount - this._Holds[pureKey].tick
        this._Holds.Delete(pureKey)
        if (this._LastLogTick.Has(pureKey))
            this._LastLogTick.Delete(pureKey)
        if (this._PhysDown.Has(pureKey))
            this._PhysDown.Delete(pureKey)
        if (reason = "fallback") {
            this._ClosedTick[pureKey] := A_TickCount
            Logger.Info("HoldGuard", "兜底结束按住周期：key=" pureKey "，按住 " held "ms（物理态已抬起或跳变自愈；"
                . "数百 ms 内的短按多为此前动作处于 Critical 段导致 Up 变体迟到，属预期）")
        } else {
            if (this._ClosedTick.Has(pureKey))
                this._ClosedTick.Delete(pureKey)
            if (held >= this.HoldLogIntervalMs)
                Logger.Info("HoldGuard", "按住周期结束：key=" pureKey "，按住 " held "ms")
        }
        this._ClosedCycle[pureKey] := A_TickCount
        this._RunTail(pureKey)
        return held
    }

    ; 该键的按住周期是否刚由兜底路径结束
    static WasClosedByFallback(pureKey) {
        if (pureKey = "" || !this._ClosedTick.Has(pureKey))
            return false
        closed := this._ClosedTick[pureKey]
        this._ClosedTick.Delete(pureKey)
        return (A_TickCount - closed) <= this.LateUpWindowMs
    }

    static _PhysDownSnapshot() {
        parts := ""
        for pureKey, _ in this._Holds
            parts .= (parts = "" ? "" : " ") pureKey "=" (this._PhysDown.Has(pureKey) && this._PhysDown[pureKey] ? "down" : "up/unknown")
        return (parts = "" ? "(无)" : parts)
    }

    static _RunTail(pureKey) {
        if !this._Tails.Has(pureKey)
            return
        fn := this._Tails[pureKey]
        this._Tails.Delete(pureKey)
        try {
            fn()
        } catch Error as e {
            Logger.Exception("HoldGuard", e, "按住周期收尾回调失败：key=" pureKey)
        }
    }

    ; 兜底轮询
    static _VerifyReleased() {
        for pureKey, closedTick in this._ClosedCycle.Clone() {
            if !this.ShouldGate(pureKey) {
                this._ClosedCycle.Delete(pureKey)
                continue
            }
            if !this._Holds.Has(pureKey) && GetKeyState(pureKey, "P") = 0 {
                this._ClosedCycle.Delete(pureKey)
                continue
            }
            if (A_TickCount - closedTick >= this.SwallowDetectDelayMs) {
                this._ClosedCycle.Delete(pureKey)
                if this._Holds.Has(pureKey)
                    continue
                Logger.Warn("HoldGuard", "抬起被吞：key=" pureKey "（结束按住周期已 " (A_TickCount - closedTick)
                    . "ms，系统仍认为该键处于按下）。该键的抬起事件未到达系统，属设备/驱动层丢事件；"
                    . "在被吞状态清除前，系统与游戏都会认为该键一直被按住")
            }
        }
    }

    static Poll() {
        this._PollTicks++
        if (this._Holds.Count = 0) {
            this._VerifyReleased()
            return
        }
        now := A_TickCount
        for pureKey, info in this._Holds {
            isDown := false
            try {
                isDown := GetKeyState(pureKey, "P") = 1
            } catch Error {
                isDown := true    ; 键名不可查询时保守按"仍按下"处理，交给跳变路径
            }
            if !this._PhysDown.Has(pureKey) {
                this._PhysDown[pureKey] := isDown
                continue
            }
            prevDown := this._PhysDown[pureKey]
            this._PhysDown[pureKey] := isDown

            if !isDown {
                this.EndHoldMs(pureKey, "fallback")
                continue
            }
            if !prevDown {
                Logger.Warn("HoldGuard", "按住周期自愈：key=" pureKey "，检测到抬起事件丢失后的新按下"
                    . "（按住周期已持续 " (now - info.tick) "ms）")
                this.EndHoldMs(pureKey, "fallback")
                continue
            }
            if (now - this._LastLogTick.Get(pureKey, 0) >= this.HoldLogIntervalMs) {
                this._LastLogTick[pureKey] := now
                Logger.Info("HoldGuard", "按住周期：key=" pureKey " 已按住 " Round((now - info.tick) / 1000, 1)
                    . "s（物理态仍为按下；正常长按，若用户已松手则是抬起事件丢失、等待跳变自愈）")
            }
        }
        if (this._Holds.Count > 0 && now - this._LastHeartbeatTick >= this.PollHeartbeatMs) {
            this._LastHeartbeatTick := now
            Logger.Info("HoldGuard", "轮询心跳：tick=" this._PollTicks "，活跃按住周期=" this._Holds.Count "，物理态=" this._PhysDownSnapshot())
        }
        this._VerifyReleased()
    }
}

; == 功能实现 ==
class HotkeyActions {
    ; -- 常规作战 --
    ; 按下暂停
    static ActionPressPause(ThisHotkey) {
        if !GuardInLevel("ActionPressPause", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        Logger.Info("HotkeyActions", "ActionPressPause 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        Thread "NoTimers"
        ; ESC 同帧竞态防护：ESC 也在拦截正则内（守卫热键绑定 ESC 时），物理松开的补发 up 与注入 down 同帧会丢失按下
        GameKeys.MarkInjectedPress("Escape")
        Send "{ESC Down}"
        USleep(50)
        GameKeys.UnmarkInjectedPress("Escape")
        Send "{ESC Up}"
        Thread "NoTimers", false
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 松开暂停
    static ActionReleasePause(ThisHotkey) {
        if !GuardInLevel("ActionReleasePause", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        Logger.Info("HotkeyActions", "ActionReleasePause 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("pauseBattle")
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 切换倍速
    static ActionGameSpeed(ThisHotkey) {
        if !GuardInLevel("ActionGameSpeed", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        Logger.Info("HotkeyActions", "ActionGameSpeed 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        Thread "NoTimers"
        GameKeys.SendDown("changeSpeed")
        USleep(50)
        GameKeys.SendUp("changeSpeed")
        Thread "NoTimers", false
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 前进档位1，原先为前进16ms，现可自定义
    static Action16ms(ThisHotkey) {
        this._FrameSkip("Action16ms", "FrameSkip16msDelay", ThisHotkey)
    }
    ; 前进档位2，原先为前进33ms
    static Action33ms(ThisHotkey) {
        this._FrameSkip("Action33ms", "FrameSkip33msDelay", ThisHotkey)
    }
    ; 前进档位3，原先为前进166ms
    static Action166ms(ThisHotkey) {
        this._FrameSkip("Action166ms", "FrameSkip166msDelay", ThisHotkey)
    }

    ; 过帧通用实现：ESC 触发暂停后按配置延迟发送 pauseBattle
    static _FrameSkip(actionName, delayConfigKey, ThisHotkey) {
        if !GuardInLevel(actionName, ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        Logger.Info("HotkeyActions", actionName " 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        delay := Integer(Config.ReadCustomFromIni(delayConfigKey))
        Critical
        ; ESC 同帧竞态防护：ESC 也在拦截正则内（守卫热键绑定 ESC 时），物理松开的补发 up 与注入 down 同帧会丢失按下
        GameKeys.MarkInjectedPress("Escape")
        Send "{ESC Down}"
        USleep(delay)
        GameKeys.SendDown("pauseBattle")
        USleep(50)
        GameKeys.UnmarkInjectedPress("Escape")
        Send "{ESC Up}"
        GameKeys.SendUp("pauseBattle")
        Critical "Off"
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 暂停选中
    static ActionPauseSelect(ThisHotkey) {
        if !GuardInLevel("ActionPauseSelect", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Info("HotkeyActions", "ActionPauseSelect 跳过：鼠标不在客户端")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        PosL := PauseButtonPositionLeft()
        PosR := PauseButtonPositionRight()
        if !PosL || !PosR {
            Logger.Warn("HotkeyActions", "ActionPauseSelect 跳过：游戏窗口不存在")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Logger.Info("HotkeyActions", "ActionPauseSelect 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        MouseGetPos &xpos, &ypos
        Thread "NoTimers"
        TouchInjector.Tap(PosL.PBLX, PosL.PBLY)
        TouchInjector.Tap(xpos, ypos)
        TouchInjector.Tap(PosR.PBRX, PosR.PBRY)
        USleep(TimingService.GetCurrentDelay() * 1.5)
        TouchInjector.Move(xpos, ypos)
        MouseMove xpos, ypos
        Thread "NoTimers", false
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 发送技能键
    static ActionSkill(ThisHotkey) {
        if !GuardInLevel("ActionSkill", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        Logger.Info("HotkeyActions", "ActionSkill 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("releaseSkill")
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 发送撤退键
    static ActionRetreat(ThisHotkey) {
        if !GuardInLevel("ActionRetreat", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        Logger.Info("HotkeyActions", "ActionRetreat 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("retreatChar")
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 一键技能
    static ActionOneClickSkill(ThisHotkey) {
        if !GuardInLevel("ActionOneClickSkill", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Info("HotkeyActions", "ActionOneClickSkill 跳过：鼠标不在客户端")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Logger.Info("HotkeyActions", "ActionOneClickSkill 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        Thread "NoTimers"
        Send "{LButton Down}"
        Send "{LButton Up}"
        USleep(TimingService.GetClickDelay())
        GameKeys.Tap("releaseSkill")
        Thread "NoTimers", false
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 一键撤退
    static ActionOneClickRetreat(ThisHotkey) {
        if !GuardInLevel("ActionOneClickRetreat", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Info("HotkeyActions", "ActionOneClickRetreat 跳过：鼠标不在客户端")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Logger.Info("HotkeyActions", "ActionOneClickRetreat 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        ; NoTimers 挡定时器轮询的时序干扰，允许其他热键中断（Critical 会连热键一起挡）
        Thread "NoTimers"
        Send "{LButton Down}"
        Send "{LButton Up}"
        USleep(TimingService.GetClickDelay())
        GameKeys.Tap("retreatChar")
        Thread "NoTimers", false
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 暂停技能
    static ActionPauseSkill(ThisHotkey) {
        if !GuardInLevel("ActionPauseSkill", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Info("HotkeyActions", "ActionPauseSkill 跳过：鼠标不在客户端")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        PosL := PauseButtonPositionLeft()
        PosR := PauseButtonPositionRight()
        if !PosL || !PosR {
            Logger.Warn("HotkeyActions", "ActionPauseSkill 跳过：游戏窗口不存在")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Logger.Info("HotkeyActions", "ActionPauseSkill 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        MouseGetPos &xpos, &ypos
        Thread "NoTimers"
        TouchInjector.Tap(PosL.PBLX, PosL.PBLY)
        TouchInjector.Tap(xpos, ypos)
        TouchInjector.Tap(PosR.PBRX, PosR.PBRY)
        USleep(TimingService.GetClickDelay())
        GameKeys.SendDown("releaseSkill")
        USleep(Max(TimingService.GetCurrentDelay() * 1.5 - TimingService.GetClickDelay(), 0))
        TouchInjector.Move(xpos, ypos)
        MouseMove xpos, ypos
        USleep(50)
        GameKeys.SendUp("releaseSkill")
        Thread "NoTimers", false
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 暂停撤退
    static ActionPauseRetreat(ThisHotkey) {
        if !GuardInLevel("ActionPauseRetreat", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Info("HotkeyActions", "ActionPauseRetreat 跳过：鼠标不在客户端")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        PosL := PauseButtonPositionLeft()
        PosR := PauseButtonPositionRight()
        if !PosL || !PosR {
            Logger.Warn("HotkeyActions", "ActionPauseRetreat 跳过：游戏窗口不存在")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Logger.Info("HotkeyActions", "ActionPauseRetreat 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        MouseGetPos &xpos, &ypos
        Thread "NoTimers"
        TouchInjector.Tap(PosL.PBLX, PosL.PBLY)
        TouchInjector.Tap(xpos, ypos)
        TouchInjector.Tap(PosR.PBRX, PosR.PBRY)
        USleep(TimingService.GetClickDelay())
        GameKeys.SendDown("retreatChar")
        USleep(Max(TimingService.GetCurrentDelay() * 1.5 - TimingService.GetClickDelay(), 0))
        TouchInjector.Move(xpos, ypos)
        MouseMove xpos, ypos
        USleep(50)
        GameKeys.SendUp("retreatChar")
        Thread "NoTimers", false
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }

    ; 视角切换
    static ActionSwitchView(ThisHotkey) {
        if !GuardInLevel("ActionSwitchView", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Info("HotkeyActions", "ActionSwitchView 跳过：鼠标不在客户端")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        PosL := PauseButtonPositionLeft()
        PosR := PauseButtonPositionRight()
        if !PosL || !PosR {
            Logger.Warn("HotkeyActions", "ActionSwitchView 跳过：游戏窗口不存在")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Logger.Info("HotkeyActions", "ActionSwitchView 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        MouseGetPos &xpos, &ypos
        Thread "NoTimers"
        TouchInjector.Tap(PosL.PBLX, PosL.PBLY)
        TouchInjector.Tap(xpos, ypos)
        TouchInjector.Tap(PosR.PBRX, PosR.PBRY)
        TouchInjector.Tap(xpos, ypos)
        Thread "NoTimers", false
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 快捷切换开局暂停开关
    static ActionBeginPauseSwitch(ThisHotkey) {
        currentValue := Config.GetImportant("AutoBeginPause")
        newValue := (currentValue = "1") ? "0" : "1"
        ; 只发布设置变更请求，由 SettingsService/临时处理器执行持久化与刷新
        EventBus.Publish("SettingsValueChangeRequested", {key: "AutoBeginPause", value: newValue})
        if InStr(ThisHotkey, "Wheel")
            return
    }

    static ActionMuteGame(ThisHotkey) => this._QueueGameAudio("mute", 0)
    static ActionGameVolumeUp(ThisHotkey) => this._QueueGameAudio("volume", 0.1)
    static ActionGameVolumeDown(ThisHotkey) => this._QueueGameAudio("volume", -0.1)

    static _QueueGameAudio(kind, delta) {
        pid := GameTarget.Pid()
        hwnd := GameTarget.Hwnd()
        candidates := [hwnd]
        if !hwnd {
            MouseGetPos(, , &hoverHwnd)
            candidates := [DllCall("GetForegroundWindow", "Ptr"), hoverHwnd]
        }
        GameAudioController.QueueAction(pid, candidates, kind, delta, this._ShowGameAudioResult.Bind(this))
    }

    static _ShowGameAudioResult(kind, result) {
        if !result.success
            message := I18n.T("音频操作未完全成功：{1}", result.message)
        else if result.found = 0
            message := I18n.T("未找到明日方舟的音频会话，请确认游戏正在运行")
        else if kind = "mute"
            message := result.muted ? I18n.T("已静音明日方舟") : I18n.T("已取消静音明日方舟")
        else
            message := I18n.T("明日方舟音量：{1}%", Round(result.volume * 100))
        this._ShowMuteTip(message)
    }

    static _ShowMuteTip(message) {
        static hide := this._HideAudioTip.Bind(this)
        ToolTip(message, , , 19)
        SetTimer hide, -1500
    }

    static _HideAudioTip() {
        ToolTip(, , , 19)
    }

    static ActionBeginSpeedSwitch(ThisHotkey) {
        currentValue := Config.GetImportant("AutoBeginSpeed")
        newValue := (currentValue = "1") ? "0" : "1"
        ; 只发布设置变更请求，由 SettingsService 执行持久化与刷新
        EventBus.Publish("SettingsValueChangeRequested", {key: "AutoBeginSpeed", value: newValue})
        if InStr(ThisHotkey, "Wheel")
            return
    }

    ; 按住开局暂停
    static ActionBeginPauseHold(ThisHotkey) {
        pureKey := KeyForward.PureKeyName(ThisHotkey)
        if InStr(ThisHotkey, "Wheel") {
            Logger.Info("HotkeyActions", "ActionBeginPauseHold 执行：滚轮无松开事件，按一次触发并以常规超时收尾，key=" pureKey)
            GameMonitor.BeginPauseHold(false)
            return
        }
        Logger.Info("HotkeyActions", "ActionBeginPauseHold 执行，key=" pureKey)
        GameMonitor.BeginPauseHold(true, pureKey)
        HoldGuard.RegisterTail(pureKey, (*) => GameMonitor.EndPauseHold())
    }

    ; 模拟鼠标左键点击
    static ActionLButtonClick(ThisHotkey) {
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Info("HotkeyActions", "ActionLButtonClick 跳过：鼠标不在客户端")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Logger.Info("HotkeyActions", "ActionLButtonClick 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        if InStr(ThisHotkey, "Wheel") {
            Send "{LButton Down}"
            Send "{LButton Up}"
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Send "{LButton Down}"
        HoldGuard.RegisterTail(KeyForward.PureKeyName(ThisHotkey), (*) => Send("{LButton Up}"))
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 放弃行动
    static ActionCeaseOperations(ThisHotkey) {
        Logger.Info("HotkeyActions", "ActionCeaseOperations 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.SendDown("battleLeftPopup")
        USleep(50)
        GameKeys.SendUp("battleLeftPopup")
        if InStr(ThisHotkey, "Wheel")
            return
    }
    ; 跳过招募动画/剧情
    static ActionSkip(ThisHotkey) {
        this._ClickButton("ActionSkip", SkipButtonPosition, ThisHotkey)
    }
    ; 返回上级菜单
    static ActionBack(ThisHotkey) {
        Logger.Info("HotkeyActions", "ActionBack 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.MarkInjectedPress("Escape")
        Send "{ESC Down}"
        ; 勾选"使用“返回上级菜单”放弃行动"时，ESC 后补发 battleLeftPopup（还原旧版放弃行动行为）
        if (Config.ReadImportantFromIni("BackCeaseOperations") = "1") {
            GameKeys.SendDown("battleLeftPopup")
            USleep(50)
            GameKeys.UnmarkInjectedPress("Escape")
            Send "{ESC Up}"
            GameKeys.SendUp("battleLeftPopup")
        } else {
            USleep(50)
            GameKeys.UnmarkInjectedPress("Escape")
            Send "{ESC Up}"
        }
        if InStr(ThisHotkey, "Wheel")
            return
    }
    ; 基建快速收取
    static ActionHarvest(ThisHotkey) {
        this._ClickButton("ActionHarvest", HarvestButtonPosition, ThisHotkey)
    }
    ; 肉鸽收集藏品
    static ActionCollectCollectibles(ThisHotkey) {
        this._ClickButton("ActionCollectCollectibles", CollectButtonPosition, ThisHotkey)
    }

    ; 通用按钮点击实现：移动鼠标到按钮位置点击后恢复原鼠标位置
    static _ClickButton(actionName, posGetter, ThisHotkey) {
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Info("HotkeyActions", actionName " 跳过：鼠标不在客户端")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Pos := posGetter()
        if !Pos {
            Logger.Warn("HotkeyActions", actionName " 跳过：游戏窗口不存在")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Logger.Info("HotkeyActions", actionName " 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        MouseGetPos &xpos, &ypos
        BlockInput "MouseMove"
        MouseMove Pos.PBX, Pos.PBY
        Send "{Lbutton Down}"
        MouseMove Pos.PBX, Pos.PBY
        Send "{LButton Up}"
        USleep(40)
        MouseMove xpos, ypos
        BlockInput "MouseMoveOff"
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; -- 卫戍协议 --
    ; 查看敌人
    static ActionCheckEnemies(ThisHotkey) {
        Logger.Info("HotkeyActions", "ActionCheckEnemies 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("autochessViewEnemy")
        if InStr(ThisHotkey, "Wheel")
            return
    }
    ; 调度中心
    static ActionDispatchCenter(ThisHotkey) {
        Logger.Info("HotkeyActions", "ActionDispatchCenter 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("autochessShop")
        if InStr(ThisHotkey, "Wheel")
            return
    }
    ; 冻结
    static ActionFreeze(ThisHotkey) {
        Logger.Info("HotkeyActions", "ActionFreeze 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("autochessFreeze")
        if InStr(ThisHotkey, "Wheel")
            return
    }
    ; 刷新
    static ActionRefresh(ThisHotkey) {
        Logger.Info("HotkeyActions", "ActionRefresh 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("autochessRefresh")
        if InStr(ThisHotkey, "Wheel")
            return
    }
    ; 升级
    static ActionUpgrade(ThisHotkey) {
        Logger.Info("HotkeyActions", "ActionUpgrade 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("autochessLevelUp")
        if InStr(ThisHotkey, "Wheel")
            return
    }
    ; 卫戍协议撤退
    static ActionStrongHoldProtocolRetreat(ThisHotkey){
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        Logger.Info("HotkeyActions", "ActionStrongHoldProtocolRetreat 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("retreatChar")
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 出售/销毁
    static ActionSell(ThisHotkey) {
        Logger.Info("HotkeyActions", "ActionSell 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("autochessSale")
        if InStr(ThisHotkey, "Wheel")
            return
    }
    ; 准备就绪
    static ActionReady(ThisHotkey) {
        Logger.Info("HotkeyActions", "ActionReady 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("autochessReady")
        if InStr(ThisHotkey, "Wheel")
            return
    }
    ; 卫戍协议一键撤退
    static ActionStrongHoldProtocolOneClickRetreat(ThisHotkey) {
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Info("HotkeyActions", "ActionStrongHoldProtocolOneClickRetreat 跳过：鼠标不在客户端")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Logger.Info("HotkeyActions", "ActionStrongHoldProtocolOneClickRetreat 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        Thread "NoTimers"
        Send "{LButton Down}"
        Send "{LButton Up}"
        USleep(TimingService.GetClickDelay())
        GameKeys.Tap("retreatChar")
        Thread "NoTimers", false
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 一键出售/销毁
    static ActionOneClickSell(ThisHotkey) {
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Info("HotkeyActions", "ActionOneClickSell 跳过：鼠标不在客户端")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Logger.Info("HotkeyActions", "ActionOneClickSell 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        Send "{LButton Down}"
        Send "{LButton Up}"
        USleep(TimingService.GetClickDelay())
        GameKeys.Tap("autochessSale")
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 一键购买
    static ActionOneClickPurchase(ThisHotkey) {
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Info("HotkeyActions", "ActionOneClickPurchase 跳过：鼠标不在客户端")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Logger.Info("HotkeyActions", "ActionOneClickPurchase 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        Send "{LButton Down}"
        Send "{LButton Up}"
        USleep(60)
        Send "{LButton Down}"
        Send "{LButton Up}"
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
}

; == 工具函数 ==
; 关卡守卫：在关卡内返回 true；拦截时透传原键并记录日志，返回 false
GuardInLevel(actionName, ThisHotkey) {
    pureKey := KeyForward.PureKeyName(ThisHotkey)
    ; 主热键（down）触发即记录该键已被 AFA 处理，Up 变体据此决定补发 up；Up 变体（含 OnUp 型）不记录
    if !RegExMatch(ThisHotkey, " Up$") && pureKey != "" {
        KeyForward.DownHandled[pureKey] := true
        ; 新的真实按下：标记"上一次补发到此为止"，避免把下一个按住周期的补发误判成回环
        KeyForward._LastForwardDownTick[pureKey] := A_TickCount
    }
    if LevelDetector.IsInLevel()
        return true
    ; 同一按住周期的重复 down（InterceptedKeys 已有，已补发过）不再记日志
    isWheel := InStr(pureKey, "wheel")
    if !KeyForward.InterceptedKeys.Has(pureKey) && (!isWheel || KeyForward.ShouldLogGuard())
        Logger.Info("HotkeyActions", actionName " 被关卡检测拦截（不在关卡界面）")
    KeyForward.ForwardOriginalKey(ThisHotkey)
    return false
}
; 获取放弃按钮位置
AbandonButtonPosition() {
    if !SafeWinGetClientPos(&ww, &wh)
        return false
    PButtonLX := ww * 0.0474
    PButtonRX := ww * 0.1369
    PButtonUY := wh * 0.0444
    PButtonDY := wh * 0.0694
    return {PBLX: PButtonLX, PBUY: PButtonUY, PBRX: PButtonRX, PBDY: PButtonDY}
}
; 获取暂停按钮位置
PauseButtonPosition() {
    if !SafeWinGetClientPos(&ww, &wh)
        return false
    PButtonX := ww * 0.9525
    PButtonY := wh * 0.0700
    return {PBX: PButtonX, PBY: PButtonY}
}
; 获取暂停按钮左半部分位置
PauseButtonPositionLeft() {
    if !SafeWinGetClientPos(&ww, &wh)
        return false
    PButtonLX := ww * 0.9400
    PButtonLY := wh * 0.0700
    return {PBLX: PButtonLX, PBLY: PButtonLY}
}
; 获取暂停按钮右半部分位置
PauseButtonPositionRight() {
    if !SafeWinGetClientPos(&ww, &wh)
        return false
    PButtonRX := ww * 0.9650
    PButtonRY := wh * 0.0700
    return {PBRX: PButtonRX, PBRY: PButtonRY}
}
; 获取自动暂停倍速按钮识别位置
SpeedButtonPositionColor() {
    if !SafeWinGetClientPos(&ww, &wh)
        return false
    PButtonCLX := ww * 0.8450
    PButtonCRX := ww * 0.8807
    PButtonCUY := wh * 0.0713
    PButtonCDY := wh * 0.0870
    return {PBCLX: PButtonCLX, PBCRX: PButtonCRX, PBCUY: PButtonCUY, PBCDY: PButtonCDY}
}
; 获取基建收取按钮位置
HarvestButtonPosition() {
    if !SafeWinGetClientPos(&ww, &wh)
        return false
    PButtonX := ww * 0.1297
    PButtonY := wh * 0.9527
    return {PBX: PButtonX, PBY: PButtonY}
}
; 获取代理接管作战按钮识别位置（线点识别 + 图像识别）
TakeOverButtonPositions() {
    if !SafeWinGetClientPos(&ww, &wh)
        return false
    ; === ImageSearch 搜索区域 ===
    ImageRegion := {
        ; 按钮右侧边缘
        RLX : ww * 0.3651, RRX : ww * 0.4073,
        RUY : wh * 0.8685, RDY : wh * 0.9546,
        ; 按钮“手”图标
        HLX : ww * 0.2583, HRX : ww * 0.3354,
        HUY : wh * 0.9037, HDY : wh * 0.9620
    }
    return {ImageRegion: ImageRegion}
}
; 获取“收下”按钮位置
CollectButtonPosition() {
    if !SafeWinGetClientPos(&ww, &wh)
        return false
    PButtonX := ww * 0.1104
    PButtonY := wh * 0.7250
    return {PBX: PButtonX, PBY: PButtonY}
}
; 获取跳过按钮位置
SkipButtonPosition() {
    if !SafeWinGetClientPos(&ww, &wh)
        return false
    PButtonX := ww * 0.959765
    PButtonY := wh * 0.05
    return {PBX: PButtonX, PBY: PButtonY}
}
; 启动热键动作域：初始化触控注入（Touch Injection）
HotkeyActionsStart() {
    ; AHK 热键名称大小写不敏感，状态表采用相同语义。
    KeyForward.InterceptedKeys.CaseSense := false
    KeyForward.DownHandled.CaseSense := false
    KeyForward.SuppressUp.CaseSense := false
    KeyForward._LastForwardTick.CaseSense := false
    KeyForward._LastForwardDownTick.CaseSense := false
    GameKeys.InjectedPressKeys.CaseSense := false
    HoldGuard.Init()
    TouchInjector.Init(3, 1)
    prevMouseCoordMode := CoordMode("Mouse", "Screen")
    try {
        MouseGetPos &screenX, &screenY
        TouchInjector.MoveFromScreen(screenX, screenY)
        MouseMove screenX, screenY, 0
    } finally {
        CoordMode("Mouse", prevMouseCoordMode)
    }
}
