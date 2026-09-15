; == 热键键值格式化工具 ==
; base 层热键键值格式化工具，供 UI 与 core 共用。

class KeyFormat {
    ; 格式化显示键值
    static VirtualNewkeyFormat(value) {
        if(value == "")
            return

        ; 提取CTRL、SHIFT、ALT修饰符
        hasLCTRL := false
        hasLSHIFT := false
        hasLALT := false
        hasRCTRL := false
        hasRSHIFT := false
        hasRALT := false
        hasCTRL := false
        hasSHIFT := false
        hasALT := false
        hasMainkey := false
        mainkey := ""

        ; 先从 AHK 内部格式中移除带侧别和通用修饰符，避免把 +c 直接替换成
        ; SHIFTC 而丢失显示分隔符。命名键（如 CtrlBreak）不含符号，不会被误拆。
        if InStr(value, "<^")
            hasLCTRL := true, value := StrReplace(value, "<^", "")
        if InStr(value, ">^")
            hasRCTRL := true, value := StrReplace(value, ">^", "")
        if InStr(value, "<+")
            hasLSHIFT := true, value := StrReplace(value, "<+", "")
        if InStr(value, ">+")
            hasRSHIFT := true, value := StrReplace(value, ">+", "")
        if InStr(value, "<!")
            hasLALT := true, value := StrReplace(value, "<!", "")
        if InStr(value, ">!")
            hasRALT := true, value := StrReplace(value, ">!", "")
        if InStr(value, "^")
            hasCTRL := true, value := StrReplace(value, "^", "")
        if InStr(value, "+")
            hasSHIFT := true, value := StrReplace(value, "+", "")
        if InStr(value, "!")
            hasALT := true, value := StrReplace(value, "!", "")

        ; 修饰键单独绑定时使用 <SHIFT/>SHIFT 等长名称，转成显示侧别后复用下方识别。
        value := RegExReplace(value, "<", "L")
        value := RegExReplace(value, ">", "R")

        ; 检查是否包含各修饰符
        if RegExMatch(value, "i)LCTRL") {
            hasLCTRL := true
            value := RegExReplace(value, "i)LCTRL", "")
        }
        if RegExMatch(value, "i)LSHIFT") {
            hasLSHIFT := true
            value := RegExReplace(value, "i)LSHIFT", "")
        }
        if RegExMatch(value, "i)LALT") {
            hasLALT := true
            value := RegExReplace(value, "i)LALT", "")
        }
        if RegExMatch(value, "i)RCTRL") {
            hasRCTRL := true
            value := RegExReplace(value, "i)RCTRL", "")
        }
        if RegExMatch(value, "i)RSHIFT") {
            hasRSHIFT := true
            value := RegExReplace(value, "i)RSHIFT", "")
        }
        if RegExMatch(value, "i)RALT") {
            hasRALT := true
            value := RegExReplace(value, "i)RALT", "")
        }
        if value != "" {
            hasMainkey := true
            mainkey := value
            value := ""
        }

        ; 按CTRL > SHIFT > ALT > Mainkey顺序排列
        if hasLCTRL
            value := value . "LCTRL+"
        if hasRCTRL
            value := value . "RCTRL+"
        if hasCTRL
            value := value . "CTRL+"
        if hasLSHIFT
            value := value . "LSHIFT+"
        if hasRSHIFT
            value := value . "RSHIFT+"
        if hasSHIFT
            value := value . "SHIFT+"
        if hasLALT
            value := value . "LALT+"
        if hasRALT
            value := value . "RALT+"
        if hasALT
            value := value . "ALT+"
        if hasMainkey
            value := value . mainkey

        ; 删除末尾的+
        value := RegExReplace(value, "\+$", "")

        ; 将鼠标键位转为可读
        value := RegExReplace(value, "i)XBUTTON1", I18n.T("鼠标后侧键"))
        value := RegExReplace(value, "i)XBUTTON2", I18n.T("鼠标前侧键"))
        value := RegExReplace(value, "i)MButton", I18n.T("鼠标中键"))
        value := RegExReplace(value, "i)RBUTTON", I18n.T("鼠标右键"))
        value := RegExReplace(value, "i)WHEELDOWN", I18n.T("滚轮向后"))
        value := RegExReplace(value, "i)WHEELUP", I18n.T("滚轮向前"))
        value := RegExReplace(value, "i)WHEELLEFT", I18n.T("滚轮向左"))
        value := RegExReplace(value, "i)WHEELRIGHT", I18n.T("滚轮向右"))
        value := RegExReplace(value, "i)ESCAPE", I18n.T("ESC"))
        return value
    }

    ; 格式化实际键值
    static RealNewkeyFormat(value) {
        if(value == "")
            return
        ; 提取CTRL、SHIFT、ALT修饰符
        hasLCTRL := false
        hasLSHIFT := false
        hasLALT := false
        hasRCTRL := false
        hasRSHIFT := false
        hasRALT := false
        hasMainkey := false
        mainkey := ""

        ; 检查是否包含各修饰符
        if RegExMatch(value, "<\^") {
            hasLCTRL := true
            value := RegExReplace(value, "<\^", "")
        }
        if RegExMatch(value, "<\+") {
            hasLSHIFT := true
            value := RegExReplace(value, "<\+", "")
        }
        if RegExMatch(value, "<!") {
            hasLALT := true
            value := RegExReplace(value, "<!", "")
        }
        if RegExMatch(value, ">\^") {
            hasRCTRL := true
            value := RegExReplace(value, ">\^", "")
        }
        if RegExMatch(value, ">\+") {
            hasRSHIFT := true
            value := RegExReplace(value, ">\+", "")
        }
        if RegExMatch(value, ">!") {
            hasRALT := true
            value := RegExReplace(value, ">!", "")
        }
        if RegExMatch(value, "i).*") {
            hasMainkey := true
            mainkey := value
            value := RegExReplace(value, "i).*", "")
        }

        ; 按CTRL > SHIFT > ALT > Mainkey顺序排列
        if hasLCTRL
            value := value . "<^"
        if hasRCTRL
            value := value . ">^"
        if hasLSHIFT
            value := value . "<+"
        if hasRSHIFT
            value := value . ">+"
        if hasLALT
            value := value . "<!"
        if hasRALT
            value := value . ">!"
        if hasMainkey
            value := value . mainkey

        ; 将末尾的符号换成对应键位
        if RegExMatch(value, "!$")
            return RegExReplace(value, "!$", "ALT")
        if RegExMatch(value, "\^$")
            return RegExReplace(value, "\^$", "CTRL")
        if RegExMatch(value, "\+$")
            return RegExReplace(value, "\+$", "SHIFT")
        return value
    }
}
