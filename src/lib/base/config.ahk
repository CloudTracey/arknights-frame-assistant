; -- 配置管理 --
class Config {
    ; 内部存储
    static _HotkeySettings := Map()
    static _ImportantSettings := Map()
    static _CustomSettings := Map()
    static _CustomHotkeySettings := []   ; Array<{Key, Name, Func, Arg, Type}>
    static _IsLoaded := false
    static GITHUB_TOKEN_PROTECTED_KEY := "GitHubTokenProtected"
    static TokenStorageStatus := "ok"

    ; 内部：默认按键设置（由 HotkeySchema 生成）
    static _DefaultHotkeys := HotkeySchema.GetDefaultHotkeys()

    ; 内部：默认重要设置
    static _DefaultImportant := Map(
        "AutoExit", "1",
        "AutoOpenSettings", "1",
        "ExitOnWindowClose", "0",
        "Frame", "90",
        "Frame155", "",
        "AutoUpdate", "1",
        "LastDismissedVersion", "",
        "UpdateChannel", "1",
        "UpdateSource", "1",
        "UseGitHubToken", "0",
        "GitHubToken", "",
        "GamePath", "",
        "GamePathCN", "",
        "GamePathBILI", "",
        "GamePathTC", "",
        "GamePathJP", "",
        "GamePathKR", "",
        "GamePathEN", "",
        "PreferredServer", "",
        "LastActiveServer", "",
        "AutoRunGame", "0",
        "AutoStartWithGame", "0",
        "LastLaunchedVersion", "",
        "DismissedChangelogVersion", "",
        "DefaultStrongHoldProtocol", "0",
        "TabOrder", Constants.DefaultTabOrder,
        "HiddenTabs", "",
        "AutoBeginPause", "0",
        "AutoBeginSpeed", "0",
        "BackCeaseOperations", "1",
        "InLevelGuard", "0",
        "DebugEnabled", "0",
        "Language", "auto",
        "ThemeMode", "auto"
    )

    ; 内部：默认自定义设置
    static _DefaultCustom := Map(
        "ClickDelay", "50",
        "SwitchHotkey", "",
        "FrameSkip16msDelay", "16",
        "FrameSkip33msDelay", "30",
        "FrameSkip166msDelay", "165",
        "HoverOperate", "0"
    )

    ; 配置文件路径
    static IniFile := ""

    ; 初始化配置文件路径
    static InitPath() {
        configDir := A_AppData "\ArknightsFrameAssistant\PC"
        if !DirExist(configDir)
            DirCreate(configDir)
        this.IniFile := configDir "\Settings.ini"
    }

    ; 清理上次异常退出遗留的 INI 临时/备份文件
    static CleanupStaleFiles() {
        if this.IniFile = ""
            this.InitPath()
        SplitPath(this.IniFile, , &configDir)
        removed := 0
        Loop Files, configDir "\Settings.ini.*-*", "F" {
            if !RegExMatch(A_LoopFileName, "^Settings\.ini\.(bak|tmp)-\d+-\d+$")
                continue
            try {
                FileSetAttrib("-R", A_LoopFileFullPath)
                FileDelete(A_LoopFileFullPath)
                removed++
            }
        }
        if (removed > 0)
            Logger.Info("Config", "已清理遗留配置临时/备份文件：" removed " 个")
    }

    ; 仅规范化单个 ASCII 大写字母主键（A -> a、<^A -> <^a）
    static _NormalizeHotkeyValue(value) {
        if RegExMatch(value, "^([~*$!^+#&<>()]*)([A-Z])$", &match)
            return match[1] StrLower(match[2])
        return value
    }

    static _IsHotkeyValuedKey(key) {
        return this._DefaultHotkeys.Has(key) || key = "SwitchHotkey"
    }

    ; 读取按键设置（内存工作副本）
    static GetHotkey(key) {
        if !this._IsLoaded
            this.LoadFromIni()
        return this._HotkeySettings.Has(key) ? this._HotkeySettings[key] : ""
    }

    ; 读取按键设置（直接读 INI）
    static ReadHotkeyFromIni(key) {
        if this.IniFile = ""
            this.InitPath()
        defaultVal := this._DefaultHotkeys.Has(key) ? this._DefaultHotkeys[key] : ""
        return this._NormalizeHotkeyValue(IniRead(this.IniFile, "Hotkeys", key, defaultVal))
    }

    ; 设置按键（仅写内存）
    static SetHotkey(key, value) {
        this._HotkeySettings[key] := this._NormalizeHotkeyValue(value)
    }

