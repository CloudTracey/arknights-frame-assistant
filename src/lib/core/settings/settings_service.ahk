; == 设置服务 ==
; 设置服务：唯一允许提交配置变更的模块，
; 负责配置加载/保存/应用/重置的编排（SettingsService.UpdatePersistedValue 是单键写口）。

class SettingsService {
    ; 初始化：订阅设置相关事件（由 bootstrap 调用，避免顶层副作用）
    static Init() {
        EventBus.Subscribe("SettingsSaveRequested", (*) => this.Save())
        EventBus.Subscribe("SettingsApplyRequested", (*) => this.Apply())
        EventBus.Subscribe("SettingsCancelRequested", (*) => this.Cancel())
        EventBus.Subscribe("SettingsResetRequested", (*) => this.Reset())
        EventBus.Subscribe("SettingsValueChangeRequested", (data) => this._HandleSettingsValueChangeRequested(data))
        EventBus.Subscribe("ChangelogDismissRequested", (data) => this._HandleChangelogDismissRequested(data))
    }

    ; 启动时加载设置
    static Initialize() {
        Config.MigrateFrameRate()
        Config.MigrateGitHubToken()
        Config.LoadFromIni()
        this._RefreshRuntime()
    }

    ; 内部：启动/保存/应用/重置后刷新与配置相关的运行时缓存
    static _RefreshRuntime() {
        debugOn := Config.ReadImportantFromIni("DebugEnabled") == "1"
        Logger.SetDebugEnabled(debugOn)
        Logger.SetConsoleEnabled(debugOn)
        TimingService.Refresh()
        HotkeyService.SetHoverOperate(Config.ReadCustomFromIni("HoverOperate") == "1")
        if IsSet(LevelDetector)
            LevelDetector.SyncGuardSetting()
    }

    ; 单键配置变更唯一入口：原子写入 INI → 更新 Config 工作副本 → 发布 SettingsChanged
    static UpdatePersistedValue(key, value) {
        if (key != "Frame"
            && !Config.AllHotkeys.Has(key)
            && !Config.AllCustom.Has(key)
            && !Config.AllImportant.Has(key)) {
            return {success: false, message: "未知配置键：" key}
        }

        result := Config._PersistSingleValue(key, value)
        if !result.success
            return result

        if (key = "Frame") {
            Config.SetImportant("Frame", value)
        } else if (Config.AllHotkeys.Has(key)) {
            Config.SetHotkey(key, value)
        } else if (Config.AllCustom.Has(key)) {
            Config.SetCustom(key, value)
        } else if (Config.AllImportant.Has(key)) {
            Config.SetImportant(key, value)
        }

        EventBus.Publish("SettingsChanged", {key: key, value: value})
        return result
    }

    ; 处理热键动作发布的单键设置变更请求
    static _HandleSettingsValueChangeRequested(data) {
        if (data.key != "AutoBeginPause")
            return
        result := this.UpdatePersistedValue(data.key, data.value)
        if (!result.success) {
            Logger.Warn("Settings", "单键设置写入失败：" result.message)
            return
        }
        Logger.Info("Settings", "切换开局自动暂停 → " (data.value = "1" ? "开" : "关"))
        if (data.value = "1") {
            HideTrayTip()
            SetTimer HideTrayTip, 0
            ShowTrayTip("已开启开局自动暂停", "AFA", "Mute")
            SetTimer HideTrayTip, -3000
        } else {
            HideTrayTip()
            SetTimer HideTrayTip, 0
            ShowTrayTip("已关闭开局自动暂停", "AFA", "Mute")
            SetTimer HideTrayTip, -3000
        }
    }

    ; 处理更新公告忽略请求（经统一配置写口）
    static _HandleChangelogDismissRequested(data) {
        result := this.UpdatePersistedValue("DismissedChangelogVersion", data.version)
        if (!result.success) {
            Logger.Warn("Changelog", "忽略版本保存失败：" result.message)
            MessageBox.Warning("更新公告已关闭，但忽略状态未能保存。下次启动可能会再次显示，请检查 Settings.ini 的写入权限。", "配置未保存")
        }
    }

    ; 保存并关闭
    static Save() {
        this._SaveOrApply(false)
    }

    ; 应用设置
    static Apply() {
        this._SaveOrApply(true)
    }

