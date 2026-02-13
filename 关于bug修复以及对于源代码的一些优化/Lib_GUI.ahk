; 声明全局 GUI 对象
global MyGui := Gui(, WindowName)

ShowMainGui() 
{
    MyGui.BackColor := "FFFFFF"
    MyGui.SetFont("s9", "Microsoft YaHei UI")

    MyGui.Add("GroupBox", "x15 y10 w300 h240 Section", "常规设置")
    MyGui.Add("Text", "xs+10 ys+10 w0 h0") 
    AddBindRow("额外暂停键A", "PauseA")
    AddBindRow("额外暂停键B", "PauseB", "(松开触发)")
    MyGui.Add("Text", "xs+10 y+17 w100 Right +0x200", "切换倍速") 
    MyGui.Add("Edit", "x+10 yp w120 Center ReadOnly Uppercase vGameSpeed", AppSettings["GameSpeed"])
    AddBindRow("暂停选中", "Pauseselect")
    AddBindRow("干员技能", "Skill")
    AddBindRow("干员撤退", "Retreat")

    MyGui.Add("GroupBox", "x330 y10 w300 h240 Section", "帧操功能")
    MyGui.Add("Text", "xs+10 ys+10 w0 h0") 
    AddBindRow("前进 33ms", "33ms")
    AddBindRow("前进 166ms", "166ms")
    AddBindRow("一键技能", "OneClickSkill")
    AddBindRow("一键撤退", "OneClickRetreat")
    AddBindRow("暂停技能", "PauseSkill")
    AddBindRow("暂停撤退", "PauseRetreat")

    MyGui.Add("Text", "x15 y+30 w610 h1 0x10")
    MyGui.Add("Text", "x30 y+12 w100 Right +0x200", "紧急停止键:") 
    MyGui.Add("Edit", "x+10 yp w80 Center ReadOnly Uppercase vPanicKey", AppSettings["PanicKey"])
    MyGui.SetFont("s8 cGray"), MyGui.Add("Text", "x+5 yp+3", "(强制重置脚本)"), MyGui.SetFont("s9 cDefault")

    MyGui.Add("Checkbox", "x30 y+15 h24 vAutoClose", " 随游戏进程关闭自动退出").Value := AppSettings["AutoClose"]
    MyGui.Add("Checkbox", "x240 yp h24 vAutoOpen", " 启动时自动打开设置窗口").Value := AppSettings["AutoOpen"]
    MyGui.Add("Text", "x30 y+12", "游戏内帧数:")
    GuiFrame := MyGui.Add("DropDownList", "x+12 y+-18 vFrame AltSubmit", ["30", "60", "120"])
    GuiFrame.Value := AppSettings["Frame"]

    MyGui.SetFont("s9 c1b98d7"), MyGui.Add("Text", "xm y+15 w630 Center", "提示: 使用一键/暂停功能前，请先将鼠标指针指向对应干员"), MyGui.SetFont("s9 cff2424"), MyGui.Add("Text", "xm y+10 w630 Center", "注意: 请关闭游戏内垂直同步，并确保设置与游戏内一致"), MyGui.SetFont("s9 cDefault")

    btnReset := MyGui.Add("Button", "x30 y+20 w100 h32", "重置按键"), btnReset.OnEvent("Click", (*) => SetDefaultSetting())
    btnSave := MyGui.Add("Button", "x530 yp w110 h32 Default", "保存并应用"), btnSave.OnEvent("Click", (*) => SaveAndClose())

    OnMessage(0x0201, WM_LBUTTONDOWN)
    MyGui.Show()
    btnSave.Focus()
    SetTimer(WatchActiveWindow, 50)
}

AddBindRow(LabelText, KeyVar, Notes := "") 
{
    MyGui.Add("Text", "xs+10 y+12 w100 Right +0x200", LabelText) 
    MyGui.Add("Edit", "x+10 yp w120 Center ReadOnly Uppercase v" . KeyVar, AppSettings[KeyVar])
    if (Notes != "") 
        MyGui.SetFont("s8 cGray"), MyGui.Add("Text", "x+5 yp+3", Notes), MyGui.SetFont("s9 cDefault")
}

