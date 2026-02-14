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

; 包含全局变量
#Include ./lib/global.ahk

; 包含功能实现
#Include ./lib/actions.ahk

; 初始化
LoadSettings()
HotkeyOn()

; 包含GUI
#Include ./lib/gui.ahk

; 包含设置
#Include ./lib/setting.ahk

; 包含热键控制
#Include ./lib/hotkey.ahk

; 包含游戏监控
#Include ./lib/game_monitor.ahk

; 按键绑定
#Include ./lib/key_bind.ahk