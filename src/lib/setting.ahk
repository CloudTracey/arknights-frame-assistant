; == 设置相关 ==
; 从配置文件加载设置
LoadSettings() {
    HotKeySettings["PressPause"] := IniRead(INI_FILE, "Hotkeys", "PressPause", DefaultHotKeySettings["PressPause"])
    HotKeySettings["ReleasePause"] := IniRead(INI_FILE, "Hotkeys", "ReleasePause", DefaultHotKeySettings["ReleasePause"])
    HotKeySettings["GameSpeed"] := IniRead(INI_FILE, "Hotkeys", "GameSpeed", DefaultHotKeySettings["GameSpeed"])
    HotKeySettings["Skill"] := IniRead(INI_FILE, "Hotkeys", "Skill", DefaultHotKeySettings["Skill"])
    HotKeySettings["Retreat"] := IniRead(INI_FILE, "Hotkeys", "Retreat", DefaultHotKeySettings["Retreat"])
    HotKeySettings["PauseSkill"] := IniRead(INI_FILE, "Hotkeys", "PauseSkill", DefaultHotKeySettings["PauseSkill"])
    HotKeySettings["PauseRetreat"] := IniRead(INI_FILE, "Hotkeys", "PauseRetreat", DefaultHotKeySettings["PauseRetreat"])
    HotKeySettings["33ms"] := IniRead(INI_FILE, "Hotkeys", "33ms", DefaultHotKeySettings["33ms"])
    HotKeySettings["166ms"] := IniRead(INI_FILE, "Hotkeys", "166ms", DefaultHotKeySettings["166ms"])
    HotKeySettings["PauseSelect"] := IniRead(INI_FILE, "Hotkeys", "PauseSelect", DefaultHotKeySettings["PauseSelect"])
    HotKeySettings["OneClickSkill"] := IniRead(INI_FILE, "Hotkeys", "OneClickSkill", DefaultHotKeySettings["OneClickSkill"])
    HotKeySettings["OneClickRetreat"] := IniRead(INI_FILE, "Hotkeys", "OneClickRetreat", DefaultHotKeySettings["OneClickRetreat"])
    MainSettings["AutoClose"] := IniRead(INI_FILE, "Main", "AutoClose", DefaultMainSettings["AutoClose"])
    MainSettings["AutoOpen"] := IniRead(INI_FILE, "Main", "AutoOpen", DefaultMainSettings["AutoOpen"])
    MainSettings["Frame"] := IniRead(INI_FILE, "Main", "Frame", DefaultMainSettings["Frame"])
    DelaySetting()
}

; 操作延迟设置
DelaySetting() {
    global Delay
    if (MainSettings["Frame"] == 1) {
        Delay := DelayA
    }
    else if (MainSettings["Frame"] == 2) {
        Delay := DelayB
    }
    else if (MainSettings["Frame"] == 3) {
        Delay := DelayC
    }
}

