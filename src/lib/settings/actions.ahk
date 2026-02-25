; == 设置操作 ==

; 初始化：订阅事件
EventBus.Subscribe("SettingsReset", HandleSettingsReset)
EventBus.Subscribe("SettingsSave", HandleSettingsSave)
EventBus.Subscribe("SettingsApply", HandleSettingsApply)
EventBus.Subscribe("SettingsCancel", HandleSettingsCancel)

; 处理重置按键设置事件
HandleSettingsReset(*) {
    Result := MsgBox("  确定重置按键为默认设置吗 ？","重置按键设置", "YesNo")
    if (Result == "Yes") {
        EventBus.Publish("HotkeyOff")
        Config.ResetHotkeyToDefaults()
        EventBus.Publish("GuiUpdateHotkeyControls")
        Saver.SettingsIniWrite()
        Loader.LoadSettings()
        EventBus.Publish("HotkeyOn")
    }
}

; 处理保存设置事件
HandleSettingsSave(*) {
    EventBus.Publish("HotkeyOff")
    Saver.SettingsIniWrite()
    Loader.LoadSettings()
    EventBus.Publish("HotkeyOn")
    Saver.ResetGameStateIfNeeded()
    EventBus.Publish("GuiHide")
    MsgBox("设置已保存！后续可从右下角托盘区图标右键菜单打开设置", "保存成功", "Iconi")
}

; 处理应用设置事件
HandleSettingsApply(*) {
    EventBus.Publish("HotkeyOff")
    Saver.SettingsIniWrite()
    Loader.LoadSettings()
    EventBus.Publish("HotkeyOn")
    Saver.ResetGameStateIfNeeded()
    MsgBox("设置已应用！", "应用成功")
}

; 处理取消设置事件
HandleSettingsCancel(*) {
    ; 通过事件总线通知GUI恢复显示
    EventBus.Publish("GuiUpdateHotkeyControls")
    EventBus.Publish("GuiUpdateSettingsControls")
    ; 通过事件总线通知GUI隐藏
    EventBus.Publish("GuiHide")
}
