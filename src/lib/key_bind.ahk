; == 按键绑定 == 
class KeyBinder {
    ; 按键绑定状态
    static ModifyHook := InputHook("L0")
    static LastEditObject := ""
    static OriginalValue := ""
    static ControlObj := ""
    static WaitingModify := false
    static ReleaseKey := ""

    ; 创建Hook
    static CreateHook() {
        ; 创建HookA
        this.ReleaseKey :=  ""
        this.ModifyHook := InputHook("L0")
        this.ModifyHook.VisibleNonText := false
        this.ModifyHook.KeyOpt("{All}", "E")
        this.ModifyHook.KeyOpt("{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}", "-E +N")
        this.ModifyHook.OnKeyUp := (ih, vk, sc) => this.OnKeyUp(ih, vk, sc)
        this.ModifyHook.OnEnd := (*) => this.EndChange(this.ModifyHook.EndMods . this.ReleaseKey . this.ModifyHook.EndKey)
        this.ModifyHook.Start()
    }
    ; 释放Hook
    static StopHook() {
        if(this.ModifyHook.InProgress) {
            this.ModifyHook.OnEnd := ""
            this.ModifyHook.Stop()
            EventBus.Publish("KeyBindFocusSave")
        }
    }

    ; 处理指定按键释放
    static OnKeyUp(ih, vk, sc) {
        KeyBinder.ReleaseKey := GetKeyName(Format("vk{:x}sc{:x}", vk, sc))
        KeyBinder.ReleaseKey := RegExReplace(KeyBinder.ReleaseKey, "i)^L", "<")
        KeyBinder.ReleaseKey := RegExReplace(KeyBinder.ReleaseKey, "i)^R", ">")
        KeyBinder.ReleaseKey := RegExReplace(KeyBinder.ReleaseKey, "i)CONTROL$", "^")
        KeyBinder.ReleaseKey := RegExReplace(KeyBinder.ReleaseKey, "i)ALT$", "!")
        KeyBinder.ReleaseKey := RegExReplace(KeyBinder.ReleaseKey, "i)SHIFT$", "+")
        KeyBinder.ModifyHook.Stop()
    }

    ; 处理设置保存前事件
    static HandleSettingsWillSave(*) {
        KeyBinder.StopHook()
    }

    ; 改绑按键
    static EndChange(Newkey) {
        virtualNewkey := KeyBinder.VirtualNewkeyFormat(Newkey)        ; 在GUI上显示的键值
        realNewkey := KeyBinder.RealNewkeyFormat(Newkey)              ; 触发热键的实际键值
        ; 若没有输入按键
        if(Newkey == "") {
            if(KeyBinder.WaitingModify == true)
                return
            if(KeyBinder.ModifyHook.InProgress) {
                KeyBinder.ModifyHook.Stop()
            }
            KeyBinder.WaitingModify := false
            EventBus.Publish("KeyBindFocusSave")
            return
        }
        ; 若有输入按键且不是鼠标左键
        if(Newkey != "") {
            pureNewkey := RegExReplace(Newkey, "^[~*$!^+#&<>()]+")
            if(pureNewkey == "Escape" OR pureNewkey == "Backspace") {
                KeyBinder.ControlObj.Value := ""
                Config.SetHotkey(KeyBinder.ControlObj.Name, "")
            }
            else if(pureNewkey == "LWin" OR pureNewkey == "RWin") {
                KeyBinder.LastEditObject.Value := KeyBinder.OriginalValue
            }
            else {
                KeyBinder.ControlObj.Value := virtualNewkey ; 让GUI显示人能读的东西
                if(KeyBinder.ControlObj.Name == "SwitchHotkey")
                    Config.SetCustom(KeyBinder.ControlObj.Name, realNewkey)
                else 
                    Config.SetHotkey(KeyBinder.ControlObj.Name, realNewkey) ; 把人不能读也不该读的东西丢给内存
            }
        }
        KeyBinder.LastEditObject := ""
        KeyBinder.WaitingModify := false
        KeyBinder.ReleaseKey :=  ""
        KeyBinder.StopHook()
        EventBus.Publish("KeyBindFocusSave")
    }

