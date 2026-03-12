; == GUI管理器 ==

class GuiManager {
    ; GUI实例和控件引用（静态属性）
    static MainGui := ""
    static WindowName := ""
    static BtnSave := ""
    static BtnDefaultHotkeys := ""
    static BtnCheckGamePath := ""
    static BtnCheckUpdate := ""
    static BtnApply := ""
    static BtnCancel := ""
    static GuiFrame := ""
    static SkillAndRetreatDelay := ""
    static SwitchHotkey := ""
    static IsModified := false
    static IsOnStrongHoldProtocol := false
    static DefaultTab := ""
    
    ; 窗口尺寸常量
    static GuiWidth := 720
    static TabWidth := this.GuiWidth / 4
    static ColWidth := this.GuiWidth / 2
    static GuiXMargin := 30
    static BtnW := 100

    ; 存储不同标签页的控件
    static KeybindControls := []      ; 常规作战相关控件
    static QuickControls := [] ; 快捷操作相关控件
    static StrongHoldProtocolControls := [] ; 卫戍协议相关控件
    static OtherSettingsControls := [] ; 其他设置相关控件
    static NotOtherControls := [] ; 仅非其他设置相关控件
    static TxtKeybind := ""           ; "常规作战"标签文本
    static TxtQuick := ""             ; "快捷操作"标签文本
    static TxtStrongHoldProtocol := ""  ; "卫戍协议"标签文本
    static TxtOther := ""             ; "其他设置"标签文本
    static CurrentTab := ""    ; 当前显示的标签页
    static LastActiveTab := "keyBind"  ; 最后选中的功能性标签页（排除"其他设置"）
    
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
        if (Config.GetImportant("DefaultStrongHoldProtocol") == "1")
            this.DefaultTab := "strongHoldProtocol"
        else
            this.DefaultTab := "keyBind"
        this.SwitchTab(this.DefaultTab)
        
