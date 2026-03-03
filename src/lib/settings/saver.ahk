; == 设置保存器 ==
class Saver {
    ; 记录设置并写入配置文件
    static SettingsIniWrite() {
        EventBus.Publish("SettingsWillSave")
        SavedObj := GuiManager.Submit()
        ; 检查按键冲突
        UsedKeys := Map()
        for keyVar, keyName in Constants.KeyNames {
            if (!SavedObj.HasProp(keyVar))
                continue
            currentKey := SavedObj.%keyVar%
            if (currentKey != "") {
                ; 按键冲突提示
                if (UsedKeys.Has(currentKey)) {
                    prevKeyName := UsedKeys[currentKey]
                    MessageBox.Error("按键冲突！`n【" currentKey "】 已经被设置为: 【" prevKeyName "】`n请先修改重复的按键。", "保存失败")
                    Exit
                }
                UsedKeys[currentKey] := keyName
            }
        }
        for keyVar, keyName in Constants.CustomNames {
            if (keyVar != "SwitchHotkey")
                continue
            if (!SavedObj.HasProp(keyVar))
                continue
            currentKey := SavedObj.%keyVar%
            if (currentKey != "") {
                ; 按键冲突提示
                if (UsedKeys.Has(currentKey)) {
                    prevKeyName := UsedKeys[currentKey]
                    MessageBox.Error("按键冲突！`n【" currentKey "】 已经被设置为: 【" prevKeyName "】`n请先修改重复的按键。", "保存失败")
                    Exit
                }
                UsedKeys[currentKey] := keyName
            }
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

        ; 保存到INI
        Config.SaveToIni(SavedObj)
    }

    ; 重置游戏状态
    static ResetGameStateIfNeeded(*) {
        if (Config.GetImportant("AutoExit") == "1" && !WinExist("ahk_exe Arknights.exe")) {
            State.GameHasStarted := false
        }
    }
}