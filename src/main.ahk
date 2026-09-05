#Requires AutoHotkey v2.0
#SingleInstance Off
#Warn All, Off
; 键盘钩子存活护栏（#340）：AFA 全部热键都注册在 HotIf 回调下，每次按键都要由主线程求值，
; 求值期间钩子回调一直阻塞。系统对低级钩子有独立超时（LowLevelHooksTimeout，未配置时默认 300ms），
; 累计超时 11 次就会静默摘除钩子——表现为"所有快捷键突然失效，必须重启或重新注册才恢复"。
; AHK 默认的 #HotIfTimeout 是 1000ms，比系统红线宽 3 倍多，等于放任每次主线程卡顿都记一次超时。
; 这里压到 100ms：拦截键有主热键与 Up 两个变体，文档说超时可能按变体分别计算，
; 2×100=200ms 仍安全在 300ms 以内（若取 150 则 2×150 正好顶到红线）。
; 代价：主线程卡顿期间该次按键判定为 false（这种时候热键本就无法正常工作），换取钩子永不被摘除。
#HotIfTimeout 100

; 所有模块只定义、零顶层副作用；启动由下方 App.Bootstrap() 显式执行。
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
#Include ./lib/base/file_extractor.ahk
#Include ./lib/base/timing.ahk
#Include ./lib/base/window.ahk
#Include ./lib/base/key_format.ahk
#Include ./lib/base/tray.ahk
#Include ./lib/base/version_utils.ahk
#Include ./lib/base/touch_injection.ahk
#Include ./lib/base/custom_hotkey_store.ahk
#Include ./lib/core/game/game_client_registry.ahk
#Include ./lib/core/diagnostics/log_exporter.ahk
#Include ./lib/core/diagnostics/hook_health.ahk
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
#Include ./lib/ui/updater_ui.ahk
#Include ./lib/core/launch/game_launcher.ahk
#Include ./lib/ui/changelog_ui.ahk
#Include ./lib/core/changelog/changelog_checker.ahk
#Include ./lib/ui/status_bar.ahk
#Include ./lib/ui/gui.ahk
#Include ./lib/ui/custom_key_editor.ahk
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

