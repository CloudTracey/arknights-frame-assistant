; == 热键控制 ==
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
