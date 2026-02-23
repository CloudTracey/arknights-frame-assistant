; == 功能实现 ==
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
    if InStr(ThisHotkey, "Wheel") == 0 {
        PureKeyWait(ThisHotkey)
    }
    Send "{ESC Down}"
    USleep(50)
    Send "{ESC Up}"
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
    if !IsMouseInClient()
        return
    Pos := PauseButtonPosition()
    MouseGetPos &xpos, &ypos
    BlockInput "MouseMove"
    MouseMove Pos.PBX, Pos.PBY
    Send "{Lbutton Down}"
    MouseMove Pos.PBX, Pos.PBY
    Send "{LButton Up}"
    USleep(30)
    Send "{ESC Down}"
    USleep(15)
    MouseMove xpos, ypos
    BlockInput "MouseMoveOff"
    USleep(30)
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 前进166ms
Action166ms(ThisHotkey) {
    if !IsMouseInClient()
        return
    Pos := PauseButtonPosition()
    MouseGetPos &xpos, &ypos
    BlockInput "MouseMove"
    MouseMove Pos.PBX, Pos.PBY
    Send "{Lbutton Down}"
    MouseMove Pos.PBX, Pos.PBY
    Send "{LButton Up}"
    USleep(45)
    MouseMove xpos, ypos
    BlockInput "MouseMoveOff"
    USleep(120)
    Send "{ESC Down}"
    USleep(45)
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 暂停选中
ActionPauseSelect(ThisHotkey) {
    if !IsMouseInClient()
        return
    Pos := PauseButtonPosition()
    MouseGetPos &xpos, &ypos
    BlockInput "MouseMove"
    MouseMove Pos.PBX, Pos.PBY
    Send "{Lbutton Down}"
    MouseMove Pos.PBX, Pos.PBY
    Send "{LButton Up}"
    USleep(State.CurrentDelay * 1.3)
    MouseMove xpos, ypos
    Send "{RButton Down}"
    BlockInput "MouseMoveOff"
    Send "{ESC Down}"
    Send "{RButton Up}"
    USleep(45)
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
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
    if !IsMouseInClient()
        return
    Send "{RButton Down}"
    Send "{RButton Up}"
    USleep(50)
    Send "{e Down}"
    USleep(50)
    Send "{e Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 一键撤退
ActionOneClickRetreat(ThisHotkey) {
    if !IsMouseInClient()
        return
    Send "{RButton Down}"
    Send "{RButton Up}"
    USleep(50)
    Send "{q Down}"
    USleep(50)
    Send "{q Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 暂停技能
ActionPauseSkill(ThisHotkey) {
    if !IsMouseInClient()
        return
    Pos := PauseButtonPosition()
    MouseGetPos &xpos, &ypos
    BlockInput "MouseMove"
    MouseMove Pos.PBX, Pos.PBY
    Send "{Lbutton Down}"
    MouseMove Pos.PBX, Pos.PBY
    Send "{LButton Up}"
    USleep(State.CurrentDelay * 1.3)
    MouseMove xpos, ypos
    Send "{RButton Down}"
    BlockInput "MouseMoveOff"
    Send "{ESC Down}"
    Send "{RButton Up}"
    USleep(50)
    Send "{e Down}"
    USleep(50)
    Send "{e Up}"
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 暂停撤退
ActionPauseRetreat(ThisHotkey) {
    if !IsMouseInClient()
        return
    Pos := PauseButtonPosition()
    MouseGetPos &xpos, &ypos
    BlockInput "MouseMove"
    MouseMove Pos.PBX, Pos.PBY
    Send "{Lbutton Down}"
    MouseMove Pos.PBX, Pos.PBY
    Send "{LButton Up}"
    USleep(State.CurrentDelay * 1.3)
    MouseMove xpos, ypos
    Send "{RButton Down}"
    BlockInput "MouseMoveOff"
    Send "{ESC Down}"
    Send "{RButton Up}"
    USleep(50)
    Send "{q Down}"
    USleep(50)
    Send "{q Up}"
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 模拟鼠标左键点击
LButtonClick(ThisHotkey) {
    if !IsMouseInClient()
        return
    Send "{Lbutton Down}"
    if InStr(ThisHotkey, "Wheel") {
        Send "{LButton Up}"
        return
    }
    PureKeyWait(ThisHotkey)
    Send "{LButton Up}"
}

; == 工具函数 ==
; 高精度延迟
USleep(delay_ms) {
    static freq := 0
    ;if (delay_ms <= State.CurrentDelay) {
    ;   delay_ms := State.CurrentDelay
    ;}
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
        if (remaining > 2)
            DllCall("Sleep", "UInt", 1)
    }
}
; 去除修饰符前缀
PureKeyWait(ThisHotkey) {
    pureKey := RegExReplace(ThisHotkey, "^[~*$#!^+&]+")
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