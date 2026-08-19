; == 热键键值格式化工具 ==
; base 层热键键值格式化工具，供 UI 与 core 共用。

class KeyFormat {
    ; 格式化显示键值
    static VirtualNewkeyFormat(value) {
        if(value == "")
            return
        ; 将<替换为L，>替换为R
        value := RegExReplace(value, "<", "L")
        value := RegExReplace(value, ">", "R")

        ; 将修饰符!^+替换为完整名称
        value := RegExReplace(value, "!", "ALT")
        value := RegExReplace(value, "\^", "CTRL")
        value := RegExReplace(value, "\+", "SHIFT")

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
        if RegExMatch(value, "i).*") {
            hasMainkey := true
            mainkey := value
            value := RegExReplace(value, "i).*", "")
        }

        ; 按CTRL > SHIFT > ALT > Mainkey顺序排列
        if hasLCTRL
            value := value . "LCTRL+"
        if hasRCTRL
            value := value . "RCTRL+"
        if hasLSHIFT
            value := value . "LSHIFT+"
        if hasRSHIFT
            value := value . "RSHIFT+"
        if hasLALT
            value := value . "LALT+"
        if hasRALT
            value := value . "RALT+"
        if hasMainkey
            value := value . mainkey

        ; 删除末尾的+
        value := RegExReplace(value, "\+$", "")

        ; 将鼠标键位转为可读
        value := RegExReplace(value, "i)XBUTTON1", "鼠标后侧键")
        value := RegExReplace(value, "i)XBUTTON2", "鼠标前侧键")
        value := RegExReplace(value, "i)MButton", "鼠标中键")
        value := RegExReplace(value, "i)RBUTTON", "鼠标右键")
        value := RegExReplace(value, "i)WHEELDOWN", "滚轮向后")
        value := RegExReplace(value, "i)WHEELUP", "滚轮向前")
        value := RegExReplace(value, "i)WHEELLEFT", "滚轮向左")
        value := RegExReplace(value, "i)WHEELRIGHT", "滚轮向右")
        value := RegExReplace(value, "i)ESCAPE", "ESC")
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
