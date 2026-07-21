; == 功能实现 ==
; -- 常规作战 --
; 按下暂停
ActionPressPause(ThisHotkey) {
    Send "{ESC Down}"
    USleep(50)
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 松开暂停
ActionReleasePause(ThisHotkey) {
    GameKeys.Tap("pauseBattle")
}
; 切换倍速
ActionGameSpeed(ThisHotkey) {
    GameKeys.SendDown("changeSpeed")
    USleep(50)
    GameKeys.SendUp("changeSpeed")
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 前进16ms
Action16ms(ThisHotkey) {
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    delay := Integer(Config.GetCustom("FrameSkip16msDelay"))
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
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    delay := Integer(Config.GetCustom("FrameSkip33msDelay"))
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
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    delay := Integer(Config.GetCustom("FrameSkip166msDelay"))
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
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PosL := PauseButtonPositionLeft()
    PosR := PauseButtonPositionRight()
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
    GameKeys.Tap("releaseSkill")
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 发送撤退键
ActionRetreat(ThisHotkey) {
    GameKeys.Tap("retreatChar")
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 一键技能
ActionOneClickSkill(ThisHotkey) {
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
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
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
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
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PosL := PauseButtonPositionLeft()
    PosR := PauseButtonPositionRight()
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
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PosL := PauseButtonPositionLeft()
    PosR := PauseButtonPositionRight()
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
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PosL := PauseButtonPositionLeft()
    PosR := PauseButtonPositionRight()
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
    if (newValue = "1") {
        TrayTip
        TrayTip("已开启开局自动暂停", "AFA")
    } else {
        TrayTip
        TrayTip("已关闭开局自动暂停", "AFA")
    }
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 开局暂停
ActionBeginPause() {
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    PosC := SpeedButtonPositionColor()
    while(true) {
        ; ToolTip("正在识别按钮！")  ; 调试代码
        if PixelSearch(&FoundX, &FoundY, PosC.PBCRX, PosC.PBCUY, PosC.PBCLX, PosC.PBCDY, 0xffffff, 10)
        {
            if !IsInLevel() {
                State.BlackScreenDetected := false
                State.ReadyForPause := false
                SetTimer CheckGameStatus, 400
                return
            }
            Send "{ESC Down}"
            USleep(50)
            Send "{ESC Up}"
            ; ToolTip("已严肃暂停")  ; 调试代码
            ; 为了降低暂停延迟，后置代理指挥识别，识别到是代理指挥时取消暂停
            isProxy := false
            TobC := TakeOverButtonPositions()
            ; 接管代理按钮右侧边缘
            if ImageSearch(&OutputVarX, &OutputVarY, TobC.ImageRegion.RLX, TobC.ImageRegion.RUY, TobC.ImageRegion.RRX, TobC.ImageRegion.RDY, "*90 " FileExtractor.TakeOver1Path) or ImageSearch(&OutputVarX, &OutputVarY, TobC.ImageRegion.RLX, TobC.ImageRegion.RUY, TobC.ImageRegion.RRX, TobC.ImageRegion.RDY, "*90 " FileExtractor.TakeOver2Path) { ; 0 帧暂停接管按钮半透明导致至少需要 90 容错
                isProxy := true
            }
            ; 接管代理按钮“手”图标拇指
            if !ImageSearch(&OutputVarX, &OutputVarY, TobC.ImageRegion.HLX, TobC.ImageRegion.HUY, TobC.ImageRegion.HRX, TobC.ImageRegion.HDY, "*90 " FileExtractor.TakeOver3Path) {
                ; ToolTip("图2识别失败")
                isProxy := false
            }
            if isProxy {
                Send "{ESC Down}"
                USleep(50)
                Send "{ESC Up}"
                ; ToolTip("是代理指挥，取消暂停")  ; 调试代码
            } else {
                ; ToolTip("没有找到代理指挥")  ; 调试代码
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
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
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
    GameKeys.SendDown("battleLeftPopup")
    Send "{ESC Down}"
    USleep(50)
    GameKeys.SendUp("battleLeftPopup")
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 跳过招募动画/剧情
ActionSkip(ThisHotkey) {
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Pos := SkipButtonPosition()
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
    GameKeys.SendDown("battleLeftPopup")
    Send "{ESC Down}"
    USleep(50)
    GameKeys.SendUp("battleLeftPopup")
    Send "{ESC Up}"
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
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Pos := HarvestButtonPosition()
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
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Pos := CollectButtonPosition()
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
    GameKeys.Tap("autochessViewEnemy")
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 调度中心
ActionDispatchCenter(ThisHotkey) {
    GameKeys.Tap("autochessShop")
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 冻结
ActionFreeze(ThisHotkey) {
    GameKeys.Tap("autochessFreeze")
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 刷新
ActionRefresh(ThisHotkey) {
    GameKeys.Tap("autochessRefresh")
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 升级
ActionUpgrade(ThisHotkey) {
    GameKeys.Tap("autochessLevelUp")
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 出售/销毁
ActionSell(ThisHotkey) {
    GameKeys.Tap("autochessSale")
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 准备就绪
ActionReady(ThisHotkey) {
    GameKeys.Tap("autochessReady")
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 一键出售/销毁
ActionOneClickSell(ThisHotkey) {
    try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
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
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
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
    pureKey := RegExReplace(ThisHotkey, "^[~*$!^+#&<>()]+")
    KeyWait(pureKey)
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
    WinGetClientPos ,, &ww, &wh, "ahk_exe Arknights.exe"
    PButtonLX := ww * 0.0474
    PButtonRX := ww * 0.1369
    PButtonUY := wh * 0.0444
    PButtonDY := wh * 0.0694
    return {PBLX: PButtonLX, PBUY: PButtonUY, PBRX: PButtonRX, PBDY: PButtonDY}
}
; 关卡界面检测
IsInLevel() {
    AbdC := AbandonButtonPosition()
    if PixelSearch(&FoundX, &FoundY, AbdC.PBRX, AbdC.PBDY, AbdC.PBLX, AbdC.PBUY, 0x8c8c8c, 0) {
        return true
    }
    if PixelSearch(&FoundX, &FoundY, AbdC.PBRX, AbdC.PBDY, AbdC.PBLX, AbdC.PBUY, 0xd8d769, 0) {
        return true
    }
    return false
}
; 获取暂停按钮位置
PauseButtonPosition() {
    WinGetClientPos ,, &ww, &wh, "ahk_exe Arknights.exe"
    PButtonX := ww * 0.9525
    PButtonY := wh * 0.0700
    return {PBX: PButtonX, PBY: PButtonY}
}
; 获取暂停按钮左半部分位置
PauseButtonPositionLeft() {
    WinGetClientPos ,, &ww, &wh, "ahk_exe Arknights.exe"
    PButtonLX := ww * 0.9400
    PButtonLY := wh * 0.0700
    return {PBLX: PButtonLX, PBLY: PButtonLY}
}
; 获取暂停按钮右半部分位置
PauseButtonPositionRight() {
    WinGetClientPos ,, &ww, &wh, "ahk_exe Arknights.exe"
    PButtonRX := ww * 0.9650
    PButtonRY := wh * 0.0700
    return {PBRX: PButtonRX, PBRY: PButtonRY}
}
; 获取自动暂停倍速按钮识别位置
SpeedButtonPositionColor() {
    WinGetClientPos ,, &ww, &wh, "ahk_exe Arknights.exe"
    PButtonCLX := ww * 0.8450
    PButtonCRX := ww * 0.8807
    PButtonCUY := wh * 0.0713
    PButtonCDY := wh * 0.0870
    return {PBCLX: PButtonCLX, PBCRX: PButtonCRX, PBCUY: PButtonCUY, PBCDY: PButtonCDY}
}
; 获取基建收取按钮位置
HarvestButtonPosition() {
    WinGetClientPos ,, &ww, &wh, "ahk_exe Arknights.exe"
    PButtonX := ww * 0.1297
    PButtonY := wh * 0.9527
    return {PBX: PButtonX, PBY: PButtonY}
}
; 获取代理接管作战按钮识别位置（线点识别 + 图像识别）
TakeOverButtonPositions() {
    WinGetClientPos ,, &ww, &wh, "ahk_exe Arknights.exe"
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
    WinGetClientPos ,, &ww, &wh, "ahk_exe Arknights.exe"
    PButtonX := ww * 0.1104
    PButtonY := wh * 0.7250
    return {PBX: PButtonX, PBY: PButtonY}
}
; 获取跳过按钮位置
SkipButtonPosition() {
    WinGetClientPos ,, &ww, &wh, "ahk_exe Arknights.exe"
    PButtonX := ww * 0.959765
    PButtonY := wh * 0.091666
    return {PBX: PButtonX, PBY: PButtonY}
}

; == 工具类 ==
#Include ./touch_injection.ahk