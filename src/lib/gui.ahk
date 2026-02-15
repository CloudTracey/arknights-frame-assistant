; == GUI管理器 ==
; 封装所有GUI相关的变量和操作，消除全局变量依赖

class GuiManager {
    ; GUI实例和控件引用（静态属性）
    static MainGui := ""
    static WindowName := ""
    static btnSave := ""
    static btnDefault := ""
    static btnApply := ""
    static btnCancel := ""
    static GuiFrame := ""
    static WarningText := ""
    
    ; 窗口尺寸常量
    static GuiWidth := 620
    static ColWidth := 280
    static BtnW := 100
    
    ; 初始化GUI（单例模式）
    static Init() {
        if (this.MainGui != "")
            return  ; 已初始化，直接返回
            
        ; 窗口设置
        this.WindowName := "明日方舟帧操小助手 ArknightsFrameAssistant - " Constants.Version
        State.GuiWindowName := this.WindowName
        this.MainGui := Gui(, this.WindowName)
        this.MainGui.Opt("+MinimizeBox")
        this.MainGui.BackColor := "FFFFFF"
        this.MainGui.SetFont("s9", "Microsoft YaHei UI")
        
        ; 创建控件
        this._CreateControls()
        
        ; 订阅事件
        this._SubscribeEvents()
        
        ; 设置托盘菜单
        A_TrayMenu.Delete
        A_TrayMenu.Add("打开按键设置", (*) => this.Show())
        A_TrayMenu.Add("退出", (*) => ExitApp())
        A_TrayMenu.Default := "打开按键设置"
        
        ; 根据设置决定是否自动显示
        if (Config.GetImportant("AutoOpen") == "1") {
            this.Show()
        }
    }
    
    ; 内部：创建所有控件
    static _CreateControls() {
        ; 辅助函数：添加绑定行
        AddBindRow(LabelText, KeyVar, Notes := "") {
            this.MainGui.Add("Text", "xs+10 y+12 w90 Right +0x200", LabelText) 
            this.MainGui.Add("Edit", "x+10 yp w120 Center ReadOnly Uppercase v" KeyVar, Config.GetHotkey(KeyVar))
            if (Notes != "") {
                this.MainGui.SetFont("s8 cGray")
                this.MainGui.Add("Text", "x+5 yp+3", Notes)
                this.MainGui.SetFont("s9 cDefault")
            }
        }
        
        ; 按键设置 - 左列
        this.MainGui.Add("GroupBox", "x15 y10 w0 h0 Section", "")
        this.MainGui.Add("Text", "xs+10 ys+10 w0 h0")
        AddBindRow("额外暂停键A", "PressPause")
        AddBindRow("额外暂停键B", "ReleasePause", "(松开触发)")
        this.MainGui.Add("Text", "xs+10 y+17 w90 Right +0x200", "切换倍速") 
        this.MainGui.Add("Edit", "x+10 yp w120 Center ReadOnly Uppercase v" "GameSpeed", Config.GetHotkey("GameSpeed"))
        AddBindRow("暂停选中", "PauseSelect")
        AddBindRow("干员技能", "Skill")
        AddBindRow("干员撤退", "Retreat")
        
        ; 按键设置 - 右列
        this.MainGui.Add("GroupBox", "x" (this.ColWidth + 30) " y10 w0 h0 Section", "")
        this.MainGui.Add("Text", "xs+10 ys+10 w0 h0")
        AddBindRow("前进 33ms", "33ms")
        AddBindRow("前进 166ms", "166ms")
        AddBindRow("一键技能", "OneClickSkill")
        AddBindRow("一键撤退", "OneClickRetreat")
        AddBindRow("暂停技能", "PauseSkill")
        AddBindRow("暂停撤退", "PauseRetreat")
        
        ; 常规设置
        this.MainGui.Add("Text", "x15 y+30 w" (this.GuiWidth - 30) " h1 0x10")
        this.MainGui.Add("Checkbox", "x30 y+20 h24 vAutoClose", " 随游戏进程关闭自动退出（强烈建议开启）")
        this.MainGui.Add("Checkbox", "x+20 yp h24 vAutoOpen", " 小助手启动时自动打开设置窗口")
        this.MainGui["AutoClose"].Value := Config.GetImportant("AutoClose")
        this.MainGui["AutoOpen"].Value := Config.GetImportant("AutoOpen")
        this.MainGui.Add("Text", "x30 y+12", "游戏内帧数:")
        this.GuiFrame := this.MainGui.Add("DropDownList", "x+12 y+-18 vFrame AltSubmit", ["30", "60", "120"])
        this.MainGui["Frame"].Value := Config.GetImportant("Frame")
        this.GuiFrame.OnEvent("Change", (*) => this._ShowWarning())
        
        ; 提示语
        this.MainGui.SetFont("s9 c1b98d7")
        this.MainGui.Add("Text", "xm y+15 w" (this.GuiWidth - 30) " Center", "注: 请确保游戏内的按键为默认设置，点击输入框修改按键，使用ESC和退格键清除按键")
        this.MainGui.Add("Text", "xm y+10 w" (this.GuiWidth - 30) " Center", "请确保上方“游戏内帧数”设置与游戏内保持一致，且关闭游戏内“垂直同步”")
        this.MainGui.SetFont("s9 cDefault")
        this.MainGui.SetFont("s9 cff2424")
        this.WarningText := this.MainGui.Add("Text", "xm y+10 w" (this.GuiWidth - 30) " Center", "当前版本的33ms过帧功能对60帧及以下帧率支持较差，请尽量在子弹时间下使用166ms的过帧档")
        this.MainGui.SetFont("s9 cDefault")
        this._ShowWarning()
        
        ; 底部按钮
        BtnX_Default := 25
        BtnX_Save := this.GuiWidth - (this.BtnW * 3) - 45
        BtnX_Apply := this.GuiWidth - (this.BtnW * 2) - 35
        BtnX_Cancel := this.GuiWidth - this.BtnW - 25
        
        this.btnDefault := this.MainGui.Add("Button", "x" BtnX_Default " y+20 w" this.BtnW " h32", "重置按键设置")
        this.btnDefault.OnEvent("Click", (*) => EventBus.Publish("SettingsReset"))
        this.btnSave := this.MainGui.Add("Button", "x" BtnX_Save " yp w" this.BtnW " h32 Default", "保存设置")
        this.btnSave.OnEvent("Click", (*) => EventBus.Publish("SettingsSave"))
        this.btnApply := this.MainGui.Add("Button", "x" BtnX_Apply " yp w" this.BtnW " h32 Default", "应用设置")
        this.btnApply.OnEvent("Click", (*) => EventBus.Publish("SettingsApply"))
        this.btnCancel := this.MainGui.Add("Button", "x" BtnX_Cancel " yp w" this.BtnW " h32", "取消")
        this.btnCancel.OnEvent("Click", (*) => EventBus.Publish("SettingsCancel"))
        
        ; 空白占位
        this.MainGui.Add("Text", "xm y+15 w1 h1")
    }
    
