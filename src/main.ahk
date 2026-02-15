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
DllCall("winmm\timeBeginPeriod", "UInt", 1)
OnExit (*) => DllCall("winmm\timeEndPeriod", "UInt", 1)

; 获取权限
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

; 包含配置管理
#Include ./lib/config.ahk

; 包含功能实现
#Include ./lib/actions.ahk

; 包含按键绑定（StopHook）
#Include ./lib/key_bind.ahk

; 包含热键控制（HotkeyOn/Off）
#Include ./lib/hotkey.ahk

; 包含设置管理（LoadSettings 等）
#Include ./lib/setting.ahk

; 初始化（需要在 setting 和 hotkey 之后）
LoadSettings()
HotkeyOn()

; 包含GUI（需要在 setting 之后，使用 setting 的函数）
#Include ./lib/gui.ahk

; 包含游戏监控
#Include ./lib/game_monitor.ahk