    ; 取消设置修改
    static Cancel() {
        Config.LoadFromIni()
        this._RefreshRuntime()
        Logger.Info("Settings", "取消设置修改并恢复配置")
        EventBus.Publish("SettingsViewRefreshRequested")
        EventBus.Publish("SettingsCancelled")
    }

    ; 重置按键为默认值
    static Reset() {
        result := MessageBox.Confirm("  确定重置*所有*按键为默认设置吗 ？", "重置按键设置")
        if (result != "Yes")
            return
        EventBus.Publish("HotkeyOff")        ; Legacy
        EventBus.Publish("UnsetSwitchKey")   ; Legacy
        EventBus.Publish("SettingsSaveStarting")
        Config.ResetHotkeyToDefaults()
        saveResult := Config.SaveHotkeysToIni()
        if (!saveResult.success) {
            Logger.Warn("Settings", "重置按键并保存中止：" saveResult.message)
            MessageBox.Error(saveResult.message, "设置保存失败")
            return
        }
        this._RefreshRuntime()
        EventBus.Publish("SettingsViewRefreshRequested")
        EventBus.Publish("SettingsReset")
        Logger.Info("Settings", "已重置按键并保存默认设置")
    }

    ; 内部：保存/应用共用流程
    static _SaveOrApply(isApply) {
        if (!this._ValidateAndPersist()) {
            Logger.Warn("Settings", isApply ? "设置应用中止" : "设置保存中止")
            return
        }
        this._RefreshRuntime()
        this._ResetGameStateIfNeeded()
        if (isApply) {
            EventBus.Publish("SettingsApplied")
            Logger.Info("Settings", "设置已应用")
            MessageBox.Info("设置已应用！", "应用成功")
        } else {
            EventBus.Publish("SettingsSaved")
            Logger.Info("Settings", "设置已保存并关闭")
            MessageBox.Info("设置已保存！后续可双击右下角托盘区图标或通过右键菜单打开设置", "保存成功")
        }
    }

    ; 内部：验证并持久化当前 Config 工作副本
    static _ValidateAndPersist() {
        ; 保存/应用/重置期间暂停热键与切换键，完成后由 SettingsSaved/Applied/Reset 驱动恢复
        EventBus.Publish("HotkeyOff")        ; Legacy
        EventBus.Publish("UnsetSwitchKey")   ; Legacy
        EventBus.Publish("SettingsSaveStarting")

        ; 登记本次会话中的敏感值，覆盖后续验证、外部设置和保存流程的日志。
        Logger.RegisterSecret(Config.GetImportant("GitHubToken"))
        Logger.RegisterSecret(Config.GetImportant("GamePath"))

        ; 检查按键冲突
        if (!this._CheckKeyConflicts()) {
            Logger.Warn("Settings", "保存中止：检测到按键冲突")
            return false
        }

        ; 验证 GitHub Token（如果输入了的话，且相对已持久化值有变化）
        currentToken := Config.GetImportant("GitHubToken")
        persistedToken := Config.ReadImportantFromIni("GitHubToken")
        if (currentToken != "" && currentToken != persistedToken) {
            tokenResult := GitHubTokenService.Validate(currentToken)
            if (!tokenResult.valid) {
                Logger.Warn("Settings", "GitHub Token 验证失败：" tokenResult.message)
                result := MessageBox.Confirm("GitHub Token验证失败：" tokenResult.message "`n`n是否仍要保存此Token？", "Token验证失败")
                if (result = "No")
                    return false
            } else {
                GitHubTokenService.TokenValidated := true
                Logger.Info("Settings", "GitHub Token 验证成功")
                MessageBox.Info("GitHub Token验证成功！`n用户: " tokenResult.username "`nAPI配额: " tokenResult.rateLimit, "Token有效")
            }
        }

        ; 在应用其他外部设置前，预检 GitHub Token 的 DPAPI 加密。
        tokenStorage := Config.PrepareGitHubTokenForStorage(currentToken)
        if (!tokenStorage.success) {
            Logger.Warn("Settings", "保存中止：GitHub Token 无法安全保存（" tokenStorage.message "）")
            MessageBox.Error("GitHub Token 无法安全保存：`n" tokenStorage.message, "设置保存失败")
            return false
        }

        ; 验证游戏路径
        gamePath := Config.GetImportant("GamePath")
        if (gamePath != "") {
            if !FileExist(gamePath) {
                result := MessageBox.Confirm("游戏路径不存在：`n" gamePath "`n`n是否仍要保存？", "路径不存在")
                if (result = "No") {
                    Logger.Warn("Settings", "保存中止：游戏路径不存在")
                    return false
                }
            } else {
                SplitPath(gamePath, &fileName)
                if (fileName != "Arknights.exe") {
                    result := MessageBox.Confirm("游戏路径不正确：`n" gamePath "`n`n目标文件不是 Arknights.exe，请确保选择正确的游戏可执行文件。`n`n是否仍要保存？", "路径不正确")
                    if (result = "No") {
                        Logger.Warn("Settings", "保存中止：游戏路径不是 Arknights.exe")
                        return false
                    }
                }
            }
        }

        ; 应用“启动游戏时自动启动小助手”设置
        if (!this._ApplyGameAutoStart()) {
            Logger.Warn("Settings", "保存中止：随游戏自动启动设置应用失败")
            return false
        }

        ; 保存到 INI（全量保存 Config 工作副本；单键场景请走 UpdatePersistedValue）
        saveResult := Config.SaveAllToIni()
        if (!saveResult.success) {
            MessageBox.Error(saveResult.message, "设置保存失败")
            return false
        }
        return true
    }

