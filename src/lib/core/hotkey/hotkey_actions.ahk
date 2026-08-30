; == 按键透传（守卫拦截时还原原键输入） ==
; 状态与行为内聚为类：InterceptedKeys 记录已补发 key down 的键，Up 变体回调据此补发 key up
class KeyForward {
    static InterceptedKeys := Map()
    ; down 已被 AFA 主热键处理过的键（运行时标记，GuardInLevel 记录）：Up 变体据此决定是否放行补发 key up
    ; ——覆盖守卫放行/拦截两路径的失焦/拖出卡键；游戏外主热键不触发则不记录，Up 变体不放行，物理 up 正常透传（打字不受影响）。
    static DownHandled := Map()
    ; 补发 up 期间的递归抑制记录（按键级，pureKey→true）：ActionUpForward 的 Send 补发会被钩子重新捕获触发同名 Up 变体，
    ; 若继续放行会无限循环（导致游戏外按键失灵）。仅抑制正在补发的同名键，不误挡同时松开的其它键——
    ; 全局布尔会把其它键的物理 Up 也挡掉（HotkeyContext 条件失败→被吞→卡键，见多键同松竞态）。
    static SuppressUp := Map()
    ; 守卫拦截日志节流：滚轮等无 down/up 状态的事件每次独立滚动都走拦截路径（不写 InterceptedKeys，无按键去重），
    ; 无极/高分辨率滚轮可达数百次/秒——若逐条 Info 落盘会形成"每档位一次文件 IO"的洪峰，
    ; 拖慢主线程并刷爆日志轨（15MiB）。按 100ms 时间窗去重（普通键维持 InterceptedKeys 原去重语义，不在此限流）。
    static GuardLogIntervalMs := 100
    static _GuardLogNextTick := 0

    ; 判定当前时刻是否应记录守卫拦截日志：窗口内最多一条，窗口自然滑动，无需主动清理状态
    static ShouldLogGuard() {
        if (A_TickCount < this._GuardLogNextTick)
            return false
        this._GuardLogNextTick := A_TickCount + this.GuardLogIntervalMs
        return true
    }

