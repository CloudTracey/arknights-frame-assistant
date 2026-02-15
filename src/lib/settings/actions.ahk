; == 设置操作 ==
; 负责处理用户触发的设置操作（重置、保存、应用、取消）

; 重置默认设置
SetDefaultSetting() {
    Result := MsgBox("  确定重置按键为默认设置吗 ？","重置按键设置", "YesNo")
    if (Result == "Yes") {
        Config.ResetToDefaults()
        ; 重置按键设置显示
        for key, value in Config.AllHotkeys {
            GuiManager.SetControlValue(key, value)
        }
        ; 同时也重置重要设置显示
        for key, value in Config.AllImportant {
            GuiManager.SetControlValue(key, value)
        }
        ; 更新警告文本显示（根据Frame值）
        GuiManager.UpdateWarning()
        HotkeyOff()
        HotkeyIniWrite()
        LoadSettings()
        ResetGameStateIfNeeded()
        HotkeyOn()
    }
}

; 保存设置
SaveAndClose() {
    HotkeyOff()
    HotkeyIniWrite()
    LoadSettings()
    ResetGameStateIfNeeded()
    HotkeyOn()
    GuiManager.Hide()
    MsgBox("设置已保存！后续可从右下角托盘区图标右键菜单打开设置", "保存成功", "Iconi")
}

; 应用设置
ApplySettings() {
    HotkeyOff()
    HotkeyIniWrite()
    LoadSettings()
    ResetGameStateIfNeeded()
    HotkeyOn()
    MsgBox("设置已应用！", "应用成功")
}

; 取消设置
CancleSetting() {
    ; 恢复按键设置
    for key, value in Config.AllHotkeys {
        GuiManager.SetControlValue(key, value)
    }
    ; 恢复重要设置
    for key, value in Config.AllImportant {
        GuiManager.SetControlValue(key, value)
    }
    GuiManager.Hide()
}
