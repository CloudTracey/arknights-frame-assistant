; == 游戏启动器 ==

class GameLauncher {
    ; 初始化启动器
    static Init() {
        EventBus.Subscribe("AppStarted", (*) => this.OnAppStarted())
        EventBus.Subscribe("CheckGamePathClick", (*) => this.CheckGamePath())
    }

    ; 确认是否自动启动
    static OnAppStarted() {
        if (Config.GetImportant("AutoRunGame") == "1") {
            this.Launch()
        }
    }

    ; 获取游戏路径（ProcessGetPath 失败时降级到 WMI 查询）
    static CheckGamePath() {
        if(ProcessExist("Arknights.exe")) {
            pid := ProcessExist("Arknights.exe")
            path := ""
            try {
                path := ProcessGetPath(pid)
            } catch Error as e {
                Logger.Warn("GameLauncher", "ProcessGetPath 异常 (pid=" pid "): " e.Message)
            }
            if (path != "") {
                GuiManager.SetControlValue("GamePath", path)
                GuiManager.TrackChange("GamePath")
                return
            }
            ; 主路径失败，降级到 WMI 查询
            Logger.Warn("GameLauncher", "ProcessGetPath 失败，降级到 WMI 查询 (pid=" pid ")")
            path := GameLauncher._GetProcessPathByWmi(pid)
            if (path != "") {
                GuiManager.SetControlValue("GamePath", path)
                GuiManager.TrackChange("GamePath")
                Logger.Info("GameLauncher", "WMI 降级查询成功: " path)
                return
            }
            Logger.Error("GameLauncher", "WMI 降级查询也失败 (pid=" pid ")")
            MessageBox.Warning("未检测到游戏进程，请先启动游戏再进行识别", "识别失败")
        } else {
            MessageBox.Warning("未检测到游戏进程，请先启动游戏再进行识别", "识别失败")
        }
    }
    
    ; 启动游戏
    static Launch() {
        gamePath := Config.GetImportant("GamePath")
        
        ; 检查是否已运行
        if ProcessExist("Arknights.exe") {
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
            if ProcessExist("Arknights.exe") {
                Logger.Info("GameLauncher", "检测到游戏进程已启动")
                return true
            }
            Sleep(1000)
        }
        Logger.Warn("GameLauncher", "等待游戏启动超时")
        return false
    }
}

GameLauncher.Init()