; 启动分步计时：在每段开始前标记下一段名称，段切换时输出上一段的耗时。
; 若某步骤卡住，日志中缺失对应的「启动步骤 xxx 完成」行即为卡住位置（排查启动缓慢/卡死）。
; name 为空字符串时仅输出上一段，不开启新段（用于收尾）。
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
        ; 保留按键历史。排查"所有热键突然失效"时，
        ; KeyHistory 窗口顶部直接给出 Keybd hook 是否仍安装、最近按键流是否停更——
        ; 这是区分"系统已摘除钩子"与"HotIf 判定返回 false"的直接证据。
        KeyHistory 200
        ProcessSetPriority "High"
        SendMode "Input"
        SetKeyDelay -1, -1
        ; #279：高分辨率/无级滚轮可超过 200 次/2000ms，AHK 会弹出警告并发出系统提示音。
        ; 决策：全局关闭洪峰警告（grilling 确认）。代价是失去“热键自触发循环”的告警兜底；
        ; 若未来出现按键自触发循环，需另行评估热键注册/InputLevel 加固，而不是恢复此提示。
        ; A_MaxHotkeysPerInterval := 200 保留用于记录洪峰阈值，但 A_HotkeyInterval := 0 时该警告已被全局关闭
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

        ; ---- 单例识别（命名互斥体）----
        if (!SingleInstance.Acquire()) {
            ; 随游戏自动启动触发（--game-autostart）：旧实例正在运行并已接管游戏监控，本次静默退出。
            ; （与旧版 #SingleInstance Ignore 行为一致：任务触发的新实例不打扰已运行实例）
            if (HasLaunchArgument("--game-autostart")) {
                OutputDebug("[AFA] 单例冲突：--game-autostart 触发时已有实例在运行，静默退出")
                ExitApp
            }
            ; 手动重复启动：提示弹窗后退出。
            ; 弹窗早于 SettingsService.Initialize()（用户配置尚未加载），先按用户配置语言初始化 i18n。
            I18n.Init(Config.ReadImportantFromIni("Language"))
            MessageBox.Info(I18n.T("已有一个AFA实例正在运行，请关闭旧实例再尝试启动新实例"), I18n.T("AFA已在运行"))
            ExitApp
        }

        ; ---- 提权 ----
        if not A_IsAdmin {
            try
            {
                ; 让位互斥体：提权重启的新进程会重新 Acquire()，避免其启动时被误判为重复实例
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

        ; 上一会话异常退出（Logger.PreviousAbnormalFile 在 Logger.Init 已识别）时提示用户。
        ; 放在 I18n.Init 之后，保证提示使用用户选择的界面语言。
        if (Logger.PreviousAbnormalFile != "") {
            Logger.Info("Startup", "检测到上一会话异常退出，提示用户导出诊断包")
            MessageBox.Info(I18n.T("检测到上次异常退出（可能被任务管理器强杀或系统直接关机），如非手动强杀则可能是意外崩溃。`n日志已自动完整记录，请用「生成日志压缩包」导出诊断包反馈给开发者。"), "AFA")
        }

        ; 写入启动来源状态，并校准随游戏自动启动的 Windows 审核和计划任务
        StartupMark("随游戏自动启动校准")
        AppContext.SetStartedByGameAutoStart(startedByGameAutoStart)
        autoStartResult := GameAutoStartManager.Reconcile()
        if (!autoStartResult.success) {
            autoStartResult.degraded := true
            Logger.Error("GameAutoStart", "启动时校准失败：" autoStartResult.message)
            if (!AppContext.GetStartedByGameAutoStart() && Config.GetImportant("AutoStartWithGame") = "1")
                pendingAutoStartWarning := autoStartResult.message
        }

        ; 关闭功能后若有遗留事件触发，只清理任务，不启动AFA主体
        if (autoStartResult.HasProp("shouldExit") && autoStartResult.shouldExit)
            ExitApp

        ; 确保嵌入文件已提取到 AppData
        StartupMark("资源提取")
        FileExtractor.EnsureExtracted()

        ; 初始化游戏按键识别（必须在 HotkeyOn 之前）
        StartupMark("游戏按键识别")
        GameKeys.Init()

        StartupMark("热键注册")
        HotkeyService.HotkeyOn()

        ; 启动键盘钩子健康探针（须在 HotkeyOn 之后，监视键位表来自已注册热键）
        HookHealth.Start()

        ; 检查并显示更新公告（事件驱动）
        StartupMark("GUI 初始化")
        EventBus.Publish("ChangelogShowRequested")

        ; 初始化 GUI（含 Alt+F4 退出热键注册）
        GuiManager.Start()

        ; 初始化更新 UI（在 GUI 之后）
        UpdateUI.Init()

        ; 启动校准失败只在 GUI 就绪后用托盘提示一次，不阻塞主流程，也不改变已保存配置。
        if (IsSet(pendingAutoStartWarning))
            ShowTrayTip(pendingAutoStartWarning, I18n.T("随游戏自动启动校准失败"), 2)

        tokenStorageWarning := Config.GetTokenStorageWarning()
        if (tokenStorageWarning != "")
            MessageBox.Warning(tokenStorageWarning, I18n.T("GitHub Token 存储提示"))

        ; 触发应用启动事件（触发自动更新检查和游戏自动启动）
        StartupMark("启动收尾")
        EventBus.Publish("AppStartCompleted")

        ; 启动游戏监控定时器
        GameMonitor.Start()

        ; 初始化按键
        EventBus.Publish("SetSwitchKey") ; Legacy

        ; 刷新 GUI 以正确应用文本（Legacy 启动刷新；内部标签切换由 GuiManager 直接调用自身方法）
        EventBus.Publish("GuiUpdateHotkeyControls")    ; Legacy
        EventBus.Publish("GuiUpdateImportantControls") ; Legacy
        EventBus.Publish("GuiUpdateCustomControls")    ; Legacy

        ; 收尾：输出最后一段耗时（name 为空）
        StartupMark("")
        Logger.Info("Startup", "启动流程完成")
    }
}

; 启动
App.Bootstrap()
