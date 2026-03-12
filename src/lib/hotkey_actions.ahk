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
    Send "{Space Down}"
    USleep(50)
    Send "{Space Up}"
}
; 切换倍速
ActionGameSpeed(ThisHotkey) {
    Send "{f Down}"
    Send "{g Down}"
    USleep(50)
    Send "{f Up}"
    Send "{g Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 前进33ms，由于波动，过帧间隔设置为30ms，避免一次过两帧
Action33ms(ThisHotkey) {
    oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Send "{ESC Down}"
    USleep(30)
    Send "{Space Down}"
    USleep(50)
    Send "{ESC Up}"
    Send "{Space Up}"
    if InStr(ThisHotkey, "Wheel") {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 前进166ms
Action166ms(ThisHotkey) {
    oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Send "{ESC Down}"
    USleep(165)
    Send "{Space Down}"
    USleep(50)
    Send "{ESC Up}"
    Send "{Space Up}"
    if InStr(ThisHotkey, "Wheel") {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 暂停选中
ActionPauseSelect(ThisHotkey) {
    oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Send "{Space Down}"
    USleep(State.CurrentDelay)
    Send "{RButton Down}"
    Send "{RButton Up}"
    Send "{ESC Down}"
    USleep(50)
    Send "{Space Up}"
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel") {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 干员技能
ActionSkill(ThisHotkey) {
    Send "{e Down}"
    USleep(50)
    Send "{e Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 干员撤退
ActionRetreat(ThisHotkey) {
    Send "{q Down}"
    USleep(50)
    Send "{q Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 一键技能
ActionOneClickSkill(ThisHotkey) {
    oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Send "{RButton Down}"
    Send "{RButton Up}"
    USleep(State.SkillAndRetreatDelay)
    Send "{e Down}"
    USleep(50)
    Send "{e Up}"
    if InStr(ThisHotkey, "Wheel") {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 一键撤退
ActionOneClickRetreat(ThisHotkey) {
    oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Send "{RButton Down}"
    Send "{RButton Up}"
    USleep(State.SkillAndRetreatDelay)
    Send "{q Down}"
    USleep(50)
    Send "{q Up}"
    if InStr(ThisHotkey, "Wheel") {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 暂停技能
ActionPauseSkill(ThisHotkey) {
    oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Send "{Space Down}"
    USleep(State.CurrentDelay)
    Send "{RButton Down}"
    Send "{RButton Up}"
    Send "{ESC Down}"
    USleep(State.SkillAndRetreatDelay)
    Send "{e Down}"
    USleep(50)
    Send "{e Up}"
    Send "{Space Up}"
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel") {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 暂停撤退
ActionPauseRetreat(ThisHotkey) {
    oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Send "{Space Down}"
    USleep(State.CurrentDelay)
    Send "{RButton Down}"
    Send "{RButton Up}"
    Send "{ESC Down}"
    USleep(State.SkillAndRetreatDelay)
    Send "{q Down}"
    USleep(50)
    Send "{q Up}"
    Send "{Space Up}"
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel") {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}

; -- 快捷操作 --
; 模拟鼠标左键点击
ActionLButtonClick(ThisHotkey) {
    oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Send "{LButton Down}"
    if InStr(ThisHotkey, "Wheel") {
        Send "{LButton Up}"
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    Send "{LButton Up}"
    DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 放弃行动
ActionCeaseOperations(ThisHotkey) {
    Send "{v Down}"
    Send "{ESC Down}"
    USleep(50)
    Send "{v Up}"
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 跳过招募动画/剧情
ActionSkip(ThisHotkey) {
    oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Pos := PauseButtonPosition()
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
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 返回上级菜单
ActionBack(ThisHotkey) {
    Send "{v Down}"
    Send "{ESC Down}"
    USleep(50)
    Send "{v Up}"
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 基建快速收取
ActionHarvest(ThisHotkey) {
    oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
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
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 肉鸽收集藏品
ActionCollectCollectibles(ThisHotkey){
    oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
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
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}

; -- 卫戍协议 --
; 查看敌人
ActionCheckEnemies(ThisHotkey) {
    Send "{w Down}"
    USleep(50)
    Send "{w Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 调度中心
ActionDispatchCenter(ThisHotkey) {
    Send "{a Down}"
    USleep(50)
    Send "{a Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 冻结
ActionFreeze(ThisHotkey) {
    Send "{s Down}"
    USleep(50)
    Send "{s Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 刷新
ActionRefresh(ThisHotkey) {
    Send "{d Down}"
    USleep(50)
    Send "{d Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 升级
ActionUpgrade(ThisHotkey) {
    Send "{g Down}"
    USleep(50)
    Send "{g Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 出售
ActionSell(ThisHotkey) {
    Send "{x Down}"
    USleep(50)
    Send "{x Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 准备就绪
ActionReady(ThisHotkey) {
    Send "{c Down}"
    USleep(50)
    Send "{c Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 一键出售
ActionOneClickSell(ThisHotkey) {
    oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Send "{LButton Down}"
    Send "{LButton Up}"
    USleep(State.SkillAndRetreatDelay)
    Send "{X Down}"
    USleep(50)
    Send "{X Up}"
    if InStr(ThisHotkey, "Wheel") {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
}
; 一键购买
ActionOneClickPurchase(ThisHotkey) {
    oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
    if !IsMouseInClient() {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    Send "{LButton Down}"
    Send "{LButton Up}"
    USleep(40)
    Send "{LButton Down}"
    Send "{LButton Up}"
    if InStr(ThisHotkey, "Wheel") {
        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        return
    }
    PureKeyWait(ThisHotkey)
    DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
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
; 获取暂停按钮位置
PauseButtonPosition() {
    WinGetClientPos ,, &ww, &wh, "ahk_exe Arknights.exe"
    PButtonX := ww * 0.9442
    PButtonY := wh * 0.0666
    return {PBX: PButtonX, PBY: PButtonY}
}
; 获取基建收取按钮位置
HarvestButtonPosition() {
    WinGetClientPos ,, &ww, &wh, "ahk_exe Arknights.exe"
    PButtonX := ww * 0.1297
    PButtonY := wh * 0.9527
    return {PBX: PButtonX, PBY: PButtonY}
}
; 获取“收下”按钮位置
CollectButtonPosition() {
    WinGetClientPos ,, &ww, &wh, "ahk_exe Arknights.exe"
    PButtonX := ww * 0.1104
    PButtonY := wh * 0.7250
    return {PBX: PButtonX, PBY: PButtonY}
}