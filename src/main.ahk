#Requires AutoHotkey v2.0
#SingleInstance Ignore
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
CoordMode "Mouse", "Client"
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

; 包含功能实现
#Include ./lib/hotkey_actions.ahk

; 包含按键绑定
#Include ./lib/key_bind.ahk

; 包含热键控制
#Include ./lib/hotkey_control.ahk

; 包含设置管理
#Include ./lib/settings/settings_manager.ahk

; 包含更新模块
#Include ./lib/updater/version_checker.ahk
#Include ./lib/updater/downloader.ahk
#Include ./lib/updater/self_replacer.ahk
#Include ./lib/updater/updater_manager.ahk

; 包含游戏启动器
#Include ./lib/game_launcher.ahk

; 加载设置
Loader.LoadSettings()

; 包含GUI
#Include ./lib/gui.ahk
#Include ./lib/updater/updater_ui.ahk

; 触发应用启动事件（触发自动更新检查和游戏自动启动）
EventBus.Publish("AppStarted")

; 包含游戏监控
#Include ./lib/game_monitor.ahk

; 初始化按键
EventBus.Publish("HotkeyOn")
EventBus.Publish("SetSwitchKey")

; 刷新GUI以正确应用文本
EventBus.Publish("GuiUpdateHotkeyControls")
EventBus.Publish("GuiUpdateImportantControls")
EventBus.Publish("GuiUpdateCustomControls")