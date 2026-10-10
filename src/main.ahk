#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn All, Off
; 键盘钩子超时护栏
#HotIfTimeout 100

#Include ./lib/base/logger.ahk
#Include ./lib/base/version.ahk
#Include ./lib/base/message_box.ahk
#Include ./lib/base/single_instance.ahk
#Include ./lib/base/token_protector.ahk
#Include ./lib/base/hotkey_schema.ahk
#Include ./lib/base/constants.ahk
#Include ./lib/base/config.ahk
#Include ./lib/base/theme.ahk
#Include ./lib/base/eventbus.ahk
#Include ./lib/base/i18n.ahk
#Include ./lib/base/changelog_format.ahk
#Include ./lib/base/metrics.ahk
#Include ./lib/base/locales/zh_hans.ahk
#Include ./lib/base/locales/ja_jp.ahk
#Include ./lib/base/locales/ko_kr.ahk
#Include ./lib/base/locales/en_us.ahk
#Include ./lib/base/locales/zh_hant.ahk
#Include ./lib/base/server_profile.ahk
#Include ./lib/base/game_target.ahk
#Include ./lib/base/file_integrity.ahk
#Include ./lib/base/file_extractor.ahk
#Include ./lib/base/timing.ahk
#Include ./lib/base/window.ahk
#Include ./lib/base/key_format.ahk
#Include ./lib/base/tray.ahk
#Include ./lib/base/version_utils.ahk
#Include ./lib/base/touch_injection.ahk
#Include ./lib/base/custom_hotkey_store.ahk
#Include ./lib/base/webview_runtime.ahk
#Include ./lib/core/game/game_client_registry.ahk
#Include ./lib/core/diagnostics/log_exporter.ahk
#Include ./lib/core/launch/app_context.ahk
#Include ./lib/core/launch/game_auto_start.ahk
#Include ./lib/core/hotkey/timing_service.ahk
#Include ./lib/core/hotkey/game_keys.ahk
#Include ./lib/core/hotkey/hotkey_actions.ahk
#Include ./lib/core/hotkey/custom_script.ahk
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
#Include ./lib/core/updater/changelog_checker.ahk
#Include ./lib/ui/updater_ui.ahk
#Include ./lib/core/launch/game_launcher.ahk
#Include ./lib/ui/changelog_ui.ahk
#Include ./lib/ui/status_bar.ahk
#Include ./lib/ui/gui.ahk
#Include ./lib/ui/ui_shell.ahk
#Include ./lib/ui/tray_controller.ahk
#Include ./lib/ui/web/web_engine.ahk
#Include ./lib/ui/custom_key_editor.ahk
#Include ./lib/core/monitor/game_monitor.ahk
#Include ./lib/core/monitor/hook_monitor.ahk

