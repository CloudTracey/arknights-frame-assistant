; ==GUI==
; 窗口设置
WindowName := "明日方舟帧操小助手 ArknightsFrameAssistant - " Version
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
MyGui.Add("Checkbox", "x30 y+10 h24 vAutoCheckUpdate", " 启动时自动检查更新")
MyGui["AutoCheckUpdate"].Value := ImportantSettings["AutoCheckUpdate"]

MyGui["AutoClose"].Value := ImportantSettings["AutoClose"]
MyGui["AutoOpen"].Value := ImportantSettings["AutoOpen"]
MyGui.Add("Text", "x30 y+12", "游戏内帧数:")
GuiFrame := MyGui.Add("DropDownList", "x+12 y+-18 vFrame AltSubmit", ["30", "60", "120"])
MyGui["Frame"].Value := ImportantSettings["Frame"]
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
btnCheckUpdate := MyGui.Add("Button", "x" BtnX_Default + 110 " yp w100 h32", "检查更新")
btnCheckUpdate.OnEvent("Click", (*) => CheckUpdate(false)) ; false 表示手动检查，显示“最新版”提示
; 空白占位
MyGui.Add("Text", "xm y+15 w1 h1")
; 托盘区右键菜单
A_TrayMenu.Delete
A_TrayMenu.Add("打开按键设置", (*) => ShowSettings())
A_TrayMenu.Add("退出", (*) => ExitApp())
A_TrayMenu.Default := "打开按键设置"
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
    StopHook()
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
if(ImportantSettings["AutoOpen"] == 1) {
    ShowSettings()
}