    ; 读取重要设置（内存工作副本）
    static GetImportant(key) {
        if !this._IsLoaded
            this.LoadFromIni()
        if (key = "Frame") {
            frame155 := this._ImportantSettings.Has("Frame155") && this._ImportantSettings["Frame155"] != ""
                ? this._ImportantSettings["Frame155"]
                : IniRead(this.IniFile, "Main", "Frame155", "")
            frameIndex := this._ImportantSettings.Has("Frame") ? this._ImportantSettings["Frame"] : ""
            return this._ResolveFrame(frame155, frameIndex)
        }
        return this._ImportantSettings.Has(key) ? this._ImportantSettings[key] : ""
    }

    ; 读取重要设置（直接读 INI）
    static ReadImportantFromIni(key) {
        if this.IniFile = ""
            this.InitPath()
        if (key = "ThemeMode")
            return Constants.NormalizeThemeMode(IniRead(this.IniFile, "Main", key, "auto"))
        if (key = "GitHubToken") {
            return this._ReadGitHubToken()
        }
        if (key = "Frame") {
            frame155 := IniRead(this.IniFile, "Main", "Frame155", "")
            frameIndex := IniRead(this.IniFile, "Main", "Frame", this._DefaultImportant["Frame"])
            return this._ResolveFrame(frame155, frameIndex)
        }
        defaultVal := this._DefaultImportant.Has(key) ? this._DefaultImportant[key] : ""
        return IniRead(this.IniFile, "Main", key, defaultVal)
    }

    ; 内部：解析 Frame 值
    static _ResolveFrame(frame155, frameIndex) {
        if (frame155 != "")
            return frame155
        if Constants.FrameOldIndexToText.Has(frameIndex)
            return Constants.FrameOldIndexToText[frameIndex]
        return this._DefaultImportant["Frame"]
    }

    ; 设置重要设置
    static SetImportant(key, value) {
        if (key = "ThemeMode")
            value := Constants.NormalizeThemeMode(value)
        this._ImportantSettings[key] := value
        if (key = "Frame")
            this._ImportantSettings["Frame155"] := value
    }

    ; 读取自定义设置（内存工作副本）
    static GetCustom(key) {
        if !this._IsLoaded
            this.LoadFromIni()
        return this._CustomSettings.Has(key) ? this._CustomSettings[key] : ""
    }

    ; 读取自定义设置（直接读 INI）
    static ReadCustomFromIni(key) {
        if this.IniFile = ""
            this.InitPath()
        defaultVal := this._DefaultCustom.Has(key) ? this._DefaultCustom[key] : ""
        value := IniRead(this.IniFile, "Custom", key, defaultVal)
        return this._IsHotkeyValuedKey(key) ? this._NormalizeHotkeyValue(value) : value
    }

    ; 设置自定义设置（仅写内存）
    static SetCustom(key, value) {
        this._CustomSettings[key] := this._IsHotkeyValuedKey(key) ? this._NormalizeHotkeyValue(value) : value
    }

    ; ── 自定义按键（CustomHotkeys.json） ──

    static AllCustomHotkeys => this._CustomHotkeySettings

    ; 读取自定义按键（直接读存储文件）
    ; 返回 Array<{Index, Key, Name, Func, Arg, Type}>
    static ReadCustomHotkeys() {
        entries := CustomHotkeyStore.Load()
        result := []
        for i, entry in entries {
            if !HotkeySchema.CustomTypeProfiles.Has(entry.Type) {
                Logger.Warn("Config", "自定义按键类型非法，回退 global：" entry.Type)
                entry.Type := "global"
            }
            if !this._IsValidFunc(entry.Func) {
                Logger.Warn("Config", "自定义按键功能非法，回退 click：" entry.Func)
                entry.Func := "click"
            }
            result.Push({Index: i, Key: entry.Key, Name: entry.Name, Func: entry.Func, Arg: entry.Arg, Type: entry.Type})
        }
        return result
    }

    ; 内部：功能码是否为已知功能
    static _IsValidFunc(func) {
        for opt in Constants.CustomHotkeyFuncOptions {
            if opt.code = func
                return true
        }
        return false
    }

    ; 追加空条目
    static AddCustomHotkey() {
        this._CustomHotkeySettings.Push({Key: "", Name: "", Func: "click", Arg: "", Type: "global"})
    }

    ; 删除指定行（1-based）
    static RemoveCustomHotkeyAt(index) {
        if index < 1 || index > this._CustomHotkeySettings.Length
            return
        this._CustomHotkeySettings.RemoveAt(index)
    }

