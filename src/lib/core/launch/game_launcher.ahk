; == 游戏启动器 ==

class GameLauncher {
    ; 初始化启动器
    static Init() {
        EventBus.Subscribe("AppStartCompleted", (*) => this.OnAppStarted())
        EventBus.Subscribe("CheckGamePathClick", (*) => this.CheckGamePath())
    }

    ; 确认是否自动启动
    static OnAppStarted() {
        if (Config.GetImportant("AutoRunGame") == "1") {
            this.Launch()
        }
    }

    ; 获取游戏路径：识别正在运行的实例（权威），并合并按目录特征扫描到的已安装区服路径。
    static CheckGamePath() {
        GameClientRegistry.Refresh()
        clients := GameClientRegistry.GetClients()
        firstPath := ""
        detected := false
        defaultGamePath := Config.GetImportant("GamePath")
        identified := Map()  ; 已由运行中客户端识别的区服，扫描不再重复写入/记录

        ; 1. 识别正在运行的客户端实例
        for client in clients {
            if (client.exePath = "")
                continue
            detected := true
            if (firstPath = "" && defaultGamePath = "")
                firstPath := client.exePath
            if (client.serverId != "" && client.serverId != "Unknown") {
                identified[client.serverId] := true
                key := "GamePath" client.serverId
                SettingsService.UpdatePersistedValue(key, client.exePath)
                Logger.Info("GameLauncher", "识别到 " client.serverId " 游戏路径：" client.exePath)
            } else if (defaultGamePath = "") {
                SettingsService.UpdatePersistedValue("GamePath", client.exePath)
                Logger.Info("GameLauncher", "识别到未知区服游戏路径：" client.exePath)
            }
        }

        ; 2. 未运行区服按已知目录特征扫描（FindInstalledPaths 内部优先保留已配置且存在的路径，
        ;    与运行中客户端一致；已识别区服跳过，避免覆盖运行实例路径与重复日志）
        installed := ServerProfile.FindInstalledPaths()
        for serverId, path in installed {
            detected := true
            if (firstPath = "" && defaultGamePath = "")
                firstPath := path
            if (identified.Has(serverId))
                continue
            key := "GamePath" serverId
            SettingsService.UpdatePersistedValue(key, path)
            Logger.Info("GameLauncher", "扫描识别到 " serverId " 游戏路径：" path)
        }

        ; 识别到任意有效路径即发布事件刷新 GUI（firstPath 为空仅表示不填充默认 GamePath，不代表识别失败）
        if (detected)
            EventBus.Publish("GamePathDetected", {path: firstPath, clients: clients, installed: installed})
        else
            MessageBox.Warning(I18n.T("未检测到游戏进程，且未在常见目录找到游戏路径。`n请先启动游戏，或手动填写游戏路径。"), I18n.T("识别失败"))
    }

    ; 启动游戏
    static Launch() {
        gamePath := Config.GetImportant("GamePath")

        ; 检查是否已运行（任意区服客户端都算已运行）
        if GameClientRegistry.HasClients() || GameTarget.ProcessExists() {
            Logger.Info("GameLauncher", "游戏已在运行，跳过启动")
            return { success: true, message: I18n.T("游戏已在运行") }
        }

        ; 检查游戏路径配置
        if (gamePath = "" || gamePath = "游戏路径") {
            Logger.Warn("GameLauncher", "游戏路径未配置")
            return { success: false, message: I18n.T("游戏路径未配置，请在设置中指定") }
        }

        ; 检查游戏文件是否存在
        if !FileExist(gamePath) {
            Logger.Warn("GameLauncher", "游戏文件不存在：" gamePath)
            return { success: false, message: I18n.T("游戏文件不存在，请检查路径配置") }
        }

        ; 启动游戏
        try {
            Run(gamePath)
            Logger.Info("GameLauncher", "游戏已启动：" gamePath)
            return { success: true, message: I18n.T("游戏启动成功") }
        } catch Error as e {
            Logger.Error("GameLauncher", "启动失败：" e.Message)
            return { success: false, message: I18n.T("启动失败：{1}", e.Message) }
        }
    }

    ; 通过 WMI 查询进程路径，用作 ProcessGetPath 失败时的降级方案
    static _GetProcessPathByWmi(pid) {
        try {
            wmi := ComObject("winmgmts:{impersonationLevel=impersonate}!\\.\root\cimv2")
            query := "SELECT ExecutablePath FROM Win32_Process WHERE ProcessId = " pid
            for process in wmi.ExecQuery(query) {
                path := Trim(process.ExecutablePath)
                if (path != "")
                    return path
            }
            return ""
        } catch Error as e {
            Logger.Error("GameLauncher", "WMI 查询失败: " e.Message)
            return ""
        }
    }

    ; 等待游戏启动完成（可选）
    static WaitForGame(timeout := 60000) {
        startTime := A_TickCount
        while (A_TickCount - startTime < timeout) {
            if GameClientRegistry.HasClients() || GameTarget.ProcessExists() {
                Logger.Info("GameLauncher", "检测到游戏进程已启动")
                return true
            }
            Sleep(1000)
        }
        Logger.Warn("GameLauncher", "等待游戏启动超时")
        return false
    }
}