    ; 提取纯键名（去除 ~*$ 前缀、修饰符与 Up 后缀；保留左右修饰键信息 <SHIFT→LShift、>SHIFT→RShift）
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
        ; 左右前缀 + 通用修饰键名 → 对应侧规范键名（<SHIFT→LShift），否则 Send 补发不区分左右会漏释放（如 >SHIFT 卡右 Shift）
        if (side != "") {
            static ModNames := Map("shift", "Shift", "ctrl", "Ctrl", "control", "Control", "alt", "Alt", "win", "Win")
            if ModNames.Has(StrLower(pureKey))
                pureKey := side ModNames[StrLower(pureKey)]
        }
        ; Hotkey 名称大小写不敏感，但 Map 键默认大小写敏感；统一字母键名称，
        ; 避免同一物理键因首次注册拼写不同（如 Issue #240 的 a/A）而漏掉 Up。
        return StrLower(GetKeyName(pureKey))
    }
    ; 透传原热键给游戏（守卫拦截时调用，只拦 AFA 功能不吞原键）
    ; - 带 ~ 前缀的热键按键本就透传，无需补发，避免重复输入
    ; - 按下型热键：按键被 AFA 吞掉，补发 key down 并记录标志；key up 由 Up 变体热键回调（ActionUpForward）补发，事件驱动无阻塞
    ; - Up 型热键（松开暂停）：非拦截键带 ~ 前缀，down 未被吞；被拦截键会被 AHK 整键接管（Hotkeys.htm：
    ;   "An Up hotkey without a normal/down counterpart hotkey will completely take over that key"）——
    ;   **down 也被吞**，且 Up 型热键没有 Down 热键给透传机会，故此处须补发完整按下（down→delay→up），
    ;   否则关卡外该键输入整次丢失（如"松开时暂停"绑定 Space 后无法输入空格）
    ; - 滚轮等无 down/up 状态的事件：直接发送完整事件（同 action 尾部 Wheel 处理）
    ; - {Blind}：默认 Send 会临时改写 CapsLock（SetStoreCapsLockMode 默认开启）并释放-重注入物理按住的修饰键，
    ;   透传的注入事件会被按“小写/无修饰”翻译——大写锁定开启或按住 Shift 时游戏收不到物理状态对应的字符；
    ;   Blind 保持两者状态不变，注入即物理状态的忠实镜像（与直接按键产生的输入完全一致）
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
        ; 注入改用原生 mouse_event：AHK Send 注入的滚轮事件带 KEY_IGNORE_LEVEL(0) 标记（0xFFC3D44D），
        ; 部分用户环境的输入监听组件会对此标记做出响应（如系统提示音）；mouse_event 走同一输入队列
        ; 但无该标记，且 {Blind} 语义天然满足（不触碰修饰键状态，不夺焦点）。
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
            ; InterceptedKeys 记录"down 已补发"：常规 Down 型热键的 down 已由主热键透传，只补发 up；
            ; 无记录说明 down 从未到达游戏（AHK 对无 ~ 的 Up 热键整键接管吞掉了 down）——补发完整按下。
            if !this.InterceptedKeys.Has(pureKey)
                Send "{Blind}{" pureKey " Down}"
            Send "{Blind}{" pureKey " Up}"
            return
        }
        ; 长按自动重复期间只保留一组逻辑 Down/Up。
        if this.InterceptedKeys.Has(pureKey)
            return
        this.InterceptedKeys[pureKey] := true
        try {
            Send "{Blind}{" pureKey " Down}"
            Logger.Debug("KeyForward", "透传 Down：key=" pureKey)
        } catch Error as e {
            this.InterceptedKeys.Delete(pureKey)
            Logger.Exception("KeyForward", e, "透传 Down 失败：key=" pureKey)
            throw
        }
    }
    ; Up 变体热键统一回调：被拦截的键松开时一律补发 key up
    ; 原因：AHK Send 对物理按住的修饰键会做“释放-重注入”（Send.htm：默认 Send 等价 {Blind}{Ctrl up}x{Ctrl down}），
    ; 而被拦截（无 ~）的修饰键物理 up 也被吞；若只在 ForwardOriginalKey 置位时才补发 up，
    ; 关卡内路径（动作正常执行、未走透传）会漏掉 Up，导致修饰键在 OS 层卡住（如 GameSpeed=<SHIFT）。
    ; 补发对未按下的键是无害 no-op，故无条件补发（不再依赖 InterceptedKeys 标志）；
    ; 唯一抑制条件：该键处于“注入按下未完成”窗口（GameKeys.InjectedPressKeys）——注入动作自管完整按下
    ; （注入 down→up）时，物理松开的补发 up 若与注入 down 落在同一画面帧，游戏的帧开头轮询只读到 up，
    ; 注入的按下整次丢失（见 AGENTS.md“帧开头轮询”知识点）。{Blind} 理由同 ForwardOriginalKey。
    static ActionUpForward(ThisHotkey) {
        pureKey := this.PureKeyName(ThisHotkey)
        if (pureKey == "")
            return
        ; 防递归：Send 补发的 up 会被钩子重新捕获触发本变体，补发期间同名键直接返回（键级作用域，不挡其它键）
        if KeyForward.SuppressUp.Has(pureKey)
            return
        ; 注入按下未完成（注入 down 已发、注入 up 未发）：抑制补发。物理 up 仍被本热键（无 ~）吞掉不会漏到游戏，
        ; 游戏收到的是注入动作自管的完整按下；注入 up 由 GameKeys.SendUp 先清标记再发送，故注入 up 自身触发本回调
        ; （SendEvent 降级路径）时标记已清除，仍会补发，不会在游戏内卡键。
        if GameKeys.IsInjectedPressPending(pureKey) {
            Logger.Debug("KeyForward", "抑制透传 Up：key=" pureKey "（注入按下未完成，避免同帧补发吞掉注入按下）")
            return
        }
        KeyForward.SuppressUp[pureKey] := true
        try {
            Send "{Blind}{" pureKey " Up}"
            ; 关卡内路径未走 ForwardOriginalKey，flag 不存在；Delete 对不存在的键会抛 UnsetItemError，需先检查
            if (this.InterceptedKeys.Has(pureKey))
                this.InterceptedKeys.Delete(pureKey)
            if (KeyForward.DownHandled.Has(pureKey))
                KeyForward.DownHandled.Delete(pureKey)
            Logger.Debug("KeyForward", "透传 Up：key=" pureKey)
        } catch Error as e {
            Logger.Exception("KeyForward", e, "透传 Up 失败：key=" pureKey)
        } finally {
            KeyForward.SuppressUp.Delete(pureKey)
        }
    }
}