    ; 更新单行字段（仅写内存）
    static SetCustomHotkeyField(index, field, value) {
        if index < 1 || index > this._CustomHotkeySettings.Length
            return
        entry := this._CustomHotkeySettings[index]
        switch field {
            case "Key", "Name", "Arg":
                entry.%field% := value
            case "Func":
                if this._IsValidFunc(value)
                    entry.Func := value
            case "Type":
                if HotkeySchema.CustomTypeProfiles.Has(value)
                    entry.Type := value
        }
    }

    ; 工作副本条目数
    static CustomHotkeyCount() {
        return this._CustomHotkeySettings.Length
    }

    ; 迁移：Frame 旧序号 → Frame155 文本值
    static MigrateFrameRate() {
        if this.IniFile = ""
            this.InitPath()
        if (!FileExist(this.IniFile))
            return

        frame155Value := IniRead(this.IniFile, "Main", "Frame155", "")
        if (frame155Value != "")
            return

        frameValue := IniRead(this.IniFile, "Main", "Frame", "")
        if (frameValue = "")
            return

        if Constants.FrameOldIndexToText.Has(frameValue) {
            try {
                IniWrite(Constants.FrameOldIndexToText[frameValue], this.IniFile, "Main", "Frame155")
            } catch Error as e {
                Logger.Warn("Config", "帧率迁移写入失败：" e.Message)
            }
        }
    }

    ; 迁移：明文 Token → DPAPI 加密键
    static MigrateGitHubToken() {
        if this.IniFile = ""
            this.InitPath()
        if !FileExist(this.IniFile)
            return true

        protectedValue := IniRead(this.IniFile, "Main", this.GITHUB_TOKEN_PROTECTED_KEY, "")
        legacyValue := IniRead(this.IniFile, "Main", "GitHubToken", "")

        if (protectedValue != "") {
            protectedResult := TokenProtector.Unprotect(protectedValue)
            if (protectedResult.success && protectedResult.format = "protected") {
                if (legacyValue != "") {
                    try IniDelete(this.IniFile, "Main", "GitHubToken")
                    catch Error as e {
                        this._SetTokenStorageStatus("cleanup_failed")
                        return false
                    }
                }
                this._SetTokenStorageStatus("ok")
                return true
            }

            ; 加密值损坏且仍有旧明文时，尝试恢复并重新迁移
            if (legacyValue = "") {
                this._SetTokenStorageStatus("decrypt_failed")
                return false
            }
        }

        if (legacyValue = "") {
            if (protectedValue = "")
                this._SetTokenStorageStatus("ok")
            return true
        }

        protectedResult := TokenProtector.Protect(legacyValue)
        if !protectedResult.success {
            this._SetTokenStorageStatus("migration_failed")
            return false
        }

        verification := TokenProtector.Unprotect(protectedResult.storedValue)
        if (!verification.success || verification.plainText != legacyValue) {
            this._SetTokenStorageStatus("migration_failed")
            return false
        }

        try {
            IniWrite(protectedResult.storedValue, this.IniFile, "Main", this.GITHUB_TOKEN_PROTECTED_KEY)
            if (IniRead(this.IniFile, "Main", this.GITHUB_TOKEN_PROTECTED_KEY, "") != protectedResult.storedValue)
                throw Error("加密 Token 写入校验失败。")
            IniDelete(this.IniFile, "Main", "GitHubToken")
            this._SetTokenStorageStatus("ok")
            return true
        } catch Error as e {
            this._SetTokenStorageStatus("migration_failed")
            return false
        }
    }

    ; 读取 Token（配置层之外只返回明文）
    static _ReadGitHubToken() {
        protectedValue := IniRead(this.IniFile, "Main", this.GITHUB_TOKEN_PROTECTED_KEY, "")
        if (protectedValue != "") {
            result := TokenProtector.Unprotect(protectedValue)
            if (result.success && result.format = "protected")
                return result.plainText

            if (IniRead(this.IniFile, "Main", "GitHubToken", "") = "") {
                this._SetTokenStorageStatus("decrypt_failed")
                return ""
            }
        }

        legacyValue := IniRead(this.IniFile, "Main", "GitHubToken", "")
        if (legacyValue != "")
            return legacyValue
        return ""
    }

    ; 保存前预生成密文
    static PrepareGitHubTokenForStorage(plainToken) {
        if (this.TokenStorageStatus = "decrypt_failed" && plainToken = "")
            return {success: false, message: I18n.T("GitHub Token 无法解密。为避免覆盖原加密配置，请重新输入 Token 后再保存。")}
        return TokenProtector.Protect(plainToken)
    }