    ; 格式化显示键值
    static VirtualNewkeyFormat(value) {
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
        return value
    }
    ; 格式化实际键值
    static RealNewkeyFormat(value) {
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

; 在设置窗口监听鼠标左键
OnMessage(0x0201, WM_LBUTTONDOWN)

; 左键点击判定
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    MouseGetPos ,,, &CtrlHwnd, 2 ; 获取鼠标下的控件ID
    ; 获取被点击的控件对象
    try KeyBinder.ControlObj := GuiCtrlFromHwnd(CtrlHwnd)
    catch
        KeyBinder.ControlObj := ""
    ; -- 如果点的是 Edit 控件 --
    if (KeyBinder.ControlObj && KeyBinder.ControlObj.Type == "Edit") {
        ; 排除非按键绑定输入框
        if (KeyBinder.ControlObj.Name == "GitHubToken" || KeyBinder.ControlObj.Name == "GamePath" || KeyBinder.ControlObj.Name == "SkillAndRetreatDelay") {
            return
        }
        ; 若为首次点击Edit控件
        if(KeyBinder.LastEditObject == "") {
            ; 记录点击前的控件值，并修改值，以及记录本次点击
            KeyBinder.OriginalValue := KeyBinder.ControlObj.Value ; OriginalValue为原先值
            KeyBinder.ControlObj.Value := "请按键"
            KeyBinder.LastEditObject := KeyBinder.ControlObj
            KeyBinder.WaitingModify := true
            ; 释放可能存在的Hook
            KeyBinder.StopHook()
            ; 配置 Hook
            KeyBinder.CreateHook()
        }
        ; 否则为连续第二次点击edit控件
        else {
            ; 如果两次点击的是同一edit控件
            if(KeyBinder.ControlObj == KeyBinder.LastEditObject) {
                return ; 无事发生
            }
            ; 如果两次点击的不是同一edit控件
            else {
                ; 恢复上一次点击的edit控件的值
                KeyBinder.LastEditObject.Value := KeyBinder.OriginalValue
                KeyBinder.OriginalValue := KeyBinder.ControlObj.Value ; OriginalValue为原先值
                KeyBinder.ControlObj.Value := "请按键"
                KeyBinder.LastEditObject := KeyBinder.ControlObj
                ; 释放可能存在的Hook
                KeyBinder.StopHook()
                ; 配置Hook
                KeyBinder.CreateHook()
            }
        }
        return
    }
    ; -- 点击的是其他地方 --
    else {
        ; 如果上次点击的是edit控件
        if(KeyBinder.LastEditObject != "") {
            ; 将上次点击的edit控件还原至点击前的状态
            KeyBinder.LastEditObject.Value := KeyBinder.OriginalValue
            KeyBinder.LastEditObject := ""
            KeyBinder.WaitingModify := false
            ; 释放可能存在的Hook
            KeyBinder.StopHook()
        }
        return
    }
    ; 无事发生
    return
}

; 窗口活动监控
WatchActiveWindow(){
    ; 当窗口失去焦点时
    if(WinActive(State.GuiWindowName) == 0) {
        ; 如果上次点击的是edit控件
        if(KeyBinder.LastEditObject != "") {
            ; 将上次点击的edit控件还原至点击前的状态
            KeyBinder.LastEditObject.Value := KeyBinder.OriginalValue
            KeyBinder.LastEditObject := ""
            KeyBinder.WaitingModify := false
            ; 释放可能存在的Hook
            KeyBinder.StopHook()
            EventBus.Publish("KeyBindFocusSave")
        }
    }
}

; 订阅设置保存前事件
EventBus.Subscribe("SettingsWillSave", KeyBinder.HandleSettingsWillSave)

; 鼠标录制
#HotIf KeyBinder.WaitingModify
*RButton::
*MButton::
*XButton1::
*XButton2::
*WheelUp::
*WheelDown::
{
    pureKey := RegExReplace(A_ThisHotkey, "^[~*$!^+#&<>()]+")
    KeyBinder.ModifyHook.OnEnd := (*) => KeyBinder.EndChange(KeyBinder.ModifyHook.EndMods . pureKey)
    KeyBinder.ModifyHook.Stop()
}
; 避免触发GUI菜单导致卡死
~LAlt::
~RAlt::
{
    Send "{Blind}{vkE8}"
}
#HotIf
