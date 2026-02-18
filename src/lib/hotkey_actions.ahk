; == 功能实现 ==
; 按下暂停
ActionPressPause(ThisHotkey) {
    Send "{ESC Down}"
    USleep(State.CurrentDelay)
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
    USleep(State.CurrentDelay)
    Send "{ESC Up}"
}
; 切换倍速
ActionGameSpeed(ThisHotkey) {
    Send "{f Down}"
    USleep(State.CurrentDelay)
    Send "{f Up}"
    Send "{g Down}"
    USleep(State.CurrentDelay)
    Send "{g Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 前进33ms，由于波动，过帧间隔设置为29ms，避免一次过两帧
Action33ms(ThisHotkey) {
    Send "{ESC Down}"
    USleep(State.CurrentDelay)
    Send "{ESC Up}"
    USleep(29 - State.CurrentDelay)
    Send "{ESC Down}"
    USleep(State.CurrentDelay)
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 前进166ms
Action166ms(ThisHotkey) {
    Send "{ESC Down}"
    USleep(State.CurrentDelay)
    Send "{ESC Up}"
    USleep(166 - State.CurrentDelay)
    Send "{ESC Down}"
    USleep(State.CurrentDelay)
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 暂停选中
ActionPauseSelect(ThisHotkey) {
    if !IsMouseInClient()
        return
    Send "{ESC Down}"
    USleep(State.CurrentDelay)
    Send "{Click Left}"
    Send "{ESC Up}"
    USleep(State.CurrentDelay * 1.2)
    Send "{ESC Down}"
    USleep(State.CurrentDelay)
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 干员技能
ActionSkill(ThisHotkey) {
    Send "{e Down}"
    USleep(State.CurrentDelay)
    Send "{e Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 干员撤退
ActionRetreat(ThisHotkey) {
    Send "{q Down}"
    USleep(State.CurrentDelay)
    Send "{q Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 一键技能
ActionOneClickSkill(ThisHotkey) {
    if !IsMouseInClient()
        return
    Send "{Click Left}"
    USleep(Constants.SkillAndRetreatDelay * 1.5)
    Send "{e Down}"
    USleep(State.CurrentDelay * 1.3)
    Send "{e Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 一键撤退
ActionOneClickRetreat(ThisHotkey) {
    if !IsMouseInClient()
        return
    Send "{Click Left}"
    USleep(Constants.SkillAndRetreatDelay * 1.5)
    Send "{q Down}"
    USleep(State.CurrentDelay * 1.3)
    Send "{q Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 暂停技能
ActionPauseSkill(ThisHotkey) {
    if !IsMouseInClient()
        return
    Send "{ESC Down}"
    USleep(State.CurrentDelay)
    Send "{Click Left}"
    Send "{ESC Up}"
    USleep(Constants.SkillAndRetreatDelay * 1.4)
    Send "{ESC Down}"
    USleep(State.CurrentDelay)
    Send "{ESC Up}"
    Send "{e Down}"
    USleep(State.CurrentDelay * 1.2)
    Send "{e Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 暂停撤退
ActionPauseRetreat(ThisHotkey) {
    if !IsMouseInClient()
        return
    Send "{ESC Down}"
    USleep(State.CurrentDelay)
    Send "{Click Left}"
    Send "{ESC Up}"
    USleep(Constants.SkillAndRetreatDelay * 1.4)
    Send "{ESC Down}"
    USleep(State.CurrentDelay)
    Send "{ESC Up}"
    Send "{q Down}"
    USleep(State.CurrentDelay * 1.2)
    Send "{q Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 模拟鼠标左键点击
RbuttonClick(ThisHotkey) {
    if !IsMouseInClient()
        return
    Send "{Click Left}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}

; == 工具函数 ==
; 高精度延迟
USleep(delay_ms) {
    static freq := 0
    static isHighRes := false
    if (delay_ms <= State.CurrentDelay) {
        delay_ms := State.CurrentDelay
    }
    if (freq = 0) {
        DllCall("QueryPerformanceFrequency", "Int64*", &freq)
    }
    if (!isHighRes) {
        DllCall("winmm\timeBeginPeriod", "UInt", 1)
        isHighRes := true
    }
    start := 0
    DllCall("QueryPerformanceCounter", "Int64*", &start)
    target := start + (delay_ms * freq / 1000)
    Loop {
        current := 0
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