    static _SetTokenStorageStatus(status) {
        this.TokenStorageStatus := status
        if (status = "ok")
            Logger.Info("Config", "GitHub Token 存储状态：" status)
        else
            Logger.Warn("Config", "GitHub Token 存储异常：" status)
    }

    ; Token 存储提示文案（不含敏感数据）
    static GetTokenStorageWarning() {
        switch this.TokenStorageStatus {
            case "migration_failed":
                return I18n.T("旧版 GitHub Token 未能完成加密迁移，原配置已保留。请恢复 Settings.ini 的写入权限后重启 AFA。")
            case "cleanup_failed":
                return I18n.T("GitHub Token 已完成加密，但旧明文未能删除。请恢复 Settings.ini 的写入权限后重新保存设置。")
            case "decrypt_failed":
                return I18n.T("GitHub Token 无法解密，可能来自其他 Windows 用户或电脑。请重新输入 Token 并保存。")
            default:
                return ""
        }
    }

    ; 迁移：Settings.ini 中的大写字母主键 → 小写
    static MigrateHotkeyCase() {
        if this.IniFile = ""
            this.InitPath()
        if !FileExist(this.IniFile)
            return true

        sentinel := "__AFA_MISSING_HOTKEY__"
        changes := []
        changedKeys := ""
        for keyVar, _ in this._DefaultHotkeys {
            value := IniRead(this.IniFile, "Hotkeys", keyVar, sentinel)
            normalized := this._NormalizeHotkeyValue(value)
            if (value != sentinel && !(value == normalized)) {
                changes.Push({Section: this._SectionForKey(keyVar), Key: keyVar, Value: normalized})
                changedKeys .= (changedKeys = "" ? "" : ", ") keyVar
            }
        }
        switchKey := "SwitchHotkey"
        switchSection := this._SectionForKey(switchKey)
        switchValue := IniRead(this.IniFile, switchSection, switchKey, sentinel)
        normalizedSwitch := this._NormalizeHotkeyValue(switchValue)
        if (switchValue != sentinel && !(switchValue == normalizedSwitch)) {
            changes.Push({Section: switchSection, Key: switchKey, Value: normalizedSwitch})
            changedKeys .= (changedKeys = "" ? "" : ", ") switchKey
        }

        if changes.Length = 0
            return true

        Critical "On"
        try {
            this._WriteIniEntriesAtomic(this.IniFile, changes)
            Logger.Info("Config", "热键大小写已规范化，数量=" changes.Length "，键：" changedKeys)
            return true
        } catch Error as e {
            Logger.Warn("Config", "热键大小写规范化写入失败，运行时仍使用小写值：" e.Message)
            return false
        } finally {
            Critical "Off"
        }
    }

    ; 从配置文件加载
    static LoadFromIni() {
        if this.IniFile = ""
            this.InitPath()

        ; 检查配置文件是否存在
        fileExists := FileExist(this.IniFile)

        ; 加载按键设置
        for keyVar, defaultVal in this._DefaultHotkeys {
            value := IniRead(this.IniFile, "Hotkeys", keyVar, defaultVal)
            this._HotkeySettings[keyVar] := this._NormalizeHotkeyValue(value)
        }

        ; 加载重要设置
        for keyVar, defaultVal in this._DefaultImportant {
            if (keyVar = "GitHubToken") {
                tokenValue := this._ReadGitHubToken()
                this._ImportantSettings[keyVar] := tokenValue
            } else {
                this._ImportantSettings[keyVar] := IniRead(this.IniFile, "Main", keyVar, defaultVal)
            }
        }

        this._ImportantSettings["ThemeMode"] := Constants.NormalizeThemeMode(this._ImportantSettings["ThemeMode"])

        ; 加载自定义设置
        for keyVar, defaultVal in this._DefaultCustom {
            value := IniRead(this.IniFile, "Custom", keyVar, defaultVal)
            this._CustomSettings[keyVar] := this._IsHotkeyValuedKey(keyVar) ? this._NormalizeHotkeyValue(value) : value
        }

        if (!fileExists) {
            this._EnsureConfigFileExists()
        } else {
            this._BackfillMissingCustomDefaults()
        }

        this._CustomHotkeySettings := CustomHotkeyStore.Load()

        this._IsLoaded := true
    }

