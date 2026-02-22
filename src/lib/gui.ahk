; == GUI管理器 ==

class GuiManager {
    ; GUI实例和控件引用（静态属性）
    static MainGui := ""
    static WindowName := ""
    static btnSave := ""
    static btnDefaultHotkeys := ""
    static btnCheckUpdate := ""
    static btnApply := ""
    static btnCancel := ""
    static GuiFrame := ""
    
    ; 窗口尺寸常量
    static GuiWidth := 720
    static ColWidth := this.GuiWidth / 2
    static GuiXMargin := 30
    static BtnW := 100

    ; 存储不同标签页的控件
    static KeybindControls := []      ; 按键设置相关控件
    static OtherSettingsControls := [] ; 其他设置相关控件
    static TxtKeybind := ""           ; "按键设置"标签文本
    static TxtOther := ""             ; "其他设置"标签文本
    static CurrentTab := ""    ; 当前显示的标签页
    
    ; 初始化GUI（单例模式）
    static Init() {
        if (this.MainGui != "")
            return
            
        ; 窗口设置
        this.WindowName := "明日方舟帧操小助手 ArknightsFrameAssistant - " Version.Get()
        State.GuiWindowName := this.WindowName
        this.MainGui := Gui(, this.WindowName)
        this.MainGui.MarginX := 0
        this.MainGui.Opt("+MinimizeBox")
        this.MainGui.BackColor := "FFFFFF"
        WinSetTransColor("ffa8a8", this.MainGui)
        this.MainGui.SetFont("s9", "Microsoft YaHei UI")
        hWnd := this.MainGui.Hwnd
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hWnd, "int", 38, "int*", true, "int", 4)
        this.MainGui.OnEvent("Close", (*) => EventBus.Publish("SettingsCancel"))
        
        ; 创建控件
        this._CreateControls()
        
        ; 订阅事件
        this._SubscribeEvents()

        ; 初始化标签页
        this.SwitchTab("KeyBind")
        
        ; 设置托盘菜单
        A_TrayMenu.Delete
        A_TrayMenu.Add("打开按键设置", (*) => this.Show())
        A_TrayMenu.Add("重启小助手", (*) => Reload())
        A_TrayMenu.Add("退出", (*) => ExitApp())
        A_TrayMenu.Default := "打开按键设置"

