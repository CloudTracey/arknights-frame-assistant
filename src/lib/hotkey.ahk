; == 热键控制 ==
; 启用热键
HotkeyOn() {
    HotIfWinActive("ahk_exe Arknights.exe") 
    for keyVar, _ in Constants.KeyNames {
        hotkeyValue := Config.GetHotkey(keyVar)
        if (hotkeyValue != "") {
            Action := "Action" . keyVar
            if (hotkeyValue ~= "^(E|Q|F|G)$") {
                Hotkey(hotkeyValue, %Action%, "On")
            }
            else {
                Hotkey("~" hotkeyValue, %Action%, "On")
            }
        }
    }
    HotIf
}

; 禁用热键
HotkeyOff() {
    HotIfWinActive("ahk_exe Arknights.exe") 
    for keyVar, _ in Constants.KeyNames {
        hotkeyValue := Config.GetHotkey(keyVar)
        if (hotkeyValue != "") {
            Action := "Action" . keyVar
            if (hotkeyValue ~= "^(E|Q|F|G)$") {
                Hotkey(hotkeyValue, %Action%, "Off")
            }
            else {
                Hotkey("~" hotkeyValue, %Action%, "Off")
            }
        }
    }
    HotIf
}
