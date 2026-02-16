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
; 包含版本号
#Include ./lib/version.ahk

; 包含配置管理
#Include ./lib/config.ahk

; 包含事件总线
#Include ./lib/eventbus.ahk

; 包含更新模块
#Include ./lib/updater/version_checker.ahk
#Include ./lib/updater/ui.ahk
#Include ./lib/updater/downloader.ahk

; 包含功能实现
#Include ./lib/hotkey_actions.ahk

; 包含按键绑定
#Include ./lib/key_bind.ahk

; 包含热键控制
#Include ./lib/hotkey.ahk

; 包含设置管理
#Include ./lib/setting.ahk

; 订阅设置相关事件
SubscribeSettingEvents()
SubscribeHotkeyEvents()
SubscribeKeyBindEvents()

; 初始化
LoadSettings()
HotkeyOn()

; 包含GUI
#Include ./lib/gui.ahk

; 包含游戏监控
#Include ./lib/game_monitor.ahk
