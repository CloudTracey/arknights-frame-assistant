; == 按键绑定 == 
; 写的什么屎山
; 在设置窗口监听鼠标左键
OnMessage(0x0201, WM_LBUTTONDOWN)

; 创建Hook
CreateHook() {
    global ModifyHook
    ModifyHook := InputHook("L0")
    ModifyHook.VisibleNonText := false
    ModifyHook.KeyOpt("{All}", "E")
    ModifyHook.KeyOpt("{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}", "E")
    ModifyHook.OnEnd := (*) => EndChange(ModifyHook.EndKey)
    ModifyHook.Start()
}
; 释放Hook
StopHook() {
    global ModifyHook
    if(ModifyHook.InProgress) {
        ModifyHook.Stop()
    }
}

; 左键点击判定
WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) {
    global LastEditObject, OriginalValue, ModifyHook, ControlObj, WaitingModify
    MouseGetPos ,,, &CtrlHwnd, 2 ; 获取鼠标下的控件ID
    ; 获取被点击的控件对象
    try ControlObj := GuiCtrlFromHwnd(CtrlHwnd)
    catch
        ControlObj := ""
    ; -- 如果点的是 Edit 控件 --
    if (ControlObj && ControlObj.Type == "Edit") {
        ; 若为首次点击Edit控件
        if(LastEditObject == "") {
            ; 记录点击前的控件值，并修改值，以及记录本次点击
            OriginalValue := ControlObj.Value ; OriginalValue为原先值
            ControlObj.Value := "请按键"
            LastEditObject := ControlObj
            WaitingModify := true
            ; 释放可能存在的Hook
            StopHook()
            ; 配置 Hook
            CreateHook()
        }
        ; 否则为连续第二次点击edit控件
        else {
            ; 如果两次点击的是同一edit控件
            if(ControlObj == LastEditObject) {
                return ; 无事发生
            }
            ; 如果两次点击的不是同一edit控件
            else {
                ; 恢复上一次点击的edit控件的值
                LastEditObject.Value := OriginalValue
                OriginalValue := ControlObj.Value ; OriginalValue为原先值
                ControlObj.Value := "请按键"
                LastEditObject := ControlObj
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
        if(LastEditObject != "") {
            ; 将上次点击的edit控件还原至点击前的状态
            LastEditObject.Value := OriginalValue
            LastEditObject := ""
            WaitingModify := false
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
    global LastEditObject, OriginalValue, ModifyHook, WaitingModify
    ; 当窗口失去焦点时
    if(WinActive(WindowName) == 0) {
        ; 如果上次点击的是edit控件
        if(LastEditObject != "") {
            ; 将上次点击的edit控件还原至点击前的状态
            LastEditObject.Value := OriginalValue
            LastEditObject := ""
            WaitingModify := false
            ; 释放可能存在的Hook
            StopHook()
            btnSave.Focus()
        }
    }
}

; 改绑按键
EndChange(Newkey) {
    global LastEditObject, OriginalValue, ModifyHook, ControlObj, WaitingModify
    ; 若没有输入按键
    if(Newkey == "") {
        if(WaitingModify == true)
            return
        if(ModifyHook.InProgress) {
            ModifyHook.Stop()
        }
        WaitingModify := false
        btnSave.Focus()
        return
    }
    ; 若有输入按键且不是鼠标左键
    if(Newkey != "") {
        if(Newkey == "Escape" OR Newkey == "Backspace") {
            ControlObj.Value := ""
        }
        else if(Newkey == "LWin" OR Newkey == "LWin") {
            LastEditObject.Value := OriginalValue
        }
        else {
            ControlObj.Value := Newkey
        }
    }
    LastEditObject := ""
    WaitingModify := false
    StopHook()
    btnSave.Focus()
}

; 鼠标录制
#HotIf WaitingModify
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