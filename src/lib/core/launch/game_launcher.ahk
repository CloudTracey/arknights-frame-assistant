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

    ; 获取游戏路径：优先识别正在运行的实例；没有进程时按已知目录特征扫描常见安装位置
    static CheckGamePath() {
        GameClientRegistry.Refresh()
        clients := GameClientRegistry.GetClients()
        if (clients.Length > 0) {
            firstPath := ""
            defaultGamePath := Config.GetImportant("GamePath")
            for client in clients {
                if (client.exePath = "")
                    continue
                if (firstPath = "" && defaultGamePath = "")
                    firstPath := client.exePath
                if (client.serverId != "" && client.serverId != "Unknown") {
                    key := "GamePath" client.serverId
                    SettingsService.UpdatePersistedValue(key, client.exePath)
                    Logger.Info("GameLauncher", "识别到 " client.serverId " 游戏路径：" client.exePath)
                } else if (defaultGamePath = "") {
                    SettingsService.UpdatePersistedValue("GamePath", client.exePath)
                    Logger.Info("GameLauncher", "识别到未知区服游戏路径：" client.exePath)
                }
            }
            if (firstPath != "")
                EventBus.Publish("GamePathDetected", {path: firstPath, clients: clients})
            return
        }

        ; 没有运行中的客户端时，尝试按固定目录特征直接扫描
        installed := ServerProfile.FindInstalledPaths()
        if (installed.Count > 0) {
            firstPath := ""
            defaultGamePath := Config.GetImportant("GamePath")
            for serverId, path in installed {
                if (firstPath = "" && defaultGamePath = "")
                    firstPath := path
                key := "GamePath" serverId
                SettingsService.UpdatePersistedValue(key, path)
                Logger.Info("GameLauncher", "扫描识别到 " serverId " 游戏路径：" path)
            }
            if (firstPath != "")
                EventBus.Publish("GamePathDetected", {path: firstPath, installed: installed})
            return
        }

        MessageBox.Warning("未检测到游戏进程，且未在常见目录找到游戏路径。`n请先启动游戏，或手动填写游戏路径。", "识别失败")
    }

    ; 启动游戏
    static Launch() {
        gamePath := Config.GetImportant("GamePath")

        ; 检查是否已运行（任意区服客户端都算已运行）
        if GameClientRegistry.HasClients() || GameTarget.ProcessExists() {
            Logger.Info("GameLauncher", "游戏已在运行，跳过启动")
            return { success: true, message: "游戏已在运行" }
        }

        ; 检查游戏路径配置
        if (gamePath = "" || gamePath = "游戏路径") {
            Logger.Warn("GameLauncher", "游戏路径未配置")
            return { success: false, message: "游戏路径未配置，请在设置中指定" }
        }

        ; 检查游戏文件是否存在
        if !FileExist(gamePath) {
            Logger.Warn("GameLauncher", "游戏文件不存在：" gamePath)
            return { success: false, message: "游戏文件不存在，请检查路径配置" }
        }

        ; 启动游戏
        try {
            Run(gamePath)
            Logger.Info("GameLauncher", "游戏已启动：" gamePath)
            return { success: true, message: "游戏启动成功" }
        } catch Error as e {
            Logger.Error("GameLauncher", "启动失败：" e.Message)
            return { success: false, message: "启动失败：" e.Message }
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

