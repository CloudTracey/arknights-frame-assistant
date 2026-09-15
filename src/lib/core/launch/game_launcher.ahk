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
    ; 识别前先清掉无效的路径记录（文件不存在、或不是明日方舟可执行文件）——区服键在 GUI 中
    ; 只有只读总览、没有编辑入口，用户删掉游戏或填错路径后无法自行清除，会一直卡在保存校验上。
    static CheckGamePath() {
        ; 必须先于 Refresh/FindInstalledPaths：两者都会读到配置里的旧路径
        ; （GameClientRegistry 用配置区分 CN/BILI，ServerProfile._FindServerPath 优先保留已配置路径），
        ; 清理晚于它们会拿到脏数据，且删除过的游戏目录会被“已配置路径”重新写回。
        cleanedPaths := this._CleanUpGamePaths()

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
        if (detected) {
            EventBus.Publish("GamePathDetected", {path: firstPath, clients: clients, installed: installed})
            return
        }
        ; 未识别到任何路径时，把本次清理结果写进提示，避免用户误以为区服记录“凭空消失”
        message := I18n.T("未检测到游戏进程，且未在常见目录找到游戏路径。`n请先启动游戏，或手动填写游戏路径。")
        if (cleanedPaths.Length > 0) {
            Logger.Info("GameLauncher", "识别失败，但已清理 " cleanedPaths.Length " 条无效路径记录")
            message .= "`n`n" I18n.T("未检测到有效游戏路径，已清除下列无效路径记录：`n{2}", cleanedPaths.Length, this._JoinPaths(cleanedPaths))
        }
        MessageBox.Warning(message, I18n.T("识别失败"))
    }

    ; 路径数组拼成多行文本（Format 不接受数组参数，必须传字符串）
    static _JoinPaths(paths) {
        text := ""
        for path in paths
            text .= (text = "" ? "" : "`n") path
        return text
    }

    ; 清除“文件已不存在”或“不是明日方舟可执行文件（推断不出区服）”的游戏路径配置
    ; （旧 GamePath + 各区服 GamePath<Id>），返回被清除的路径数组。
    ; 判定必须与保存校验（SettingsService._ValidateAndPersist）同源，否则会出现
    ; “能挡住保存、却清不掉”的路径：文件不存在走 FileExist，推不出区服走 FromExePath。
    ; 用同一个 FromExePath（而不是单纯比较文件名）：重命名过但仍能经 app.info/注册表
    ; 识别的安装目录属合法自定义位置，不能误清。
    static _CleanUpGamePaths() {
        cleaned := []
        for entry in ServerProfile.AllGamePathEntries() {
            path := Config.GetImportant(entry.key)
            if (path = "")
                continue
            reason := ""
            if !FileExist(path)
                reason := I18n.T("路径不存在")
            else if InStr(FileExist(path), "D")
                reason := I18n.T("路径不正确")   ; 目录不是可执行文件
            else {
                info := ServerProfile.FromExePath(path)
                if (info.serverId = "" || info.serverId = "Unknown")
                    reason := I18n.T("路径不正确")
            }
            if (reason = "")
                continue
            label := entry.name != "" ? entry.name " " : ""
            ; 原子落盘（与识别即写入 GamePath<Id> 的既有行为一致）；失败只记日志，不阻断识别
            result := SettingsService.UpdatePersistedValue(entry.key, "")
            if (!result.success) {
                Logger.Warn("GameLauncher", "清除无效游戏路径失败（" entry.key "）：" result.message)
                continue
            }
            cleaned.Push("[" reason "] " label path)
            Logger.Info("GameLauncher", "已清除无效游戏路径记录（" entry.key "，" reason "）：" path)
        }
        return cleaned
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