SetDefaultSetting() 
{
    if (MsgBox("确定重置所有按键为默认设置吗？", "询问", "YesNo") == "No") 
        return
    
    for key, val in DefaultAppSettings 
        try MyGui[key].Value := val
    
    ToolTip("按键已重置，请点击保存！"), SetTimer(() => ToolTip(), -2500)
}

SaveAndClose() 
{
    SavedObj := MyGui.Submit(0) 
    KeyLabels := Map("PauseA", "额外暂停键A", "PauseB", "额外暂停键B", "GameSpeed", "切换倍速", "Pauseselect", "暂停选中", "Skill", "干员技能", "Retreat", "干员撤退", "33ms", "前进 33ms", "166ms", "前进 166ms", "OneClickSkill", "一键技能", "OneClickRetreat", "一键撤退", "PauseSkill", "暂停技能", "PauseRetreat", "暂停撤退", "PanicKey", "紧急停止键")
    UsedKeys := Map()
    for keyVar, label in KeyLabels 
    {
        if !SavedObj.HasProp(keyVar)
            continue
        currentKey := SavedObj.%keyVar%
        if (currentKey == "")
            continue
        if (UsedKeys.Has(currentKey)) 
        {
            prevLabel := UsedKeys[currentKey]
            MsgBox("按键冲突！`n[" currentKey "] 已经被设置为: 【" prevLabel "】`n请先修改重复的按键。", "保存失败", "Icon!")
            return 
        }
        UsedKeys[currentKey] := label
    }
    MyGui.Hide()
    HotkeyOff()
    for k, v in DefaultAppSettings 
    {
        if SavedObj.HasProp(k) 
            IniWrite(SavedObj.%k%, INI_FILE, (k ~= "Auto|Frame" ? "Main" : "Hotkeys"), k)
    }
    if SavedObj.HasProp("PanicKey") 
         IniWrite(SavedObj.PanicKey, INI_FILE, "Hotkeys", "PanicKey")
    
    LoadSettings(), HotkeyOn()
    ToolTip("设置已应用！"), SetTimer(() => ToolTip(), -2000)
}

WatchActiveWindow() 
{
    if (WinActive(WindowName) == 0 && LastEditObject != "") 
    {
        LastEditObject.Value := OriginalValue
        global LastEditObject := "", WaitingModify := false
        if (ModifyHook.InProgress) 
            ModifyHook.Stop()
    }
}

WM_LBUTTONDOWN(wParam, lParam, msg, hwnd) 
{
    try 
        Ctrl := GuiCtrlFromHwnd(hwnd)
    catch 
        return

    if (Ctrl && Ctrl.Type == "Edit") 
    {
        if (LastEditObject != "" && Ctrl != LastEditObject) 
            LastEditObject.Value := OriginalValue
        
        global LastEditObject := Ctrl, OriginalValue := Ctrl.Value, WaitingModify := true
        Ctrl.Value := "请按键"
        if (ModifyHook.InProgress) 
            ModifyHook.Stop()
        
        ModifyHook.KeyOpt("{All}", "E")
        ModifyHook.OnEnd := (ih) => EndChange(ih.EndKey)
        ModifyHook.Start()
    } 
    else if (LastEditObject != "") 
    {
        LastEditObject.Value := OriginalValue
        global LastEditObject := "", WaitingModify := false
        if (ModifyHook.InProgress) 
            ModifyHook.Stop()
    }
}

EndChange(Newkey) 
{
    if (Newkey != "" && LastEditObject != "") 
    {
        if (Newkey == "Escape" || Newkey == "Backspace") 
            LastEditObject.Value := ""
        else 
            LastEditObject.Value := Newkey
        
        global LastEditObject := "", WaitingModify := false
    }
}

#HotIf WaitingModify
*RButton::
*MButton::
*XButton1::
*XButton2::
*WheelUp::
*WheelDown::
{
    EndChange(StrReplace(A_ThisHotkey, "*", ""))
}
#HotIf