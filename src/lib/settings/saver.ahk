; == 设置保存器 ==

; 记录热键并写入配置文件
HotkeyIniWrite() {
    EventBus.Publish("SettingsWillSave")
    SavedObj := GuiManager.Submit()
    UsedKeys := Map()
    for keyVar, keyName in Constants.KeyNames {
        if (!SavedObj.HasProp(keyVar))
            continue
        currentKey := SavedObj.%keyVar%
        if (currentKey != "") {
            ; 按键冲突提示
            if (UsedKeys.Has(currentKey)) {
                prevKeyName := UsedKeys[currentKey]
                MsgBox("按键冲突！`n【" currentKey "】 已经被设置为: 【" prevKeyName "】`n请先修改重复的按键。", "保存失败", "Icon!")
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
                result := MsgBox("GitHub Token验证失败：" tokenResult.message "`n`n是否仍要保存此Token？", "Token验证失败", "YesNo Icon!")
                if (result = "No") {
                    Exit
                }
            } else {
                ; Token有效，更新验证状态
                VersionChecker.TokenValidated := true
                MsgBox("GitHub Token验证成功！`n用户: " tokenResult.username "`nAPI配额: " tokenResult.rateLimit, "Token有效", "Iconi")
            }
        }
    }
    
    ; 保存到INI
    Config.SaveToIni(SavedObj)
}

; 重置游戏状态
ResetGameStateIfNeeded() {
    if (Config.GetImportant("AutoExit") == "1" && !WinExist("ahk_exe Arknights.exe")) {
        State.GameHasStarted := false
    }
}
