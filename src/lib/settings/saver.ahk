; == 设置保存器 ==
class Saver {
    ; 记录设置并写入配置文件
    static SettingsIniWrite() {
        EventBus.Publish("SettingsWillSave")
        SavedObj := GuiManager.Submit()
        
        ; 检查按键冲突
        if (!this._CheckKeyConflicts()) {
            Exit
        }
        
        ; 验证GitHub Token（如果输入了的话）
        if (SavedObj.HasProp("GitHubToken") && SavedObj.GitHubToken != "") {
            ; 如果Token与当前保存的不同，需要验证
            currentToken := Config.GetImportant("GitHubToken")
            if (SavedObj.GitHubToken != currentToken) {
                ; 验证新Token
                tokenResult := VersionChecker.ValidateToken(SavedObj.GitHubToken)
                if (!tokenResult.valid) {
                    result := MessageBox.Confirm("GitHub Token验证失败：" tokenResult.message "`n`n是否仍要保存此Token？", "Token验证失败")
                    if (result = "No") {
                        Exit
                    }
                } else {
                    ; Token有效，更新验证状态
                    VersionChecker.TokenValidated := true
                    MessageBox.Info("GitHub Token验证成功！`n用户: " tokenResult.username "`nAPI配额: " tokenResult.rateLimit, "Token有效")
                }
            }
        }

        ; 在应用其他外部设置前，预检 GitHub Token 的 DPAPI 加密。
        plainToken := SavedObj.HasProp("GitHubToken") ? SavedObj.GitHubToken : ""
        tokenStorage := Config.PrepareGitHubTokenForStorage(plainToken)
        if (!tokenStorage.success) {
            MessageBox.Error("GitHub Token 无法安全保存：`n" tokenStorage.message, "设置保存失败")
            Exit
        }
        
        ; 验证游戏路径
        if (SavedObj.HasProp("GamePath") && SavedObj.GamePath != "") {
            if !FileExist(SavedObj.GamePath) {
                result := MessageBox.Confirm("游戏路径不存在：`n" SavedObj.GamePath "`n`n是否仍要保存？", "路径不存在")
                if (result = "No") {
                    Exit
                }
            } else {
                ; 验证是否为 Arknights.exe
                SplitPath(SavedObj.GamePath, &fileName)
                if (fileName != "Arknights.exe") {
                    result := MessageBox.Confirm("游戏路径不正确：`n" SavedObj.GamePath "`n`n目标文件不是 Arknights.exe，请确保选择正确的游戏可执行文件。`n`n是否仍要保存？", "路径不正确")
                    if (result = "No") {
                        Exit
                    }
                }
            }
        }

        ; 应用“启动游戏时自动启动小助手”设置
        if (!this._ApplyGameAutoStart(SavedObj)) {
            Exit
        }

        ; 保存到INI
        saveResult := Config.SaveToIni(SavedObj, tokenStorage)
        if (!saveResult.success) {
            MessageBox.Error(saveResult.message, "设置保存失败")
            Exit
        }
    }

    ; 应用随游戏自动启动配置。外部任务成功后才保存配置开关。
    static _ApplyGameAutoStart(SavedObj) {
        if (!SavedObj.HasProp("AutoStartWithGame"))
            return true

        enabled := (SavedObj.AutoStartWithGame = 1 || SavedObj.AutoStartWithGame = "1")
        appliedGamePath := ""
        if (enabled) {
            validation := GameAutoStartManager.ValidateGamePath(SavedObj.GamePath)
            if (!validation.success) {
                MessageBox.Error(validation.message, "无法启用随游戏自动启动")
                return false
            }
            ; 保存规范化后的绝对路径，确保后续启动校准使用同一事件过滤条件。
            SavedObj.GamePath := validation.path
            GuiManager.SetControlValue("GamePath", validation.path)
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
    static ResetGameStateIfNeeded(*) {
        if (Config.GetImportant("AutoExit") == "1" && !WinExist("ahk_exe Arknights.exe")) {
            State.GameHasStarted := false
        }
    }
}
