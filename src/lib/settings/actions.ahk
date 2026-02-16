; == 设置操作 ==
; 负责处理用户触发的设置操作（重置、保存、应用、取消）
; 通过事件总线接收事件，解耦与GUI的直接依赖

; 初始化：订阅事件
SubscribeSettingEvents() {
    EventBus.Subscribe("SettingsReset", HandleSettingsReset)
    EventBus.Subscribe("SettingsSave", HandleSettingsSave)
    EventBus.Subscribe("SettingsApply", HandleSettingsApply)
    EventBus.Subscribe("SettingsCancel", HandleSettingsCancel)
}

; 处理重置默认设置事件
HandleSettingsReset(*) {
    Result := MsgBox("  确定重置按键为默认设置吗 ？","重置按键设置", "YesNo")
    if (Result == "Yes") {
        Config.ResetToDefaults()
        EventBus.Publish("GuiUpdateControls")
        EventBus.Publish("HotkeyReload")
    }
}

; 处理保存设置事件
HandleSettingsSave(*) {
    EventBus.Publish("HotkeyReload")
    EventBus.Publish("GuiHide")
    MsgBox("设置已保存！后续可从右下角托盘区图标右键菜单打开设置", "保存成功", "Iconi")
}

; 处理应用设置事件
HandleSettingsApply(*) {
    EventBus.Publish("HotkeyReload")
    MsgBox("设置已应用！", "应用成功")
}

; 处理取消设置事件
HandleSettingsCancel(*) {
    ; 通过事件总线通知GUI恢复显示
    EventBus.Publish("GuiUpdateControls")
    ; 通过事件总线通知GUI隐藏
    EventBus.Publish("GuiHide")
}
