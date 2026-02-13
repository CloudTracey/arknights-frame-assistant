#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, Off
ListLines False
KeyHistory 0
ProcessSetPriority "High"
SendMode "Input"
SetKeyDelay -1, -1
SetMouseDelay -1
SetWinDelay -1
SetDefaultMouseSpeed 0
SetTitleMatchMode 3

; 获取权限
if not A_IsAdmin
{
    try
    {
        if A_IsCompiled
            Run '*RunAs "' A_ScriptFullPath '" /restart'
        else
            Run '*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"'
    }
    ExitApp
}

; 配置文件路径
ConfigDir := A_AppData "\ArknightsFrameAssistant\PC"
if !DirExist(ConfigDir)
    DirCreate(ConfigDir)
INI_FILE := ConfigDir "\Settings.ini"

; == 全局变量 ==
; 窗口名
global WindowName := "明日方舟帧操小助手 ArknightsFrameAssistant - v1.0.7"
; 按键默认设置
global DefaultHotKeySettings := Map()
DefaultHotKeySettings["PressPause"] := "f"
DefaultHotKeySettings["ReleasePause"] := "Space"
DefaultHotKeySettings["GameSpeed"] := "d"
DefaultHotKeySettings["PauseSelect"] := "w"
DefaultHotKeySettings["Skill"] := "s"
DefaultHotKeySettings["Retreat"] := "a"
DefaultHotKeySettings["33ms"] := "r"
DefaultHotKeySettings["166ms"] := "t"
DefaultHotKeySettings["OneClickSkill"] := "e"
DefaultHotKeySettings["OneClickRetreat"] := "q"
DefaultHotKeySettings["PauseSkill"] := "XButton2"
DefaultHotKeySettings["PauseRetreat"] := "XButton1"
; 按键设置
global HotkeySettings := DefaultHotKeySettings.Clone()
; 按键设置映射
global KeyNames := Map(
    "PressPause", "额外暂停键A",
    "ReleasePause", "额外暂停键B",
    "GameSpeed",   "切换倍速",
    "PauseSelect", "暂停选中",
    "Skill",       "干员技能",
    "Retreat",     "干员撤退",
    "33ms",   "前进 33ms",
    "166ms",  "前进 166ms",
    "OneClickSkill",  "一键技能",
    "OneClickRetreat", "一键撤退",
    "PauseSkill",  "暂停技能",
    "PauseRetreat","暂停撤退"
)

; 其他默认设置
global DefaultMainSettings := Map()
DefaultMainSettings["AutoClose"] := "1"
DefaultMainSettings["AutoOpen"] := "1"
DefaultMainSettings["Frame"] := "3"
; 其他设置
global MainSettings := DefaultMainSettings.Clone()

; 游戏状态
global GameHasStarted := false 

; 按键绑定相关全局变量
global LastEditObject := ""
global OriginalValue := ""
global ModifyHook := InputHook("L0")
global ControlObj := ""
global WaitingModify := false

; 默认延迟
global DelayA := 35.3 ; 30帧
global DelayB := 19.6 ; 60帧
global DelayC := 11.3 ; 120帧

; 自动退出计时器
SetTimer CheckGameStatus, 1000

LoadSettings()
HotkeyOn()

