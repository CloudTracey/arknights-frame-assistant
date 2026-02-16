; == 设置保存器 ==
; 负责保存设置到配置文件及相关状态管理

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
    
    ; 保存到INI
    Config.SaveToIni(SavedObj)
}

; 重置游戏状态
ResetGameStateIfNeeded() {
    if (Config.GetImportant("AutoClose") == "1" && !WinExist("ahk_exe Arknights.exe")) {
        State.GameHasStarted := false
    }
}
