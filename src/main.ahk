#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, Off

ListLines False
KeyHistory 0
ProcessSetPriority "High"
SendMode "Input"
SetKeyDelay -1, -1
SetMouseDelay -1
SetWinDelay -1
SetDefaultMouseSpeed 0
SetTitleMatchMode 3

; 开启高精度计时器
DllCall("winmm\timeBeginPeriod", "UInt", 1)
OnExit (*) => DllCall("winmm\timeEndPeriod", "UInt", 1)

; 获取管理员权限
if not A_IsAdmin
{
    try
    {
        if A_IsCompiled
            Run '*RunAs "' A_ScriptFullPath '" /restart'
        else
            Run '*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"'
    }
    ExitApp
}

#Include ./lib/global.ahk
#Include ./lib/gui.ahk
#Include ./lib/setting.ahk
#Include ./lib/key_bind.ahk

; 初始化加载
LoadSettings()
HotkeyOn()

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

; 前进33ms
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
    ; 若已实现自定义延迟，此处建议改为 AppSettings["SkillDelay"]
    USleep(Delay * 1.5)
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
    USleep(Delay * 1.5)
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
    USleep(Delay * 1.4)
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
    USleep(Delay * 1.4)
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


; 高精度延迟 (QPC实现)
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

; 去除修饰符前缀并执行KeyWait
PureKeyWait(ThisHotkey) {
    pureKey := RegExReplace(ThisHotkey, "^[~*$#!^+&]+")
    KeyWait(pureKey)
}

A_TrayMenu.Delete() 
A_TrayMenu.Add("设置中心", TrayShowGui)
A_TrayMenu.Default := "设置中心" 
A_TrayMenu.Add("重启助手", (*) => Reload())
A_TrayMenu.Add() 
A_TrayMenu.Add("退出程序", (*) => ExitApp())

TrayShowGui(*) {
    ; 显式声明全局变量，确保在双击托盘时能正确识别 GUI 对象
    global MyGui, WindowName 

    try {
        if IsSet(MyGui) {
            ; 显示助手设置窗口
            MyGui.Show()
            
            ; 焦点行为修正：
            ; 激活设置窗口本身，并确保它位于屏幕最前端
            WinActivate(MyGui.Hwnd)
            WinRestore(MyGui.Hwnd)
        }
    }
}