    ; 回填已存在配置文件中缺失的自定义设置默认键
    static _BackfillMissingCustomDefaults() {
        if this.IniFile = ""
            this.InitPath()
        if !FileExist(this.IniFile)
            return
        ; 哨兵值用于区分"键不存在"与"键存在但值为空"
        sentinel := "__AFA_MISSING_KEY__"
        for keyVar, defaultVal in this._DefaultCustom {
            if IniRead(this.IniFile, "Custom", keyVar, sentinel) = sentinel {
                try IniWrite(defaultVal, this.IniFile, "Custom", keyVar)
                catch Error as e
                    Logger.Warn("Config", "回填自定义设置失败：" keyVar " - " e.Message)
            }
        }
    }

    ; 确保配置文件存在并包含所有配置项
    static _EnsureConfigFileExists() {
        if FileExist(this.IniFile)
            return
        Logger.Info("Config", "配置文件不存在，创建默认配置")
        ; 确保目录存在
        configDir := A_AppData "\ArknightsFrameAssistant\PC"
        if !DirExist(configDir)
            DirCreate(configDir)

        ; 写入所有默认重要设置
        for keyVar, defaultVal in this._DefaultImportant {
            if (keyVar = "GitHubToken")
                continue
            IniWrite(defaultVal, this.IniFile, "Main", keyVar)
        }

        ; 写入所有默认按键设置
        for keyVar, defaultVal in this._DefaultHotkeys {
            IniWrite(defaultVal, this.IniFile, "Hotkeys", keyVar)
        }

        ; 写入所有默认自定义设置
        for keyVar, defaultVal in this._DefaultCustom {
            IniWrite(defaultVal, this.IniFile, "Custom", keyVar)
        }
    }

    ; 迁移：单一 GamePath → 按区服 GamePath<Id>（GamePath 保留为默认启动路径）
    static MigrateGamePaths() {
        if this.IniFile = ""
            this.InitPath()
        if !FileExist(this.IniFile)
            return

        for serverId in ServerProfile.Ids() {
            this._ReconcileMisidentifiedPath(serverId)
        }

        legacy := IniRead(this.IniFile, "Main", "GamePath", "")
        if (legacy = "")
            return
        if !FileExist(legacy)
            return

        info := ServerProfile.FromExePath(legacy)
        if (info.serverId = "" || info.serverId = "Unknown")
            return

        key := "GamePath" info.serverId
        if (IniRead(this.IniFile, "Main", key, "") = "") {
            try {
                IniWrite(legacy, this.IniFile, "Main", key)
                if (this._ImportantSettings.Has(key))
                    this._ImportantSettings[key] := legacy
                Logger.Info("Config", "旧 GamePath 已迁移到 " key)
            } catch Error as e {
                Logger.Warn("Config", "迁移 GamePath 失败：" e.Message)
            }
        }

        if (IniRead(this.IniFile, "Main", "PreferredServer", "") = "") {
            try {
                IniWrite(info.serverId, this.IniFile, "Main", "PreferredServer")
                if (this._ImportantSettings.Has("PreferredServer"))
                    this._ImportantSettings["PreferredServer"] := info.serverId
            } catch Error as e {
                Logger.Warn("Config", "写入 PreferredServer 失败：" e.Message)
            }
        }
    }

    ; 校验区服键路径与识别结果是否一致，不一致时迁移到正确键
    static _ReconcileMisidentifiedPath(serverId) {
        key := "GamePath" serverId
        path := IniRead(this.IniFile, "Main", key, "")
        if (path = "" || !FileExist(path))
            return
        info := ServerProfile.FromExePath(path)
        if (info.serverId = "" || info.serverId = "Unknown" || info.serverId = serverId)
            return

        correctKey := "GamePath" info.serverId
        try {
            if (IniRead(this.IniFile, "Main", correctKey, "") = "") {
                IniWrite(path, this.IniFile, "Main", correctKey)
                if (this._ImportantSettings.Has(correctKey))
                    this._ImportantSettings[correctKey] := path
            }
            IniDelete(this.IniFile, "Main", key)
            if (this._ImportantSettings.Has(key))
                this._ImportantSettings[key] := ""
            Logger.Info("Config", "误识别路径已迁移：" key " -> " correctKey "（路径：" path "）")
        } catch Error as e {
            Logger.Warn("Config", "迁移误识别路径失败（" key "）：" e.Message)
        }
    }

