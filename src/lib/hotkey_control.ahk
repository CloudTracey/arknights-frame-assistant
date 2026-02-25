; == 热键控制 ==
; 订阅热键事件
EventBus.Subscribe("HotkeyOff", HotkeyOff)
EventBus.Subscribe("HotkeyOn", HotkeyOn)

; 热键回调函数映射表
ActionCallbacks := Map(
    "PressPause", ActionPressPause,
    "ReleasePause", ActionReleasePause,
    "GameSpeed", ActionGameSpeed,
    "33ms", Action33ms,
    "166ms", Action166ms,
    "PauseSelect", ActionPauseSelect,
    "Skill", ActionSkill,
    "Retreat", ActionRetreat,
    "OneClickSkill", ActionOneClickSkill,
    "OneClickRetreat", ActionOneClickRetreat,
    "PauseSkill", ActionPauseSkill,
    "PauseRetreat", ActionPauseRetreat,
    "LButtonClick", LButtonClick
)

; 启用热键
HotkeyOn(*) {
    HotIfWinActive("ahk_exe Arknights.exe")
    for keyVar, _ in Constants.KeyNames {
        hotkeyValue := Config.GetHotkey(keyVar)
        if (hotkeyValue != "" && ActionCallbacks.Has(keyVar)) {
            callback := ActionCallbacks[keyVar]
            if (hotkeyValue ~= "i)^(E|Q|F|G|RButton|MButton)$") {
                Hotkey(hotkeyValue, callback, "On")
            }
            else {
                Hotkey("~" hotkeyValue, callback, "On")
            }
        }
    }
    HotIf
}

; 禁用热键
HotkeyOff(*) {
    HotIfWinActive("ahk_exe Arknights.exe")
    for keyVar, _ in Constants.KeyNames {
        hotkeyValue := Config.GetHotkey(keyVar)
        if (hotkeyValue != "" && ActionCallbacks.Has(keyVar)) {
            callback := ActionCallbacks[keyVar]
            if (hotkeyValue ~= "i)^(E|Q|F|G|RButton|MButton)$") {
                Hotkey(hotkeyValue, callback, "Off")
            }
            else {
                Hotkey("~" hotkeyValue, callback, "Off")
            }
        }
    }
    HotIf
}