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
            EventBus.Publish("KeyBindFocusCancel")
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
        virtualNewkey := KeyFormat.VirtualNewkeyFormat(Newkey)        ; 在GUI上显示的键值
        realNewkey := KeyFormat.RealNewkeyFormat(Newkey)              ; 触发热键的实际键值
        ; 若没有输入按键
        if(Newkey == "") {
            if(KeyBinder.WaitingModify == true)
                return
            if(KeyBinder.ModifyHook.InProgress) {
                KeyBinder.ModifyHook.Stop()
            }
            KeyBinder.WaitingModify := false
            EventBus.Publish("KeyBindFocusCancel")
            return
        }
        ; 若有输入按键且不是鼠标左键
        if(Newkey != "") {
            pureNewkey := RegExReplace(Newkey, "^[~*$!^+#&<>()]+")
            if(pureNewkey == "Backspace" || pureNewkey == "Delete") {
                Logger.Debug("KeyBind", "清除按键：" KeyBinder.ControlObj.Name)
                KeyBinder.ControlObj.Value := ""
                if(KeyBinder.ControlObj.Name == "SwitchHotkey")
                    Config.SetCustom(KeyBinder.ControlObj.Name, "")
                else
                    Config.SetHotkey(KeyBinder.ControlObj.Name, "")
                KeyBinder.NotifyBindingChanged(KeyBinder.ControlObj.Name)
            }
            else if(pureNewkey == "LWin" OR pureNewkey == "RWin") {
                KeyBinder.LastEditObject.Value := KeyBinder.OriginalValue
            }
            else {
                Logger.Debug("KeyBind", "改键：" KeyBinder.ControlObj.Name " → " realNewkey)
                KeyBinder.ControlObj.Value := virtualNewkey ; 让GUI显示人能读的东西
                if(KeyBinder.ControlObj.Name == "SwitchHotkey")
                    Config.SetCustom(KeyBinder.ControlObj.Name, realNewkey)
                else
                    Config.SetHotkey(KeyBinder.ControlObj.Name, realNewkey) ; 把人不能读也不该读的东西丢给内存
                KeyBinder.NotifyBindingChanged(KeyBinder.ControlObj.Name)
            }
        }
        KeyBinder.LastEditObject := ""
        KeyBinder.WaitingModify := false
        KeyBinder.ReleaseKey :=  ""
        KeyBinder.StopHook()
        EventBus.Publish("KeyBindFocusCancel")
    }

    ; 通知 GUI 重新计算热键冲突，并更新修改状态。
    static NotifyBindingChanged(controlName) {
        GuiManager.TrackChange(controlName)
        EventBus.Publish("HotkeyBindingsChanged")
    }

    ; 启动按键绑定：注册窗口鼠标监听、设置保存前订阅与录制热键（原为文件末尾顶层副作用）
    static Start() {
        OnMessage(0x0201, WM_LBUTTONDOWN)
        EventBus.Subscribe("SettingsWillSave", KeyBinder.HandleSettingsWillSave)
        HotIf((*) => KeyBinder.WaitingModify)
        Hotkey("*RButton", KeyBinder.HandleModifyMouseHotkey.Bind(KeyBinder), "On")
        Hotkey("*MButton", KeyBinder.HandleModifyMouseHotkey.Bind(KeyBinder), "On")
        Hotkey("*XButton1", KeyBinder.HandleModifyMouseHotkey.Bind(KeyBinder), "On")
        Hotkey("*XButton2", KeyBinder.HandleModifyMouseHotkey.Bind(KeyBinder), "On")
        Hotkey("*WheelUp", KeyBinder.HandleModifyMouseHotkey.Bind(KeyBinder), "On")
        Hotkey("*WheelDown", KeyBinder.HandleModifyMouseHotkey.Bind(KeyBinder), "On")
        Hotkey("~LAlt", KeyBinder.HandleModifyAlt.Bind(KeyBinder), "On")
        Hotkey("~RAlt", KeyBinder.HandleModifyAlt.Bind(KeyBinder), "On")
        HotIf
    }

    ; 鼠标录制热键回调（原 #HotIf 块内的鼠标键/滚轮处理）
    static HandleModifyMouseHotkey(ThisHotkey) {
        pureKey := RegExReplace(ThisHotkey, "^[~*$!^+#&<>()]+")
        KeyBinder.ModifyHook.OnEnd := (*) => KeyBinder.EndChange(KeyBinder.ModifyHook.EndMods . pureKey)
        KeyBinder.ModifyHook.Stop()
    }

    ; 避免触发 GUI 菜单导致卡死（原 ~LAlt/~RAlt 热键）
    static HandleModifyAlt(ThisHotkey) {
        Send "{Blind}{vkE8}"
    }
}


; 左键点击判定
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    MouseGetPos ,,, &CtrlHwnd, 2 ; 获取鼠标下的控件ID
    ; 获取被点击的控件对象
    try KeyBinder.ControlObj := GuiCtrlFromHwnd(CtrlHwnd)
    catch
        KeyBinder.ControlObj := ""
    ; -- 如果点的是 Edit 控件 --
    if (KeyBinder.ControlObj && KeyBinder.ControlObj.Type == "Edit") {
        ; 仅处理设置窗口内的 Edit 控件，排除更新弹窗、更新公告弹窗等
        try {
            if (GuiManager.MainGui = "" || KeyBinder.ControlObj.Gui.Hwnd != GuiManager.MainGui.Hwnd)
                return
        }
        ; 排除非按键绑定输入框（使用Set查找，新增时只需加一行）
        static nonKeybindEdits := Map(
            "GitHubToken", 1,
            "GamePath", 1,
            "ClickDelay", 1,
            "FrameSkip16msDelay", 1,
            "FrameSkip33msDelay", 1,
            "FrameSkip166msDelay", 1
        )
        if nonKeybindEdits.Has(KeyBinder.ControlObj.Name) {
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
        ; 点击非Edit区域时聚焦取消按钮，取消普通Edit控件的选中状态（MainGui 未初始化时不处理）
        if (GuiManager.MainGui != "" && hwnd = GuiManager.MainGui.Hwnd)
            GuiManager.FocusCancelButton()
        return
    }
    ; 无事发生
    return
}

; 窗口活动监控
WatchActiveWindow(){
    ; 当窗口失去焦点时
    if(WinActive("ahk_id " GuiManager.MainGui.Hwnd) == 0) {
        ; 如果上次点击的是edit控件
        if(KeyBinder.LastEditObject != "") {
            ; 将上次点击的edit控件还原至点击前的状态
            KeyBinder.LastEditObject.Value := KeyBinder.OriginalValue
            KeyBinder.LastEditObject := ""
            KeyBinder.WaitingModify := false
            ; 释放可能存在的Hook
            KeyBinder.StopHook()
            EventBus.Publish("KeyBindFocusCancel")
        }
    }
}

