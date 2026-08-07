; == 全局配置管理 ==

; -- 常量定义 --
class Constants {
    static DefaultTabOrder := "keyBind,quick,strongHoldProtocol,other"

    ; 延迟常量
    static Delay30 := 34      ; 30帧
    static Delay60 := 17      ; 60帧
    static Delay90 := 12      ; 90帧
    static Delay120 := 9      ; 120帧
    static Delay144 := 8      ; 144帧
    static Delay165 := 7      ; 165帧
    static Delay180 := 6      ; 180帧
    static Delay240 := 5      ; 240帧

    ; 帧率选项（下拉框显示文本→下拉框索引，1-based）
    static FrameOptions := ["30", "60", "90", "120", "144", "165", "180", "240+"]
    ; 帧率文本→旧版序号（用于Frame双写兼容）
    static FrameTextToOldIndex := Map("30","1", "60","2", "90","3", "120","4", "144","5", "165","6", "180","6", "240+","7")
    ; 旧版序号→帧率文本（用于迁移和回退）
    static FrameOldIndexToText := Map("1","30", "2","60", "3","90", "4","120", "5","144", "6","165", "7","240+")

    ; 按键名称映射
    static KeyNames := Map(
        ; 常规作战
        "PressPause", "按下暂停",
        "ReleasePause", "松开暂停",
        "GameSpeed", "切换倍速",
        "PauseSelect", "暂停选中",
        "Skill", "单位技能",
        "Retreat", "单位撤退",
        "16ms", "前进 16ms",
        "33ms", "前进 33ms",
        "166ms", "前进 166ms",
        "OneClickSkill", "一键技能",
        "OneClickRetreat", "一键撤退",
        "PauseSkill", "暂停技能",
        "PauseRetreat", "暂停撤退",
        "SwitchView", "视角切换",
        "AutoBeginPauseSwitch", "开局自动暂停开关",
        ; 快捷操作
        "LButtonClick", "左键点击",
        "CeaseOperations", "放弃行动",
        "Skip", "跳过招募动画/剧情",
        "Back", "返回上级菜单",
        "Harvest", "基建快速收取",
        "CollectCollectibles", "肉鸽收取道具",
        ; 卫戍协议按键
        "CheckEnemies", "查看敌人",
        "DispatchCenter", "调度中心",  ; 不知道舟里的调度中心指的是哪种调度中心，随便选了一个译名
        "Freeze", "冻结",
        "Refresh", "刷新",
        "Upgrade", "升级",
        "Sell", "出售",
        "Ready", "准备就绪",
        "StrongHoldProtocolLButtonClick", "卫戍协议模拟左键点击",
        "StrongHoldProtocolRetreat", "卫戍协议单位撤退",
        "StrongHoldProtocolOneClickRetreat", "卫戍协议一键撤退",
        "OneClickSell", "一键出售",
        "OneClickPurchase", "一键购买"
    )

    ; 热键启用分组，同时作为冲突检测的唯一分组数据源
    static CombatHotkeys := Map(
        "PressPause", true,
        "ReleasePause", true,
        "GameSpeed", true,
        "PauseSelect", true,
        "Skill", true,
        "Retreat", true,
        "16ms", true,
        "33ms", true,
        "166ms", true,
        "OneClickSkill", true,
        "OneClickRetreat", true,
        "PauseSkill", true,
        "PauseRetreat", true,
        "SwitchView", true,
        "BeginPause", true,
        "AutoBeginPauseSwitch", true
    )

    static QuickHotkeys := Map(
        "LButtonClick", true,
        "CeaseOperations", true,
        "Skip", true,
        "Back", true,
        "Harvest", true,
        "CollectCollectibles", true
    )

    static StrongHoldHotkeys := Map(
        "CheckEnemies", true,
        "DispatchCenter", true,
        "Freeze", true,
        "Refresh", true,
        "Upgrade", true,
        "Sell", true,
        "Ready", true,
        "StrongHoldProtocolLButtonClick", true,
        "StrongHoldProtocolRetreat", true,
        "StrongHoldProtocolOneClickRetreat", true,
        "OneClickSell", true,
        "OneClickPurchase", true
    )

