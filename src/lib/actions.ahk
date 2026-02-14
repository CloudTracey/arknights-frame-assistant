; == 功能实现 ==
; 按下暂停
ActionPressPause(ThisHotkey) {
    Send "{ESC Down}"
    USleep(Delay)
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
    USleep(Delay)
    Send "{ESC Up}"
}
; 切换倍速
ActionGameSpeed(ThisHotkey) {
    Send "{f Down}"
    USleep(Delay)
    Send "{f Up}"
    Send "{g Down}"
    USleep(Delay)
    Send "{g Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 前进33ms，由于波动，过帧间隔设置为29ms，避免一次过两帧
Action33ms(ThisHotkey) {
    Send "{ESC Down}"
    USleep(Delay)
    Send "{ESC Up}"
    USleep(29 - Delay)
    Send "{ESC Down}"
    USleep(Delay)
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 前进166ms
Action166ms(ThisHotkey) {
    Send "{ESC Down}"
    USleep(Delay)
    Send "{ESC Up}"
    USleep(166 - Delay)
    Send "{ESC Down}"
    USleep(Delay)
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 暂停选中
ActionPauseSelect(ThisHotkey) {
    Send "{ESC Down}"
    USleep(Delay)
    Send "{Click Left}"
    Send "{ESC Up}"
    USleep(Delay * 1.2)
    Send "{ESC Down}"
    USleep(Delay)
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 干员技能
ActionSkill(ThisHotkey) {
    Send "{e Down}"
    USleep(Delay)
    Send "{e Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 干员撤退
ActionRetreat(ThisHotkey) {
    Send "{q Down}"
    USleep(Delay)
    Send "{q Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 一键技能
ActionOneClickSkill(ThisHotkey) {
    Send "{Click Left}"
    USleep(SkillAndRetreatDelay * 1.5)
    Send "{e Down}"
    USleep(Delay * 1.3)
    Send "{e Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 一键撤退
ActionOneClickRetreat(ThisHotkey) {
    Send "{Click Left}"
    USleep(SkillAndRetreatDelay * 1.5)
    Send "{q Down}"
    USleep(Delay * 1.3)
    Send "{q Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 暂停技能
ActionPauseSkill(ThisHotkey) {
    Send "{ESC Down}"
    USleep(Delay)
    Send "{Click Left}"
    Send "{ESC Up}"
    USleep(SkillAndRetreatDelay * 1.4)
    Send "{ESC Down}"
    USleep(Delay)
    Send "{ESC Up}"
    Send "{e Down}"
    USleep(Delay * 1.2)
    Send "{e Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 暂停撤退
ActionPauseRetreat(ThisHotkey) {
    Send "{ESC Down}"
    USleep(Delay)
    Send "{Click Left}"
    Send "{ESC Up}"
    USleep(SkillAndRetreatDelay * 1.4)
    Send "{ESC Down}"
    USleep(Delay)
    Send "{ESC Up}"
    Send "{q Down}"
    USleep(Delay * 1.2)
    Send "{q Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 模拟鼠标左键点击
RbuttonClick(ThisHotkey) {
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
    if (delay_ms <= Delay) {
        delay_ms := Delay
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