; == 功能实现 ==
; -- 常规作战 --
; 按下暂停
class HotkeyActions {
    static ActionPressPause(ThisHotkey) {
        if !GuardInLevel("ActionPressPause", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        Logger.Debug("HotkeyActions", "ActionPressPause 执行，key=" KeyForward.PureKeyName(ThisHotkey))
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
        PureKeyWait(ThisHotkey)
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 松开暂停
    static ActionReleasePause(ThisHotkey) {
        if !GuardInLevel("ActionReleasePause", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        Logger.Debug("HotkeyActions", "ActionReleasePause 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("pauseBattle")
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 切换倍速
    static ActionGameSpeed(ThisHotkey) {
        if !GuardInLevel("ActionGameSpeed", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        Logger.Debug("HotkeyActions", "ActionGameSpeed 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        Thread "NoTimers"
        GameKeys.SendDown("changeSpeed")
        USleep(50)
        GameKeys.SendUp("changeSpeed")
        Thread "NoTimers", false
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        PureKeyWait(ThisHotkey)
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 前进16ms
    static Action16ms(ThisHotkey) {
        this._FrameSkip("Action16ms", "FrameSkip16msDelay", ThisHotkey)
    }
    ; 前进33ms，由于波动，过帧间隔设置为30ms，避免一次过两帧
    static Action33ms(ThisHotkey) {
        this._FrameSkip("Action33ms", "FrameSkip33msDelay", ThisHotkey)
    }
    ; 前进166ms
    static Action166ms(ThisHotkey) {
        this._FrameSkip("Action166ms", "FrameSkip166msDelay", ThisHotkey)
    }

    ; 过帧通用实现：ESC 触发暂停后按配置延迟发送 pauseBattle
    static _FrameSkip(actionName, delayConfigKey, ThisHotkey) {
        if !GuardInLevel(actionName, ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        Logger.Debug("HotkeyActions", actionName " 执行，key=" KeyForward.PureKeyName(ThisHotkey))
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
        PureKeyWait(ThisHotkey)
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 暂停选中
    static ActionPauseSelect(ThisHotkey) {
        if !GuardInLevel("ActionPauseSelect", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Debug("HotkeyActions", "ActionPauseSelect 跳过：鼠标不在客户端")
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
        Logger.Debug("HotkeyActions", "ActionPauseSelect 执行，key=" KeyForward.PureKeyName(ThisHotkey))
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
        PureKeyWait(ThisHotkey)
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 发送技能键
    static ActionSkill(ThisHotkey) {
        if !GuardInLevel("ActionSkill", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        Logger.Debug("HotkeyActions", "ActionSkill 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("releaseSkill")
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        PureKeyWait(ThisHotkey)
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 发送撤退键
    static ActionRetreat(ThisHotkey) {
        if !GuardInLevel("ActionRetreat", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        Logger.Debug("HotkeyActions", "ActionRetreat 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("retreatChar")
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        PureKeyWait(ThisHotkey)
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 一键技能
    static ActionOneClickSkill(ThisHotkey) {
        if !GuardInLevel("ActionOneClickSkill", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Debug("HotkeyActions", "ActionOneClickSkill 跳过：鼠标不在客户端")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Logger.Debug("HotkeyActions", "ActionOneClickSkill 执行，key=" KeyForward.PureKeyName(ThisHotkey))
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
        PureKeyWait(ThisHotkey)
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 一键撤退
    static ActionOneClickRetreat(ThisHotkey) {
        if !GuardInLevel("ActionOneClickRetreat", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Debug("HotkeyActions", "ActionOneClickRetreat 跳过：鼠标不在客户端")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Logger.Debug("HotkeyActions", "ActionOneClickRetreat 执行，key=" KeyForward.PureKeyName(ThisHotkey))
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
        PureKeyWait(ThisHotkey)
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 暂停技能
    static ActionPauseSkill(ThisHotkey) {
        if !GuardInLevel("ActionPauseSkill", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Debug("HotkeyActions", "ActionPauseSkill 跳过：鼠标不在客户端")
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
        Logger.Debug("HotkeyActions", "ActionPauseSkill 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        MouseGetPos &xpos, &ypos
        ; NoTimers 挡定时器轮询的时序干扰，允许其他热键中断（Critical 会连热键一起挡）
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
        PureKeyWait(ThisHotkey)
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 暂停撤退
    static ActionPauseRetreat(ThisHotkey) {
        if !GuardInLevel("ActionPauseRetreat", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Debug("HotkeyActions", "ActionPauseRetreat 跳过：鼠标不在客户端")
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
        Logger.Debug("HotkeyActions", "ActionPauseRetreat 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        MouseGetPos &xpos, &ypos
        ; NoTimers 挡定时器轮询的时序干扰，允许其他热键中断（Critical 会连热键一起挡）
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
        PureKeyWait(ThisHotkey)
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }

    ; 视角切换
    static ActionSwitchView(ThisHotkey) {
        if !GuardInLevel("ActionSwitchView", ThisHotkey)
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Debug("HotkeyActions", "ActionSwitchView 跳过：鼠标不在客户端")
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
        Logger.Debug("HotkeyActions", "ActionSwitchView 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        MouseGetPos &xpos, &ypos
        ; NoTimers 挡定时器轮询的时序干扰，允许其他热键中断（Critical 会连热键一起挡）
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
        PureKeyWait(ThisHotkey)
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
        PureKeyWait(ThisHotkey)
    }

    ; 模拟鼠标左键点击
    static ActionLButtonClick(ThisHotkey) {
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Debug("HotkeyActions", "ActionLButtonClick 跳过：鼠标不在客户端")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Logger.Debug("HotkeyActions", "ActionLButtonClick 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        Send "{LButton Down}"
        if InStr(ThisHotkey, "Wheel") {
            Send "{LButton Up}"
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        PureKeyWait(ThisHotkey)
        Send "{LButton Up}"
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 放弃行动
    static ActionCeaseOperations(ThisHotkey) {
        Logger.Debug("HotkeyActions", "ActionCeaseOperations 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.SendDown("battleLeftPopup")
        USleep(50)
        GameKeys.SendUp("battleLeftPopup")
        if InStr(ThisHotkey, "Wheel")
            return
        PureKeyWait(ThisHotkey)
    }
    ; 跳过招募动画/剧情
    static ActionSkip(ThisHotkey) {
        this._ClickButton("ActionSkip", SkipButtonPosition, ThisHotkey)
    }
    ; 返回上级菜单
    static ActionBack(ThisHotkey) {
        Logger.Debug("HotkeyActions", "ActionBack 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        ; ESC 同帧竞态防护：ESC 也在拦截正则内（守卫热键绑定 ESC 时），物理松开的补发 up 与注入 down 同帧会丢失按下
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
        PureKeyWait(ThisHotkey)
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
            Logger.Debug("HotkeyActions", actionName " 跳过：鼠标不在客户端")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Pos := posGetter()
        if !Pos {
            Logger.Warn("HotkeyActions", actionName " 跳过：游戏窗口不存在")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Logger.Debug("HotkeyActions", actionName " 执行，key=" KeyForward.PureKeyName(ThisHotkey))
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
        PureKeyWait(ThisHotkey)
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; -- 卫戍协议 --
    ; 查看敌人
    static ActionCheckEnemies(ThisHotkey) {
        Logger.Debug("HotkeyActions", "ActionCheckEnemies 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("autochessViewEnemy")
        if InStr(ThisHotkey, "Wheel")
            return
        PureKeyWait(ThisHotkey)
    }
    ; 调度中心
    static ActionDispatchCenter(ThisHotkey) {
        Logger.Debug("HotkeyActions", "ActionDispatchCenter 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("autochessShop")
        if InStr(ThisHotkey, "Wheel")
            return
        PureKeyWait(ThisHotkey)
    }
    ; 冻结
    static ActionFreeze(ThisHotkey) {
        Logger.Debug("HotkeyActions", "ActionFreeze 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("autochessFreeze")
        if InStr(ThisHotkey, "Wheel")
            return
        PureKeyWait(ThisHotkey)
    }
    ; 刷新
    static ActionRefresh(ThisHotkey) {
        Logger.Debug("HotkeyActions", "ActionRefresh 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("autochessRefresh")
        if InStr(ThisHotkey, "Wheel")
            return
        PureKeyWait(ThisHotkey)
    }
    ; 升级
    static ActionUpgrade(ThisHotkey) {
        Logger.Debug("HotkeyActions", "ActionUpgrade 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("autochessLevelUp")
        if InStr(ThisHotkey, "Wheel")
            return
        PureKeyWait(ThisHotkey)
    }
    ; 卫戍协议撤退
    static ActionStrongHoldProtocolRetreat(ThisHotkey){
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        Logger.Debug("HotkeyActions", "ActionStrongHoldProtocolRetreat 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("retreatChar")
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        PureKeyWait(ThisHotkey)
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 出售/销毁
    static ActionSell(ThisHotkey) {
        Logger.Debug("HotkeyActions", "ActionSell 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("autochessSale")
        if InStr(ThisHotkey, "Wheel")
            return
        PureKeyWait(ThisHotkey)
    }
    ; 准备就绪
    static ActionReady(ThisHotkey) {
        Logger.Debug("HotkeyActions", "ActionReady 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        GameKeys.Tap("autochessReady")
        if InStr(ThisHotkey, "Wheel")
            return
        PureKeyWait(ThisHotkey)
    }
    ; 卫戍协议一键撤退
    static ActionStrongHoldProtocolOneClickRetreat(ThisHotkey) {
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Debug("HotkeyActions", "ActionStrongHoldProtocolOneClickRetreat 跳过：鼠标不在客户端")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Logger.Debug("HotkeyActions", "ActionStrongHoldProtocolOneClickRetreat 执行，key=" KeyForward.PureKeyName(ThisHotkey))
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
        PureKeyWait(ThisHotkey)
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 一键出售/销毁
    static ActionOneClickSell(ThisHotkey) {
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Debug("HotkeyActions", "ActionOneClickSell 跳过：鼠标不在客户端")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Logger.Debug("HotkeyActions", "ActionOneClickSell 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        Send "{LButton Down}"
        Send "{LButton Up}"
        USleep(TimingService.GetClickDelay())
        GameKeys.Tap("autochessSale")
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        PureKeyWait(ThisHotkey)
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }
    ; 一键购买
    static ActionOneClickPurchase(ThisHotkey) {
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        if !IsMouseInClient() {
            Logger.Debug("HotkeyActions", "ActionOneClickPurchase 跳过：鼠标不在客户端")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Logger.Debug("HotkeyActions", "ActionOneClickPurchase 执行，key=" KeyForward.PureKeyName(ThisHotkey))
        Send "{LButton Down}"
        Send "{LButton Up}"
        USleep(60)
        Send "{LButton Down}"
        Send "{LButton Up}"
        if InStr(ThisHotkey, "Wheel") {
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        PureKeyWait(ThisHotkey)
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }

    ; == 工具函数 ==
    ; 去除修饰符前缀
}

PureKeyWait(ThisHotkey) {
    if (ThisHotkey == "")
        return
    KeyWait(KeyForward.PureKeyName(ThisHotkey))
}
; 关卡守卫：在关卡内返回 true；拦截时透传原键并记录日志，返回 false
; 判定依据：LevelDetector 投票状态机维护的 LevelDetector.IsInLevel()（读内存标志，无像素检测、无 DPI 切换）
; 守卫关闭（InLevelGuard=0）时 LevelDetector 停止轮询并强制 InLevel=true，此处直接放行，无 I/O
; 拦截是预期行为（非异常），用 Info 级别避免刷 critical 轨（WARN/ERROR 5 MiB 留给真正的问题）
GuardInLevel(actionName, ThisHotkey) {
    pureKey := KeyForward.PureKeyName(ThisHotkey)
    ; 主热键（down）触发即记录该键已被 AFA 处理，Up 变体据此决定补发 up；Up 变体（含 OnUp 型）不记录；
    ; PureKeyName 为空时不记录，避免 DownHandled 出现 "" 键干扰后续逻辑
    if !RegExMatch(ThisHotkey, " Up$") && pureKey != ""
        KeyForward.DownHandled[pureKey] := true
    if LevelDetector.IsInLevel()
        return true
    ; 同一按住周期的重复 down（InterceptedKeys 已有，已补发过）不再记日志，避免切走时 key repeat 刷屏；
    ; 滚轮不写 InterceptedKeys，每次独立滚动都走拦截路径（无极/高分辨率滚轮可达数百次/秒）——
    ; 逐条落盘会形成每档位一次文件 IO 的洪峰，故滚轮按 100ms 时间窗节流（ShouldLogGuard），
    ; 普通键维持 InterceptedKeys 去重语义（按住周期内一条）
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
    GameKeys.InjectedPressKeys.CaseSense := false
    TouchInjector.Init(3, 1)

    ; #289：Client 模式下 MouseGetPos 相对“当前活动窗口”，启动时可能是托盘菜单/资源管理器。
    ; 统一切到 Screen 取点；触控注入由 MoveFromScreen 换算成游戏客户区坐标；
    ; MouseMove 在 Screen 模式下还原光标，不受活动窗口切换影响。
    prevMouseCoordMode := CoordMode("Mouse", "Screen")
    try {
        MouseGetPos &screenX, &screenY
        TouchInjector.MoveFromScreen(screenX, screenY)
        MouseMove screenX, screenY, 0
    } finally {
        CoordMode("Mouse", prevMouseCoordMode)
    }
}
