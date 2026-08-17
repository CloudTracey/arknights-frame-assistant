; == 设置操作 ==

; 初始化：订阅设置操作事件（由 bootstrap 调用，避免顶层副作用）
SettingsActionsStart() {
    EventBus.Subscribe("SettingsReset", HandleSettingsReset)
    EventBus.Subscribe("SettingsSave", HandleSettingsSave)
    EventBus.Subscribe("SettingsApply", HandleSettingsApply)
    EventBus.Subscribe("SettingsCancel", HandleSettingsCancel)
    EventBus.Subscribe("SettingsValueChangeRequested", HandleSettingsValueChangeRequested)
}

; 临时处理器：承接热键动作发布的单键设置变更请求（阶段 6 将由 SettingsService 接管）
HandleSettingsValueChangeRequested(data) {
    if (data.key != "AutoBeginPause")
        return
    newValue := data.value
    Config.SetImportant("AutoBeginPause", newValue)
    try {
        GuiManager.SetControlValue("AutoBeginPause", newValue = "1")
    }
    EventBus.Publish("HotkeyOff")
    IniWrite(newValue, Config.IniFile, "Main", "AutoBeginPause")
    Loader.LoadSettings()
    HotkeyService.EnableByTab(HotkeyService.GetActiveTab())
    Logger.Info("Settings", "切换开局自动暂停 → " (newValue = "1" ? "开" : "关"))
    if (newValue = "1") {
        HideTrayTip()
        SetTimer HideTrayTip, 0
        ShowTrayTip("已开启开局自动暂停", "AFA", "Mute")
        SetTimer HideTrayTip, -3000
    } else {
        HideTrayTip()
        SetTimer HideTrayTip, 0
        ShowTrayTip("已关闭开局自动暂停", "AFA", "Mute")
        SetTimer HideTrayTip, -3000
    }
}

; 处理重置按键设置事件
HandleSettingsReset(*) {
    result := MessageBox.Confirm("  确定重置*所有*按键为默认设置吗 ？","重置按键设置")
    if (result == "Yes") {
        EventBus.Publish("HotkeyOff")
        EventBus.Publish("UnsetSwitchKey")
        Config.ResetHotkeyToDefaults()
        EventBus.Publish("GuiUpdateHotkeyControls")
        EventBus.Publish("GuiUpdateCustomControls")
        Saver.SettingsIniWrite()
        Loader.LoadSettings()
        Logger.Info("Settings", "已重置按键并保存默认设置")
        if(HotkeyService.HotkeyState == true) {
            HotkeyService.EnableByTab(HotkeyService.GetActiveTab())
        }
        EventBus.Publish("SetSwitchKey")
        ; 清除GUI的已修改状态
        GuiManager.SetIsModifiedFalse()
        GuiManager.CaptureInitialSnapshot()
    }
}

; 处理保存设置事件
HandleSettingsSave(*) {
    EventBus.Publish("HotkeyOff")
    EventBus.Publish("UnsetSwitchKey")
    Saver.SettingsIniWrite()
    Loader.LoadSettings()
    GuiManager.CommitTabSettings()
    Logger.Info("Settings", "设置已保存并关闭")
    if(HotkeyService.HotkeyState == true) {
        HotkeyService.EnableByTab(HotkeyService.GetActiveTab())
    }
    EventBus.Publish("SetSwitchKey")
    Saver.ResetGameStateIfNeeded()
    EventBus.Publish("GuiHide")
    ; 清除GUI的已修改状态
    GuiManager.SetIsModifiedFalse()
    GuiManager.CaptureInitialSnapshot()
    MessageBox.Info("设置已保存！后续可双击右下角托盘区图标或通过右键菜单打开设置", "保存成功")
}

; 处理应用设置事件
HandleSettingsApply(*) {
    EventBus.Publish("HotkeyOff")
    EventBus.Publish("UnsetSwitchKey")
    Saver.SettingsIniWrite()
    Loader.LoadSettings()
    GuiManager.CommitTabSettings()
    Logger.Info("Settings", "设置已应用")
    if(HotkeyService.HotkeyState == true) {
        HotkeyService.EnableByTab(HotkeyService.GetActiveTab())
    }
    EventBus.Publish("SetSwitchKey")
    Saver.ResetGameStateIfNeeded()
    ; 清除GUI的已修改状态
    GuiManager.SetIsModifiedFalse()
    GuiManager.CaptureInitialSnapshot()
    MessageBox.Info("设置已应用！", "应用成功")
}

; 处理取消设置事件
HandleSettingsCancel(*) {
    Loader.LoadSettings()
    Logger.Info("Settings", "取消设置修改并恢复配置")
    ; 通过事件总线通知GUI恢复显示
    EventBus.Publish("GuiUpdateHotkeyControls")
    EventBus.Publish("GuiUpdateImportantControls")
    EventBus.Publish("GuiUpdateCustomControls")
    ; 清除GUI的已修改状态
    GuiManager.SetIsModifiedFalse()
    GuiManager.CaptureInitialSnapshot()
    ; 通过事件总线通知GUI隐藏
    EventBus.Publish("GuiHide")
}