    ; 应用随游戏自动启动配置。外部任务成功后才保存配置开关。
    static _ApplyGameAutoStart() {
        if !Config.AllImportant.Has("AutoStartWithGame")
            return true

        enabled := (Config.GetImportant("AutoStartWithGame") = 1 || Config.GetImportant("AutoStartWithGame") = "1")
        appliedGamePath := ""
        if (enabled) {
            gamePath := Config.GetImportant("GamePath")
            validation := GameAutoStartManager.ValidateGamePath(gamePath)
            if (!validation.success) {
                MessageBox.Error(validation.message, "无法启用随游戏自动启动")
                return false
            }
            ; 保存规范化后的绝对路径，确保后续启动校准使用同一事件过滤条件。
            Config.SetImportant("GamePath", validation.path)
            Logger.RegisterSecret(validation.path)
            EventBus.Publish("GamePathNormalized", {path: validation.path})
            appliedGamePath := validation.path

            if (Config.GetImportant("AutoStartWithGame") != "1") {
                confirmationMessage := "启用此功能需要开启 Windows 的“进程创建成功审核”。`n"
                confirmationMessage .= "Windows 将为进程启动记录安全日志；关闭此功能后，审核设置仍会保留。`n`n"
                confirmationMessage .= "是否继续？"
                result := MessageBox.Confirm(confirmationMessage, "启用随游戏自动启动")
                if (result = "No")
                    return false
            }
        }

        result := GameAutoStartManager.Apply(enabled, appliedGamePath)
        if (!result.success) {
            MessageBox.Error(result.message, enabled ? "启用随游戏自动启动失败" : "关闭随游戏自动启动失败")
            return false
        }
        return true
    }

    ; 内部：检查按键冲突
    ; 检测规则：
    ; 1. 常规作战 + 快捷操作 + SwitchHotkey 互相检测
    ; 2. 卫戍协议按键 + SwitchHotkey 互相检测
    ; 3. 卫戍协议按键不与作战/快捷操作检测冲突
    static _CheckKeyConflicts() {
        result := HotkeyConflictValidator.FindAll(
            Config.AllHotkeys,
            Config.AllCustom
        )

        if !result.HasConflicts
            return true

        conflict := result.Items[1]
        this._ShowConflictError(
            conflict.Key,
            HotkeyConflictValidator.GetDisplayName(conflict.FirstControl),
            HotkeyConflictValidator.GetDisplayName(conflict.SecondControl)
        )
        return false
    }

    ; 内部：显示冲突错误
    static _ShowConflictError(conflictKey, prevName, currentName) {
        MessageBox.Error("按键冲突！`n【" conflictKey "】`n已被【" prevName "】使用，与【" currentName "】冲突`n`n请先修改重复的按键。", "保存失败")
    }

    ; 重置游戏状态
    static _ResetGameStateIfNeeded() {
        if (Config.GetImportant("AutoExit") == "1" && !WinExist("ahk_exe Arknights.exe")) {
            GameMonitor.ResetRunRecord()
        }
    }
}
