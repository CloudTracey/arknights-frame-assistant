; == 按键绑定 == 
; 在设置窗口监听鼠标左键
OnMessage(0x0201, WM_LBUTTONDOWN)

; 创建Hook
CreateHook() {
    State.ModifyHook := InputHook("L0")
    State.ModifyHook.VisibleNonText := false
    State.ModifyHook.KeyOpt("{All}", "E")
    State.ModifyHook.KeyOpt("{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}", "E")
    State.ModifyHook.OnEnd := (*) => EndChange(State.ModifyHook.EndKey)
    State.ModifyHook.Start()
}
; 释放Hook
StopHook() {
    if(State.ModifyHook.InProgress) {
        State.ModifyHook.Stop()
    }
}

; 订阅设置保存前事件
SubscribeKeyBindEvents() {
    EventBus.Subscribe("SettingsWillSave", HandleSettingsWillSave)
}

; 处理设置保存前事件
HandleSettingsWillSave(*) {
    StopHook()
}

; 左键点击判定
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    MouseGetPos ,,, &CtrlHwnd, 2 ; 获取鼠标下的控件ID
    ; 获取被点击的控件对象
    try State.ControlObj := GuiCtrlFromHwnd(CtrlHwnd)
    catch
        State.ControlObj := ""
    ; -- 如果点的是 Edit 控件 --
    if (State.ControlObj && State.ControlObj.Type == "Edit") {
        ; 排除 GitHubToken 输入框（该控件用于文本输入，不是按键绑定）
        if (State.ControlObj.Name == "GitHubToken") {
            return
        }
        ; 若为首次点击Edit控件
        if(State.LastEditObject == "") {
            ; 记录点击前的控件值，并修改值，以及记录本次点击
            State.OriginalValue := State.ControlObj.Value ; OriginalValue为原先值
            State.ControlObj.Value := "请按键"
            State.LastEditObject := State.ControlObj
            State.WaitingModify := true
            ; 释放可能存在的Hook
            StopHook()
            ; 配置 Hook
            CreateHook()
        }
        ; 否则为连续第二次点击edit控件
        else {
            ; 如果两次点击的是同一edit控件
            if(State.ControlObj == State.LastEditObject) {
                return ; 无事发生
            }
            ; 如果两次点击的不是同一edit控件
            else {
                ; 恢复上一次点击的edit控件的值
                State.LastEditObject.Value := State.OriginalValue
                State.OriginalValue := State.ControlObj.Value ; OriginalValue为原先值
                State.ControlObj.Value := "请按键"
                State.LastEditObject := State.ControlObj
                ; 释放可能存在的Hook
                StopHook()
                ; 配置Hook
                CreateHook()
            }
        }
        return
    }
    ; -- 点击的是其他地方 --
    else {
        ; 如果上次点击的是edit控件
        if(State.LastEditObject != "") {
            ; 将上次点击的edit控件还原至点击前的状态
            State.LastEditObject.Value := State.OriginalValue
            State.LastEditObject := ""
            State.WaitingModify := false
            ; 释放可能存在的Hook
            StopHook()
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
        if(State.LastEditObject != "") {
            ; 将上次点击的edit控件还原至点击前的状态
            State.LastEditObject.Value := State.OriginalValue
            State.LastEditObject := ""
            State.WaitingModify := false
            ; 释放可能存在的Hook
            StopHook()
            EventBus.Publish("KeyBindFocusSave")
        }
    }
}

; 改绑按键
EndChange(Newkey) {
    ; 若没有输入按键
    if(Newkey == "") {
        if(State.WaitingModify == true)
            return
        if(State.ModifyHook.InProgress) {
            State.ModifyHook.Stop()
        }
        State.WaitingModify := false
        EventBus.Publish("KeyBindFocusSave")
        return
    }
    ; 若有输入按键且不是鼠标左键
    if(Newkey != "") {
        if(Newkey == "Escape" OR Newkey == "Backspace") {
            State.ControlObj.Value := ""
        }
        else if(Newkey == "LWin" OR Newkey == "RWin") {
            State.LastEditObject.Value := State.OriginalValue
        }
        else {
            State.ControlObj.Value := Newkey
        }
    }
    State.LastEditObject := ""
    State.WaitingModify := false
    StopHook()
    EventBus.Publish("KeyBindFocusSave")
}

; 鼠标录制
#HotIf State.WaitingModify
RButton::
MButton::
XButton1::
XButton2::
WheelUp::
WheelDown::
{
    EndChange(A_ThisHotkey)
}
#HotIf
