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

; 统一日志和版本定义需要在提权前可用，便于后续启动流程记录。
#Include ./lib/logger.ahk
#Include ./lib/version.ahk

HandleAfaExit(exitReason, exitCode) {
    Logger.HandleExit(exitReason, exitCode)
    DllCall("winmm\timeEndPeriod", "UInt", 1)
}

OnExit HandleAfaExit

; 判断是否由游戏启动事件触发
HasLaunchArgument(argument) {
    for arg in A_Args {
        if (StrLower(arg) = StrLower(argument))
            return true
    }
    return false
}

startedByGameAutoStart := HasLaunchArgument("--game-autostart")

; 获取权限
if not A_IsAdmin {
    try
    {
        launchContextArgs := startedByGameAutoStart ? " --game-autostart" : ""
        if A_IsCompiled
            Run '*RunAs "' A_ScriptFullPath '" /restart' launchContextArgs
        else
            Run '*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"' launchContextArgs
    }
    ExitApp
}

; 管理员进程开始记录持久化日志。
Logger.Init()
Logger.Info("Startup", "管理员进程启动，脚本=" A_ScriptName)

; 包含统一消息框
#Include ./lib/message_box.ahk

; 包含 GitHub Token 保护模块
#Include ./lib/token_protector.ahk

; 包含配置管理
#Include ./lib/config.ahk

; 包含日志压缩包导出
#Include ./lib/log_exporter.ahk

; 包含随游戏自动启动模块
#Include ./lib/game_auto_start.ahk

; 包含事件总线
#Include ./lib/eventbus.ahk

; 包含文件提取模块
#Include ./lib/file_extractor.ahk

; 包含游戏按键注册表识别
#Include ./lib/game_keys.ahk

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
Logger.RegisterSecret(Config.GetImportant("GitHubToken"))
Logger.RegisterSecret(Config.GetImportant("GamePath"))
Logger.RegisterSecret(A_ScriptFullPath)
Logger.Info("Startup", "配置加载完成，版本=" Version.Get())

; 写入启动来源状态，并校准随游戏自动启动的 Windows 审核和计划任务
State.StartedByGameAutoStart := startedByGameAutoStart
autoStartResult := GameAutoStartManager.Reconcile()
if (!autoStartResult.success) {
    Logger.Error("GameAutoStart", "启动时校准失败：" autoStartResult.message)
    if (!State.StartedByGameAutoStart && Config.GetImportant("AutoStartWithGame") = "1")
        MessageBox.Warning(autoStartResult.message, "随游戏自动启动校准失败")
}

; 关闭功能后若有遗留事件触发，只清理任务，不启动小助手主体
if (State.StartedByGameAutoStart && Config.GetImportant("AutoStartWithGame") != "1")
    ExitApp

; 确保嵌入文件已提取到 AppData
FileExtractor.EnsureExtracted()

; 初始化游戏按键识别（必须在 HotkeyOn 之前）
GameKeys.Init()

HotkeyController.HotkeyOn()

; 包含更新公告模块
#Include ./lib/changelog/changelog.ahk
#Include ./lib/changelog/changelog_ui.ahk
#Include ./lib/changelog/changelog_checker.ahk

; 检查并显示更新公告
ChangelogChecker.CheckAndShow()

; 包含GUI
#Include ./lib/gui.ahk
#Include ./lib/updater/updater_ui.ahk

tokenStorageWarning := Config.GetTokenStorageWarning()
if (tokenStorageWarning != "")
    MessageBox.Warning(tokenStorageWarning, "GitHub Token 存储提示")

; 触发应用启动事件（触发自动更新检查和游戏自动启动）
EventBus.Publish("AppStarted")

; 包含游戏监控
#Include ./lib/game_monitor.ahk

; 初始化按键
EventBus.Publish("SetSwitchKey")

; 刷新GUI以正确应用文本
EventBus.Publish("GuiUpdateHotkeyControls")
EventBus.Publish("GuiUpdateImportantControls")
EventBus.Publish("GuiUpdateCustomControls")