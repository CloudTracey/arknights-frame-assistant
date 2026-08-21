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
        Config.MigrateGamePaths()
        I18n.Init(Config.ReadImportantFromIni("Language"))
        this._RefreshRuntime()
    }

    ; 内部：启动/保存/应用/重置后刷新与配置相关的运行时缓存
    static _RefreshRuntime() {
        debugOn := Config.ReadImportantFromIni("DebugEnabled") == "1"
        Logger.SetDebugEnabled(debugOn)
        Logger.SetConsoleEnabled(debugOn)
        TimingService.Refresh()
        HotkeyService.SetHoverOperate(Config.ReadCustomFromIni("HoverOperate") == "1")
        lang := Config.ReadImportantFromIni("Language")
        if (lang = "auto")
            lang := I18n.DetectAutoLocale()
        I18n.SetLocale(lang)
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
            ShowTrayTip(I18n.T("tray.autoBeginPauseOn"), "AFA", "Mute")
            SetTimer HideTrayTip, -3000
        } else {
            HideTrayTip()
            SetTimer HideTrayTip, 0
            ShowTrayTip(I18n.T("tray.autoBeginPauseOff"), "AFA", "Mute")
            SetTimer HideTrayTip, -3000
        }
    }

    ; 处理更新公告忽略请求（经统一配置写口）
    static _HandleChangelogDismissRequested(data) {
        result := this.UpdatePersistedValue("DismissedChangelogVersion", data.version)
        if (!result.success) {
            Logger.Warn("Changelog", "忽略版本保存失败：" result.message)
            MessageBox.Warning(I18n.T("msg.changelogDismissFailed"), I18n.T("msg.configNotSavedTitle"))
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
        result := MessageBox.Confirm(I18n.T("msg.resetKeysConfirm"), I18n.T("msg.resetKeysTitle"))
        if (result != "Yes")
            return
        EventBus.Publish("HotkeyOff")        ; Legacy
        EventBus.Publish("UnsetSwitchKey")   ; Legacy
        EventBus.Publish("SettingsSaveStarting")
        Config.ResetHotkeyToDefaults()
        saveResult := Config.SaveHotkeysToIni()
        if (!saveResult.success) {
            Logger.Warn("Settings", "重置按键并保存中止：" saveResult.message)
            MessageBox.Error(saveResult.message, I18n.T("msg.saveFailedTitle"))
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
            MessageBox.Info(I18n.T("msg.settingsApplied"), I18n.T("msg.settingsAppliedTitle"))
        } else {
            EventBus.Publish("SettingsSaved")
            Logger.Info("Settings", "设置已保存并关闭")
            MessageBox.Info(I18n.T("msg.settingsSaved"), I18n.T("msg.settingsSavedTitle"))
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
                result := MessageBox.Confirm(I18n.T("msg.tokenValidateFailed", tokenResult.message), I18n.T("msg.tokenValidateFailedTitle"))
                if (result = "No")
                    return false
            } else {
                GitHubTokenService.TokenValidated := true
                Logger.Info("Settings", "GitHub Token 验证成功")
                MessageBox.Info(I18n.T("msg.tokenValidateSuccess", tokenResult.username, tokenResult.rateLimit), I18n.T("msg.tokenValidateSuccessTitle"))
            }
        }

        ; 在应用其他外部设置前，预检 GitHub Token 的 DPAPI 加密。
        tokenStorage := Config.PrepareGitHubTokenForStorage(currentToken)
        if (!tokenStorage.success) {
            Logger.Warn("Settings", "保存中止：GitHub Token 无法安全保存（" tokenStorage.message "）")
            MessageBox.Error(I18n.T("msg.tokenStorageFailed", tokenStorage.message), I18n.T("msg.tokenStorageFailedTitle"))
            return false
        }

        ; 验证游戏路径（旧 GamePath + 按区服路径）
        pathsToValidate := [Config.GetImportant("GamePath")]
        for serverId in ["CN", "JP", "KR", "EN"] {
            key := "GamePath" serverId
            value := Config.GetImportant(key)
            if (value != "")
                pathsToValidate.Push(value)
        }
        for gamePath in pathsToValidate {
            if (gamePath = "")
                continue
            if !FileExist(gamePath) {
                result := MessageBox.Confirm(I18n.T("msg.gamePathMissingConfirm", gamePath), I18n.T("msg.gamePathMissingTitle"))
                if (result = "No") {
                    Logger.Warn("Settings", "保存中止：游戏路径不存在")
                    return false
                }
                continue
            }
            info := ServerProfile.FromExePath(gamePath)
            if (info.serverId = "") {
                result := MessageBox.Confirm(I18n.T("msg.gamePathInvalidConfirm", gamePath), I18n.T("msg.gamePathInvalidTitle"))
                if (result = "No") {
                    Logger.Warn("Settings", "保存中止：无法从路径推断区服")
                    return false
                }
            } else {
                Logger.Info("Settings", "游戏路径区服识别：" info.serverId " - " gamePath)
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
            MessageBox.Error(saveResult.message, I18n.T("msg.saveFailedTitle"))
            return false
        }
        return true
    }

    ; 应用随游戏自动启动配置。外部任务成功后才保存配置开关。
    static _ApplyGameAutoStart() {
        if !Config.AllImportant.Has("AutoStartWithGame")
            return true

        enabled := (Config.GetImportant("AutoStartWithGame") = 1 || Config.GetImportant("AutoStartWithGame") = "1")
        appliedGamePaths := []
        if (enabled) {
            gamePaths := GameAutoStartManager.GetConfiguredGamePaths()
            if (gamePaths.Length = 0)
                gamePaths := [Config.GetImportant("GamePath")]
            defaultGamePath := Config.GetImportant("GamePath")
            for gamePath in gamePaths {
                if (gamePath = "")
                    continue
                validation := GameAutoStartManager.ValidateGamePath(gamePath)
                if (!validation.success) {
                    MessageBox.Error(validation.message, I18n.T("msg.autoStartTitle"))
                    return false
                }
                ; 只有当前路径就是用户指定的默认启动路径时，才更新 GamePath；
                ; 其余区服路径只参与自启任务，不能覆盖默认启动路径。
                if (gamePath = defaultGamePath) {
                    Config.SetImportant("GamePath", validation.path)
                    EventBus.Publish("GamePathNormalized", {path: validation.path})
                }
                appliedGamePaths.Push(validation.path)
            }
            if (appliedGamePaths.Length = 0) {
                MessageBox.Error(I18n.T("msg.autoStartNoPath"), I18n.T("msg.autoStartTitle"))
                return false
            }

            if (Config.GetImportant("AutoStartWithGame") != "1") {
                result := MessageBox.Confirm(I18n.T("msg.autoStartConfirmBody"), I18n.T("msg.autoStartConfirmTitle"))
                if (result = "No")
                    return false
            }
        }

        result := GameAutoStartManager.Apply(enabled, appliedGamePaths)
        if (!result.success) {
            MessageBox.Error(result.message, enabled ? I18n.T("msg.autoStartEnableFailedTitle") : I18n.T("msg.autoStartDisableFailedTitle"))
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
        MessageBox.Error(I18n.T("msg.keyConflict", conflictKey, prevName, currentName), I18n.T("msg.keyConflictTitle"))
    }

    ; 重置游戏状态
    static _ResetGameStateIfNeeded() {
        if (Config.GetImportant("AutoExit") == "1" && !GameTarget.Exists()) {
            GameMonitor.ResetRunRecord()
        }
    }
}
