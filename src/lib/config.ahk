; == 全局配置管理 ==

; -- 常量定义 --
class Constants {
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
    
    ; 重要设置名称映射
    static ImportantNames := Map(
        "AutoExit", "自动退出",
        "AutoOpenSettings", "自动打开设置界面",
        "Frame", "游戏内帧率设置（兼容旧版）",
        "Frame155", "游戏内帧率设置",
        "AutoUpdate", "自动检查更新",
        "LastDismissedVersion", "上次忽略的更新版本",
        "UpdateChannel", "更新渠道",
        "UseGitHubToken", "是否使用GitHub Token",
        "GitHubToken", "GitHub Token",
        "GamePath", "游戏路径",
        "AutoRunGame", "随小助手自动启动明日方舟",
        "DismissedChangelogVersion", "已忽略公告版本",
        "DefaultStrongHoldProtocol", "默认启动卫戍协议方案",
        "AutoBeginPause", "开局自动暂停"
    )

    ; 自定义设置名称映射
    static CustomNames := Map(
        "ClickDelay", "点击延迟",
        "SwitchHotkey", "启用/禁用热键",
        "FrameSkip16msDelay", "前进16ms延迟",
        "FrameSkip33msDelay", "前进33ms延迟",
        "FrameSkip166msDelay", "前进166ms延迟"
    )
}