        ; 设置托盘菜单
        A_IconTip := "AFA`n热键已启用"
        A_TrayMenu.Delete
        A_TrayMenu.Add("打开设置界面", (*) => this.Show())
        A_TrayMenu.Add("启用/禁用热键", (*) => EventBus.Publish("SwitchHotkey"))
        A_TrayMenu.Add("重启小助手", (*) => Reload())
        A_TrayMenu.Add("退出", (*) => ExitApp())
        A_TrayMenu.Default := "打开设置界面"

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
            txt := this.MainGui.Add("Text", "xs+15 y+16 w120 Right +0x200", LabelText) 
            edit := this.MainGui.Add("Edit", "x+20 yp-4 w140 Center -TabStop Uppercase v" KeyVar, Config.GetHotkey(KeyVar))
            controls.Push(txt)
            controls.Push(edit)
            return controls
        }

        ; 让text控件假装自己是tab控件
        this.MainGui.SetFont("s9")
        this.TxtKeybind := this.MainGui.Add("Text", "x0 y5 h20 w" this.TabWidth " Center Section c1994d2", "常规作战")
        TabKeybind := this.MainGui.Add("Text", "xs y0 h25 w" this.TabWidth " Center BackgroundTrans")
        this.TxtQuick := this.MainGui.Add("Text", "ys h20 w" this.TabWidth " Center Section", "快捷操作")
        TabQuick := this.MainGui.Add("Text", "xs y0 h25 w" this.TabWidth " Center BackgroundTrans")
        this.TxtStrongHoldProtocol := this.MainGui.Add("Text", "ys h20 w" this.TabWidth " Center Section", "卫戍协议")
        TabStrongHoldProtocol := this.MainGui.Add("Text", "xs y0 h25 w" this.TabWidth " Center BackgroundTrans")
        this.TxtOther := this.MainGui.Add("Text", "ys h20 w" this.TabWidth " Center Section", "其他设置")
        TabOther := this.MainGui.Add("Text", "xs y0 h25 w" this.TabWidth " Center BackgroundTrans")
        ; 为标签添加点击事件
        TabKeybind.OnEvent("Click", (*) => this.SwitchTab("keyBind"))
        TabQuick.OnEvent("Click", (*) => this.SwitchTab("quick"))
        TabStrongHoldProtocol.OnEvent("Click", (*) => this.SwitchTab("strongHoldProtocol"))
        TabOther.OnEvent("Click", (*) => this.SwitchTab("other"))

        this.TabIndicator := this.MainGui.Add("Text", "xs y23 w" this.TabWidth " h2 Background1994d2") ; 选中指示线
        this.MainGui.Add("Text", "x0 y25 w" this.GuiWidth " h1 Backgroundd0d0d0") ; 分割线
        
        ; -- 常规作战 --
        ; 常规作战 - 左列
        this.MainGui.Add("GroupBox", "x0 y35 w" this.ColWidth " h0 Section vKeybindLeftGroup", "")
        this.KeybindControls.Push(this.MainGui["KeybindLeftGroup"])

        this.KeybindControls.Push(AddBindRow("按下暂停", "PressPause")*)
        this.KeybindControls.Push(AddBindRow("松开暂停", "ReleasePause")*)
        this.KeybindControls.Push(AddBindRow("切换倍速", "GameSpeed")*)
        this.KeybindControls.Push(AddBindRow("暂停选中", "PauseSelect")*)
        this.KeybindControls.Push(AddBindRow("单位技能", "Skill")*)
        this.KeybindControls.Push(AddBindRow("单位撤退", "Retreat")*)
        
        ; 常规作战 - 右列
        this.MainGui.Add("GroupBox", "x" this.ColWidth " ys w" this.ColWidth  " h0 Section vKeybindRightGroup", "")
        this.KeybindControls.Push(this.MainGui["KeybindRightGroup"])
        
        this.KeybindControls.Push(AddBindRow("前进 33ms", "33ms")*)
        this.KeybindControls.Push(AddBindRow("前进 166ms", "166ms")*)
        this.KeybindControls.Push(AddBindRow("一键技能", "OneClickSkill")*)
        this.KeybindControls.Push(AddBindRow("一键撤退", "OneClickRetreat")*)
        this.KeybindControls.Push(AddBindRow("暂停技能", "PauseSkill")*)
        this.KeybindControls.Push(AddBindRow("暂停撤退", "PauseRetreat")*)
        ; 空白占位
        placeholderKeybind := this.MainGui.Add("Text", "xs+45 y+-10 w90 h0 Right +0x200")
        this.KeybindControls.Push(placeholderKeybind)

        ; 常规作战提示语
        this.MainGui.SetFont("s9 c1994d2")
        hintKeybind1 := this.MainGui.Add("Text", "x0 yp+40 w" this.GuiWidth " Center", "请确保游戏内的按键为默认设置，点击输入框修改按键，使用【BACKSPACE】清除按键")
        this.MainGui.SetFont("s9 c1994d2 bold")
        hintKeybind2 := this.MainGui.Add("Text", "x0 y+8 w" this.GuiWidth " Center", "为避免冲突，切换到此页面时“卫戍协议”按键将被禁用")
        this.MainGui.SetFont("s9 cDefault Norm")
        this.KeybindControls.Push(hintKeybind1)
        this.KeybindControls.Push(hintKeybind2)

        ; 分割线
        sepKeybind := this.MainGui.Add("Text", "x" this.GuiXMargin " y+15 w" this.GuiWidth - 60 " h1 Backgroundd0d0d0") ; 分割线
        this.NotOtherControls.Push(sepKeybind)

        ; 游戏内帧数设置
        txtFrame := this.MainGui.Add("Text", "x45 y+20 w90 Right", "游戏内帧数")
        this.GuiFrame := this.MainGui.Add("DropDownList", "x+20 y+-18 w120 vFrame AltSubmit", ["30", "60", "120"])
        this.GuiFrame.OnEvent("Change", (*) => this.SetIsModifiedTrue())
        this.MainGui["Frame"].Value := Config.GetImportant("Frame")
        this.NotOtherControls.Push(txtFrame)
        this.NotOtherControls.Push(this.GuiFrame)

        ; 帧数设置提示语
        this.MainGui.SetFont("s9 c1994d2")
        hintFrame1 := this.MainGui.Add("Text", "x0 y+15 w" this.GuiWidth " Center", "请确保上方“游戏内帧数”设置与游戏内保持一致，若屏幕刷新率低于120，请关闭游戏内的“垂直同步”")
        this.NotOtherControls.Push(hintFrame1)
        hintFrame2 := this.MainGui.Add("Text", "x0 y+8 w" this.GuiWidth " Center", "或确保“游戏内帧数”设置与显示器刷新率一致再开启“垂直同步”")
        this.MainGui.SetFont("s9 cDefault")
        this.NotOtherControls.Push(hintFrame2)

        ; -- 快捷操作 --
        ; 快捷操作 - 左列
        this.MainGui.Add("GroupBox", "x0 y35 w" this.ColWidth " h0 Section vQuickLeftGroup", "")
        this.QuickControls.Push(this.MainGui["QuickLeftGroup"])

        this.QuickControls.Push(AddBindRow("模拟左键点击", "LButtonClick")*)
        this.QuickControls.Push(AddBindRow("放弃行动", "CeaseOperations")*)
        this.QuickControls.Push(AddBindRow("基建快速收取", "Harvest")*)
        
        ; 快捷操作 - 右列
        this.MainGui.Add("GroupBox", "x" this.ColWidth " ys w" this.ColWidth  " h0 Section vQuickRightGroup", "")
        this.QuickControls.Push(this.MainGui["QuickRightGroup"])
        
        this.QuickControls.Push(AddBindRow("跳过招募动画/剧情", "Skip")*)
        this.QuickControls.Push(AddBindRow("肉鸽收取道具", "CollectCollectibles")*)
        this.QuickControls.Push(AddBindRow("返回上级菜单", "Back")*)
        ; 空白占位
        placeholderQuick := this.MainGui.Add("Text", "xs+45 y+-10 w90 h0 Right +0x200")
        this.QuickControls.Push(placeholderQuick)

        ; 快捷操作提示语
        this.MainGui.SetFont("s9 c1994d2")
        hintQuick1 := this.MainGui.Add("Text", "x0 yp+40 w" this.GuiWidth " Center", "请确保游戏内的按键为默认设置，点击输入框修改按键，使用【BACKSPACE】清除按键")
        this.MainGui.SetFont("s9 c1994d2 bold")
        hintQuick2 := this.MainGui.Add("Text", "x0 y+8 w" this.GuiWidth " Center", "为避免冲突，切换到此页面时“卫戍协议”按键将被禁用")
        this.MainGui.SetFont("s9 cDefault Norm")
        this.QuickControls.Push(hintQuick1)
        this.QuickControls.Push(hintQuick2)

        ; -- 卫戍协议 --
        ; 卫戍协议 - 左列
        this.MainGui.Add("GroupBox", "x0 y35 w" this.ColWidth " h0 Section vStrongHoldProtocolLeftGroup", "")
        this.StrongHoldProtocolControls.Push(this.MainGui["StrongHoldProtocolLeftGroup"])

        this.StrongHoldProtocolControls.Push(AddBindRow("查看敌人", "CheckEnemies")*)
        this.StrongHoldProtocolControls.Push(AddBindRow("调度中心", "DispatchCenter")*)
        this.StrongHoldProtocolControls.Push(AddBindRow("冻结", "Freeze")*)
        this.StrongHoldProtocolControls.Push(AddBindRow("刷新", "Refresh")*)
        this.StrongHoldProtocolControls.Push(AddBindRow("准备就绪", "Ready")*)
        this.StrongHoldProtocolControls.Push(AddBindRow("模拟左键点击", "StrongHoldProtocolLButtonClick")*)
        
        ; 卫戍协议 - 右列
        this.MainGui.Add("GroupBox", "x" this.ColWidth " ys w" this.ColWidth  " h0 Section vStrongHoldProtocolRightGroup", "")
        this.StrongHoldProtocolControls.Push(this.MainGui["StrongHoldProtocolRightGroup"])
        
        this.StrongHoldProtocolControls.Push(AddBindRow("升级", "Upgrade")*)
        this.StrongHoldProtocolControls.Push(AddBindRow("出售", "Sell")*)
        this.StrongHoldProtocolControls.Push(AddBindRow("单位撤退", "StrongHoldProtocolRetreat")*)
        this.StrongHoldProtocolControls.Push(AddBindRow("一键撤退", "StrongHoldProtocolOneClickRetreat")*)
        this.StrongHoldProtocolControls.Push(AddBindRow("一键出售", "OneClickSell")*)
        this.StrongHoldProtocolControls.Push(AddBindRow("一键购买", "OneClickPurchase")*)

        ; 空白占位
        placeholderStrongHoldProtocol := this.MainGui.Add("Text", "xs+45 y+-10 w90 h0 Right +0x200")
        this.StrongHoldProtocolControls.Push(placeholderStrongHoldProtocol)

        ; 卫戍协议提示语
        this.MainGui.SetFont("s9 c1994d2")
        hintStrongHoldProtocol1 := this.MainGui.Add("Text", "x0 yp+40 w" this.GuiWidth " Center", "请确保游戏内的卫戍协议按键为默认设置，点击输入框修改按键，使用【BACKSPACE】清除按键")
        this.MainGui.SetFont("s9 c1994d2 bold")
        hintStrongHoldProtocol2 := this.MainGui.Add("Text", "x0 y+8 w" this.GuiWidth " Center", "为避免冲突，切换到此页面时“常规作战”、“快捷操作”按键将被禁用")
        this.MainGui.SetFont("s9 cDefault Norm")
        this.StrongHoldProtocolControls.Push(hintStrongHoldProtocol1)
        this.StrongHoldProtocolControls.Push(hintStrongHoldProtocol2)

        ; -- 其他设置 --
        this.MainGui.Add("GroupBox", "x0 y45 w" this.ColWidth " h0 Section vOtherSettingsGroup", "")
        ; - 启动与退出设置 -
        sepLaunch := this.MainGui.Add("Text", "x" this.GuiXMargin " ys+10 w" this.GuiWidth - 60 " h1 Backgroundd0d0d0 Center") ; 分割线
        sepLaunchTxt := this.MainGui.Add("Text", "x" this.GuiXMargin " xs+50 y+-9 Center ca0a0a0", "  启动与退出设置  ")
        this.OtherSettingsControls.Push(sepLaunch)
        this.OtherSettingsControls.Push(sepLaunchTxt)
        ; 自动关闭
        checkboxAutoExit := this.MainGui.Add("Checkbox", "x" this.GuiXMargin " y+10 h24 vAutoExit", " 随游戏进程关闭自动退出（强烈建议开启）")
        checkboxAutoExit.OnEvent("Click", (*) => this.SetIsModifiedTrue())
        this.MainGui["AutoExit"].Value := Config.GetImportant("AutoExit")
        this.OtherSettingsControls.Push(checkboxAutoExit)
        ; 自动打开设置
        checkboxAutoOpenSettings := this.MainGui.Add("Checkbox", "x" this.GuiXMargin " y+10 h24 vAutoOpenSettings", " 启动时打开设置窗口")
        checkboxAutoOpenSettings.OnEvent("Click", (*) => this.SetIsModifiedTrue())
        this.MainGui["AutoOpenSettings"].Value := Config.GetImportant("AutoOpenSettings")
        this.OtherSettingsControls.Push(checkboxAutoOpenSettings)
        ; 默认启动卫戍协议方案
        checkboxDefaultStrongHoldProtocol := this.MainGui.Add("Checkbox", "x" this.GuiXMargin " y+10 h24 vDefaultStrongHoldProtocol", " 默认启动卫戍协议方案")
        checkboxDefaultStrongHoldProtocol.OnEvent("Click", (*) => this.SetIsModifiedTrue())
        this.MainGui["DefaultStrongHoldProtocol"].Value := Config.GetImportant("DefaultStrongHoldProtocol")
        this.OtherSettingsControls.Push(checkboxDefaultStrongHoldProtocol)
        ; 自动启动游戏
        checkboxAutoRunGame := this.MainGui.Add("Checkbox", "x" this.GuiXMargin " y+10 h24 vAutoRunGame", " 同时启动明日方舟")
        checkboxAutoRunGame.OnEvent("Click", (*) => this.SetIsModifiedTrue())
        this.MainGui["AutoRunGame"].Value := Config.GetImportant("AutoRunGame")
        this.OtherSettingsControls.Push(checkboxAutoRunGame)
        ; 识别游戏路径
        this.BtnCheckGamePath := this.MainGui.Add("Button", "x+10 yp w" this.BtnW " h24", "识别游戏路径")
        hintGamePath := this.MainGui.Add("Text", "x+15 yp+4 h20 c9c9c9c", "请先启动游戏再进行识别")
        this.BtnCheckGamePath.OnEvent("Click", (*) => EventBus.Publish("CheckGamePathClick"))
        this.OtherSettingsControls.Push(this.BtnCheckGamePath)
        this.OtherSettingsControls.Push(hintGamePath)
        ; 游戏路径
        txtGamePath := this.MainGui.Add("Text", "x" this.GuiXMargin +17 " y+10 h24", " 游戏路径: ")
        editGamePath := this.MainGui.Add("Edit", "x+10 yp-2 w576 h20 vGamePath -Multi +0x1", Config.GetImportant("GamePath"))
        editGamePath.OnEvent("Change", (*) => this.SetIsModifiedTrue())
        this.OtherSettingsControls.Push(txtGamePath)
        this.OtherSettingsControls.Push(editGamePath)
        this.MainGui.Add("Text", "yp+30 w0 h0")

        ; - 更新设置 -
        sepUpdate := this.MainGui.Add("Text", "x" this.GuiXMargin " y+20 w" this.GuiWidth - 60 " h1 Backgroundd0d0d0 Center") ; 分割线
        sepUpdateTxt := this.MainGui.Add("Text", "x" this.GuiXMargin " xs+50 y+-9 Center ca0a0a0", "  更新设置  ")
        this.OtherSettingsControls.Push(sepUpdate)
        this.OtherSettingsControls.Push(sepUpdateTxt)
        ; 自动检查更新
        checkboxAutoUpdate := this.MainGui.Add("Checkbox", "x" this.GuiXMargin " y+10 h24 vAutoUpdate", " 自动检查更新")
        checkboxAutoUpdate.OnEvent("Click", (*) => this.SetIsModifiedTrue())
        this.MainGui["AutoUpdate"].Value := Config.GetImportant("AutoUpdate")
        this.OtherSettingsControls.Push(checkboxAutoUpdate)
        ; 手动检查更新
        this.BtnCheckUpdate := this.MainGui.Add("Button", "x+10 yp w" this.BtnW " h24", "手动检查更新")
        this.BtnCheckUpdate.OnEvent("Click", (*) => EventBus.Publish("CheckUpdateClick"))
        this.BtnManualDownload := this.MainGui.Add("Button", "x+10 yp w" this.BtnW " h24", "手动下载更新")
        this.BtnManualDownload.OnEvent("Click", (*) => EventBus.Publish("OnManualDownload"))
        this.OtherSettingsControls.Push(this.BtnCheckUpdate)
        this.OtherSettingsControls.Push(this.BtnManualDownload)
        ; github token
        checkboxUseGitHubToken := this.MainGui.Add("Checkbox", "x" this.GuiXMargin " y+10 h24 vUseGitHubToken", " 使用GitHub Token: ")
        checkboxUseGitHubToken.OnEvent("Click", (*) => this.SetIsModifiedTrue())
        this.MainGui["UseGitHubToken"].Value := Config.GetImportant("UseGitHubToken")
        checkboxUseGitHubToken.OnEvent("Click", (*) => this.SetEditDisabled(editGithubToken, checkboxUseGitHubToken.Value))
        editGithubToken := this.MainGui.Add("Edit", "x+10 yp+2 w515 h20 vGitHubToken Password -Multi +0x1", Config.GetImportant("GitHubToken"))
        this.SetEditDisabled(editGithubToken, checkboxUseGitHubToken.Value)
        hintGithubToken := this.MainGui.Add("Text", "xs+50 y+6 c9c9c9c", "只要没有提示API配额超限，就不需要使用GitHub Token")
        this.OtherSettingsControls.Push(checkboxUseGitHubToken)
        this.OtherSettingsControls.Push(editGithubToken)
        this.OtherSettingsControls.Push(hintGithubToken)
        this.MainGui.Add("Text", "yp+30 w0 h0")

        ; - 自定义设置 -
        sepCustom := this.MainGui.Add("Text", "x" this.GuiXMargin " y+20 w" this.GuiWidth - 60 " h1 Backgroundd0d0d0 Center") ; 分割线
        sepCustomTxt := this.MainGui.Add("Text", "x" this.GuiXMargin " xs+50 y+-9 Center ca0a0a0", "  自定义设置  ")
        this.OtherSettingsControls.Push(sepCustom)
        this.OtherSettingsControls.Push(sepCustomTxt)
        ; 技能和撤退点击延迟设置
        txtSkillAndRetreatDelay := this.MainGui.Add("Text", "x" this.GuiXMargin " y+10 Section", "技能和撤退点击延迟")
        this.SkillAndRetreatDelay := this.MainGui.Add("Edit", "x+15 y+-18 w120 h21 vSkillAndRetreatDelay Number", Config.GetCustom("SkillAndRetreatDelay"))
        this.SkillAndRetreatDelay.OnEvent("Change", (*) => this.SetIsModifiedTrue())
        updownSkillAndRetreatDelay := this.MainGui.Add("UpDown", ,Config.GetCustom("SkillAndRetreatDelay"))
        hintSkillAndRetreatDelay := this.MainGui.Add("Text", "x+15 ys c9c9c9c", "从选中单位到按下【技能】【撤退】【出售】的时长，单位为毫秒")
        this.OtherSettingsControls.Push(txtSkillAndRetreatDelay)
        this.OtherSettingsControls.Push(this.SkillAndRetreatDelay)
        this.OtherSettingsControls.Push(updownSkillAndRetreatDelay)
        this.OtherSettingsControls.Push(hintSkillAndRetreatDelay)
        ; 启用/禁用热键快捷键
        txtSwitchHotkey := this.MainGui.Add("Text", "x" this.GuiXMargin " y+16 Right +0x200", "启用/禁用热键快捷键") 
        this.SwitchHotkey := this.MainGui.Add("Edit", "x+10 yp-4 w140 Center -TabStop Uppercase vSwitchHotkey", Config.GetCustom("SwitchHotkey"))
        this.OtherSettingsControls.Push(txtSwitchHotkey)
        this.OtherSettingsControls.Push(this.SwitchHotkey)
        
        ; -- 底部按钮 --
        BtnMargin := 15
        BtnX_DefaultHotkeys := 30
        BtnX_Save := this.GuiWidth - (this.BtnW * 3) - BtnMargin * 2 - BtnX_DefaultHotkeys
        BtnX_Apply := this.GuiWidth - (this.BtnW * 2) - BtnMargin * 1 - BtnX_DefaultHotkeys
        BtnX_Cancel := this.GuiWidth - this.BtnW - BtnX_DefaultHotkeys
        
        this.BtnDefaultHotkeys := this.MainGui.Add("Button", "x" BtnX_DefaultHotkeys " y+20 w" this.BtnW " h32", "重置按键") ; 仅在按键相关标签下显示
        this.BtnDefaultHotkeys.OnEvent("Click", (*) => EventBus.Publish("SettingsReset"))
        this.NotOtherControls.Push(this.BtnDefaultHotkeys)
        
        this.BtnSave := this.MainGui.Add("Button", "x" BtnX_Save " yp w" this.BtnW " h32 Default", "保存并关闭")
        this.BtnSave.OnEvent("Click", (*) => EventBus.Publish("SettingsSave"))
        this.BtnApply := this.MainGui.Add("Button", "x" BtnX_Apply " yp w" this.BtnW " h32 Default", "应用设置")
        this.BtnApply.OnEvent("Click", (*) => EventBus.Publish("SettingsApply"))
        this.BtnCancel := this.MainGui.Add("Button", "x" BtnX_Cancel " yp w" this.BtnW " h32", "取消")
        this.BtnCancel.OnEvent("Click", (*) => EventBus.Publish("SettingsCancel"))

        ; 空白占位
        this.MainGui.Add("Text", "xm y+15 w1 h1")
    }
    
    ; 内部：更新热键控件值（从配置）
    static _UpdateHotkeyControlsFromConfig() {
        for key, value in Config.AllHotkeys {
            try {
                value := KeyBinder.VirtualNewkeyFormat(value)
                this.MainGui[key].Value := value
            }
        }
    }

    ; 内部：更新其他控件值（从配置）
    static _UpdateImportantControlsFromConfig() {
        for key, value in Config.AllImportant {
            try {
                this.MainGui[key].Value := value
            }
        }
    }

    ; 内部：更新其他控件值（从配置）
    static _UpdateCustomControlsFromConfig() {
        for key, value in Config.AllCustom {
            try {
                value := KeyBinder.VirtualNewkeyFormat(value)
                this.MainGui[key].Value := value
            }
        }
    }
    
    ; 内部：订阅事件总线
    static _SubscribeEvents() {
        EventBus.Subscribe("GuiUpdateHotkeyControls", (*) => this._UpdateHotkeyControlsFromConfig())
        EventBus.Subscribe("GuiUpdateImportantControls", (*) => this._UpdateImportantControlsFromConfig())
        EventBus.Subscribe("GuiUpdateCustomControls", (*) => this._UpdateCustomControlsFromConfig())
        EventBus.Subscribe("GuiHide", (*) => this.Hide())
        EventBus.Subscribe("KeyBindFocusSave", (*) => this.FocusSaveButton())
        EventBus.Subscribe("GuiHideStopHook", HandleGuiHideStopHook)
    }
    
    ; 显示GUI窗口
    static Show() {
        this.MainGui.Show()
        this.BtnSave.Focus()
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
        this.BtnSave.Focus()
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

    ; 将修改状态改为已修改
    static SetIsModifiedTrue() {
        if (this.IsModified == true)
            return
        this.IsModified := true
    }

    ; 将修改状态改为未修改
    static SetIsModifiedFalse() {
        if (this.IsModified == false)
            return
        this.IsModified := false
    }

    ; 内部：隐藏所有标签页的控件
    static _HideAllControls(special := "") {
        if (special == "NotOther") {
            for ctrl in this.NotOtherControls {
                if (IsObject(ctrl)) {
                    try ctrl.Visible := false
                }
            }   
            return
        }
        for ctrl in this.KeybindControls {
            if (IsObject(ctrl)) {
                try ctrl.Visible := false
            }
        }
        for ctrl in this.QuickControls {
            if (IsObject(ctrl)) {
                try ctrl.Visible := false
            }
        }
        for ctrl in this.StrongHoldProtocolControls {
            if (IsObject(ctrl)) {
                try ctrl.Visible := false
            }
        }
        for ctrl in this.OtherSettingsControls {
            if (IsObject(ctrl)) {
                try ctrl.Visible := false
            }
        }
    }

    ; 内部：显示指定控件组
    static _ShowControls(controls) {
        for ctrl in controls {
            if (IsObject(ctrl)) {
                try ctrl.Visible := true
            }
        }
    }

    ; 内部：更新标签页UI
    static _UpdateTabUI(tabName) {
        ; 首先隐藏所有标签页的控件
        this._HideAllControls()
        
        ; 切换到常规作战页
        if (tabName = "keyBind") {
            ; 更新标签样式
            this.TxtKeybind.SetFont("c1994d2")  ; 蓝色（选中）
            this.TxtQuick.SetFont("cDefault")   ; 默认色
            this.TxtStrongHoldProtocol.SetFont("cDefault")  ; 默认色
            this.TxtOther.SetFont("cDefault")   ; 默认色

            ; 更新标签文本
            this.TxtKeybind.text := "常规作战 √"
            this.TxtQuick.text := "快捷操作 √"
            this.TxtStrongHoldProtocol.text := "卫戍协议 ×"
            
            ; 移动指示线
            this.TxtKeybind.GetPos(&x)
            this.TabIndicator.Move(x, 23)
            
            ; 显示常规作战控件
            this._ShowControls(this.KeybindControls)
            ; 显示仅非其他设置控件
            this._ShowControls(this.NotOtherControls)
        }

        ; 切换到快捷操作页
        else if (tabName = "quick") {
            ; 更新标签样式
            this.TxtKeybind.SetFont("cDefault")  ; 默认色
            this.TxtQuick.SetFont("c1994d2")     ; 蓝色（选中）
            this.TxtStrongHoldProtocol.SetFont("cDefault")  ; 默认色
            this.TxtOther.SetFont("cDefault")    ; 默认色

            ; 更新标签文本
            this.TxtKeybind.text := "常规作战 √"
            this.TxtQuick.text := "快捷操作 √"
            this.TxtStrongHoldProtocol.text := "卫戍协议 ×"
            
            ; 移动指示线
            this.TxtQuick.GetPos(&x)
            this.TabIndicator.Move(x, 23)
            
            ; 显示快捷操作控件
            this._ShowControls(this.QuickControls)
            ; 显示仅非其他设置控件
            this._ShowControls(this.NotOtherControls)
        }

        ; 切换到卫戍协议页
        else if (tabName = "strongHoldProtocol") {
            ; 更新标签样式
            this.TxtKeybind.SetFont("cDefault")  ; 默认色
            this.TxtQuick.SetFont("cDefault")    ; 默认色
            this.TxtStrongHoldProtocol.SetFont("c1994d2")  ; 蓝色（选中）
            this.TxtOther.SetFont("cDefault")    ; 默认色

            ; 更新标签文本
            this.TxtKeybind.text := "常规作战 ×"
            this.TxtQuick.text := "快捷操作 ×"
            this.TxtStrongHoldProtocol.text := "卫戍协议 √"
            
            ; 移动指示线
            this.TxtStrongHoldProtocol.GetPos(&x)
            this.TabIndicator.Move(x, 23)
            
            ; 显示卫戍协议控件
            this._ShowControls(this.StrongHoldProtocolControls)
            ; 显示仅非其他设置控件
            this._ShowControls(this.NotOtherControls)
        }

        ; 切换到其他设置页
        else if (tabName = "other") {
            ; 更新标签样式
            this.TxtKeybind.SetFont("cDefault")  ; 默认色
            this.TxtQuick.SetFont("cDefault")    ; 默认色
            this.TxtStrongHoldProtocol.SetFont("cDefault")  ; 默认色
            this.TxtOther.SetFont("c1994d2")     ; 蓝色（选中）
            
            ; 移动指示线
            this.TxtOther.GetPos(&x)
            this.TabIndicator.Move(x, 23)
            
            ; 显示其他设置控件
            this._ShowControls(this.OtherSettingsControls)
            ; 隐藏仅非其他设置控件
            this._HideAllControls("NotOther")
        }
        EventBus.Publish("GuiUpdateHotkeyControls")
        EventBus.Publish("GuiUpdateImportantControls")
        EventBus.Publish("GuiUpdateCustomControls")
    }

    ; 切换标签页
    static SwitchTab(tabName) {
        if (tabName = this.CurrentTab)
            return
        if (this.IsModified == true) {
            result := MessageBox.Confirm("  修改尚未保存，确定离开此页面吗 ？","保存提示")
            if (result == "No")
                return
        }
        this.CurrentTab := tabName
        
        ; 记录最后选中的标签页（排除"其他设置"）
        if (tabName != "other") {
            this.LastActiveTab := tabName
        }
        
        ; 如果当前处于热键禁用状态，只更新UI，不切换热键
        if (!HotkeyController.HotkeyState) {
            this._UpdateTabUI(tabName)
            return
        }
        
        ; 根据标签页切换热键组
        if (tabName = "keyBind" || tabName = "quick") {
            HotkeyController.EnableByTab("keyBind")
            if (this.IsOnStrongHoldProtocol == true) {
                this.IsOnStrongHoldProtocol := false
                TrayTip
                TrayTip("已退出卫戍协议方案", "AFA")
            }
        }
        else if (tabName = "strongHoldProtocol") {
            HotkeyController.EnableByTab("strongHoldProtocol")
            if (this.IsOnStrongHoldProtocol == false) {
                this.IsOnStrongHoldProtocol := true
                TrayTip
                TrayTip("已启用卫戍协议方案", "AFA")
            }
        }
        ; "other"标签页不改变热键
        
        ; 更新UI
        this._UpdateTabUI(tabName)

        ; 将修改状态改回未修改
        this.SetIsModifiedFalse()
    }
}

; 处理GUI隐藏时停止Hook的事件
HandleGuiHideStopHook(*) {
    KeyBinder.StopHook()
}

; 初始化GUI
GuiManager.Init()