        ; 根据设置决定是否自动显示
        if (Config.GetImportant("AutoOpenSettings") == "1") {
            this.Show()
        }
    }
    
    ; 内部：创建所有控件
    ; AHKv2的原生GUI实在是太“简洁”了，想做得轻量又豪堪只能这么干了，传奇手搓硬编码苦痛之旅开始了
    static _CreateControls() {
        ; 辅助函数：添加绑定行
        AddBindRow(LabelText, KeyVar) {
            controls := []
            txt := this.MainGui.Add("Text", "xs+45 y+16 w90 Right +0x200", LabelText) 
            edit := this.MainGui.Add("Edit", "x+20 yp-4 w120 Center -TabStop Uppercase v" KeyVar, Config.GetHotkey(KeyVar))
            controls.Push(txt)
            controls.Push(edit)
            return controls
        }

        ; 让text控件假装自己是tab控件
        this.MainGui.SetFont("s9")
        this.TxtKeybind := this.MainGui.Add("Text", "x0 y5 h20 w" this.ColWidth " Center Section c1994d2", "按键设置")
        TabKeybind := this.MainGui.Add("Text", "x0 y0 h25 w" this.ColWidth " Center BackgroundTrans")
        this.TxtOther := this.MainGui.Add("Text", "ys h20 w" this.ColWidth " Center", "其他设置")
        TabOther := this.MainGui.Add("Text", "x" this.GuiWidth / 2 " y0 h25 w" this.ColWidth " Center BackgroundTrans")
        ; 为标签添加点击事件
        TabKeybind.OnEvent("Click", (*) => this.SwitchTab("keybind"))
        TabOther.OnEvent("Click", (*) => this.SwitchTab("other"))

        this.TabIndicator := this.MainGui.Add("Text", "xs y23 w" this.ColWidth " h2 Background1994d2") ; 选中指示线
        this.MainGui.Add("Text", "x0 y25 w" this.GuiWidth " h1 Backgroundd0d0d0") ; 分割线
        
        ; -- 按键设置 --
        ; 按键设置 - 左列
        this.MainGui.Add("GroupBox", "x0 y35 w" this.ColWidth " h0 Section vKeybindLeftGroup", "")
        this.KeybindControls.Push(this.MainGui["KeybindLeftGroup"])

        this.KeybindControls.Push(AddBindRow("按下暂停", "PressPause")*)
        this.KeybindControls.Push(AddBindRow("松开暂停", "ReleasePause")*)
        this.KeybindControls.Push(AddBindRow("切换倍速", "GameSpeed")*)
        this.KeybindControls.Push(AddBindRow("暂停选中", "PauseSelect")*)
        this.KeybindControls.Push(AddBindRow("干员技能", "Skill")*)
        this.KeybindControls.Push(AddBindRow("干员撤退", "Retreat")*)
        this.KeybindControls.Push(AddBindRow("模拟左键点击", "LbuttonClick")*)
        
        ; 按键设置 - 右列
        this.MainGui.Add("GroupBox", "x" this.ColWidth " ys w" this.ColWidth  " h0 Section vKeybindRightGroup", "")
        this.KeybindControls.Push(this.MainGui["KeybindRightGroup"])
        
        this.KeybindControls.Push(AddBindRow("前进 33ms", "33ms")*)
        this.KeybindControls.Push(AddBindRow("前进 166ms", "166ms")*)
        this.KeybindControls.Push(AddBindRow("一键技能", "OneClickSkill")*)
        this.KeybindControls.Push(AddBindRow("一键撤退", "OneClickRetreat")*)
        this.KeybindControls.Push(AddBindRow("暂停技能", "PauseSkill")*)
        this.KeybindControls.Push(AddBindRow("暂停撤退", "PauseRetreat")*)
        ; 空白占位
        placeholder1 := this.MainGui.Add("Text", "xs+45 y+16 w90 Right +0x200")
        this.KeybindControls.Push(placeholder1)

        ; 按键设置提示语
        this.MainGui.SetFont("s9 c1994d2")
        hint1 := this.MainGui.Add("Text", "x0 yp+40 w" this.GuiWidth " Center", "注: 请确保游戏内的按键为默认设置，点击输入框修改按键，使用【ESC】和【BACKSPACE】清除按键")
        this.MainGui.SetFont("s9 cDefault")
        this.KeybindControls.Push(hint1)

        ; 分割线
        sep1 := this.MainGui.Add("Text", "x" this.GuiXMargin " y+15 w" this.GuiWidth - 60 " h1 Backgroundd0d0d0") ; 分割线
        this.KeybindControls.Push(sep1)

        ; 游戏内帧数设置
        txtFrame := this.MainGui.Add("Text", "x45 y+20 w90 Right", "游戏内帧数")
        this.GuiFrame := this.MainGui.Add("DropDownList", "x+20 y+-18 w120 vFrame AltSubmit", ["30", "60", "120"])
        this.MainGui["Frame"].Value := Config.GetImportant("Frame")
        this.KeybindControls.Push(txtFrame)
        this.KeybindControls.Push(this.GuiFrame)

        ; 帧数设置提示语
        this.MainGui.SetFont("s9 c1994d2")
        hint2 := this.MainGui.Add("Text", "x0 y+15 w" this.GuiWidth " Center", "请确保上方“游戏内帧数”设置与游戏内保持一致，若屏幕刷新率低于120，请关闭游戏内的“垂直同步”")
        this.MainGui.SetFont("s9 cDefault")
        this.KeybindControls.Push(hint2)

        ; 底部按钮
        BtnMargin := 15
        BtnX_DefaultHotkeys := 45
        BtnX_Save := this.GuiWidth - (this.BtnW * 3) - BtnMargin * 2 - 45
        BtnX_Apply := this.GuiWidth - (this.BtnW * 2) - BtnMargin * 1 - 45
        BtnX_Cancel := this.GuiWidth - this.BtnW - 45
        
        this.btnDefaultHotkeys := this.MainGui.Add("Button", "x" BtnX_DefaultHotkeys " y+20 w" this.BtnW " h32", "重置按键") ; 仅在按键设置标签下显示
        this.btnDefaultHotkeys.OnEvent("Click", (*) => EventBus.Publish("SettingsReset"))
        
        this.btnSave := this.MainGui.Add("Button", "x" BtnX_Save " yp w" this.BtnW " h32 Default", "保存并关闭")
        this.btnSave.OnEvent("Click", (*) => EventBus.Publish("SettingsSave"))
        this.btnApply := this.MainGui.Add("Button", "x" BtnX_Apply " yp w" this.BtnW " h32 Default", "应用设置")
        this.btnApply.OnEvent("Click", (*) => EventBus.Publish("SettingsApply"))
        this.btnCancel := this.MainGui.Add("Button", "x" BtnX_Cancel " yp w" this.BtnW " h32", "取消")
        this.btnCancel.OnEvent("Click", (*) => EventBus.Publish("SettingsCancel"))
        this.KeybindControls.Push(this.btnDefaultHotkeys)

        ; 空白占位
        this.MainGui.Add("Text", "xm y+15 w1 h1")

        ; -- 其他设置 --
        this.MainGui.Add("GroupBox", "x0 y45 w" this.ColWidth " h0 Section vImportantGroupz", "")
        ; - 启动与退出设置 -
        sep2 := this.MainGui.Add("Text", "x" this.GuiXMargin " ys+10 w" this.GuiWidth - 60 " h1 Backgroundd0d0d0 Center") ; 分割线
        sep2txt := this.MainGui.Add("Text", "x" this.GuiXMargin " xs+50 y+-9 Center ca0a0a0", "  启动与退出设置  ")
        this.OtherSettingsControls.Push(sep2)
        this.OtherSettingsControls.Push(sep2txt)
        ; 自动关闭
        checkboxAutoExit := this.MainGui.Add("Checkbox", "x" this.GuiXMargin " y+10 h24 vAutoExit", " 随游戏进程关闭自动退出（强烈建议开启）")
        this.MainGui["AutoExit"].Value := Config.GetImportant("AutoExit")
        this.OtherSettingsControls.Push(checkboxAutoExit)
        ; 自动打开设置
        checkboxAutoOpenSettings := this.MainGui.Add("Checkbox", "x" this.GuiXMargin " y+10 h24 vAutoOpenSettings", " 小助手启动时自动打开设置窗口")
        this.MainGui["AutoOpenSettings"].Value := Config.GetImportant("AutoOpenSettings")
        this.OtherSettingsControls.Push(checkboxAutoOpenSettings)
        ; - 更新设置 -
        sep3 := this.MainGui.Add("Text", "x" this.GuiXMargin " y+20 w" this.GuiWidth - 60 " h1 Backgroundd0d0d0 Center") ; 分割线
        sep3txt := this.MainGui.Add("Text", "x" this.GuiXMargin " xs+50 y+-9 Center ca0a0a0", "  更新设置  ")
        this.OtherSettingsControls.Push(sep3)
        this.OtherSettingsControls.Push(sep3txt)
        ; 自动检查更新
        checkboxAutoUpdate := this.MainGui.Add("Checkbox", "x" this.GuiXMargin " y+10 h24 vAutoUpdate", " 自动检查更新")
        this.MainGui["AutoUpdate"].Value := Config.GetImportant("AutoUpdate")
        this.OtherSettingsControls.Push(checkboxAutoUpdate)
        ; 手动检查更新
        this.btnCheckUpdate := this.MainGui.Add("Button", "x+10 yp w" this.BtnW " h24", "手动检查更新")
        this.btnCheckUpdate.OnEvent("Click", (*) => EventBus.Publish("CheckUpdateClick"))
        this.OtherSettingsControls.Push(this.btnCheckUpdate)
        ; github token
        checkboxUseGithubToken := this.MainGui.Add("Checkbox", "x" this.GuiXMargin " y+10 h24 vUseGithubToken", " 使用GitHub Token: ")
        checkboxUseGithubToken.OnEvent("Click", (*) => this.SetEditDisabled(githubTokenEdit, checkboxUseGithubToken.Value))
        githubTokenEdit := this.MainGui.Add("Edit", "x+10 yp+2 w380 h20 vGitHubToken Password -Multi +0x1", Config.GetImportant("GitHubToken"))
        this.SetEditDisabled(githubTokenEdit, checkboxUseGithubToken.Value)
        hint3 := this.MainGui.Add("Text", "xs+50 y+6 c9c9c9c", "只要没有提示API配额超限，就不需要使用GitHub Token")
        this.OtherSettingsControls.Push(checkboxUseGithubToken)
        this.OtherSettingsControls.Push(githubTokenEdit)
        this.OtherSettingsControls.Push(hint3)
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

    ; 将edit设为禁用
    static SetEditDisabled(ctrl, value) {
        if (value == 1)
            ctrl.Opt("-Disabled")
        else 
            ctrl.Opt("+Disabled")
    }

    ; 切换标签页
    static SwitchTab(tabName) {
        if (tabName = this.CurrentTab)
            return
        this.CurrentTab := tabName
        
        if (tabName = "keybind") {
            ; 切换到按键设置页
            ; 更新标签样式
            this.TxtKeybind.SetFont("c1994d2")  ; 蓝色（选中）
            this.TxtOther.SetFont("cDefault")   ; 默认色
            ; 移动指示线
            this.TabIndicator.Move(0, 23)
            
            ; 显示按键设置控件
            for ctrl in this.KeybindControls {
                if (IsObject(ctrl)) {
                    try ctrl.Visible := true
                }
            }
            
            ; 隐藏其他设置控件
            for ctrl in this.OtherSettingsControls {
                if (IsObject(ctrl)) {
                    try ctrl.Visible := false
                }
            }
        }
        else if (tabName = "other") {
            ; 切换到其他设置页
            ; 更新标签样式
            this.TxtKeybind.SetFont("cDefault")  ; 默认色
            this.TxtOther.SetFont("c1994d2")     ; 蓝色（选中）
            ; 移动指示线
            this.TabIndicator.Move(this.ColWidth, 23)
            
            ; 隐藏按键设置控件
            for ctrl in this.KeybindControls {
                if (IsObject(ctrl)) {
                    try ctrl.Visible := false
                }
            }
            
            ; 显示其他设置控件
            for ctrl in this.OtherSettingsControls {
                if (IsObject(ctrl)) {
                    try ctrl.Visible := true
                }
            }
        }
    }
}

; 处理GUI隐藏时停止Hook的事件
HandleGuiHideStopHook(*) {
    StopHook()
}

; 初始化GUI
GuiManager.Init()
