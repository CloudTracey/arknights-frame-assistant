; == 按键透传（守卫拦截时还原原键输入） ==
; 状态与行为内聚为类：InterceptedKeys 记录已补发 key down 的键，Up 变体回调据此补发 key up
class KeyForward {
    static InterceptedKeys := Map()
    ; down 已被 AFA 主热键处理过的键（运行时标记，GuardInLevel 记录）：Up 变体据此决定是否放行补发 key up
    ; ——覆盖守卫放行/拦截两路径的失焦/拖出卡键；游戏外主热键不触发则不记录，Up 变体不放行，物理 up 正常透传（打字不受影响）。
    static DownHandled := Map()
    ; 补发 up 期间的递归抑制标志：ActionUpForward 的 Send 补发会被钩子重新捕获触发 Up 变体，
    ; 若 Up 变体继续放行会无限循环（导致游戏外按键失灵）。置位时 HotkeyContext/ActionUpForward 均不再放行/补发。
    static SuppressUp := false

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
    ; - Up 型热键（松开暂停）：按下时 down 未被吞（游戏已收到），松开时只补发 key up
    ; - 滚轮等无 down/up 状态的事件：直接发送完整事件（同 action 尾部 Wheel 处理）
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
            Send "{" pureKey "}"
            return
        }
        if isUp {
            Send "{" pureKey " Up}"
            return
        }
        ; 长按自动重复期间只保留一组逻辑 Down/Up。
        if this.InterceptedKeys.Has(pureKey)
            return
        this.InterceptedKeys[pureKey] := true
        try {
            Send "{" pureKey " Down}"
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
    ; 补发对未按下的键是无害 no-op，故无条件补发（不再依赖 InterceptedKeys 标志）。
    static ActionUpForward(ThisHotkey) {
        pureKey := this.PureKeyName(ThisHotkey)
        if (pureKey == "")
            return
        ; 防递归：Send 补发的 up 会被钩子重新捕获触发本变体，置位期间直接返回
        if KeyForward.SuppressUp
            return
        KeyForward.SuppressUp := true
        try {
            Send "{" pureKey " Up}"
            ; 关卡内路径未走 ForwardOriginalKey，flag 不存在；Delete 对不存在的键会抛 UnsetItemError，需先检查
            if (this.InterceptedKeys.Has(pureKey))
                this.InterceptedKeys.Delete(pureKey)
            if (KeyForward.DownHandled.Has(pureKey))
                KeyForward.DownHandled.Delete(pureKey)
            Logger.Debug("KeyForward", "透传 Up：key=" pureKey)
        } catch Error as e {
            Logger.Exception("KeyForward", e, "透传 Up 失败：key=" pureKey)
        } finally {
            KeyForward.SuppressUp := false
        }
    }
}
; AHK 热键名称大小写不敏感，状态表采用相同语义。
KeyForward.InterceptedKeys.CaseSense := false
KeyForward.DownHandled.CaseSense := false

