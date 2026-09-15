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
        Config.MigrateHotkeyCase()
        Config.LoadFromIni()
        ; 缺键时默认读取不会落盘；启动时仅补回主题键，不保存其他工作副本。
        if (IniRead(Config.IniFile, "Main", "ThemeMode", "__AFA_MISSING_KEY__") = "__AFA_MISSING_KEY__") {
            themeBackfill := Config._PersistSingleValue("ThemeMode", "auto")
            if !themeBackfill.success
                Logger.Warn("Settings", "回填主题设置失败：" themeBackfill.message)
        }
        Config.MigrateGamePaths()
        I18n.Init(Config.ReadImportantFromIni("Language"))
        Theme.Confirm(Config.ReadImportantFromIni("ThemeMode"))
        this._RefreshRuntime()
    }

    ; 内部：启动/保存/应用/重置后刷新与配置相关的运行时缓存
    static _RefreshRuntime() {
        ; DebugEnabled 现仅控制实时调试控制台（日志全级别恒持久化，不再依赖该开关）
        Logger.SetConsoleEnabled(Config.ReadImportantFromIni("DebugEnabled") == "1")
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
    ; ThemeMode 的规范化由 Config._PersistSingleValue 与 Config.SetImportant 各自保证，此处不重复。
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

        if (key = "ThemeMode")
            Theme.Confirm(value)
        EventBus.Publish("SettingsChanged", {key: key, value: value})
        return result
    }

    ; 处理热键动作发布的单键设置变更请求
    static _HandleSettingsValueChangeRequested(data) {
        if (data.key != "AutoBeginPause" && data.key != "AutoBeginSpeed")
            return
        isSpeed := (data.key = "AutoBeginSpeed")
        result := this.UpdatePersistedValue(data.key, data.value)
        if (!result.success) {
            Logger.Warn("Settings", "单键设置写入失败：" result.message)
            return
        }
        Logger.Info("Settings", (isSpeed ? "切换开局自动二倍速 → " : "切换开局自动暂停 → ") (data.value = "1" ? "开" : "关"))
        if (data.value = "1") {
            HideTrayTip()
            SetTimer HideTrayTip, 0
            ShowTrayTip(I18n.T(isSpeed ? "已开启开局自动二倍速" : "已开启开局自动暂停"), "AFA", "Mute")
            SetTimer HideTrayTip, -3000
        } else {
            HideTrayTip()
            SetTimer HideTrayTip, 0
            ShowTrayTip(I18n.T(isSpeed ? "已关闭开局自动二倍速" : "已关闭开局自动暂停"), "AFA", "Mute")
            SetTimer HideTrayTip, -3000
        }
    }

    ; 处理更新公告忽略请求（经统一配置写口）
    static _HandleChangelogDismissRequested(data) {
        result := this.UpdatePersistedValue("DismissedChangelogVersion", data.version)
        if (!result.success) {
            Logger.Warn("Changelog", "忽略版本保存失败：" result.message)
            MessageBox.Warning(I18n.T("更新公告已关闭，但忽略状态未能保存。下次启动可能会再次显示，请检查 Settings.ini 的写入权限。"), I18n.T("配置未保存"))
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
        Theme.Confirm(Config.ReadImportantFromIni("ThemeMode"))
        this._RefreshRuntime()
        Logger.Info("Settings", "取消设置修改并恢复配置")
        EventBus.Publish("SettingsViewRefreshRequested")
        EventBus.Publish("SettingsCancelled")
    }

    ; 重置按键为默认值
    static Reset() {
        result := MessageBox.Confirm(I18n.T("  确定重置*所有*非自定义按键为默认设置吗 ？"), I18n.T("重置按键设置"))
        if (result != "Yes")
            return
        EventBus.Publish("HotkeyOff")        ; Legacy
        EventBus.Publish("UnsetSwitchKey")   ; Legacy
        EventBus.Publish("SettingsSaveStarting")
        Config.ResetHotkeyToDefaults()
        saveResult := Config.SaveHotkeysToIni()
        if (!saveResult.success) {
            Logger.Warn("Settings", "重置按键并保存中止：" saveResult.message)
            MessageBox.Error(saveResult.message, I18n.T("设置保存失败"))
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
        Theme.Confirm(Config.ReadImportantFromIni("ThemeMode"))
        this._RefreshRuntime()
        this._ResetGameStateIfNeeded()
        if (isApply) {
            EventBus.Publish("SettingsApplied")
            Logger.Info("Settings", "设置已应用")
            MessageBox.Info(I18n.T("设置已应用！"), I18n.T("应用成功"))
        } else {
            EventBus.Publish("SettingsSaved")
            Logger.Info("Settings", "设置已保存并关闭")
            MessageBox.Info(I18n.T("设置已保存！后续可双击右下角托盘区图标或通过右键菜单打开设置"), I18n.T("保存成功"))
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

        ; 验证 GitHub Token（如果输入了的话，且相对已持久化值有变化）
        currentToken := Config.GetImportant("GitHubToken")
        persistedToken := Config.ReadImportantFromIni("GitHubToken")
        if (currentToken != "" && currentToken != persistedToken) {
            tokenResult := GitHubTokenService.Validate(currentToken)
            if (!tokenResult.valid) {
                Logger.Warn("Settings", "GitHub Token 验证失败：" tokenResult.message)
                result := MessageBox.Confirm(I18n.T("GitHub Token验证失败：{1}`n`n是否仍要保存此Token？", tokenResult.message), I18n.T("Token验证失败"))
                if (result = "No")
                    return false
            } else {
                GitHubTokenService.TokenValidated := true
                Logger.Info("Settings", "GitHub Token 验证成功")
                MessageBox.Info(I18n.T("GitHub Token验证成功！`n用户: {1}`nAPI配额: {2}", tokenResult.username, tokenResult.rateLimit), I18n.T("Token有效"))
            }
        }

        ; 在应用其他外部设置前，预检 GitHub Token 的 DPAPI 加密。
        tokenStorage := Config.PrepareGitHubTokenForStorage(currentToken)
        if (!tokenStorage.success) {
            Logger.Warn("Settings", "保存中止：GitHub Token 无法安全保存（" tokenStorage.message "）")
            MessageBox.Error(I18n.T("GitHub Token 无法安全保存：`n{1}", tokenStorage.message), I18n.T("设置保存失败"))
            return false
        }

        ; 验证游戏路径（旧 GamePath + 按区服路径）
        ; 区服键在 GUI 中只有只读总览、没有编辑入口，文件被删后用户无从清除，
        ; 故此处对“文件不存在”只询问、不硬拒：确认后清掉记录继续保存，否则中止。
        ; 目录不算“文件不存在”（路径本身还在），仍走下方“路径不正确”硬拒——
        ; 与 GameAutoStartManager.ValidateGamePath 的要求一致：配置项必须是 Arknights.exe 文件。
        missingEntries := []
        missingPaths := []
        pathEntries := []   ; {key, path, serverId}，只保留非空配置项供后续区服校验
        for entry in ServerProfile.AllGamePathEntries() {
            value := Config.GetImportant(entry.key)
            if (value = "")
                continue
            attrs := FileExist(value)
            if (attrs = "") {
                missingEntries.Push(entry)
                missingPaths.Push(value)
                continue
            }
            ; 非空且存在的配置项（含目录）：后面统一用 FromExePath 判是否为 Arknights.exe
            pathEntries.Push({key: entry.key, path: value, serverId: entry.serverId})
        }
        if (missingEntries.Length > 0) {
            if (MessageBox.Confirm(this._BuildMissingPathsPrompt(missingEntries, missingPaths), I18n.T("路径不存在")) != "Yes") {
                Logger.Warn("Settings", "保存中止：用户选择自行修正无效路径，共 " missingEntries.Length " 条")
                return false
            }
            ; 这里只记录用户已确认的清理意图，真正改内存工作副本推迟到落盘前（见下方 _ClearConfirmedPaths）：
            ; 若后续校验/外部设置/落盘失败而保存中止，内存仍与磁盘一致，不会出现
            ; “没保存却先把记录清了”，也不会让用户取消时反而把已删记录恢复回来。
        }
        for item in pathEntries {
            info := ServerProfile.FromExePath(item.path)
            if (info.serverId = "" || info.serverId = "Unknown") {
                ; 严格拒绝：无法确认是明日方舟可执行文件时不落盘
                MessageBox.Error(I18n.T("游戏路径不正确：`n{1}`n`n目标文件不是明日方舟可执行文件（Arknights.exe），请修正后再保存。", item.path), I18n.T("路径不正确"))
                Logger.Warn("Settings", "保存中止：无法从路径推断区服：" item.path)
                return false
            }
            Logger.Info("Settings", "游戏路径区服识别：" info.serverId " - " item.path)
        }

        ; 应用“启动游戏时自动启动AFA”设置。
        ; 自启校验必须看到“已确认清理后”的路径视图：否则用户刚确认删除的失效路径
        ; 会被自启校验重新报成「游戏路径不存在或不是文件」，保存再次被挡住、点不动。
        ; 这里临时清空内存取值（事务上仍保持“保存失败即还原”，见下）。
        autoStartSnapshot := this._SnapshotPaths(missingEntries)
        this._ClearConfirmedPaths(missingEntries)
        autoStartOk := this._ApplyGameAutoStart()
        this._RestorePaths(autoStartSnapshot)
        if (!autoStartOk) {
            Logger.Warn("Settings", "保存中止：随游戏自动启动设置应用失败")
            return false
        }

        ; 校验自定义按键功能与参数（编辑窗口保存时已校验过，此处为防线兜底）
        for i, entry in Config.AllCustomHotkeys {
            result := CustomScriptEngine.Validate(entry.Func, entry.Arg)
            if (!result.success) {
                name := entry.Name != "" ? entry.Name : I18n.T("自定义按键 {1}", i)
                Logger.Warn("Settings", "保存中止：自定义按键「" name "」功能参数非法：" result.message)
                MessageBox.Error(I18n.T("自定义按键「{1}」：`n{2}", name, result.message), I18n.T("自定义按键参数错误"))
                return false
            }
        }

        ; 保存到 INI（全量保存 Config 工作副本；单键场景请走 UpdatePersistedValue）
        ; 用户已确认的失效路径清理在此提交：此前任何一步失败都已在上面还原，内存与磁盘保持一致。
        this._ClearConfirmedPaths(missingEntries)

        ; 主题最后提交：自定义按键文件失败时，不把仍处于预览的主题提前落盘。
        themeMode := Config.GetImportant("ThemeMode")
        savedThemeMode := Config.ReadImportantFromIni("ThemeMode")
        Config.SetImportant("ThemeMode", savedThemeMode)
        try saveResult := Config.SaveAllToIni()
        finally Config.SetImportant("ThemeMode", themeMode)
        if (!saveResult.success) {
            MessageBox.Error(saveResult.message, I18n.T("设置保存失败"))
            return false
        }
        ; 落盘成功后才记清理日志：避免“日志说已清除、实际写入失败”的误导
        this._LogConfirmedPathsCleared(missingEntries, missingPaths)

        ; 落盘自定义按键（独立文件；Settings.ini 成功后才写入，任一步失败都中止保存）
        customSaveResult := CustomHotkeyStore.Save(Config.AllCustomHotkeys)
        if (!customSaveResult.success) {
            Logger.Warn("Settings", "保存中止：自定义按键文件写入失败：" customSaveResult.message)
            MessageBox.Error(I18n.T("配置文件写入失败：{1}", customSaveResult.message), I18n.T("设置保存失败"))
            return false
        }
        if (themeMode != savedThemeMode) {
            themeSaveResult := Config._PersistSingleValue("ThemeMode", themeMode)
            if (!themeSaveResult.success) {
                MessageBox.Error(themeSaveResult.message, I18n.T("设置保存失败"))
                return false
            }
        }
        return true
    }

    ; 应用随游戏自动启动配置。外部任务成功后才保存配置开关。
    static _ApplyGameAutoStart() {
        if !Config.AllImportant.Has("AutoStartWithGame")
            return true

        enabled := (Config.GetImportant("AutoStartWithGame") = 1 || Config.GetImportant("AutoStartWithGame") = "1")
        collect := this._CollectAutoStartPaths(enabled)
        if (collect.invalidMessage != "") {
            ; 某条路径校验失败：保持既有行为——中止保存并提示具体原因
            MessageBox.Error(collect.invalidMessage, I18n.T("无法启用随游戏自动启动"))
            return false
        }
        appliedGamePaths := collect.paths
        if (enabled && appliedGamePaths.Length = 0) {
            ; 一条有效路径都没有（例如用户刚确认清掉最后一条失效路径）：只记录日志、跳过计划任务
            ; 的创建/删除，且**不改动开关**——保留「随游戏自动启动AFA」的勾选状态，
            ; 用户后续识别或填入游戏路径后无需重新开启（任务由下次启动的 Reconcile 按新路径重建）。
            Logger.Info("Settings", "无有效路径：跳过随游戏自动启动的计划任务创建")
            return true
        }

        if (enabled && Config.GetImportant("AutoStartWithGame") != "1") {
            result := MessageBox.Confirm(I18n.T("启用此功能需要开启 Windows 的“进程创建成功审核”。`nWindows 将为进程启动记录安全日志；关闭此功能后，审核设置仍会保留。`n`n是否继续？"), I18n.T("启用随游戏自动启动"))
            if (result = "No")
                return false
        }

        result := GameAutoStartManager.Apply(enabled, appliedGamePaths)
        if (!result.success) {
            MessageBox.Error(result.message, enabled ? I18n.T("启用随游戏自动启动失败") : I18n.T("关闭随游戏自动启动失败"))
            return false
        }
        return true
    }

    ; 收集本次要写入自启任务的路径（规范化后的完整路径），返回 {paths, invalidMessage}。
    ; 纯逻辑、不弹窗：便于抛给调用方决定提示文案，也便于脱离 GUI 验证。
    ; invalidMessage 非空表示某条路径校验失败（调用方应中止并提示）。
    static _CollectAutoStartPaths(enabled) {
        result := {paths: [], invalidMessage: ""}
        if (!enabled)
            return result

        gamePaths := GameAutoStartManager.GetConfiguredGamePaths()
        if (gamePaths.Length = 0)
            gamePaths := [Config.GetImportant("GamePath")]
        defaultGamePath := Config.GetImportant("GamePath")
        for gamePath in gamePaths {
            if (gamePath = "")
                continue
            validation := GameAutoStartManager.ValidateGamePath(gamePath)
            if (!validation.success) {
                result.invalidMessage := validation.message
                return result
            }
            ; 只有当前路径就是用户指定的默认启动路径时，才更新 GamePath；
            ; 其余区服路径只参与自启任务，不能覆盖默认启动路径。
            if (gamePath = defaultGamePath) {
                Config.SetImportant("GamePath", validation.path)
                EventBus.Publish("GamePathNormalized", {path: validation.path})
            }
            result.paths.Push(validation.path)
        }
        return result
    }

    ; 暂存若干配置项当前值，供“临时改内存后还原”使用（返回 Map(key → value)）
    static _SnapshotPaths(entries) {
        snapshot := Map()
        for entry in entries
            snapshot[entry.key] := Config.GetImportant(entry.key)
        return snapshot
    }

    ; 还原 _SnapshotPaths 暂存的值
    static _RestorePaths(snapshot) {
        for key, value in snapshot
            Config.SetImportant(key, value)
    }

    ; 清空用户已确认的失效路径（内存工作副本）。
    ; 只做清空、不记日志：本流程会调用两次（自启校验前临时清、落盘前提交），
    ; 日志由 _LogConfirmedPathsCleared 在提交后统一记一次，避免重复条目。
    static _ClearConfirmedPaths(missingEntries) {
        for entry in missingEntries
            Config.SetImportant(entry.key, "")
    }

    ; 记录已提交的失效路径清理（提交后调用一次）
    static _LogConfirmedPathsCleared(missingEntries, missingPaths) {
        if (missingEntries.Length = 0)
            return
        Logger.Info("Settings", "已清除 " missingEntries.Length " 条失效游戏路径记录：" this._BuildMissingPathsLines(missingEntries, missingPaths))
    }

    ; 无效路径多行文本（“区服名: 路径”，旧 GamePath 无区服名只列路径）。
    ; 必须拼成单个字符串再传：I18n.T → Format 不接受数组参数。
    static _BuildMissingPathsLines(missingEntries, missingPaths) {
        lines := ""
        for i, entry in missingEntries {
            label := entry.name != "" ? entry.name ": " : ""
            lines .= (lines = "" ? "" : "`n") label missingPaths[i]
        }
        return lines
    }

    ; 无效路径询问文案：保留路径换行安全前提（选“是”才会清除配置）
    static _BuildMissingPathsPrompt(missingEntries, missingPaths) {
        return I18n.T("以下游戏路径已不存在：`n{1}`n`n是否清除这些路径记录并继续保存？",
            this._BuildMissingPathsLines(missingEntries, missingPaths))
    }

    ; 重置游戏状态
    static _ResetGameStateIfNeeded() {
        if (Config.GetImportant("AutoExit") == "1" && !GameTarget.Exists()) {
            GameMonitor.ResetRunRecord()
        }
    }
}