; 记录热键并写入配置文件
HotkeyIniWrite() {
    if(ModifyHook.InProgress) {
        ModifyHook.Stop()
    }
    SavedObj := MyGui.Submit(0) 
    UsedKeys := Map()
    for keyVar, keyName in KeyNames {
        if (!SavedObj.HasProp(keyVar))
            continue
        currentKey := SavedObj.%keyVar%
        if (currentKey != "") {
            ; 按键冲突提示
            if (UsedKeys.Has(currentKey)) {
                prevKeyName := UsedKeys[currentKey]
                MsgBox("按键冲突！`n[" currentKey "] 已经被设置为: 【" prevKeyName "】`n请先修改重复的按键。", "保存失败", "Icon!")
                Exit
            }
            UsedKeys[currentKey] := keyName
        }
    }
    IniWrite(SavedObj.PressPause,  INI_FILE, "Hotkeys", "PressPause")
    IniWrite(SavedObj.ReleasePause,  INI_FILE, "Hotkeys", "ReleasePause")
    IniWrite(SavedObj.GameSpeed,   INI_FILE, "Hotkeys", "GameSpeed")
    IniWrite(SavedObj.Skill,       INI_FILE, "Hotkeys", "Skill")
    IniWrite(SavedObj.Retreat,     INI_FILE, "Hotkeys", "Retreat")
    IniWrite(SavedObj.PauseSkill,  INI_FILE, "Hotkeys", "PauseSkill")
    IniWrite(SavedObj.PauseRetreat,INI_FILE, "Hotkeys", "PauseRetreat")
    IniWrite(SavedObj.33ms,    INI_FILE, "Hotkeys", "33ms")
    IniWrite(SavedObj.166ms,   INI_FILE, "Hotkeys", "166ms")
    IniWrite(SavedObj.PauseSelect, INI_FILE, "Hotkeys", "PauseSelect")
    IniWrite(SavedObj.OneClickSkill,  INI_FILE, "Hotkeys", "OneClickSkill")
    IniWrite(SavedObj.OneClickRetreat, INI_FILE, "Hotkeys", "OneClickRetreat")
    IniWrite(SavedObj.AutoClose, INI_FILE, "Main", "AutoClose")
    IniWrite(SavedObj.AutoOpen,  INI_FILE, "Main", "AutoOpen")
    IniWrite(SavedObj.Frame,  INI_FILE, "Main", "Frame")
}

; 重置默认设置
SetDefaultSetting() {
    Result := MsgBox("  确定重置按键为默认设置吗 ？","重置按键设置", "YesNo")
    if (Result == "Yes") {
        for key, _ in DefaultHotKeySettings {
                MyGui[key].Value := DefaultHotKeySettings[key]
        }
    }
    HotkeyOff()
    HotkeyIniWrite()
    LoadSettings()
    HotkeyOn()
}

; 保存设置
SaveAndClose() {
    HotkeyOff()
    HotkeyIniWrite()
    LoadSettings()
    HotkeyOn()
    HideGui()
    MsgBox("设置已保存！后续可从右下角托盘区图标右键菜单打开设置", "保存成功", "Iconi")
}

; 应用设置
ApplySettings() {
    HotkeyOff()
    HotkeyIniWrite()
    LoadSettings()
    HotkeyOn()
    MsgBox("设置已应用！", "应用成功")
}

; 取消设置
CancleSetting() {
    for key, _ in HotkeySettings {
        MyGui[key].Value := HotkeySettings[key]
    }
    for key, _ in MainSettings {
        MyGui[key].Value := MainSettings[key]
    }
    HideGui()
}

; 启用热键
HotkeyOn() {
    HotIfWinActive("ahk_exe Arknights.exe") 
    for keyVar, _ in KeyNames {
        if (HotkeySettings[keyVar] != "") {
            Action := "Action" . keyVar
            if (HotkeySettings[keyVar] ~= "^(E|Q|F|G)$") {
                Hotkey(HotkeySettings[keyVar], %Action%, "On")
            }
            else {
                Hotkey("~" HotkeySettings[keyVar], %Action%, "On")
            }
        }
    }
    HotIf
}

; 禁用热键
HotkeyOff() {
    HotIfWinActive("ahk_exe Arknights.exe") 
    for keyVar, _ in KeyNames {
        if (HotkeySettings[keyVar] != "") {
            Action := "Action" . keyVar
            if (HotkeySettings[keyVar] ~= "^(E|Q|F|G)$") {
                Hotkey(HotkeySettings[keyVar], %Action%, "Off")
            }
            else {
                Hotkey("~" HotkeySettings[keyVar], %Action%, "Off")
            }
        }
    }
    HotIf
}

; 自动退出计时器
SetTimer CheckGameStatus, 1000

; 检查游戏状态
CheckGameStatus() {
    global GameHasStarted
    if (MainSettings["AutoClose"] != "1")
        return
    if WinExist("ahk_exe Arknights.exe") {
        GameHasStarted := true
    }
    else {
        if (GameHasStarted == true) {
            ExitApp
        }
    }
}