    ; 保存到配置文件（原子替换）
    static SaveToIni(settingsMap, tokenStorage := "") {
        if this.IniFile = ""
            this.InitPath()

        targetIniFile := this.IniFile
        tempIniFile := ""
        Critical "On"
        try {
            requestedToken := settingsMap.HasProp("GitHubToken") ? settingsMap.GitHubToken : ""
            if (this.TokenStorageStatus = "decrypt_failed" && requestedToken = "")
                return {success: false, message: I18n.T("GitHub Token 无法解密。为避免覆盖原加密配置，请重新输入 Token 后再保存。")}

            if !IsObject(tokenStorage)
                tokenStorage := this.PrepareGitHubTokenForStorage(requestedToken)
            if !tokenStorage.success
                return tokenStorage

            tempIniFile := targetIniFile ".tmp-" A_TickCount "-" Random(1000, 9999)
            if FileExist(targetIniFile)
                FileCopy(targetIniFile, tempIniFile, true)
            else {
                tempHandle := FileOpen(tempIniFile, "w")
                tempHandle.Close()
            }
            this.IniFile := tempIniFile

            try IniDelete(this.IniFile, "Hotkeys")
            try IniDelete(this.IniFile, "Main")
            try IniDelete(this.IniFile, "Custom")

            ; 保存按键设置
            for keyVar, _ in Constants.KeyNames {
                if this._HotkeySettings.Has(keyVar) {
                    IniWrite(this._HotkeySettings[keyVar], this.IniFile, "Hotkeys", keyVar)
                }
            }

            ; 保存重要设置
            for keyVar, _ in Constants.ImportantNames {
                if settingsMap.HasProp(keyVar)
                    this.SetImportant(keyVar, settingsMap.%keyVar%)
            }
            for keyVar, _ in Constants.ImportantNames {
                if (keyVar = "Frame155" || keyVar = "GitHubToken")
                    continue
                if this._ImportantSettings.Has(keyVar) {
                    IniWrite(this._ImportantSettings[keyVar], this.IniFile, "Main", keyVar)
                }
            }

            if (tokenStorage.storedValue != "")
                IniWrite(tokenStorage.storedValue, this.IniFile, "Main", this.GITHUB_TOKEN_PROTECTED_KEY)

            ; Frame 双写：Frame155 存文本值，Frame 存旧版索引
            if this._ImportantSettings.Has("Frame") {
                frameText := this._ImportantSettings["Frame"]
                frameIndex := Constants.FrameTextToOldIndex.Has(frameText) ? Constants.FrameTextToOldIndex[frameText] : "3"
                IniWrite(frameText, this.IniFile, "Main", "Frame155")
                IniWrite(frameIndex, this.IniFile, "Main", "Frame")
            }

            ; 保存自定义设置
            for keyVar, _ in Constants.CustomNames {
                if (keyVar = "SwitchHotkey")
                    continue
                if settingsMap.HasProp(keyVar) {
                    this.SetCustom(keyVar, settingsMap.%keyVar%)
                }
            }
            for keyVar, _ in Constants.CustomNames {
                if this._CustomSettings.Has(keyVar) {
                    IniWrite(this._CustomSettings[keyVar], this.IniFile, "Custom", keyVar)
                }
            }

            this.IniFile := targetIniFile
            this._CommitIniTemp(tempIniFile, targetIniFile)
            tempIniFile := ""
            return {success: true, message: ""}
        } catch Error as e {
            Logger.Error("Config", "配置文件写入失败：" e.Message)
            return {success: false, message: I18n.T("配置文件写入失败：{1}", e.Message)}
        } finally {
            this.IniFile := targetIniFile
            if (tempIniFile != "" && FileExist(tempIniFile))
                try FileDelete(tempIniFile)
            Critical "Off"
        }
    }

