#Requires AutoHotkey v2.0
#SingleInstance Ignore
#Warn All, Off

; 所有模块只定义、零顶层副作用；启动由下方 App.Bootstrap() 显式执行。
#Include ./lib/base/logger.ahk
#Include ./lib/base/version.ahk
#Include ./lib/base/message_box.ahk
#Include ./lib/base/token_protector.ahk
#Include ./lib/base/hotkey_schema.ahk
#Include ./lib/base/constants.ahk
#Include ./lib/base/config.ahk
#Include ./lib/base/eventbus.ahk
#Include ./lib/base/file_extractor.ahk
#Include ./lib/base/timing.ahk
#Include ./lib/base/window.ahk
#Include ./lib/base/key_format.ahk
#Include ./lib/base/tray.ahk
#Include ./lib/base/version_utils.ahk
#Include ./lib/base/touch_injection.ahk
#Include ./lib/log_exporter.ahk
#Include ./lib/core/launch/app_context.ahk
#Include ./lib/core/launch/game_auto_start.ahk
#Include ./lib/core/hotkey/timing_service.ahk
#Include ./lib/core/hotkey/game_keys.ahk
#Include ./lib/core/hotkey/hotkey_actions.ahk
#Include ./lib/core/monitor/level_detector.ahk
#Include ./lib/ui/key_bind.ahk
#Include ./lib/core/hotkey/hotkey_service.ahk
#Include ./lib/core/settings/hotkey_conflict_validator.ahk
#Include ./lib/core/settings/settings_service.ahk
#Include ./lib/core/updater/github_token_service.ahk
#Include ./lib/core/updater/release_repository.ahk
#Include ./lib/core/updater/version_checker.ahk
#Include ./lib/core/updater/downloader.ahk
#Include ./lib/core/updater/self_replacer.ahk
#Include ./lib/core/updater/updater_manager.ahk
#Include ./lib/ui/updater_ui.ahk
#Include ./lib/core/launch/game_launcher.ahk
#Include ./lib/ui/changelog_ui.ahk
#Include ./lib/core/changelog/changelog_checker.ahk
#Include ./lib/ui/gui.ahk
#Include ./lib/core/monitor/game_monitor.ahk

HandleAfaExit(exitReason, exitCode) {
    Logger.HandleExit(exitReason, exitCode)
    Logger.CloseConsole()
    DllCall("winmm\timeEndPeriod", "UInt", 1)
}

; 判断是否由游戏启动事件触发
HasLaunchArgument(argument) {
    for arg in A_Args {
        if (StrLower(arg) = StrLower(argument))
            return true
    }
    return false
}

class App {
    static Bootstrap() {
        ; ---- 环境初始化 ----
        ListLines False
        KeyHistory 0
        ProcessSetPriority "High"
        SendMode "Input"
        SetKeyDelay -1, -1
        ; 提高热键触发频率阈值：被拦截的游戏键每个按键触发 down+up 两个热键，极速连打 WASD 等键易超默认 66/2000ms 触发警告弹窗
        A_MaxHotkeysPerInterval := 200
        SetMouseDelay -1
        SetWinDelay -1
        SetDefaultMouseSpeed 0
        SetTitleMatchMode 3
        CoordMode "Mouse", "Client"
        DllCall("winmm\timeBeginPeriod", "UInt", 1)

        OnExit HandleAfaExit

        startedByGameAutoStart := HasLaunchArgument("--game-autostart")

        ; ---- 提权 ----
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

        ; ---- 管理员进程日志 ----
        Logger.Init()
        Logger.Info("Startup", "管理员进程启动，脚本=" A_ScriptName)

        ; 上一会话异常退出（Logger.PreviousAbnormalFile 在 Logger.Init 已识别）时提示用户。
        if (Logger.PreviousAbnormalFile != "") {
            Logger.Info("Startup", "检测到上一会话异常退出，提示用户开启调试模式并导出诊断包")
            MessageBox.Info("检测到上次运行崩溃。`n建议在设置中开启「调试模式」记录日志，并用「生成日志压缩包」导出诊断包反馈给开发者。", "AFA")
        }

        ; ---- 原 include 时执行的初始化（按原 include 顺序） ----
        Config.InitPath()
        HotkeyActionsStart()
        LevelDetector.Init()
        KeyBinder.Start()
        HotkeyService.Init()
        TimingService.Init()
        SettingsService.Init()
        VersionChecker.Init()
        Updater.Init()
        ChangelogChecker.Init()
        ChangelogUI.Init()
        GameLauncher.Init()

        ; ---- 加载设置 ----
        SettingsService.Initialize()
        Logger.RegisterSecret(Config.GetImportant("GitHubToken"))
        Logger.RegisterSecret(Config.GetImportant("GamePath"))
        Logger.RegisterSecret(A_ScriptFullPath)
        Logger.Info("Startup", "配置加载完成，版本=" Version.Get())

        ; 写入启动来源状态，并校准随游戏自动启动的 Windows 审核和计划任务
        AppContext.SetStartedByGameAutoStart(startedByGameAutoStart)
        autoStartResult := GameAutoStartManager.Reconcile()
        if (!autoStartResult.success) {
            autoStartResult.degraded := true
            Logger.Error("GameAutoStart", "启动时校准失败：" autoStartResult.message)
            if (!AppContext.GetStartedByGameAutoStart() && Config.GetImportant("AutoStartWithGame") = "1")
                pendingAutoStartWarning := autoStartResult.message
        }

        ; 关闭功能后若有遗留事件触发，只清理任务，不启动小助手主体
        if (autoStartResult.HasProp("shouldExit") && autoStartResult.shouldExit)
            ExitApp

        ; 确保嵌入文件已提取到 AppData
        FileExtractor.EnsureExtracted()

        ; 初始化游戏按键识别（必须在 HotkeyOn 之前）
        GameKeys.Init()

        HotkeyService.HotkeyOn()

        ; 检查并显示更新公告（事件驱动）
        EventBus.Publish("ChangelogShowRequested")

        ; 初始化 GUI（含 Alt+F4 退出热键注册）
        GuiManager.Start()

        ; 初始化更新 UI（原 updater_ui.ahk 在 GUI 之后 include）
        UpdateUI.Init()

        ; 启动校准失败只在 GUI 就绪后用托盘提示一次，不阻塞主流程，也不改变已保存配置。
        if (IsSet(pendingAutoStartWarning))
            ShowTrayTip(pendingAutoStartWarning, "随游戏自动启动校准失败", 2)

        tokenStorageWarning := Config.GetTokenStorageWarning()
        if (tokenStorageWarning != "")
            MessageBox.Warning(tokenStorageWarning, "GitHub Token 存储提示")

        ; 触发应用启动事件（触发自动更新检查和游戏自动启动）
        EventBus.Publish("AppStartCompleted")

        ; 启动游戏监控定时器
        GameMonitor.Start()

        ; 初始化按键
        EventBus.Publish("SetSwitchKey")

        ; 刷新 GUI 以正确应用文本
        EventBus.Publish("GuiUpdateHotkeyControls")
        EventBus.Publish("GuiUpdateImportantControls")
        EventBus.Publish("GuiUpdateCustomControls")
    }
}

; 启动
App.Bootstrap()