    ; 重要设置名称映射
    static ImportantNames := Map(
        "AutoExit", "自动退出",
        "AutoOpenSettings", "自动打开设置界面",
        "ExitOnWindowClose", "关闭窗口时退出小助手",
        "Frame", "游戏内帧率设置（兼容旧版）",
        "Frame155", "游戏内帧率设置",
        "AutoUpdate", "自动检查更新",
        "LastDismissedVersion", "上次忽略的更新版本",
        "UpdateChannel", "更新渠道",
        "UpdateSource", "更新源",
        "UseGitHubToken", "是否使用GitHub Token",
        "GitHubToken", "GitHub Token",
        "GamePath", "游戏路径",
        "AutoRunGame", "随小助手自动启动明日方舟",
        "AutoStartWithGame", "随明日方舟自动启动小助手",
        "DismissedChangelogVersion", "已忽略公告版本",
        "DefaultStrongHoldProtocol", "默认启动卫戍协议方案",
        "TabOrder", "标签页顺序",
        "HiddenTabs", "隐藏的标签页",
        "AutoBeginPause", "开局自动暂停",
        "BackCeaseOperations", "使用“返回上级菜单”放弃行动",
        "InLevelGuard", "在非战斗关卡场景禁用常规战斗热键",
        "DebugEnabled", "调试模式"
    )

    ; 自定义设置名称映射
    static CustomNames := Map(
        "ClickDelay", "点击延迟",
        "SwitchHotkey", "启用/禁用热键",
        "FrameSkip16msDelay", "前进16ms延迟",
        "FrameSkip33msDelay", "前进33ms延迟",
        "FrameSkip166msDelay", "前进166ms延迟",
        "HoverOperate", "游戏窗口未激活时允许鼠标悬停在窗口上触发热键"
    )
}

; -- 配置管理 --
class Config {
    ; 内部存储
    static _HotkeySettings := Map()
    static _ImportantSettings := Map()
    static _CustomSettings := Map()
    static _IsLoaded := false
    static GITHUB_TOKEN_PROTECTED_KEY := "GitHubTokenProtected"
    static TokenStorageStatus := "ok"