HandleAfaExit(exitReason, exitCode) {
    Logger.HandleExit(exitReason, exitCode)
    Logger.CloseConsole()
    SingleInstance.Release()
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

; 启动分步计时（name 为空时只输出上一段）
StartupMark(name) {
    static lastStep := ""
    static lastTick := 0
    if (lastStep != "") {
        Logger.Info("Startup", "启动步骤 " lastStep " 完成，耗时 " (A_TickCount - lastTick) "ms")
        if (name = "")
            return
    }
    lastStep := name
    lastTick := A_TickCount
}

class App {
    static Bootstrap() {
        ; ---- 环境初始化 ----
        ListLines False
        KeyHistory 200
        ProcessSetPriority "High"
        SendMode "Input"
        SetKeyDelay -1, -1
        A_MaxHotkeysPerInterval := 200
        A_HotkeyInterval := 0
        SetMouseDelay -1
        SetWinDelay -1
        SetDefaultMouseSpeed 0
        SetTitleMatchMode 3
        CoordMode "Mouse", "Client"
        DllCall("winmm\timeBeginPeriod", "UInt", 1)

        OnExit HandleAfaExit

        startedByGameAutoStart := HasLaunchArgument("--game-autostart")

        ; ---- 单例识别 ----
        if (!SingleInstance.Acquire()) {
            if (HasLaunchArgument("--game-autostart")) {
                OutputDebug("[AFA] 单例冲突：--game-autostart 触发时已有实例在运行，静默退出")
                ExitApp
            }
            I18n.Init(Config.ReadImportantFromIni("Language"))
            MessageBox.Info(I18n.T("已有一个AFA实例正在运行，请关闭旧实例再尝试启动新实例"), I18n.T("AFA已在运行"))
            ExitApp
        }

        ; ---- 提权 ----
        if not A_IsAdmin {
            try
            {
                SingleInstance.Release()
                launchContextArgs := startedByGameAutoStart ? " --game-autostart" : ""
                if A_IsCompiled
                    Run '*RunAs "' A_ScriptFullPath '" /restart' launchContextArgs
                else
                    Run '*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"' launchContextArgs
            }
            ExitApp
        }

        ; ---- 管理员进程日志 ----
        StartupMark("日志初始化")
        Logger.Init()
        Logger.Info("Startup", "管理员进程启动，脚本=" A_ScriptName)
        Logger.Info("Startup", "单例互斥体已获取，句柄=" SingleInstance.Handle)

        ; ---- 初始化各模块 ----
        StartupMark("模块初始化")
        Config.InitPath()
        GameClientRegistry.Init()
        LogExporter.Init()
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
        StartupMark("设置加载")
        SettingsService.Initialize()
        Logger.RegisterSecret(Config.GetImportant("GitHubToken"))
        Logger.RegisterSecret(A_ScriptFullPath)
        Logger.Info("Startup", "配置加载完成，版本=" Version.Get())

        if (Logger.PreviousAbnormalFile != "") {
            Logger.Info("Startup", "检测到上一会话异常退出，提示用户导出诊断包")
            MessageBox.Info(I18n.T("检测到上次异常退出（可能被任务管理器强杀或系统直接关机），如非手动强杀则可能是意外崩溃。`n日志已自动完整记录，请用「生成日志压缩包」导出诊断包反馈给开发者。"), "AFA")
        }

        StartupMark("随游戏自动启动校准")
        AppContext.SetStartedByGameAutoStart(startedByGameAutoStart)
        autoStartResult := GameAutoStartManager.Reconcile()
        if (!autoStartResult.success) {
            autoStartResult.degraded := true
            Logger.Error("GameAutoStart", "启动时校准失败：" autoStartResult.message)
            if (!AppContext.GetStartedByGameAutoStart() && Config.GetImportant("AutoStartWithGame") = "1")
                pendingAutoStartWarning := autoStartResult.message
        }

        if (autoStartResult.HasProp("shouldExit") && autoStartResult.shouldExit)
            ExitApp

        StartupMark("资源提取")
        FileExtractor.EnsureExtracted()

        StartupMark("游戏按键识别")
        GameKeys.Init()

        StartupMark("热键注册")
        HotkeyService.HotkeyOn()

        StartupMark("GUI 初始化")
        EventBus.Publish("ChangelogShowRequested")

        UiShell.Start()

        UpdateUI.Init()

        if (IsSet(pendingAutoStartWarning))
            ShowTrayTip(pendingAutoStartWarning, I18n.T("随游戏自动启动校准失败"), 2)

        tokenStorageWarning := Config.GetTokenStorageWarning()
        if (tokenStorageWarning != "")
            MessageBox.Warning(tokenStorageWarning, I18n.T("GitHub Token 存储提示"))

        StartupMark("启动收尾")
        EventBus.Publish("AppStartCompleted")

        GameMonitor.Start()
        HookMonitor.Init()

        EventBus.Publish("SetSwitchKey") ; Legacy

        EventBus.Publish("GuiUpdateHotkeyControls")
        EventBus.Publish("GuiUpdateImportantControls")
        EventBus.Publish("GuiUpdateCustomControls")

        StartupMark("")
        Logger.Info("Startup", "启动流程完成")
    }
}

App.Bootstrap()