; == 功能实现 ==
; -- 常规作战 --
; 按下暂停
ActionPressPause(ThisHotkey) {
    if !GuardInLevel("ActionPressPause", ThisHotkey)
        return
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    Logger.Debug("HotkeyActions", "ActionPressPause 执行，key=" KeyForward.PureKeyName(ThisHotkey))
    Send "{ESC Down}"
    USleep(50)
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel") {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 松开暂停
ActionReleasePause(ThisHotkey) {
    if !GuardInLevel("ActionReleasePause", ThisHotkey)
        return
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    Logger.Debug("HotkeyActions", "ActionReleasePause 执行，key=" KeyForward.PureKeyName(ThisHotkey))
    GameKeys.Tap("pauseBattle")
    try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 切换倍速
ActionGameSpeed(ThisHotkey) {
    if !GuardInLevel("ActionGameSpeed", ThisHotkey)
        return
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    Logger.Debug("HotkeyActions", "ActionGameSpeed 执行，key=" KeyForward.PureKeyName(ThisHotkey))
    GameKeys.SendDown("changeSpeed")
    USleep(50)
    GameKeys.SendUp("changeSpeed")
    if InStr(ThisHotkey, "Wheel") {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 前进16ms
Action16ms(ThisHotkey) {
    if !GuardInLevel("Action16ms", ThisHotkey)
        return
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    Logger.Debug("HotkeyActions", "Action16ms 执行，key=" KeyForward.PureKeyName(ThisHotkey))
    delay := Integer(Config.ReadCustomFromIni("FrameSkip16msDelay"))
    Send "{ESC Down}"
    USleep(delay)
    GameKeys.SendDown("pauseBattle")
    USleep(50)
    Send "{ESC Up}"
    GameKeys.SendUp("pauseBattle")
    if InStr(ThisHotkey, "Wheel") {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 前进33ms，由于波动，过帧间隔设置为30ms，避免一次过两帧
Action33ms(ThisHotkey) {
    if !GuardInLevel("Action33ms", ThisHotkey)
        return
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    Logger.Debug("HotkeyActions", "Action33ms 执行，key=" KeyForward.PureKeyName(ThisHotkey))
    delay := Integer(Config.ReadCustomFromIni("FrameSkip33msDelay"))
    Send "{ESC Down}"
    USleep(delay)
    GameKeys.SendDown("pauseBattle")
    USleep(50)
    Send "{ESC Up}"
    GameKeys.SendUp("pauseBattle")
    if InStr(ThisHotkey, "Wheel") {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 前进166ms
Action166ms(ThisHotkey) {
    if !GuardInLevel("Action166ms", ThisHotkey)
        return
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    Logger.Debug("HotkeyActions", "Action166ms 执行，key=" KeyForward.PureKeyName(ThisHotkey))
    delay := Integer(Config.ReadCustomFromIni("FrameSkip166msDelay"))
    Send "{ESC Down}"
    USleep(delay)
    GameKeys.SendDown("pauseBattle")
    USleep(50)
    Send "{ESC Up}"
    GameKeys.SendUp("pauseBattle")
    if InStr(ThisHotkey, "Wheel") {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 暂停选中
ActionPauseSelect(ThisHotkey) {
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
    TouchInjector.Tap(PosL.PBLX, PosL.PBLY)
    TouchInjector.Tap(xpos, ypos)
    TouchInjector.Tap(PosR.PBRX, PosR.PBRY)
    USleep(State.CurrentDelay * 1.5)
    TouchInjector.Move(xpos, ypos)
    MouseMove xpos, ypos
    if InStr(ThisHotkey, "Wheel") {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 发送技能键
ActionSkill(ThisHotkey) {
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
ActionRetreat(ThisHotkey) {
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
ActionOneClickSkill(ThisHotkey) {
    if !GuardInLevel("ActionOneClickSkill", ThisHotkey)
        return
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        Logger.Debug("HotkeyActions", "ActionOneClickSkill 跳过：鼠标不在客户端")
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Logger.Debug("HotkeyActions", "ActionOneClickSkill 执行，key=" KeyForward.PureKeyName(ThisHotkey))
    Send "{LButton Down}"
    Send "{LButton Up}"
    USleep(State.ClickDelay)
    GameKeys.Tap("releaseSkill")
    if InStr(ThisHotkey, "Wheel") {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 一键撤退
ActionOneClickRetreat(ThisHotkey) {
    if !GuardInLevel("ActionOneClickRetreat", ThisHotkey)
        return
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        Logger.Debug("HotkeyActions", "ActionOneClickRetreat 跳过：鼠标不在客户端")
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Logger.Debug("HotkeyActions", "ActionOneClickRetreat 执行，key=" KeyForward.PureKeyName(ThisHotkey))
    Send "{LButton Down}"
    Send "{LButton Up}"
    USleep(State.ClickDelay)
    GameKeys.Tap("retreatChar")
    if InStr(ThisHotkey, "Wheel") {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 暂停技能
ActionPauseSkill(ThisHotkey) {
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
    TouchInjector.Tap(PosL.PBLX, PosL.PBLY)
    TouchInjector.Tap(xpos, ypos)
    TouchInjector.Tap(PosR.PBRX, PosR.PBRY)
    USleep(State.ClickDelay)
    GameKeys.SendDown("releaseSkill")
    USleep(Max(State.CurrentDelay * 1.5 - State.ClickDelay, 0))
    TouchInjector.Move(xpos, ypos)
    MouseMove xpos, ypos
    USleep(50)
    GameKeys.SendUp("releaseSkill")
    if InStr(ThisHotkey, "Wheel") {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 暂停撤退
ActionPauseRetreat(ThisHotkey) {
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
    TouchInjector.Tap(PosL.PBLX, PosL.PBLY)
    TouchInjector.Tap(xpos, ypos)
    TouchInjector.Tap(PosR.PBRX, PosR.PBRY)
    USleep(State.ClickDelay)
    GameKeys.SendDown("retreatChar")
    USleep(Max(State.CurrentDelay * 1.5 - State.ClickDelay, 0))
    TouchInjector.Move(xpos, ypos)
    MouseMove xpos, ypos
    USleep(50)
    GameKeys.SendUp("retreatChar")
    if InStr(ThisHotkey, "Wheel") {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}

; 视角切换
ActionSwitchView(ThisHotkey) {
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
    TouchInjector.Tap(PosL.PBLX, PosL.PBLY)
    TouchInjector.Tap(xpos, ypos)
    TouchInjector.Tap(PosR.PBRX, PosR.PBRY)
    TouchInjector.Tap(xpos, ypos)
    if InStr(ThisHotkey, "Wheel") {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 快捷切换开局暂停开关
ActionBeginPauseSwitch(ThisHotkey) {
    currentValue := Config.GetImportant("AutoBeginPause")
    newValue := (currentValue = "1") ? "0" : "1"
    Config.SetImportant("AutoBeginPause", newValue)
    try {
        GuiManager.SetControlValue("AutoBeginPause", newValue = "1")
    }
    EventBus.Publish("HotkeyOff")
    IniWrite(newValue, Config.IniFile, "Main", "AutoBeginPause")
    Loader.LoadSettings()
    HotkeyController.EnableByTab(GuiManager.LastActiveTab)
    Logger.Info("HotkeyActions", "切换开局自动暂停 → " (newValue = "1" ? "开" : "关"))
    if (newValue = "1") {
        TrayTip
        SetTimer HideTrayTip, 0
        TrayTip("已开启开局自动暂停", "AFA", "Mute")
        SetTimer HideTrayTip, -3000
    } else {
        TrayTip
        SetTimer HideTrayTip, 0
        TrayTip("已关闭开局自动暂停", "AFA", "Mute")
        SetTimer HideTrayTip, -3000
    }
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 开局暂停
ActionBeginPause() {
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    PosC := SpeedButtonPositionColor()
    if !PosC {
        Logger.Warn("HotkeyActions", "自动暂停：游戏窗口不存在")
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Logger.Debug("HotkeyActions", "自动暂停：等待倍速按钮")
    while(true) {
        if PixelSearch(&FoundX, &FoundY, PosC.PBCRX, PosC.PBCUY, PosC.PBCLX, PosC.PBCDY, 0xffffff, 10)
        {
            GameKeys.SendDown("pauseBattle")
            USleep(50)
            GameKeys.SendUp("pauseBattle")
            Logger.Debug("HotkeyActions", "自动暂停：已暂停")
            ; 为了降低暂停延迟，后置代理指挥识别，识别到是代理指挥时取消暂停
            isProxy := false
            TobC := TakeOverButtonPositions()
            if !TobC {
                Logger.Warn("HotkeyActions", "自动暂停：游戏窗口不存在（代理指挥识别）")
                State.BlackScreenDetected := false
                State.ReadyForPause := false
                SetTimer CheckGameStatus, 400
                break
            }
            ; 接管代理按钮右侧边缘
            if ImageSearch(&OutputVarX, &OutputVarY, TobC.ImageRegion.RLX, TobC.ImageRegion.RUY, TobC.ImageRegion.RRX, TobC.ImageRegion.RDY, "*90 " FileExtractor.TakeOver1Path) or ImageSearch(&OutputVarX, &OutputVarY, TobC.ImageRegion.RLX, TobC.ImageRegion.RUY, TobC.ImageRegion.RRX, TobC.ImageRegion.RDY, "*90 " FileExtractor.TakeOver2Path) { ; 0 帧暂停接管按钮半透明导致至少需要 90 容错
                isProxy := true
            }
            ; 接管代理按钮“手”图标拇指
            if !ImageSearch(&OutputVarX, &OutputVarY, TobC.ImageRegion.HLX, TobC.ImageRegion.HUY, TobC.ImageRegion.HRX, TobC.ImageRegion.HDY, "*90 " FileExtractor.TakeOver3Path) {
                Logger.Debug("HotkeyActions", "代理指挥判定：手图标识别失败")
                isProxy := false
            }
            if isProxy {
                GameKeys.SendDown("pauseBattle")
                USleep(50)
                GameKeys.SendUp("pauseBattle")
                Logger.Debug("HotkeyActions", "代理指挥，取消暂停")
            } else {
                Logger.Debug("HotkeyActions", "非代理指挥，保持暂停")
            }

            State.BlackScreenDetected := false
            State.ReadyForPause := false
            SetTimer CheckGameStatus, 400
            break
        }
    }
    try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}

; -- 快捷操作 --
; 模拟鼠标左键点击
ActionLButtonClick(ThisHotkey) {
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
ActionCeaseOperations(ThisHotkey) {
    Logger.Debug("HotkeyActions", "ActionCeaseOperations 执行，key=" KeyForward.PureKeyName(ThisHotkey))
    GameKeys.SendDown("battleLeftPopup")
    USleep(50)
    GameKeys.SendUp("battleLeftPopup")
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 跳过招募动画/剧情
ActionSkip(ThisHotkey) {
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        Logger.Debug("HotkeyActions", "ActionSkip 跳过：鼠标不在客户端")
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Pos := SkipButtonPosition()
    if !Pos {
        Logger.Warn("HotkeyActions", "ActionSkip 跳过：游戏窗口不存在")
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Logger.Debug("HotkeyActions", "ActionSkip 执行，key=" KeyForward.PureKeyName(ThisHotkey))
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
; 返回上级菜单
ActionBack(ThisHotkey) {
    Logger.Debug("HotkeyActions", "ActionBack 执行，key=" KeyForward.PureKeyName(ThisHotkey))
    Send "{ESC Down}"
    ; 勾选"使用“返回上级菜单”放弃行动"时，ESC 后补发 battleLeftPopup（还原旧版放弃行动行为）
    if (Config.ReadImportantFromIni("BackCeaseOperations") = "1") {
        GameKeys.SendDown("battleLeftPopup")
        USleep(50)
        Send "{ESC Up}"
        GameKeys.SendUp("battleLeftPopup")
    } else {
        USleep(50)
        Send "{ESC Up}"
    }
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
/* ActionBack(ThisHotkey) {
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    foundBack := false
    Pos := BackButtonPosition()
    ; 寻找箭头时的步进量
    step := 10
    ; 黑底返回按钮
    ; 寻找黑底左上角
    PixelSearch(&FoundX, &FoundY, 0, 0, Pos.PBLX, Pos.PBUY, 0x313131, 5)
    ; MouseMove FoundX, FoundY
    try {
        ; 寻找白色箭头右上角
        PixelSearch(&FoundX, &FoundY, Pos.PBRX, FoundY, FoundX, Pos.PBDY, 0xffffff, 10)
        ; MouseMove FoundX, FoundY
        ; 向左下方向寻找白色，再向右寻找黑色，以确认是否为箭头形状
        if PixelSearch(&FoundX, &FoundY, FoundX - step - 1, FoundY + step - 1, FoundX - step + 1, FoundY + step + 1, 0xffffff, 10) and PixelSearch(&FoundX, &FoundY, FoundX + step - 1, FoundY - 1, FoundX + step + 1, FoundY + 1, 0x313131, 10) {
            foundBack := true
        }
    }
    ; 白底返回按钮
    if !foundBack {
        PixelSearch(&FoundX, &FoundY, 0, 0, Pos.PBLX, Pos.PBUY, 0xfafafa, 10)
        try {
            PixelSearch(&FoundX, &FoundY, Pos.PBRX, FoundY, FoundX, Pos.PBDY, 0x4c4c4c, 10)
            if PixelSearch(&FoundX, &FoundY, FoundX - step - 1, FoundY + step - 1, FoundX - step + 1, FoundY + step + 1, 0x4c4c4c, 10) and PixelSearch(&FoundX, &FoundY, FoundX + step - 1, FoundY - 1, FoundX + step + 1, FoundY + 1, 0xfafafa, 10) {
                foundBack := true
            }
        }
    }
    ; 局内放弃按钮
    if !foundBack {
        AbdC := AbandonButtonPosition()
        if PixelSearch(&FoundX, &FoundY, AbdC.PBRX, AbdC.PBDY, AbdC.PBLX, AbdC.PBUY, 0x8c8c8c, 0) or PixelSearch(&FoundX, &FoundY, AbdC.PBRX, AbdC.PBDY, AbdC.PBLX, AbdC.PBUY, 0x868686, 0) {
            foundBack := true
        }
    }
    ; 集成战略大退红底按钮
    if !foundBack {
        ; 寻找红底左上角
        PixelSearch(&FoundX, &FoundY, 0, 0, Pos.PBLX, Pos.PBUY, 0x5a0000, 10)
        ; 红底左上角右下方寻找白色
        try {
            if PixelSearch(&FoundX, &FoundY, Pos.PBRX, FoundY, FoundX, Pos.PBDY, 0xfafafa, 10) {
                foundBack := true
            }
        }
    }
    if foundBack {
        MouseGetPos &xpos, &ypos
        BlockInput "MouseMove"
        MouseMove FoundX, FoundY
        Send "{Lbutton Down}"
        USleep(40)
        MouseMove FoundX, FoundY
        Send "{LButton Up}"
        USleep(40)
        MouseMove xpos, ypos
        BlockInput "MouseMoveOff"
    }
    if InStr(ThisHotkey, "Wheel") {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
} */
; 基建快速收取
ActionHarvest(ThisHotkey) {
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        Logger.Debug("HotkeyActions", "ActionHarvest 跳过：鼠标不在客户端")
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Pos := HarvestButtonPosition()
    if !Pos {
        Logger.Warn("HotkeyActions", "ActionHarvest 跳过：游戏窗口不存在")
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Logger.Debug("HotkeyActions", "ActionHarvest 执行，key=" KeyForward.PureKeyName(ThisHotkey))
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
; 肉鸽收集藏品
ActionCollectCollectibles(ThisHotkey) {
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        Logger.Debug("HotkeyActions", "ActionCollectCollectibles 跳过：鼠标不在客户端")
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Pos := CollectButtonPosition()
    if !Pos {
        Logger.Warn("HotkeyActions", "ActionCollectCollectibles 跳过：游戏窗口不存在")
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Logger.Debug("HotkeyActions", "ActionCollectCollectibles 执行，key=" KeyForward.PureKeyName(ThisHotkey))
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
ActionCheckEnemies(ThisHotkey) {
    Logger.Debug("HotkeyActions", "ActionCheckEnemies 执行，key=" KeyForward.PureKeyName(ThisHotkey))
    GameKeys.Tap("autochessViewEnemy")
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 调度中心
ActionDispatchCenter(ThisHotkey) {
    Logger.Debug("HotkeyActions", "ActionDispatchCenter 执行，key=" KeyForward.PureKeyName(ThisHotkey))
    GameKeys.Tap("autochessShop")
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 冻结
ActionFreeze(ThisHotkey) {
    Logger.Debug("HotkeyActions", "ActionFreeze 执行，key=" KeyForward.PureKeyName(ThisHotkey))
    GameKeys.Tap("autochessFreeze")
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 刷新
ActionRefresh(ThisHotkey) {
    Logger.Debug("HotkeyActions", "ActionRefresh 执行，key=" KeyForward.PureKeyName(ThisHotkey))
    GameKeys.Tap("autochessRefresh")
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 升级
ActionUpgrade(ThisHotkey) {
    Logger.Debug("HotkeyActions", "ActionUpgrade 执行，key=" KeyForward.PureKeyName(ThisHotkey))
    GameKeys.Tap("autochessLevelUp")
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 出售/销毁
ActionSell(ThisHotkey) {
    Logger.Debug("HotkeyActions", "ActionSell 执行，key=" KeyForward.PureKeyName(ThisHotkey))
    GameKeys.Tap("autochessSale")
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 准备就绪
ActionReady(ThisHotkey) {
    Logger.Debug("HotkeyActions", "ActionReady 执行，key=" KeyForward.PureKeyName(ThisHotkey))
    GameKeys.Tap("autochessReady")
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 一键出售/销毁
ActionOneClickSell(ThisHotkey) {
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        Logger.Debug("HotkeyActions", "ActionOneClickSell 跳过：鼠标不在客户端")
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Logger.Debug("HotkeyActions", "ActionOneClickSell 执行，key=" KeyForward.PureKeyName(ThisHotkey))
    Send "{LButton Down}"
    Send "{LButton Up}"
    USleep(State.ClickDelay)
    GameKeys.Tap("autochessSale")
    if InStr(ThisHotkey, "Wheel") {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 一键购买
ActionOneClickPurchase(ThisHotkey) {
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
; 高精度延迟
USleep(delay_ms) {
    if (delay_ms <= 0)
        return
    static freq := 0
    if (freq = 0)
        DllCall("QueryPerformanceFrequency", "Int64*", &freq)
    start := 0
    DllCall("QueryPerformanceCounter", "Int64*", &start)
    target := start + (delay_ms * freq / 1000)
    current := 0
    Loop {
        DllCall("QueryPerformanceCounter", "Int64*", &current)
        if (current >= target)
            break
        remaining := (target - current) * 1000 / freq
        if (remaining > 4)
            DllCall("Sleep", "UInt", 1)
    }
}
; 去除修饰符前缀
PureKeyWait(ThisHotkey) {
    if (ThisHotkey == "")
        return
    KeyWait(KeyForward.PureKeyName(ThisHotkey))
}
; 关卡守卫：在关卡内返回 true；拦截时透传原键并记录日志，返回 false
; 判定依据：LevelDetector 投票状态机维护的 State.InLevel（读内存标志，无像素检测、无 DPI 切换）
; 守卫关闭（InLevelGuard=0）时 LevelDetector 停止轮询并强制 InLevel=true，此处直接放行，无 I/O
; 拦截是预期行为（非异常），用 Info 级别避免刷 critical 轨（WARN/ERROR 5 MiB 留给真正的问题）
GuardInLevel(actionName, ThisHotkey) {
    pureKey := KeyForward.PureKeyName(ThisHotkey)
    ; 主热键（down）触发即记录该键已被 AFA 处理，Up 变体据此决定补发 up；Up 变体（含 OnUp 型）不记录；
    ; PureKeyName 为空时不记录，避免 DownHandled 出现 "" 键干扰后续逻辑
    if !RegExMatch(ThisHotkey, " Up$") && pureKey != ""
        KeyForward.DownHandled[pureKey] := true
    if State.InLevel
        return true
    ; 同一按住周期的重复 down（InterceptedKeys 已有，已补发过）不再记日志，避免切走时 key repeat 刷屏；
    ; 滚轮不写 InterceptedKeys，每次独立滚动仍逐条记录（合理）
    if !KeyForward.InterceptedKeys.Has(pureKey)
        Logger.Info("HotkeyActions", actionName " 被关卡检测拦截（不在关卡界面）")
    KeyForward.ForwardOriginalKey(ThisHotkey)
    return false
}
; 判断鼠标是否在Client区域内
IsMouseInClient() {
    MouseGetPos , &ypos, &hwnd
    gameHwnd := WinExist("ahk_exe Arknights.exe")
    if !(hwnd == gameHwnd)
        return false
    ; 简单判断会不会点到最小化或者关闭窗口
    if ypos < 0
        return false
    return true
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

; 安全获取明日方舟窗口 Client 区域尺寸，窗口不存在时返回 false 而非抛出 TargetError
SafeWinGetClientPos(&ww, &wh) {
    try {
        WinGetClientPos ,, &ww, &wh, "ahk_exe Arknights.exe"
        return true
    } catch TargetError {
        return false
    }
}
#Include ./touch_injection.ahk