; == 功能实现 ==
; 按下暂停
ActionPressPause(ThisHotkey) {
    Send "{ESC Down}"
    USleep(Delay)
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 松开暂停
ActionReleasePause(ThisHotkey) {
    if InStr(ThisHotkey, "Wheel") == 0 {
        PureKeyWait(ThisHotkey)
    }
    Send "{ESC Down}"
    USleep(Delay)
    Send "{ESC Up}"
}
; 切换倍速
ActionGameSpeed(ThisHotkey) {
    Send "{f Down}"
    USleep(Delay)
    Send "{f Up}"
    Send "{g Down}"
    USleep(Delay)
    Send "{g Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 前进33ms，由于波动，过帧间隔设置为29ms，避免一次过两帧
Action33ms(ThisHotkey) {
    Send "{ESC Down}"
    USleep(Delay)
    Send "{ESC Up}"
    USleep(29 - Delay)
    Send "{ESC Down}"
    USleep(Delay)
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 前进166ms
Action166ms(ThisHotkey) {
    Send "{ESC Down}"
    USleep(Delay)
    Send "{ESC Up}"
    USleep(166 - Delay)
    Send "{ESC Down}"
    USleep(Delay)
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 暂停选中
ActionPauseSelect(ThisHotkey) {
    Send "{ESC Down}"
    USleep(Delay)
    Send "{Click Left}"
    Send "{ESC Up}"
    USleep(Delay * 1.2)
    Send "{ESC Down}"
    USleep(Delay)
    Send "{ESC Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 干员技能
ActionSkill(ThisHotkey) {
    Send "{e Down}"
    USleep(Delay)
    Send "{e Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 干员撤退
ActionRetreat(ThisHotkey) {
    Send "{q Down}"
    USleep(Delay)
    Send "{q Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 一键技能
ActionOneClickSkill(ThisHotkey) {
    Send "{Click Left}"
    USleep(Delay * 1.5)
    Send "{e Down}"
    USleep(Delay * 1.3)
    Send "{e Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 一键撤退
ActionOneClickRetreat(ThisHotkey) {
    Send "{Click Left}"
    USleep(Delay * 1.5)
    Send "{q Down}"
    USleep(Delay * 1.3)
    Send "{q Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 暂停技能
ActionPauseSkill(ThisHotkey) {
    Send "{ESC Down}"
    USleep(Delay)
    Send "{Click Left}"
    Send "{ESC Up}"
    USleep(Delay * 1.4)
    Send "{ESC Down}"
    USleep(Delay)
    Send "{ESC Up}"
    Send "{e Down}"
    USleep(Delay * 1.2)
    Send "{e Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}
; 暂停撤退
ActionPauseRetreat(ThisHotkey) {
    Send "{ESC Down}"
    USleep(Delay)
    Send "{Click Left}"
    Send "{ESC Up}"
    USleep(Delay * 1.4)
    Send "{ESC Down}"
    USleep(Delay)
    Send "{ESC Up}"
    Send "{q Down}"
    USleep(Delay * 1.2)
    Send "{q Up}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}

; 模拟鼠标左键点击
RbuttonClick(ThisHotkey) {
    Send "{Click Left}"
    if InStr(ThisHotkey, "Wheel")
        return
    PureKeyWait(ThisHotkey)
}

; 高精度延迟
USleep(delay_ms) {
    static freq := 0
    static isHighRes := false
    if (delay_ms <= Delay) {
        delay_ms := Delay
    }
    if (freq = 0) {
        DllCall("QueryPerformanceFrequency", "Int64*", &freq)
    }
    if (!isHighRes) {
        DllCall("winmm\timeBeginPeriod", "UInt", 1)
        isHighRes := true
    }
    start := 0
    DllCall("QueryPerformanceCounter", "Int64*", &start)
    target := start + (delay_ms * freq / 1000)
    Loop {
        current := 0
        DllCall("QueryPerformanceCounter", "Int64*", &current)
        if (current >= target)
            break
        remaining := (target - current) * 1000 / freq
        if (remaining > 2)
            DllCall("Sleep", "UInt", 1) 
    }
    if (isHighRes) {
        DllCall("winmm\timeEndPeriod", "UInt", 1)
        isHighRes := false
    }
}

; 去除修饰符前缀
PureKeyWait(ThisHotkey) {
    pureKey := RegExReplace(ThisHotkey, "^[~*$#!^+&]+")
    KeyWait(pureKey)
}

; == GUI 部分 ==
; 窗口设置
MyGui := Gui(, WindowName)
MyGui.Opt("+MinimizeBox")
MyGui.BackColor := "FFFFFF"
MyGui.SetFont("s9", "Microsoft YaHei UI")

GuiWidth := 620
ColWidth := 280

AddBindRow(LabelText, KeyVar, Notes := "") {
    MyGui.Add("Text", "xs+10 y+12 w90 Right +0x200", LabelText) 
    MyGui.Add("Edit", "x+10 yp w120 Center ReadOnly Uppercase v" KeyVar, HotkeySettings[KeyVar])
    if (Notes != "") {
        MyGui.SetFont("s8 cGray")
        MyGui.Add("Text", "x+5 yp+3", Notes)
        MyGui.SetFont("s9 cDefault")
    }
}
; 按键设置
MyGui.Add("GroupBox", "x15 y10 w0 h0 Section", "")
MyGui.Add("Text", "xs+10 ys+10 w0 h0") ; 定位锚点
AddBindRow("额外暂停键A", "PressPause")
AddBindRow("额外暂停键B", "ReleasePause", "(松开触发)")
MyGui.Add("Text", "xs+10 y+17 w90 Right +0x200", "切换倍速") 
MyGui.Add("Edit", "x+10 yp w120 Center ReadOnly Uppercase v" "GameSpeed", HotkeySettings["GameSpeed"])
AddBindRow("暂停选中",    "PauseSelect")
AddBindRow("干员技能",    "Skill")
AddBindRow("干员撤退",    "Retreat")
MyGui.Add("GroupBox", "x" (ColWidth + 30) " y10 w0 h0 Section", "")
MyGui.Add("Text", "xs+10 ys+10 w0 h0") ; 定位锚点
AddBindRow("前进 33ms",   "33ms")
AddBindRow("前进 166ms",  "166ms")
AddBindRow("一键技能",    "OneClickSkill")
AddBindRow("一键撤退",    "OneClickRetreat")
AddBindRow("暂停技能",    "PauseSkill")
AddBindRow("暂停撤退",    "PauseRetreat")
; 常规设置
MyGui.Add("Text", "x15 y+30 w" (GuiWidth - 30) " h1 0x10") ; 水平分割线
MyGui.Add("Checkbox", "x30 y+20 h24 vAutoClose", " 随游戏进程关闭自动退出（强烈建议开启）")
MyGui.Add("Checkbox", "x+20 yp h24 vAutoOpen", " 小助手启动时自动打开设置窗口")
MyGui["AutoClose"].Value := MainSettings["AutoClose"]
MyGui["AutoOpen"].Value := MainSettings["AutoOpen"]
MyGui.Add("Text", "x30 y+12", "游戏内帧数:")
GuiFrame := MyGui.Add("DropDownList", "x+12 y+-18 vFrame AltSubmit", ["30", "60", "120"])
MyGui["Frame"].Value := MainSettings["Frame"]
GuiFrame.OnEvent("Change", (*) => ShowWarning())
; 提示语
MyGui.SetFont("s9 c1b98d7")
MyGui.Add("Text", "xm y+15 w" (GuiWidth - 30) " Center", "注: 请确保游戏内的按键为默认设置，点击输入框修改按键，使用ESC和退格键清除按键")
MyGui.Add("Text", "xm y+10 w" (GuiWidth - 30) " Center", "请确保上方“游戏内帧数”设置与游戏内保持一致，且关闭游戏内“垂直同步”")
MyGui.SetFont("s9 cDefault")
MyGui.SetFont("s9 cff2424")
WarningText := MyGui.Add("Text", "xm y+10 w" (GuiWidth - 30) " Center", "当前版本的33ms过帧功能对60帧及以下帧率支持较差，请尽量在子弹时间下使用166ms的过帧档")
MyGui.SetFont("s9 cDefault")
ShowWarning()
; 底部按钮
BtnW := 100
BtnX_Default := 25
BtnX_Save := GuiWidth - (BtnW * 3) - 45
BtnX_Apply := GuiWidth - (BtnW * 2) - 35
BtnX_Cancel := GuiWidth - BtnW - 25
btnDefault := MyGui.Add("Button", "x" BtnX_Default " y+20 w" BtnW " h32", "重置按键设置")
btnDefault.OnEvent("Click", (*) => SetDefaultSetting())
btnSave := MyGui.Add("Button", "x" BtnX_Save " yp w" BtnW " h32 Default", "保存设置")
btnSave.OnEvent("Click", (*) => SaveAndClose())
btnApply := MyGui.Add("Button", "x" BtnX_Apply " yp w" BtnW " h32 Default", "应用设置")
btnApply.OnEvent("Click", (*) => ApplySettings())
btnCancel := MyGui.Add("Button", "x" BtnX_Cancel " yp w" BtnW " h32", "取消")
btnCancel.OnEvent("Click", (*) => CancleSetting())
; 空白占位
MyGui.Add("Text", "xm y+15 w1 h1")
; 托盘区右键菜单
A_TrayMenu.Delete
A_TrayMenu.Add("打开按键设置", (*) => ShowSettings())
A_TrayMenu.Add("退出", (*) => ExitApp())
; 焦点修正，不豪堪
; OnMessage(0x0111, (*) => (MyGui.FocusedCtrl ? "" : btnSave.Focus()))

; 显示警告
ShowWarning() {
    if (GuiFrame.Value == "1" || GuiFrame.Value == "2") {
        WarningText.Visible := true
    }
    else if (WarningText.Visible == true) {
        WarningText.Visible := false
    }
}

; 隐藏GUI
HideGui(){
    ; 释放可能存在的Hook
    if(ModifyHook.InProgress) {
        ModifyHook.Stop()
    }
    MyGui.Hide()
    ; 关闭GUI窗口监控
    SetTimer WatchActiveWindow, 0
}

; 打开GUI
ShowSettings() {
    MyGui.Show()
    btnSave.Focus()
    ; 启用GUI窗口监控
    SetTimer WatchActiveWindow, 50
}

; 随脚本启动打开GUI界面
if(MainSettings["AutoOpen"] == 1) {
    ShowSettings()
}

; == 保存相关 ==
; 加载设置
LoadSettings() {
    HotKeySettings["PressPause"] := IniRead(INI_FILE, "Hotkeys", "PressPause", DefaultHotKeySettings["PressPause"])
    HotKeySettings["ReleasePause"] := IniRead(INI_FILE, "Hotkeys", "ReleasePause", DefaultHotKeySettings["ReleasePause"])
    HotKeySettings["GameSpeed"] := IniRead(INI_FILE, "Hotkeys", "GameSpeed", DefaultHotKeySettings["GameSpeed"])
    HotKeySettings["Skill"] := IniRead(INI_FILE, "Hotkeys", "Skill", DefaultHotKeySettings["Skill"])
    HotKeySettings["Retreat"] := IniRead(INI_FILE, "Hotkeys", "Retreat", DefaultHotKeySettings["Retreat"])
    HotKeySettings["PauseSkill"] := IniRead(INI_FILE, "Hotkeys", "PauseSkill", DefaultHotKeySettings["PauseSkill"])
    HotKeySettings["PauseRetreat"] := IniRead(INI_FILE, "Hotkeys", "PauseRetreat", DefaultHotKeySettings["PauseRetreat"])
    HotKeySettings["33ms"] := IniRead(INI_FILE, "Hotkeys", "33ms", DefaultHotKeySettings["33ms"])
    HotKeySettings["166ms"] := IniRead(INI_FILE, "Hotkeys", "166ms", DefaultHotKeySettings["166ms"])
    HotKeySettings["PauseSelect"] := IniRead(INI_FILE, "Hotkeys", "PauseSelect", DefaultHotKeySettings["PauseSelect"])
    HotKeySettings["OneClickSkill"] := IniRead(INI_FILE, "Hotkeys", "OneClickSkill", DefaultHotKeySettings["OneClickSkill"])
    HotKeySettings["OneClickRetreat"] := IniRead(INI_FILE, "Hotkeys", "OneClickRetreat", DefaultHotKeySettings["OneClickRetreat"])
    MainSettings["AutoClose"] := IniRead(INI_FILE, "Main", "AutoClose", DefaultMainSettings["AutoClose"])
    MainSettings["AutoOpen"] := IniRead(INI_FILE, "Main", "AutoOpen", DefaultMainSettings["AutoOpen"])
    MainSettings["Frame"] := IniRead(INI_FILE, "Main", "Frame", DefaultMainSettings["Frame"])
    DelaySetting()
}

; 延迟设置
DelaySetting() {
    global Delay
    if (MainSettings["Frame"] == 1) {
        Delay := DelayA
    }
    else if (MainSettings["Frame"] == 2) {
        Delay := DelayB
    }
    else if (MainSettings["Frame"] == 3) {
        Delay := DelayC
    }
}

; 记录热键并写入ini文件
HotkeyIniWrite() {
    if(ModifyHook.InProgress) {
        ModifyHook.Stop()
    }
    SavedObj := MyGui.Submit(0) 
    UsedKeys := Map()
    for keyVar, keyName in KeyNames {
        if (!SavedObj.HasProp(keyVar))
            continue
        currentKey := SavedObj.%keyVar%
        if (currentKey != "") {
            ; 按键冲突提示
            if (UsedKeys.Has(currentKey)) {
                prevKeyName := UsedKeys[currentKey]
                MsgBox("按键冲突！`n[" currentKey "] 已经被设置为: 【" prevKeyName "】`n请先修改重复的按键。", "保存失败", "Icon!")
                Exit
            }
            UsedKeys[currentKey] := keyName
        }
    }
    IniWrite(SavedObj.PressPause,  INI_FILE, "Hotkeys", "PressPause")
    IniWrite(SavedObj.ReleasePause,  INI_FILE, "Hotkeys", "ReleasePause")
    IniWrite(SavedObj.GameSpeed,   INI_FILE, "Hotkeys", "GameSpeed")
    IniWrite(SavedObj.Skill,       INI_FILE, "Hotkeys", "Skill")
    IniWrite(SavedObj.Retreat,     INI_FILE, "Hotkeys", "Retreat")
    IniWrite(SavedObj.PauseSkill,  INI_FILE, "Hotkeys", "PauseSkill")
    IniWrite(SavedObj.PauseRetreat,INI_FILE, "Hotkeys", "PauseRetreat")
    IniWrite(SavedObj.33ms,    INI_FILE, "Hotkeys", "33ms")
    IniWrite(SavedObj.166ms,   INI_FILE, "Hotkeys", "166ms")
    IniWrite(SavedObj.PauseSelect, INI_FILE, "Hotkeys", "PauseSelect")
    IniWrite(SavedObj.OneClickSkill,  INI_FILE, "Hotkeys", "OneClickSkill")
    IniWrite(SavedObj.OneClickRetreat, INI_FILE, "Hotkeys", "OneClickRetreat")
    IniWrite(SavedObj.AutoClose, INI_FILE, "Main", "AutoClose")
    IniWrite(SavedObj.AutoOpen,  INI_FILE, "Main", "AutoOpen")
    IniWrite(SavedObj.Frame,  INI_FILE, "Main", "Frame")
}

; 重置默认设置
SetDefaultSetting() {
    Result := MsgBox("  确定重置按键为默认设置吗 ？","重置按键设置", "YesNo")
    if (Result == "Yes") {
        for key, _ in DefaultHotKeySettings {
                MyGui[key].Value := DefaultHotKeySettings[key]
        }
    }
    HotkeyOff()
    HotkeyIniWrite()
    LoadSettings()
    HotkeyOn()
}

; 保存设置
SaveAndClose() {
    HotkeyOff()
    HotkeyIniWrite()
    LoadSettings()
    HotkeyOn()
    HideGui()
    MsgBox("设置已保存！后续可从右下角托盘区图标右键菜单打开设置", "保存成功", "Iconi")
}

; 应用设置
ApplySettings() {
    HotkeyOff()
    HotkeyIniWrite()
    LoadSettings()
    HotkeyOn()
    MsgBox("设置已应用！", "应用成功")
}

; 取消设置
CancleSetting() {
    for key, _ in HotkeySettings {
        MyGui[key].Value := HotkeySettings[key]
    }
    for key, _ in MainSettings {
        MyGui[key].Value := MainSettings[key]
    }
    HideGui()
}

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

; 检查游戏状态
CheckGameStatus() {
    global GameHasStarted
    if (MainSettings["AutoClose"] != "1")
        return
    if WinExist("ahk_exe Arknights.exe") {
        GameHasStarted := true
    }
    else {
        if (GameHasStarted == true) {
            ExitApp
        }
    }
}

; == 按键绑定 == 
; 写的什么屎山
; 在设置窗口监听鼠标左键
OnMessage(0x0201, WM_LBUTTONDOWN)
; 创建Hook
CreateHook() {
    ModifyHook := InputHook("L0")
    ModifyHook.VisibleNonText := false
    ModifyHook.KeyOpt("{All}", "E")
    ModifyHook.KeyOpt("{LCtrl}{RCtrl}{LAlt}{RAlt}{LShift}{RShift}", "E")
    ModifyHook.OnEnd := (*) => EndChange(ModifyHook.EndKey)
    ModifyHook.Start()
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
            if(ModifyHook.InProgress) {
                ModifyHook.Stop()
            }
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
                if(ModifyHook.InProgress) {
                    ModifyHook.Stop()
                }
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
            if(ModifyHook.InProgress) {
                ModifyHook.Stop()
            }
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
            if(ModifyHook.InProgress) {
                ModifyHook.Stop()
            }
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
            try ControlObj.Value := ""
        }
        else if(Newkey == "LWin" OR Newkey == "LWin") {
            LastEditObject.Value := OriginalValue
        }
        else {
            try ControlObj.Value := Newkey
        }
    }
    LastEditObject := ""
    WaitingModify := false
    if(ModifyHook.InProgress) {
        ModifyHook.Stop()
    }
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