    ; 内部：默认按键设置
    static _DefaultHotkeys := Map(
        ; 常规作战
        "PressPause", "f",
        "ReleasePause", "Space",
        "GameSpeed", "d",
        "PauseSelect", "w",
        "Skill", "s",
        "Retreat", "a",
        "16ms", "",
        "33ms", "r",
        "166ms", "t",
        "OneClickSkill", "e",
        "OneClickRetreat", "q",
        "PauseSkill", "XButton2",
        "PauseRetreat", "XButton1",
        "SwitchView", "",
        "AutoBeginPauseSwitch", "",
        ; 快捷操作
        "LButtonClick", "",
        "CeaseOperations", "",
        "Skip", "",
        "Back", "",
        "Harvest", "",
        "CollectCollectibles", "",
        ; 卫戍协议按键
        "CheckEnemies", "",
        "DispatchCenter", "",
        "Freeze", "",
        "Refresh", "",
        "Upgrade", "",
        "Sell", "",
        "Ready", "",
        "StrongHoldProtocolLButtonClick", "",
        "StrongHoldProtocolRetreat", "",
        "StrongHoldProtocolOneClickRetreat", "",
        "OneClickSell", "",
        "OneClickPurchase", ""
    )

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
        "AutoRunGame", "0",
        "AutoStartWithGame", "0",
        "LastLaunchedVersion", "",
        "DismissedChangelogVersion", "",
        "DefaultStrongHoldProtocol", "0",
        "TabOrder", Constants.DefaultTabOrder,
        "HiddenTabs", "",
        "AutoBeginPause", "0",
        "BackCeaseOperations", "1",
        "InLevelGuard", "1",
        "DebugEnabled", "0"
    )

    ; 内部：默认自定义设置
    static _DefaultCustom := Map(
        "ClickDelay", "90",
        "SwitchHotkey", "",
        "FrameSkip16msDelay", "16",
        "FrameSkip33msDelay", "30",
        "FrameSkip166msDelay", "165",
        "HoverOperate", "1"
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

    ; 获取按键设置（从内存工作副本，供 GUI 和冲突检测使用）
    static GetHotkey(key) {
        if !this._IsLoaded
            this.LoadFromIni()
        return this._HotkeySettings.Has(key) ? this._HotkeySettings[key] : ""
    }

    ; 直接从 INI 读取按键设置（不触碰内存工作副本，供热键注册使用）
    static ReadHotkeyFromIni(key) {
        if this.IniFile = ""
            this.InitPath()
        defaultVal := this._DefaultHotkeys.Has(key) ? this._DefaultHotkeys[key] : ""
        return IniRead(this.IniFile, "Hotkeys", key, defaultVal)
    }

    ; 设置按键（仅写内存工作副本）
    static SetHotkey(key, value) {
        this._HotkeySettings[key] := value
    }

    ; 获取重要设置（从内存工作副本，供 GUI 使用）
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

    ; 直接从 INI 读取重要设置（不触碰内存工作副本，供运行时使用）
    static ReadImportantFromIni(key) {
        if this.IniFile = ""
            this.InitPath()
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

    ; 内部：解析 Frame 值（Frame155 优先，回退旧序号，再回退默认值）
    static _ResolveFrame(frame155, frameIndex) {
        if (frame155 != "")
            return frame155
        if Constants.FrameOldIndexToText.Has(frameIndex)
            return Constants.FrameOldIndexToText[frameIndex]
        return this._DefaultImportant["Frame"]
    }

    ; 设置重要设置（Frame 自动同步 Frame155）
    static SetImportant(key, value) {
        this._ImportantSettings[key] := value
        if (key = "Frame")
            this._ImportantSettings["Frame155"] := value
    }

    ; 获取自定义设置（从内存工作副本，供 GUI 和冲突检测使用）
    static GetCustom(key) {
        if !this._IsLoaded
            this.LoadFromIni()
        return this._CustomSettings.Has(key) ? this._CustomSettings[key] : ""
    }

    ; 直接从 INI 读取自定义设置（不触碰内存工作副本，供运行时使用）
    static ReadCustomFromIni(key) {
        if this.IniFile = ""
            this.InitPath()
        defaultVal := this._DefaultCustom.Has(key) ? this._DefaultCustom[key] : ""
        return IniRead(this.IniFile, "Custom", key, defaultVal)
    }

    ; 设置自定义设置（仅写内存工作副本）
    static SetCustom(key, value) {
        this._CustomSettings[key] := value
    }

    ; 帧率设置数据迁移：从旧版Frame序号迁移到Frame155文本值
    static MigrateFrameRate() {
        if this.IniFile = ""
            this.InitPath()
        if (!FileExist(this.IniFile))
            return

        ; 如果Frame155已有值，无需迁移
        frame155Value := IniRead(this.IniFile, "Main", "Frame155", "")
        if (frame155Value != "")
            return

        ; 尝试从旧Frame读取并转换为文本值
        frameValue := IniRead(this.IniFile, "Main", "Frame", "")
        if (frameValue = "")
            return

        if Constants.FrameOldIndexToText.Has(frameValue) {
            try {
                IniWrite(Constants.FrameOldIndexToText[frameValue], this.IniFile, "Main", "Frame155")
                ; 保留原Frame值给旧版本使用
            } catch Error as e {
                Logger.Warn("Config", "帧率迁移写入失败：" e.Message)
            }
        }
    }

    ; 将旧版明文 Token 迁移到 DPAPI 加密键。
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

            ; 加密值损坏时，若仍有旧明文则尝试恢复并重新迁移。
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
            ; 先写入并校验新值，再删除旧明文，避免迁移中断造成数据丢失。
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

    ; 读取 Token。配置层之外始终只返回内存中的明文。
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

    ; 保存前预生成密文，调用方可在产生其他外部副作用前完成失败检查。
    static PrepareGitHubTokenForStorage(plainToken) {
        ; 解密失败时禁止在外部设置变更前用空值覆盖仍可能可恢复的原加密配置。
        if (this.TokenStorageStatus = "decrypt_failed" && plainToken = "")
            return {success: false, message: "GitHub Token 无法解密。为避免覆盖原加密配置，请重新输入 Token 后再保存。"}
        return TokenProtector.Protect(plainToken)
    }

    static _SetTokenStorageStatus(status) {
        this.TokenStorageStatus := status
        if (status = "ok")
            Logger.Info("Config", "GitHub Token 存储状态：" status)
        else
            Logger.Warn("Config", "GitHub Token 存储异常：" status)
    }

    ; 获取面向用户的 Token 存储提示，不包含敏感数据。
    static GetTokenStorageWarning() {
        switch this.TokenStorageStatus {
            case "migration_failed":
                return "旧版 GitHub Token 未能完成加密迁移，原配置已保留。请恢复 Settings.ini 的写入权限后重启 AFA。"
            case "cleanup_failed":
                return "GitHub Token 已完成加密，但旧明文未能删除。请恢复 Settings.ini 的写入权限后重新保存设置。"
            case "decrypt_failed":
                return "GitHub Token 无法解密，可能来自其他 Windows 用户或电脑。请重新输入 Token 并保存。"
            default:
                return ""
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
            this._HotkeySettings[keyVar] := IniRead(this.IniFile, "Hotkeys", keyVar, defaultVal)
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

        ; 加载自定义设置
        for keyVar, defaultVal in this._DefaultCustom {
            this._CustomSettings[keyVar] := IniRead(this.IniFile, "Custom", keyVar, defaultVal)
        }

        ; 如果配置文件不存在，创建并写入默认值；已存在则回填新增的默认键（老用户升级自动补齐，如 HoverOperate）
        if (!fileExists) {
            this._EnsureConfigFileExists()
        } else {
            this._BackfillMissingCustomDefaults()
        }

        this._IsLoaded := true
    }

    ; 回填配置文件中缺失的自定义设置默认键（仅针对已存在的配置文件；全新文件由 _EnsureConfigFileExists 全量写入）
    static _BackfillMissingCustomDefaults() {
        if this.IniFile = ""
            this.InitPath()
        if !FileExist(this.IniFile)
            return
        ; 哨兵值不会作为正常配置出现，用于区分"键不存在"与"键存在但值为空"
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
        ; 防御：文件已存在则直接返回（LoadFromIni 调用前已守卫，此处自检以防未来其他调用方绕过）
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

    ; 保存到配置文件
    static SaveToIni(settingsMap, tokenStorage := "") {
        if this.IniFile = ""
            this.InitPath()

        targetIniFile := this.IniFile
        tempIniFile := ""
        Critical "On"
        try {
            requestedToken := settingsMap.HasProp("GitHubToken") ? settingsMap.GitHubToken : ""
            ; 解密失败时禁止用空值覆盖仍可能可恢复的原加密配置。
            if (this.TokenStorageStatus = "decrypt_failed" && requestedToken = "")
                return {success: false, message: "GitHub Token 无法解密。为避免覆盖原加密配置，请重新输入 Token 后再保存。"}

            if !IsObject(tokenStorage)
                tokenStorage := this.PrepareGitHubTokenForStorage(requestedToken)
            if !tokenStorage.success
                return tokenStorage

            ; 先在同目录临时文件中完成全部写入，成功后再替换正式配置。
            tempIniFile := targetIniFile ".tmp-" A_TickCount "-" Random(1000, 9999)
            if FileExist(targetIniFile)
                FileCopy(targetIniFile, tempIniFile, true)
            else {
                tempHandle := FileOpen(tempIniFile, "w")
                tempHandle.Close()
            }
            this.IniFile := tempIniFile

            ; 只清理临时文件中的旧 Section，原配置在提交前保持不变。
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

            ; Frame双写兼容：Frame155存文本值，Frame存旧版索引
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
            return {success: false, message: "配置文件写入失败：" e.Message}
        } finally {
            this.IniFile := targetIniFile
            if (tempIniFile != "" && FileExist(tempIniFile))
                try FileDelete(tempIniFile)
            Critical "Off"
        }
    }

    ; 保存所有内存中的配置到配置文件（用于非GUI场景）
    static SaveAllToIni() {
        if this.IniFile = ""
            this.InitPath()

        targetIniFile := this.IniFile
        tempIniFile := ""
        Critical "On"
        try {
            ; 非 GUI 保存同样不能在解密失败时用空值覆盖原加密配置。
            if (this.TokenStorageStatus = "decrypt_failed" && this._ImportantSettings.Has("GitHubToken") && this._ImportantSettings["GitHubToken"] = "")
                return {success: false, message: "GitHub Token 无法解密，已保留原加密配置。请重新输入 Token 后保存。"}

            tokenStorage := this.PrepareGitHubTokenForStorage(this._ImportantSettings.Has("GitHubToken") ? this._ImportantSettings["GitHubToken"] : "")
            if !tokenStorage.success
                return tokenStorage

            ; 先在同目录临时文件中完成全部写入，成功后再替换正式配置。
            tempIniFile := targetIniFile ".tmp-" A_TickCount "-" Random(1000, 9999)
            if FileExist(targetIniFile)
                FileCopy(targetIniFile, tempIniFile, true)
            else {
                tempHandle := FileOpen(tempIniFile, "w")
                tempHandle.Close()
            }
            this.IniFile := tempIniFile

            ; 只清理临时文件中的旧 Section，原配置在提交前保持不变。
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
            this._CommitIniTemp(tempIniFile, targetIniFile)
            tempIniFile := ""
            return {success: true, message: ""}
        } catch Error as e {
            Logger.Error("Config", "配置文件保存失败：" e.Message)
            return {success: false, message: "配置文件写入失败：" e.Message}
        } finally {
            this.IniFile := targetIniFile
            if (tempIniFile != "" && FileExist(tempIniFile))
                try FileDelete(tempIniFile)
            Critical "Off"
        }
    }

    ; 将已完整写入的临时配置文件替换为正式配置文件。
    static _CommitIniTemp(tempIniFile, targetIniFile) {
        if !FileExist(targetIniFile) {
            FileMove(tempIniFile, targetIniFile, true)
            return
        }

        if !DllCall("Kernel32\ReplaceFileW"
            , "Str", targetIniFile
            , "Str", tempIniFile
            , "Ptr", 0
            , "UInt", 0x1 ; REPLACEFILE_WRITE_THROUGH
            , "Ptr", 0
            , "Ptr", 0
            , "Int") {
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

    ; 获取所有按键设置（用于遍历）
    static AllHotkeys => this._HotkeySettings

    ; 获取所有重要设置（用于遍历）
    static AllImportant => this._ImportantSettings

    ; 获取所有自定义设置（用于遍历）
    static AllCustom => this._CustomSettings

}

; -- 状态管理 --
class State {
    ; 游戏状态
    static GameHasStarted := false

    ; 是否由游戏进程创建事件触发启动
    static StartedByGameAutoStart := false

    ; 当前延迟值
    static CurrentDelay := 11.3  ; 默认120帧

    ; 点击延迟
    static ClickDelay := 50  ; 默认50ms

    ; GUI窗口名称
    static GuiWindowName := ""

    ; 自动开局暂停状态
    static ReadyForPause := false

    ; 黑屏检测状态
    static BlackScreenDetected := false

    ; 关卡检测状态（LevelDetector 投票状态机维护；守卫/自动暂停二次确认消费）
    static InLevel := false

    ; 游戏失焦时鼠标悬停游戏即可操作热键（#213；由 Loader.LoadSettings 从配置同步，运行时供 HotkeyContext 消费）
    static HoverOperate := true

    ; 根据帧数设置更新延迟
    static UpdateDelay() {
        frame := Config.GetImportant("Frame")
        if (frame == "30") {
            this.CurrentDelay := Constants.Delay30
        } else if (frame == "60") {
            this.CurrentDelay := Constants.Delay60
        } else if (frame == "90") {
            this.CurrentDelay := Constants.Delay90
        } else if (frame == "120") {
            this.CurrentDelay := Constants.Delay120
        } else if (frame == "144") {
            this.CurrentDelay := Constants.Delay144
        } else if (frame == "165") {
            this.CurrentDelay := Constants.Delay165
        } else if (frame == "180") {
            this.CurrentDelay := Constants.Delay180
        } else if (frame == "240+") {
            this.CurrentDelay := Constants.Delay240
        }
    }

    ; 根据设置更新技能与撤退点击延迟
    static UpdateClickDelay() {
        this.ClickDelay := Config.ReadCustomFromIni("ClickDelay")
    }
}

; 初始化配置路径
Config.InitPath()
