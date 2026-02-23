; == 全局配置管理 ==

; -- 常量定义 --
class Constants {
    ; 延迟常量
    static DelayA := 35.3      ; 30帧
    static DelayB := 19.6      ; 60帧  
    static DelayC := 11.3      ; 120帧
    
    ; 按键名称映射
    static KeyNames := Map(
        "PressPause", "额外暂停键 A",
        "ReleasePause", "额外暂停键 B",
        "GameSpeed", "切换倍速",
        "PauseSelect", "暂停选中",
        "Skill", "干员技能",
        "Retreat", "干员撤退",
        "33ms", "前进 33ms",
        "166ms", "前进 166ms",
        "OneClickSkill", "一键技能",
        "OneClickRetreat", "一键撤退",
        "PauseSkill", "暂停技能",
        "PauseRetreat", "暂停撤退",
        "LButtonClick", "左键点击"
    )
    
    ; 重要设置名称映射
    static ImportantNames := Map(
        "AutoExit", "自动退出",
        "AutoOpenSettings", "自动打开设置界面",
        "Frame", "游戏内帧数设置",
        "AutoUpdate", "自动检查更新",
        "LastDismissedVersion", "上次忽略的更新版本",
        "UseGitHubToken", "是否使用GitHub Token",
        "GitHubToken", "GitHub Token"
    )
}

; -- 配置管理 --
class Config {
    ; 内部存储
    static _HotkeySettings := Map()
    static _ImportantSettings := Map()
    static _IsLoaded := false
    
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
        return this._ImportantSettings.Has(key) ? this._ImportantSettings[key] : ""
    }
    
    ; 设置重要设置
    static SetImportant(key, value) {
        this._ImportantSettings[key] := value
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
    }
    
    ; 保存到配置文件
    static SaveToIni(settingsMap) {
        if this.IniFile = ""
            this.InitPath()
        
        ; 先删除整个Section以清理旧配置
        try IniDelete(this.IniFile, "Hotkeys")
        try IniDelete(this.IniFile, "Main")
            
        ; 保存按键设置
        for keyVar, _ in Constants.KeyNames {
            if settingsMap.HasProp(keyVar) {
                IniWrite(settingsMap.%keyVar%, this.IniFile, "Hotkeys", keyVar)
            }
        }
        
        ; 保存重要设置
        for keyVar, _ in Constants.ImportantNames {
            if settingsMap.HasProp(keyVar) {
                if (keyVar = "GitHubToken") {
                    ; Token需要编码存储
                    IniWrite(this.EncodeToken(settingsMap.%keyVar%), this.IniFile, "Main", keyVar)
                } else {
                    IniWrite(settingsMap.%keyVar%, this.IniFile, "Main", keyVar)
                }
            }
        }
        
        ; 重新加载到内存
        this.LoadFromIni()
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
    }
    
    ; 加载默认值
    static LoadDefaults() {
        this._HotkeySettings := this._DefaultHotkeys.Clone()
        this._ImportantSettings := this._DefaultImportant.Clone()
        this._IsLoaded := true
    }
    
    ; 恢复默认设置
    static ResetHotkeyToDefaults() {
        this._HotkeySettings := this._DefaultHotkeys.Clone()
    }
    
    ; 内部：默认按键设置
    static _DefaultHotkeys := Map(
        "PressPause", "f",
        "ReleasePause", "Space",
        "GameSpeed", "d",
        "PauseSelect", "w",
        "Skill", "s",
        "Retreat", "a",
        "33ms", "r",
        "166ms", "t",
        "OneClickSkill", "e",
        "OneClickRetreat", "q",
        "PauseSkill", "XButton2",
        "PauseRetreat", "XButton1",
        "LButtonClick", "z"
    )
    
    ; 内部：默认重要设置
    static _DefaultImportant := Map(
        "AutoExit", "1",
        "AutoOpenSettings", "1",
        "Frame", "3",
        "AutoUpdate", "1",
        "LastDismissedVersion", "",
        "UseGitHubToken", "0",
        "GitHubToken", ""
    )
    
    ; 获取所有按键设置（用于遍历）
    static AllHotkeys => this._HotkeySettings
    
    ; 获取所有重要设置（用于遍历）
    static AllImportant => this._ImportantSettings
    
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
    
    ; 按键绑定状态
    static ModifyHook := InputHook("L0")
    static LastEditObject := ""
    static OriginalValue := ""
    static ControlObj := ""
    static WaitingModify := false
    
    ; GUI窗口名称
    static GuiWindowName := ""
    
    ; 根据帧数设置更新延迟
    static UpdateDelay() {
        frame := Config.GetImportant("Frame")
        if (frame == "1") {
            this.CurrentDelay := Constants.DelayA
        } else if (frame == "2") {
            this.CurrentDelay := Constants.DelayB
        } else {
            this.CurrentDelay := Constants.DelayC
        }
    }
}

; 初始化配置路径
Config.InitPath()