    ; 保存所有内存中的配置到配置文件（非 GUI 场景）
    static SaveAllToIni() {
        if this.IniFile = ""
            this.InitPath()

        targetIniFile := this.IniFile
        tempIniFile := ""
        backupFile := ""
        Critical "On"
        try {
            if (this.TokenStorageStatus = "decrypt_failed" && this._ImportantSettings.Has("GitHubToken") && this._ImportantSettings["GitHubToken"] = "")
                return {success: false, message: I18n.T("GitHub Token 无法解密，已保留原加密配置。请重新输入 Token 后保存。"), backup: ""}

            tokenStorage := this.PrepareGitHubTokenForStorage(this._ImportantSettings.Has("GitHubToken") ? this._ImportantSettings["GitHubToken"] : "")
            if !tokenStorage.success
                return tokenStorage

            tempIniFile := targetIniFile ".tmp-" A_TickCount "-" Random(1000, 9999)
            if FileExist(targetIniFile)
                FileCopy(targetIniFile, tempIniFile, true)
            else {
                tempHandle := FileOpen(tempIniFile, "w")
                tempHandle.Close()
            }
            this.IniFile := tempIniFile

            try IniDelete(this.IniFile, "Hotkeys")
            try IniDelete(this.IniFile, "Main")

            ; 保存按键设置
            for keyVar, value in this._HotkeySettings {
                IniWrite(value, this.IniFile, "Hotkeys", keyVar)
            }

            ; 保存重要设置
            for keyVar, value in this._ImportantSettings {
                if (keyVar = "GitHubToken")
                    continue
                IniWrite(value, this.IniFile, "Main", keyVar)
            }
            if (tokenStorage.storedValue != "")
                IniWrite(tokenStorage.storedValue, this.IniFile, "Main", this.GITHUB_TOKEN_PROTECTED_KEY)

            ; 保存自定义设置
            for keyVar, value in this._CustomSettings {
                IniWrite(value, this.IniFile, "Custom", keyVar)
            }

            this.IniFile := targetIniFile
            backupFile := targetIniFile ".bak-" A_TickCount "-" Random(1000, 9999)
            this._CommitIniTemp(tempIniFile, targetIniFile, backupFile)
            tempIniFile := ""
            return {success: true, message: "", backup: backupFile}
        } catch Error as e {
            Logger.Error("Config", "配置文件保存失败：" e.Message)
            if (backupFile != "" && FileExist(backupFile))
                Logger.Warn("Config", "配置保存失败，已保留提交前备份：" backupFile)
            return {success: false, message: I18n.T("配置文件写入失败：{1}", e.Message), backup: backupFile}
        } finally {
            this.IniFile := targetIniFile
            if (tempIniFile != "" && FileExist(tempIniFile))
                try FileDelete(tempIniFile)
            Critical "Off"
        }
    }

    ; 用保存前备份回滚 INI
    static RollbackIni(backupFile) {
        if (backupFile = "" || !FileExist(backupFile))
            return false
        try {
            this._CommitIniTemp(backupFile, this.IniFile)
            return true
        } catch Error as e {
            Logger.Error("Config", "配置回滚失败：" e.Message)
            return false
        }
    }

    ; 删除保存成功后的 INI 备份
    static DiscardIniBackup(backupFile) {
        if (backupFile = "" || !FileExist(backupFile))
            return
        try FileDelete(backupFile)
    }

    ; 原子写入/删除若干 INI 键；entries: Array<{Section, Key, Value}>，缺 Value 即删除该键
    static _WriteIniEntriesAtomic(targetIniFile, entries) {
        tempIniFile := ""
        try {
            tempIniFile := targetIniFile ".tmp-" A_TickCount "-" Random(1000, 9999)
            if FileExist(targetIniFile)
                FileCopy(targetIniFile, tempIniFile, true)
            else {
                tempHandle := FileOpen(tempIniFile, "w")
                tempHandle.Close()
            }
            ; FileCopy 会继承只读属性
            FileSetAttrib("-R", tempIniFile)
            for entry in entries {
                if entry.HasOwnProp("Value")
                    IniWrite(entry.Value, tempIniFile, entry.Section, entry.Key)
                else
                    try IniDelete(tempIniFile, entry.Section, entry.Key)
            }
            this._CommitIniTemp(tempIniFile, targetIniFile)
            tempIniFile := ""
        } finally {
            if tempIniFile != "" && FileExist(tempIniFile) {
                try FileSetAttrib("-R", tempIniFile)
                try FileDelete(tempIniFile)
            }
        }
    }

    ; 单键原子写入
    static _PersistSingleValue(key, value) {
        if this.IniFile = ""
            this.InitPath()

        if this._IsHotkeyValuedKey(key)
            value := this._NormalizeHotkeyValue(value)

        if (key = "ThemeMode")
            value := Constants.NormalizeThemeMode(value)

        Critical "On"
        try {
            entries := []
            if (key = "Frame") {
                ; Frame 双写
                frameIndex := Constants.FrameTextToOldIndex.Has(value) ? Constants.FrameTextToOldIndex[value] : "3"
                entries.Push({Section: "Main", Key: "Frame155", Value: value})
                entries.Push({Section: "Main", Key: "Frame", Value: frameIndex})
            } else if (key = "GitHubToken") {
                tokenStorage := this.PrepareGitHubTokenForStorage(value)
                if !tokenStorage.success
                    return tokenStorage
                if (tokenStorage.storedValue != "")
                    entries.Push({Section: "Main", Key: this.GITHUB_TOKEN_PROTECTED_KEY, Value: tokenStorage.storedValue})
                else
                    entries.Push({Section: "Main", Key: this.GITHUB_TOKEN_PROTECTED_KEY}) ; 缺 Value = 删除该键
            } else {
                section := this._SectionForKey(key)
                if (section = "")
                    throw Error("未知配置键：" key)
                entries.Push({Section: section, Key: key, Value: value})
            }
            this._WriteIniEntriesAtomic(this.IniFile, entries)
            return {success: true, message: ""}
        } catch Error as e {
            Logger.Error("Config", "单键配置写入失败：" e.Message)
            return {success: false, message: I18n.T("配置文件写入失败：{1}", e.Message)}
        } finally {
            Critical "Off"
        }
    }

