; == 按键绑定 == 

class KeyBinder {
    ; 按键绑定状态
    static ModifyHookA := InputHook("L0")
    static ModifyHookB := InputHook("L0")
    static LastEditObject := ""
    static OriginalValue := ""
    static ControlObj := ""
    static WaitingModify := false

    ; 创建Hook
    static CreateHook() {
        ; 创建HookA
        this.ModifyHookA := InputHook("L0")
        this.ModifyHookA.VisibleNonText := false
        this.ModifyHookA.KeyOpt("{All}", "E")
        this.ModifyHookA.KeyOpt("{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}", "E")
        this.ModifyHookA.OnEnd := (*) => this.EndChange(this.ModifyHookA.EndKey)
        this.ModifyHookA.Start()
        ; 创建HookB

    }
    ; 释放Hook
    static StopHook() {
        if(this.ModifyHookA.InProgress) {
            this.ModifyHookA.Stop()
        }
    }

    ; 处理设置保存前事件
    static HandleSettingsWillSave(*) {
        KeyBinder.StopHook()
    }

    ; 改绑按键
    static EndChange(Newkey) {
        ; 若没有输入按键
        if(Newkey == "") {
            if(this.WaitingModify == true)
                return
            if(this.ModifyHookA.InProgress) {
                this.ModifyHookA.Stop()
            }
            this.WaitingModify := false
            EventBus.Publish("KeyBindFocusSave")
            return
        }
        ; 若有输入按键且不是鼠标左键
        if(Newkey != "") {
            if(Newkey == "Escape" OR Newkey == "Backspace") {
                this.ControlObj.Value := ""
            }
            else if(Newkey == "LWin" OR Newkey == "RWin") {
                this.LastEditObject.Value := this.OriginalValue
            }
            else {
                this.ControlObj.Value := Newkey
            }
        }
        this.LastEditObject := ""
        this.WaitingModify := false
        this.StopHook()
        EventBus.Publish("KeyBindFocusSave")
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
RButton::
MButton::
XButton1::
XButton2::
WheelUp::
WheelDown::
{
    KeyBinder.EndChange(A_ThisHotkey)
}
#HotIf