    ; 内部：显示/隐藏警告文本
    static _ShowWarning() {
        if (this.GuiFrame.Value == "1" || this.GuiFrame.Value == "2") {
            this.WarningText.Visible := true
        } else if (this.WarningText.Visible == true) {
            this.WarningText.Visible := false
        }
    }
    
    ; 内部：更新所有控件值（从配置）
    static _UpdateControlsFromConfig() {
        for key, value in Config.AllHotkeys {
            try {
                this.MainGui[key].Value := value
            }
        }
        for key, value in Config.AllImportant {
            try {
                this.MainGui[key].Value := value
            }
        }
        this._ShowWarning()
    }
    
    ; 内部：订阅事件总线
    static _SubscribeEvents() {
        EventBus.Subscribe("GuiUpdateControls", (*) => this._UpdateControlsFromConfig())
        EventBus.Subscribe("GuiHide", (*) => this.Hide())
        EventBus.Subscribe("KeyBindFocusSave", (*) => this.FocusSaveButton())
        EventBus.Subscribe("GuiHideStopHook", HandleGuiHideStopHook)
    }
    
    ; 显示GUI窗口
    static Show() {
        this.MainGui.Show()
        this.btnSave.Focus()
        if (IsSet(WatchActiveWindow)) {
            SetTimer WatchActiveWindow, 50
        }
    }
    
; 隐藏GUI窗口
    static Hide() {
        EventBus.Publish("GuiHideStopHook")
        this.MainGui.Hide()
        if (IsSet(WatchActiveWindow)) {
            SetTimer WatchActiveWindow, 0
        }
    }
    
    ; 提交表单（返回包含所有控件值的对象）
    static Submit() {
        return this.MainGui.Submit(0)
    }
    
    ; 设置控件值
    static SetControlValue(controlName, value) {
        try {
            this.MainGui[controlName].Value := value
        }
    }
    
    ; 获取控件值
    static GetControlValue(controlName) {
        try {
            return this.MainGui[controlName].Value
        } catch {
            return ""
        }
    }
    
    ; 聚焦保存按钮
    static FocusSaveButton() {
        this.btnSave.Focus()
    }
    
; 获取窗口名称（用于WinActive等）
    static GetWindowName() {
        return this.WindowName
    }
}

; 处理GUI隐藏时停止Hook的事件
HandleGuiHideStopHook(*) {
    StopHook()
}

; 初始化GUI（在脚本启动时自动调用）
GuiManager.Init()