    ; 配置键名 → 所属 INI section
    static _SectionForKey(key) {
        if this._DefaultHotkeys.Has(key)
            return "Hotkeys"
        if this._DefaultImportant.Has(key)
            return "Main"
        if this._DefaultCustom.Has(key)
            return "Custom"
        return ""
    }

    ; 仅持久化热键设置（Hotkeys section + SwitchHotkey）
    static SaveHotkeysToIni() {
        if this.IniFile = ""
            this.InitPath()

        targetIniFile := this.IniFile
        tempIniFile := ""
        Critical "On"
        try {
            tempIniFile := targetIniFile ".tmp-" A_TickCount "-" Random(1000, 9999)
            if FileExist(targetIniFile)
                FileCopy(targetIniFile, tempIniFile, true)
            else {
                tempHandle := FileOpen(tempIniFile, "w")
                tempHandle.Close()
            }
            this.IniFile := tempIniFile

            try IniDelete(this.IniFile, "Hotkeys")
            try IniDelete(this.IniFile, "Custom", "SwitchHotkey")
            for keyVar, value in this._HotkeySettings {
                IniWrite(value, this.IniFile, "Hotkeys", keyVar)
            }
            if this._CustomSettings.Has("SwitchHotkey")
                IniWrite(this._CustomSettings["SwitchHotkey"], this.IniFile, "Custom", "SwitchHotkey")

            this.IniFile := targetIniFile
            this._CommitIniTemp(tempIniFile, targetIniFile)
            tempIniFile := ""
            return {success: true, message: ""}
        } catch Error as e {
            Logger.Error("Config", "热键设置写入失败：" e.Message)
            return {success: false, message: I18n.T("配置文件写入失败：{1}", e.Message)}
        } finally {
            this.IniFile := targetIniFile
            if (tempIniFile != "" && FileExist(tempIniFile))
                try FileDelete(tempIniFile)
            Critical "Off"
        }
    }

    ; 用已写入的临时文件替换正式配置文件
    static _CommitIniTemp(tempIniFile, targetIniFile, backupFile := "") {
        if !FileExist(targetIniFile) {
            FileMove(tempIniFile, targetIniFile, true)
            return
        }

        if (backupFile = "")
            replaced := DllCall("Kernel32\ReplaceFileW"
                , "Str", targetIniFile
                , "Str", tempIniFile
                , "Ptr", 0
                , "UInt", 0x1 ; REPLACEFILE_WRITE_THROUGH
                , "Ptr", 0
                , "Ptr", 0
                , "Int")
        else
            replaced := DllCall("Kernel32\ReplaceFileW"
                , "Str", targetIniFile
                , "Str", tempIniFile
                , "Str", backupFile
                , "UInt", 0x1 ; REPLACEFILE_WRITE_THROUGH
                , "Ptr", 0
                , "Ptr", 0
                , "Int")
        if !replaced {
            errorCode := A_LastError
            throw Error("配置文件替换失败，错误码：" errorCode)
        }
    }

    ; 加载默认值
    static LoadDefaults() {
        this._HotkeySettings := this._DefaultHotkeys.Clone()
        this._ImportantSettings := this._DefaultImportant.Clone()
        this._CustomSettings := this._DefaultCustom.Clone()
        this._IsLoaded := true
    }

    ; 恢复按键默认设置
    static ResetHotkeyToDefaults() {
        this._HotkeySettings := this._DefaultHotkeys.Clone()
        this._CustomSettings.Set("SwitchHotkey", this._DefaultCustom["SwitchHotkey"])
    }

    static AllHotkeys => this._HotkeySettings

    static AllImportant => this._ImportantSettings

    static AllCustom => this._CustomSettings

}