; -- 配置管理 --
class Config {
    ; 内部存储
    static _HotkeySettings := Map()
    static _ImportantSettings := Map()
    static _CustomSettings := Map()
    static _IsLoaded := false

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
        ; 快捷操作
        "LButtonClick", "z",
        "CeaseOperations", "",
        "Skip", "",
        "Back", "",
        "Harvest", "",
        "CollectCollectibles", "",
        ; 卫戍协议按键
        "CheckEnemies", "w",
        "DispatchCenter", "a",
        "Freeze", "s",
        "Refresh", "d",
        "Upgrade", "g",
        "Sell", "x",
        "Ready", "c",
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
        "Frame", "90",
        "Frame155", "",
        "AutoUpdate", "1",
        "LastDismissedVersion", "",
        "UpdateChannel", "1",
        "UseGitHubToken", "0",
        "GitHubToken", "",
        "GamePath", "",
        "AutoRunGame", "0",
        "LastLaunchedVersion", "",
        "DismissedChangelogVersion", "",
        "DefaultStrongHoldProtocol", "0",
        "AutoBeginPause", "0"
    )

    ; 内部：默认自定义设置
    static _DefaultCustom := Map(
        "ClickDelay", "50",
        "SwitchHotkey", "",
        "FrameSkip16msDelay", "16",
        "FrameSkip33msDelay", "30",
        "FrameSkip166msDelay", "165"
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
    
    ; 获取按键设置
    static GetHotkey(key) {
        if !this._IsLoaded
            this.LoadFromIni()
        else {
            for keyVar, defaultVal in this._DefaultHotkeys {
                this._HotkeySettings[keyVar] := IniRead(this.IniFile, "Hotkeys", keyVar, defaultVal)
            }
        }
        return this._HotkeySettings.Has(key) ? this._HotkeySettings[key] : ""
    }
    
    ; 设置按键
    static SetHotkey(key, value) {
        this._HotkeySettings[key] := value
    }
    
    ; 获取重要设置
    static GetImportant(key) {
        if !this._IsLoaded
            this.LoadFromIni()
        else {
            for keyVar, defaultVal in this._DefaultImportant {
                if (keyVar = "GitHubToken") {
                    ; Token 需要解码
                    encodedToken := IniRead(this.IniFile, "Main", keyVar, defaultVal)
                    ; 调试输出（仅记录长度，不记录 Token 值）
                    OutputDebug("[Config] Token 读取 - INI 中的值长度：" StrLen(encodedToken))
                    decodedToken := this.DecodeToken(encodedToken)
                    OutputDebug("[Config] Token 读取 - 解码后长度：" StrLen(decodedToken))
                    this._ImportantSettings[keyVar] := decodedToken
                } else {
                    this._ImportantSettings[keyVar] := IniRead(this.IniFile, "Main", keyVar, defaultVal)
                }
            }
        }
        ; Frame键的特殊处理：优先内存中Frame155（未持久化的值），回退INI，再回退旧序号
        if (key = "Frame") {
            frame155 := this._ImportantSettings.Has("Frame155") && this._ImportantSettings["Frame155"] != ""
                ? this._ImportantSettings["Frame155"]
                : IniRead(this.IniFile, "Main", "Frame155", "")
            if (frame155 != "")
                return frame155
            frameIndex := this._ImportantSettings.Has(key) ? this._ImportantSettings[key] : ""
            if Constants.FrameOldIndexToText.Has(frameIndex)
                return Constants.FrameOldIndexToText[frameIndex]
            return this._DefaultImportant["Frame"]
        }
        return this._ImportantSettings.Has(key) ? this._ImportantSettings[key] : ""
    }

    ; 设置重要设置
    static SetImportant(key, value) {
        this._ImportantSettings[key] := value
    }

    ; 获取自定义设置
    static GetCustom(key) {
        if !this._IsLoaded
            this.LoadFromIni()
        else {
            for keyVar, defaultVal in this._DefaultCustom {
                this._CustomSettings[keyVar] := IniRead(this.IniFile, "Custom", keyVar, defaultVal)
            }
        }
        return this._CustomSettings.Has(key) ? this._CustomSettings[key] : ""
    }
    
    ; 设置自定义设置
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
            IniWrite(Constants.FrameOldIndexToText[frameValue], this.IniFile, "Main", "Frame155")
            ; 保留原Frame值给旧版本使用
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
                ; Token 需要解码
                encodedToken := IniRead(this.IniFile, "Main", keyVar, defaultVal)
                ; 调试输出（仅记录长度，不记录 Token 值）
                OutputDebug("[Config] Token 读取 - INI 中的值长度：" StrLen(encodedToken))
                decodedToken := this.DecodeToken(encodedToken)
                OutputDebug("[Config] Token 读取 - 解码后长度：" StrLen(decodedToken))
                this._ImportantSettings[keyVar] := decodedToken
            } else {
                this._ImportantSettings[keyVar] := IniRead(this.IniFile, "Main", keyVar, defaultVal)
            }
        }

        ; 加载自定义设置
        for keyVar, defaultVal in this._DefaultCustom {
            this._CustomSettings[keyVar] := IniRead(this.IniFile, "Custom", keyVar, defaultVal)
        }
        
        ; 如果配置文件不存在，创建并写入默认值
        if (!fileExists) {
            this._EnsureConfigFileExists()
        }
        
        this._IsLoaded := true
    }
    
    ; 确保配置文件存在并包含所有配置项
    static _EnsureConfigFileExists() {
        ; 确保目录存在
        configDir := A_AppData "\ArknightsFrameAssistant\PC"
        if !DirExist(configDir)
            DirCreate(configDir)
        
        ; 写入所有默认重要设置
        for keyVar, defaultVal in this._DefaultImportant {
            if (keyVar = "GitHubToken") {
                ; Token 需要编码存储，即使为空
                encodedVal := this.EncodeToken(defaultVal)
                OutputDebug("[Config] Token 写入 - 默认值长度：" StrLen(defaultVal) ", 编码后长度：" StrLen(encodedVal))
                IniWrite(encodedVal, this.IniFile, "Main", keyVar)
            } else {
                IniWrite(defaultVal, this.IniFile, "Main", keyVar)
            }
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
    static SaveToIni(settingsMap) {
        if this.IniFile = ""
            this.InitPath()
        
        ; 先删除整个Section以清理旧配置
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
            if settingsMap.HasProp(keyVar) {
                if (keyVar = "GitHubToken") {
                    ; Token需要编码存储
                    this.SetImportant(keyVar, this.EncodeToken(settingsMap.%keyVar%))
                } else {
                    this.SetImportant(keyVar, settingsMap.%keyVar%)
                }
            }
        }
        for keyVar, _ in Constants.ImportantNames {
            if keyVar = "Frame155"
                continue
            if this._ImportantSettings.Has(keyVar) {
                IniWrite(this._ImportantSettings[keyVar], this.IniFile, "Main", keyVar)
            }
        }

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
    }
    
    ; 保存所有内存中的配置到配置文件（用于非GUI场景）
    static SaveAllToIni() {
        if this.IniFile = ""
            this.InitPath()
        
        ; 先删除整个Section以清理旧配置
        try IniDelete(this.IniFile, "Hotkeys")
        try IniDelete(this.IniFile, "Main")
        
        ; 保存按键设置
        for keyVar, value in this._HotkeySettings {
            IniWrite(value, this.IniFile, "Hotkeys", keyVar)
        }
        
        ; 保存重要设置
        for keyVar, value in this._ImportantSettings {
            if (keyVar = "GitHubToken") {
                ; Token 需要编码存储
                IniWrite(this.EncodeToken(value), this.IniFile, "Main", keyVar)
            } else {
                IniWrite(value, this.IniFile, "Main", keyVar)
            }
        }

        ; 保存自定义设置
        for keyVar, value in this._CustomSettings {
            IniWrite(value, this.IniFile, "Custom", keyVar)
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
    
    ; -- Token存储方法 --
    
    ; 编码Token（直接返回原文，不编码）
    static EncodeToken(plainToken) {
        return plainToken  ; 直接返回原文
    }
    
    ; 解码Token（直接返回原文，不解码）
    static DecodeToken(encodedToken) {
        return encodedToken  ; 直接返回原文
    }
}

; -- 状态管理 --
class State {
    ; 游戏状态
    static GameHasStarted := false
    
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
        this.ClickDelay := Config.GetCustom("ClickDelay")
    }
}

; 初始化配置路径
Config.InitPath()
