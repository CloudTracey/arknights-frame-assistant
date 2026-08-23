; == GUI管理器 ==

class GuiManager {
    ; GUI实例和控件引用（静态属性）
    static MainGui := ""
    static WindowName := ""
    static BtnSave := ""
    static BtnDefaultHotkeys := ""
    static BtnCheckGamePath := ""
    static ServerPathsText := ""
    static RunningClientsText := ""
    ; 语言代码顺序与下拉框显示顺序一致
    static LanguageCodes := ["auto", "zh-Hans", "zh-Hant", "ja-JP", "ko-KR", "en-US"]
    ; 下拉框显示名固定使用各语言自己的写法，不随当前界面语言变化
    static LanguageDisplayNames := Map(
        "auto", "Auto",
        "zh-Hans", "中文（简体）",
        "zh-Hant", "中文（繁體）",
        "ja-JP", "日本語",
        "ko-KR", "한국어",
        "en-US", "English (US)"
    )
    static BtnCheckUpdate := ""
    static BtnApply := ""
    static BtnCancel := ""
    static GuiFrame := ""
    static ClickDelay := ""
    static SwitchHotkey := ""
    static IsModified := false
    static HasHotkeyConflicts := false
    static _PrevConflictedControls := Map()  ; 上次冲突控件集合，用于增量字体更新
    static _InitialValues := Map()  ; 初始值快照，用于脏值对比
    static HintUnsaved := ""       ; 提示文字
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
    static NavItems := []              ; 左侧导航项 Text 控件列表
    static NavIndicators := []        ; 每个导航项的竖线指示器
    static CurrentOtherCategory := "General" ; 当前选中的分类（通用置首位）
    static _BottomBaseY := 0            ; 底部按钮基准 Y 坐标
    static GeneralControls := []       ; "通用"设置控件组
    static DisplayControls := []       ; "显示"设置控件组
    static LaunchControls := []        ; "启动与退出"设置控件组
    static UpdateControls := []        ; "更新"设置控件组
    static CustomControls := []        ; "自定义"设置控件组
    static AboutControls := []         ; "关于"页面控件组
    static LogControls := []           ; "日志"页面控件组
    ; 其他设置分类映射：分类名 → [控件组, 导航索引]
    static OtherCategories := Map(
        "General", [this.GeneralControls, 1],
        "Display", [this.DisplayControls, 2],
        "Launch", [this.LaunchControls, 3],
        "Update", [this.UpdateControls, 4],
        "Custom", [this.CustomControls, 5],
        "Log", [this.LogControls, 6],
        "About", [this.AboutControls, 7]
    )
    static NotOtherControls := [] ; 仅非其他设置相关控件
    static TxtKeybind := ""           ; "常规作战"标签文本
    static TxtQuick := ""             ; "快捷操作"标签文本
    static TxtStrongHoldProtocol := ""  ; "卫戍协议"标签文本
    static TxtOther := ""             ; "其他设置"标签文本
    static TabKeybind := ""           ; "常规作战"标签点击区域
    static TabQuick := ""             ; "快捷操作"标签点击区域
    static TabStrongHoldProtocol := "" ; "卫戍协议"标签点击区域
    static TabOther := ""             ; "其他设置"标签点击区域
    static TabItems := []              ; 标签描述，数组顺序为管理器中的待保存顺序
    static AppliedTabSettings := {Order: [], Visibility: Map()} ; 已保存或应用的顶部标签状态
    static TabFontState := Map() ; 各顶部标签当前字体颜色（key -> color）；空 Map 保证首次 _SetTabFontOnce 总会执行 SetFont，避免与控件创建颜色硬编码耦合
    ; 标签管理器（"显示"页内容区左侧）几何布局
    static TabManagerX := 160          ; 管理器列左边缘（内容区左侧）
    static TabManagerTitleY := 0       ; "顶部标签页"标题的 y（锚定"显示"分类内容区顶部）
    static TabManagerRowStartY := 108  ; 第一行的上边缘
    static TabManagerRowWidth := 240   ; 行宽（含"（无法隐藏）"后缀，按最长语言留足空间）
    static TabManagerRowHeight := 30   ; 行高（含间距）
    static TabDragIndex := 0
    static TabDragStartY := 0
    static TabDragMoved := false
    static _TabManagerHandlersRegistered := false
    static _AltF4Registered := false
    static _LanguageChanged := false
    static _EventsSubscribed := false
    static StrongHoldConflictHints := [] ; 非卫戍协议页面上的模式切换提示
    static CurrentTab := ""    ; 当前显示的标签页
    static LastActiveTab := "keyBind"  ; 最后选中的功能性标签页（排除"其他设置"）
    static FrameSkipLabels := Map()     ; 过帧标签控件（用于动态更新文本）
    static FrameSkipDelayKeys := ["FrameSkip16msDelay", "FrameSkip33msDelay", "FrameSkip166msDelay"]
    ; 自定义按键页
    static CustomKeyControls := []      ; 自定义按键页全部控件
    static CustomRows := []             ; 预建 16 行：Array<{Label, Edit, Gear, Del}>
    static CustomHotkeyRowStartY := 76  ; 首行 y
    static CustomHotkeyRowHeight := 34  ; 行高（含间距）
    static _InitialCustomHotkeys := []  ; 自定义按键快照（脏值对比）
    static TxtCustomKeys := ""          ; "自定义按键"标签文本
    static TabCustomKeys := ""          ; "自定义按键"标签点击区域
    ; 具有对应 GUI 控件的 Important 设置；不直接遍历 Config.AllImportant，后者还包含内部字段
    static GuiImportantKeys := ["Frame", "AutoExit", "AutoOpenSettings", "ExitOnWindowClose",
        "DefaultStrongHoldProtocol", "TabOrder", "HiddenTabs", "AutoRunGame", "AutoStartWithGame", "GamePath",
        "UpdateChannel", "UpdateSource", "AutoUpdate", "UseGitHubToken", "GitHubToken", "AutoBeginPause",
        "BackCeaseOperations", "InLevelGuard", "DebugEnabled", "Language"]

    ; 初始化GUI（单例模式）
    static Init() {
        if (this.MainGui != "")
            return

        ; 窗口设置
        this.WindowName := I18n.T("明日方舟帧操小助手 ArknightsFrameAssistant - {1}", Version.Get())
        this.MainGui := Gui(, this.WindowName)
        this.MainGui.MarginX := 0
        this.MainGui.Opt("+MinimizeBox")
        this.MainGui.BackColor := "FFFFFF"
        WinSetTransColor("ffa8a8", this.MainGui)
        this.MainGui.SetFont("s9", Metrics.FontFor(I18n.GetCurrent()))
        hWnd := this.MainGui.Hwnd
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hWnd, "int", 20, "int*", false, "int", 4)
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hWnd, "int", 35, "uint*", 0x00FFFFFF, "int", 4)
        this.MainGui.OnEvent("Close", (*) => this._HandleWindowClose())

        ; 创建控件
        this._CreateControls()
        this.LoadTabSettingsFromConfig()
        this.CommitTabSettings(false)
        this.RenderTabManager()

        ; 订阅事件
        this._SubscribeEvents()
        this.RegisterTabManagerMouseHandlers()

        ; 初始化标签页
        if (Config.GetImportant("DefaultStrongHoldProtocol") == "1"
            && this.IsTabVisible("strongHoldProtocol"))
            this.DefaultTab := "strongHoldProtocol"
        else
            this.DefaultTab := "keyBind"
        this.SwitchTab(this.DefaultTab)

        ; 设置托盘菜单
        A_IconTip := "AFA`n" I18n.T("热键已启用")
        A_TrayMenu.Delete
        A_TrayMenu.Add(I18n.T("打开设置界面"), (*) => this.Show())
        A_TrayMenu.Add(I18n.T("启用/禁用热键"), (*) => EventBus.Publish("HotkeyToggleRequested"))
        A_TrayMenu.Add(I18n.T("重启小助手"), (*) => Reload())
        A_TrayMenu.Add(I18n.T("退出"), (*) => ExitApp())
        A_TrayMenu.Default := I18n.T("打开设置界面")

        ; 根据设置决定是否自动显示
        if (Config.GetImportant("AutoOpenSettings") == "1") {
            this.Show()
        }
    }

    ; 处理设置窗口标题栏关闭按钮和 Alt+F4
    static _HandleWindowClose(*) {
        if (Config.GetImportant("ExitOnWindowClose") == "1") {
            ExitApp()
            return
        }
        EventBus.Publish("SettingsCancelRequested")
    }

    ; 内部：创建所有控件
    ; AHKv2的原生GUI实在是太“简洁”了，想做得轻量又豪堪只能这么干了，传奇手搓硬编码苦痛之旅开始了
    static _CreateControls() {
        ; 辅助函数：添加绑定行。列栅格：Edit 固定在 colX+155（左列 155 / 右列 515），
        ; 标签右缘固定在 colX+135（右对齐），宽度不足时向左延长。
        bindLabelW := this._ComputeBindLabelWidth()
        AddBindRow(LabelText, KeyVar, colX) {
            controls := []
            txt := this.MainGui.Add("Text", "x" (colX + 135 - bindLabelW) " y+16 w" bindLabelW " Right +0x200", LabelText)
            edit := this.MainGui.Add("Edit", "x" (colX + 155) " yp-4 w140 Center -TabStop Uppercase v" KeyVar, Config.GetHotkey(KeyVar))
            controls.Push(txt)
            controls.Push(edit)
            return controls
        }

        ; 让text控件假装自己是tab控件
        this.MainGui.SetFont("s9")
        this.TxtKeybind := this.MainGui.Add("Text", "x0 y5 h20 w" this.TabWidth " Center Section c1994d2", I18n.T("常规作战"))
        this.TabKeybind := this.MainGui.Add("Text", "xs y0 h25 w" this.TabWidth " Center BackgroundTrans")
        this.TxtQuick := this.MainGui.Add("Text", "ys h20 w" this.TabWidth " Center Section", I18n.T("快捷操作"))
        this.TabQuick := this.MainGui.Add("Text", "xs y0 h25 w" this.TabWidth " Center BackgroundTrans")
        this.TxtStrongHoldProtocol := this.MainGui.Add("Text", "ys h20 w" this.TabWidth " Center Section", I18n.T("卫戍协议"))
        this.TabStrongHoldProtocol := this.MainGui.Add("Text", "xs y0 h25 w" this.TabWidth " Center BackgroundTrans")
        this.TxtOther := this.MainGui.Add("Text", "ys h20 w" this.TabWidth " Center Section", I18n.T("其他设置"))
        this.TabOther := this.MainGui.Add("Text", "xs y0 h25 w" this.TabWidth " Center BackgroundTrans")
        this.TxtCustomKeys := this.MainGui.Add("Text", "ys h20 w" this.TabWidth " Center Section", I18n.T("自定义按键"))
        this.TabCustomKeys := this.MainGui.Add("Text", "xs y0 h25 w" this.TabWidth " Center BackgroundTrans")
        ; 为标签添加点击事件
        this.TabKeybind.OnEvent("Click", (*) => this.SwitchTab("keyBind"))
        this.TabQuick.OnEvent("Click", (*) => this.SwitchTab("quick"))
        this.TabStrongHoldProtocol.OnEvent("Click", (*) => this.SwitchTab("strongHoldProtocol"))
        this.TabOther.OnEvent("Click", (*) => this.SwitchTab("other"))
        this.TabCustomKeys.OnEvent("Click", (*) => this.SwitchTab("customKeys"))
        this.TabItems := [
            {
                Id: "keyBind",
                Label: I18n.T("常规作战"),
                TextControl: this.TxtKeybind,
                ClickControl: this.TabKeybind,
                CanHide: true,
                Visible: true
            },
            {
                Id: "quick",
                Label: I18n.T("快捷操作"),
                TextControl: this.TxtQuick,
                ClickControl: this.TabQuick,
                CanHide: true,
                Visible: true
            },
            {
                Id: "strongHoldProtocol",
                Label: I18n.T("卫戍协议"),
                TextControl: this.TxtStrongHoldProtocol,
                ClickControl: this.TabStrongHoldProtocol,
                CanHide: true,
                Visible: true
            },
            {
                Id: "customKeys",
                Label: I18n.T("自定义按键"),
                TextControl: this.TxtCustomKeys,
                ClickControl: this.TabCustomKeys,
                CanHide: true,
                Visible: true
            },
            {
                Id: "other",
                Label: I18n.T("其他设置"),
                TextControl: this.TxtOther,
                ClickControl: this.TabOther,
                CanHide: false,
                Visible: true
            }
        ]

        this.TabIndicator := this.MainGui.Add("Text", "xs y23 w" this.TabWidth " h2 Background1994d2") ; 选中指示线
        this.MainGui.Add("Text", "x0 y25 w" this.GuiWidth " h1 Backgroundd0d0d0") ; 分割线

        ; -- 常规作战 --
        ; 常规作战 - 左列（由 Schema 顺序生成，前半列）
        combatItems := this._GetSchemaItems("combat")
        combatHalf := Ceil(combatItems.Length / 2)
        bindColX := 0
        this.MainGui.Add("GroupBox", "x0 y35 w" this.ColWidth " h0 Section vKeybindLeftGroup", "")
        this.KeybindControls.Push(this.MainGui["KeybindLeftGroup"])

        for i, item in combatItems {
            if (i = combatHalf + 1) {
                ; 常规作战 - 右列
                this.MainGui.Add("GroupBox", "x" this.ColWidth " ys w" this.ColWidth " h0 Section vKeybindRightGroup", "")
                this.KeybindControls.Push(this.MainGui["KeybindRightGroup"])
                bindColX := this.ColWidth
            }
            row := AddBindRow(I18n.T(item.nameKey), item.id, bindColX)
            this.KeybindControls.Push(row*)
            if (item.id = "16ms" || item.id = "33ms" || item.id = "166ms")
                this.FrameSkipLabels[item.id] := row[1]
        }
        ; 空白占位
        placeholderKeybind := this.MainGui.Add("Text", "xs+45 y+-10 w90 h0 Right +0x200")
        this.KeybindControls.Push(placeholderKeybind)

        ; 常规作战提示语
        this.MainGui.SetFont("s9 c1994d2")
        hintKeybind1 := this.MainGui.Add("Text", "x0 yp+40 w" this.GuiWidth " Center",
            I18n.T("点击输入框修改按键，使用【BACKSPACE/DELETE】清除按键"))
        this.MainGui.SetFont("s9 c1994d2 bold")
        hintKeybind2 := this.MainGui.Add("Text", "x0 y+8 w" this.GuiWidth " Center", I18n.T("为避免冲突，切换到此页面时“卫戍协议”按键将被禁用"))
        this.MainGui.SetFont("s9 cDefault Norm")
        this.KeybindControls.Push(hintKeybind1)
        this.KeybindControls.Push(hintKeybind2)
        this.StrongHoldConflictHints.Push(hintKeybind2)

        ; 分割线
        sepKeybind := this.MainGui.Add("Text", "x" this.GuiXMargin " y+15 w" this.GuiWidth - 60 " h1 Backgroundd0d0d0") ; 分割线
        this.NotOtherControls.Push(sepKeybind)

        ; 游戏内帧率设置。列栅格：下拉框与按键 Edit 列对齐（x155 w140）。
        ; 文本标签用真实宽度探测（自动尺寸 → 重定宽），右缘固定 135，保证 en/ko 等长文案不换行；
        ; 中文保持 x45 w90 不变（Max(90, 实测宽)）。
        txtFrame := this.MainGui.Add("Text", "x0 y+20 Right", I18n.T("游戏内帧率"))
        txtFrame.GetPos(&frameX, &frameY, &frameW)
        frameW := Max(90, frameW + 2)  ; +2px 安全余量；中文仍为 x45 w90 不变
        txtFrame.Move(Max(0, 135 - frameW), frameY, frameW)
        this.GuiFrame := this.MainGui.Add("DropDownList", "x155 y+-18 w140 vFrame", Constants.FrameOptions)
        this.GuiFrame.OnEvent("Change", (*) => this.TrackChange("Frame"))
        frameText := Config.GetImportant("Frame")
        this.MainGui["Frame"].Value := this._FrameTextToIndex(frameText)
        this.NotOtherControls.Push(txtFrame)
        this.NotOtherControls.Push(this.GuiFrame)

        ; 自动暂停开关（仅"常规作战"页显示）。
        ; 列栅格：C 输入框与右侧按键 Edit 列对齐（x515 w140），复选框贴其左侧（右缘 500），
        ; 复选框文案向右延伸时自动左移，任何语言都不会越窗。
        autoBeginW := Metrics.TextWidth(I18n.T(" 切换开局自动暂停"))
        checkboxAutoBeginPause := this.MainGui.Add("Checkbox", "x" (500 - autoBeginW - 20) " yp-2 h24 vAutoBeginPause", I18n.T(" 切换开局自动暂停"))
        checkboxAutoBeginPause.OnEvent("Click", (*) => this.TrackChange("AutoBeginPause"))
        this.MainGui["AutoBeginPause"].Value := Config.GetImportant("AutoBeginPause")
        checkboxAutoBeginPause.GetPos(&cbPauseX, &cbPauseY)   ; 记录位置供快捷操作页复用
        this.KeybindControls.Push(checkboxAutoBeginPause)
        editAutoBeginPauseSwitch := this.MainGui.Add("Edit", "x515 yp w140 Center -TabStop Uppercase v" "AutoBeginPauseSwitch",
            Config.GetHotkey("AutoBeginPauseSwitch"))
        this.KeybindControls.Push(editAutoBeginPauseSwitch)

        ; 使用"返回上级菜单"放弃行动（仅"快捷操作"页显示，复用自动暂停开关同一位置）
        checkboxBackCease := this.MainGui.Add("Checkbox", "x" cbPauseX " y" cbPauseY " vBackCeaseOperations", I18n.T(" 使用“返回上级菜单”放弃行动"))
        checkboxBackCease.OnEvent("Click", (*) => this.TrackChange("BackCeaseOperations"))
        this.MainGui["BackCeaseOperations"].Value := Config.GetImportant("BackCeaseOperations")
        this.QuickControls.Push(checkboxBackCease)

        ; 仅在常规作战场景启用常规作战热键（控制 GuardInLevel 关卡检测守卫，仅"常规作战"页显示）。
        ; 左缘与"切换开局暂停"复选框对齐（同类控件）；用实测宽度钳制，文案过长时自动左移不越窗。
        checkboxCombatGuard := this.MainGui.Add("Checkbox", "x0 y+12 h24 vInLevelGuard", I18n.T(" 仅在关卡内启用常规作战热键（实验性）"))
        checkboxCombatGuard.GetPos(&cbGX, &cbGY, &cbGW)
        checkboxCombatGuard.Move(Min(cbPauseX, 708 - cbGW), cbGY, cbGW)
        checkboxCombatGuard.OnEvent("Click", (*) => this.TrackChange("InLevelGuard"))
        this.MainGui["InLevelGuard"].Value := Config.GetImportant("InLevelGuard")
        this.KeybindControls.Push(checkboxCombatGuard)

        ; 帧数设置提示语
        this.MainGui.SetFont("s9 c1994d2")
        hintFrame1 := this.MainGui.Add("Text", "x0 y+15 w" this.GuiWidth " Center",
            I18n.T("若开启了游戏内的“垂直同步”，请确保上方“游戏内帧率”设置与你的屏幕刷新率保持一致"))
        this.NotOtherControls.Push(hintFrame1)
        hintFrame2 := this.MainGui.Add("Text", "x0 y+8 w" this.GuiWidth " Center",
            I18n.T("若关闭了游戏的“垂直同步”，请确保上方“游戏内帧率”设置与游戏内保持一致"))
        this.MainGui.SetFont("s9 cDefault")
        this.NotOtherControls.Push(hintFrame2)

        ; 记录所有标签页底部基准 Y（取"常规作战"帧率提示的底部）
        hintFrame2.GetPos(, &y, , &h)
        this._BottomBaseY := y + h

        ; -- 快捷操作 --
        ; 快捷操作 - 左列（由 Schema 顺序生成，前半列）
        quickItems := this._GetSchemaItems("quick")
        quickHalf := Ceil(quickItems.Length / 2)
        bindColX := 0
        this.MainGui.Add("GroupBox", "x0 y35 w" this.ColWidth " h0 Section vQuickLeftGroup", "")
        this.QuickControls.Push(this.MainGui["QuickLeftGroup"])

        for i, item in quickItems {
            if (i = quickHalf + 1) {
                ; 快捷操作 - 右列
                this.MainGui.Add("GroupBox", "x" this.ColWidth " ys w" this.ColWidth " h0 Section vQuickRightGroup", "")
                this.QuickControls.Push(this.MainGui["QuickRightGroup"])
                bindColX := this.ColWidth
            }
            this.QuickControls.Push(AddBindRow(I18n.T(item.nameKey), item.id, bindColX)*)
        }
        ; 空白占位
        placeholderQuick := this.MainGui.Add("Text", "xs+45 y+-10 w90 h0 Right +0x200")
        this.QuickControls.Push(placeholderQuick)

        ; 快捷操作提示语
        this.MainGui.SetFont("s9 c1994d2")
        hintQuick1 := this.MainGui.Add("Text", "x0 yp+40 w" this.GuiWidth " Center",
            I18n.T("点击输入框修改按键，使用【BACKSPACE/DELETE】清除按键"))
        this.MainGui.SetFont("s9 c1994d2 bold")
        hintQuick3 := this.MainGui.Add("Text", "x0 y+8 w" this.GuiWidth " Center", I18n.T("为避免冲突，切换到此页面时“卫戍协议”按键将被禁用"))
        this.MainGui.SetFont("s9 cDefault Norm")
        this.QuickControls.Push(hintQuick1)
        this.QuickControls.Push(hintQuick3)
        this.StrongHoldConflictHints.Push(hintQuick3)

        ; -- 卫戍协议 --
        ; 卫戍协议 - 左列（由 Schema 顺序生成，前半列）
        strongHoldItems := this._GetSchemaItems("strongHold")
        strongHoldHalf := Ceil(strongHoldItems.Length / 2)
        bindColX := 0
        this.MainGui.Add("GroupBox", "x0 y35 w" this.ColWidth " h0 Section vStrongHoldProtocolLeftGroup", "")
        this.StrongHoldProtocolControls.Push(this.MainGui["StrongHoldProtocolLeftGroup"])

        for i, item in strongHoldItems {
            if (i = strongHoldHalf + 1) {
                ; 卫戍协议 - 右列
                this.MainGui.Add("GroupBox", "x" this.ColWidth " ys w" this.ColWidth " h0 Section vStrongHoldProtocolRightGroup",
                    "")
                this.StrongHoldProtocolControls.Push(this.MainGui["StrongHoldProtocolRightGroup"])
                bindColX := this.ColWidth
            }
            this.StrongHoldProtocolControls.Push(AddBindRow(I18n.T(item.nameKey), item.id, bindColX)*)
        }
        ; 空白占位
        placeholderStrongHoldProtocol := this.MainGui.Add("Text", "xs+45 y+-10 w90 h0 Right +0x200")
        this.StrongHoldProtocolControls.Push(placeholderStrongHoldProtocol)

        ; 卫戍协议提示语
        this.MainGui.SetFont("s9 c1994d2")
        hintStrongHoldProtocol1 := this.MainGui.Add("Text", "x0 yp+40 w" this.GuiWidth " Center",
            I18n.T("点击输入框修改按键，使用【BACKSPACE/DELETE】清除按键"))
        this.MainGui.SetFont("s9 c1994d2 bold")
        hintStrongHoldProtocol2 := this.MainGui.Add("Text", "x0 y+8 w" this.GuiWidth " Center",
            I18n.T("为避免冲突，切换到此页面时“常规作战”、“快捷操作”按键将被禁用"))
        this.MainGui.SetFont("s9 cDefault Norm")
        this.StrongHoldProtocolControls.Push(hintStrongHoldProtocol1)
        this.StrongHoldProtocolControls.Push(hintStrongHoldProtocol2)

        ; -- 自定义按键 --
        ; 新增按键按钮与提示
        btnAddCustom := this.MainGui.Add("Button", "x" this.GuiXMargin " y40 w110 h24 vBtnAddCustom", I18n.T("新增按键"))
        btnAddCustom.OnEvent("Click", (*) => this._OnAddCustomHotkey())
        this.CustomKeyControls.Push(btnAddCustom)
        hintCustom1 := this.MainGui.Add("Text", "x+15 yp+4 h20 c9c9c9c", I18n.T("点击齿轮编辑名称、类型与指令；点击 ✕ 删除"))
        this.CustomKeyControls.Push(hintCustom1)

        ; 16 行预建（两列 × 8 行，显隐 + 重写值实现增删；AHK 控件无法运行时创建/销毁）
        loop Constants.CustomHotkeyMax
            this._CreateCustomHotkeyRow(A_Index)

        ; 自定义按键提示语
        this.MainGui.SetFont("s9 c1994d2")
        hintCustom2 := this.MainGui.Add("Text", "x0 y+15 w" this.GuiWidth " Center",
            I18n.T("按键类型决定生效范围：全局按键始终生效；常规作战类受关卡守卫限制"))
        this.MainGui.SetFont("s9 cDefault")
        this.CustomKeyControls.Push(hintCustom2)

        ; -- 其他设置 --
        ; 导航区域右侧分割线——高度跟随内容到底部按钮上方
        dividerHeight := this._BottomBaseY + 20 - 38
        this.OtherSettingsControls.Push(this.MainGui.Add("Text", "x130 y38 w1 h" dividerHeight " Backgroundd0d0d0"))

        ; 其他设置 - 左侧导航
        ; 导航项"通用"（默认选中态：蓝色文字，置首位）
        this.MainGui.SetFont("s9 c1994d2")
        navGeneral := this.MainGui.Add("Text", "x0 y40 w130 Center Section", I18n.T("通用"))
        navGeneral.OnEvent("Click", (*) => this._SwitchOtherCategory("General"))
        this.NavItems.Push(navGeneral)
        this.OtherSettingsControls.Push(navGeneral)

        ; 竖线指示器——跟随导航项高度
        this.NavIndicators := []
        this.NavIndicators.Push(this.MainGui.Add("Text", "xp yp w3 hp Background1994d2"))
        this.OtherSettingsControls.Push(this.NavIndicators[1])

        ; 恢复默认字体
        this.MainGui.SetFont("s9 cDefault norm")

        ; 导航项"显示"（未选中态）
        navDisplay := this.MainGui.Add("Text", "xs y+m w130 Center", I18n.T("显示"))
        navDisplay.OnEvent("Click", (*) => this._SwitchOtherCategory("Display"))
        this.NavItems.Push(navDisplay)
        this.OtherSettingsControls.Push(navDisplay)
        this.NavIndicators.Push(this.MainGui.Add("Text", "xp yp w3 hp Background1994d2 Hidden"))
        this.OtherSettingsControls.Push(this.NavIndicators[2])

        ; 导航项"启动与退出"（未选中态）
        navLaunch := this.MainGui.Add("Text", "xs y+m w130 Center", I18n.T("启动与退出"))
        navLaunch.OnEvent("Click", (*) => this._SwitchOtherCategory("Launch"))
        this.NavItems.Push(navLaunch)
        this.OtherSettingsControls.Push(navLaunch)
        this.NavIndicators.Push(this.MainGui.Add("Text", "xp yp w3 hp Background1994d2 Hidden"))
        this.OtherSettingsControls.Push(this.NavIndicators[3])

        ; 导航项"更新"（未选中态）
        navUpdate := this.MainGui.Add("Text", "xs y+m w130 Center", I18n.T("更新"))
        navUpdate.OnEvent("Click", (*) => this._SwitchOtherCategory("Update"))
        this.NavItems.Push(navUpdate)
        this.OtherSettingsControls.Push(navUpdate)
        this.NavIndicators.Push(this.MainGui.Add("Text", "xp yp w3 hp Background1994d2 Hidden"))
        this.OtherSettingsControls.Push(this.NavIndicators[4])

        ; 导航项"自定义"（未选中态）
        navCustom := this.MainGui.Add("Text", "xs y+m w130 Center", I18n.T("自定义"))
        navCustom.OnEvent("Click", (*) => this._SwitchOtherCategory("Custom"))
        this.NavItems.Push(navCustom)
        this.OtherSettingsControls.Push(navCustom)
        this.NavIndicators.Push(this.MainGui.Add("Text", "xp yp w3 hp Background1994d2 Hidden"))
        this.OtherSettingsControls.Push(this.NavIndicators[5])

        ; 导航项"日志"（未选中态）
        navLog := this.MainGui.Add("Text", "xs y+m w130 Center", I18n.T("日志"))
        navLog.OnEvent("Click", (*) => this._SwitchOtherCategory("Log"))
        this.NavItems.Push(navLog)
        this.OtherSettingsControls.Push(navLog)
        this.NavIndicators.Push(this.MainGui.Add("Text", "xp yp w3 hp Background1994d2 Hidden"))
        this.OtherSettingsControls.Push(this.NavIndicators[6])

        ; 导航项"关于"（未选中态）
        navAbout := this.MainGui.Add("Text", "xs y+m w130 Center", I18n.T("关于"))
        navAbout.OnEvent("Click", (*) => this._SwitchOtherCategory("About"))
        this.NavItems.Push(navAbout)
        this.OtherSettingsControls.Push(navAbout)
        this.NavIndicators.Push(this.MainGui.Add("Text", "xp yp w3 hp Background1994d2 Hidden"))
        this.OtherSettingsControls.Push(this.NavIndicators[7])

        ; 其他设置 - 右侧内容区
        ; 分类"通用"（置首位）
        sepGeneral := this.MainGui.Add("Text", "x160 y48 w530 h1 Backgroundd0d0d0 Center Section")
        sepGeneralTxt := this.MainGui.Add("Text", "xs+40 y+-9 Center ca0a0a0", I18n.T("  通用设置  "))
        this.GeneralControls.Push(sepGeneral)
        this.GeneralControls.Push(sepGeneralTxt)

        ; 界面语言
        txtLanguage := this.MainGui.Add("Text", "xs y+16", I18n.T("界面语言"))
        ddLanguage := this.MainGui.Add("DropDownList", "x+10 yp-3 w140 vLanguage", this._BuildLanguageLabels())
        ddLanguage.OnEvent("Change", (*) => this.TrackChange("Language"))
        this.MainGui["Language"].Value := this._LanguageToIndex(Config.GetImportant("Language"))
        this.GeneralControls.Push(txtLanguage)
        this.GeneralControls.Push(ddLanguage)

        ; 分类"显示"
        sepDisplay := this.MainGui.Add("Text", "x160 y48 w530 h1 Backgroundd0d0d0 Center Section")
        sepDisplayTxt := this.MainGui.Add("Text", "xs+40 y+-9 Center ca0a0a0", I18n.T("  显示设置  "))
        this.DisplayControls.Push(sepDisplay)
        this.DisplayControls.Push(sepDisplayTxt)
        ; 标签管理器迁入“显示”分类后，标题重新锚定到本分类内容区顶部
        sepDisplay.GetPos(, &displayTopY)
        this.TabManagerTitleY := displayTopY + 18

        ; 分类"启动与退出"
        sepLaunch := this.MainGui.Add("Text", "x160 y48 w530 h1 Backgroundd0d0d0 Center Section")
        sepLaunchTxt := this.MainGui.Add("Text", "xs+40 y+-9 Center ca0a0a0", I18n.T("  启动与退出设置  "))
        this.LaunchControls.Push(sepLaunch)
        this.LaunchControls.Push(sepLaunchTxt)

        ; 自动关闭
        checkboxAutoExit := this.MainGui.Add("Checkbox", "xs y+12 h24 vAutoExit", I18n.T(" 随游戏进程关闭自动退出（强烈建议开启）"))
        checkboxAutoExit.OnEvent("Click", (*) => this.TrackChange("AutoExit"))
        this.MainGui["AutoExit"].Value := Config.GetImportant("AutoExit")
        this.LaunchControls.Push(checkboxAutoExit)

        ; 自动打开设置
        checkboxAutoOpenSettings := this.MainGui.Add("Checkbox", "xs y+10 h24 vAutoOpenSettings", I18n.T(" 启动时打开设置窗口"))
        checkboxAutoOpenSettings.OnEvent("Click", (*) => this.TrackChange("AutoOpenSettings"))
        this.MainGui["AutoOpenSettings"].Value := Config.GetImportant("AutoOpenSettings")
        this.LaunchControls.Push(checkboxAutoOpenSettings)

        ; 关闭窗口时退出
        checkboxExitOnWindowClose := this.MainGui.Add("Checkbox", "xs y+10 h24 vExitOnWindowClose", I18n.T(" 点击关闭窗口按钮时退出小助手"))
        checkboxExitOnWindowClose.OnEvent("Click", (*) => this.TrackChange("ExitOnWindowClose"))
        this.MainGui["ExitOnWindowClose"].Value := Config.GetImportant("ExitOnWindowClose")
        this.LaunchControls.Push(checkboxExitOnWindowClose)

        ; 默认启动卫戍协议方案
        checkboxDefaultStrongHoldProtocol := this.MainGui.Add("Checkbox", "xs y+10 h24 vDefaultStrongHoldProtocol",
            I18n.T(" 默认启动卫戍协议方案"))
        checkboxDefaultStrongHoldProtocol.OnEvent("Click", (*) => this.TrackChange("DefaultStrongHoldProtocol"))
        this.MainGui["DefaultStrongHoldProtocol"].Value := Config.GetImportant("DefaultStrongHoldProtocol")
        this.LaunchControls.Push(checkboxDefaultStrongHoldProtocol)

        ; 启动小助手时自动启动下方路径游戏
        checkboxAutoRunGame := this.MainGui.Add("Checkbox", "xs y+10 h24 vAutoRunGame", I18n.T(" 启动小助手时同时启动明日方舟"))
        checkboxAutoRunGame.OnEvent("Click", (*) => this.TrackChange("AutoRunGame"))
        this.MainGui["AutoRunGame"].Value := Config.GetImportant("AutoRunGame")
        this.LaunchControls.Push(checkboxAutoRunGame)

        ; 识别游戏路径
        this.BtnCheckGamePath := this.MainGui.Add("Button", "xs y+12 w" Max(this.BtnW, Metrics.TextWidth(I18n.T("识别游戏路径")) + 14) " h24", I18n.T("识别游戏路径"))
        hintGamePath := this.MainGui.Add("Text", "x+15 yp+4 h20 c9c9c9c", I18n.T("可同时识别所有区服的路径"))
        this.BtnCheckGamePath.OnEvent("Click", (*) => EventBus.Publish("CheckGamePathClick"))
        this.LaunchControls.Push(this.BtnCheckGamePath)
        this.LaunchControls.Push(hintGamePath)

        ; 游戏路径
        txtGamePath := this.MainGui.Add("Text", "xs y+10 h24", I18n.T(" 游戏路径: "))
        editGamePath := this.MainGui.Add("Edit", "x+10 yp-2 w462 h20 vGamePath -Multi +0x1", Config.GetImportant(
            "GamePath"))
        editGamePath.OnEvent("Change", (*) => this.TrackChange("GamePath"))
        this.LaunchControls.Push(txtGamePath)
        this.LaunchControls.Push(editGamePath)

        ; 启动游戏时自动启动小助手
        checkboxAutoStartWithGame := this.MainGui.Add("Checkbox", "xs y+10 h24 vAutoStartWithGame", I18n.T(" 启动明日方舟时自动启动小助手（以下路径均可触发）"))
        checkboxAutoStartWithGame.OnEvent("Click", (*) => this.TrackChange("AutoStartWithGame"))
        this.MainGui["AutoStartWithGame"].Value := Config.GetImportant("AutoStartWithGame")
        this.LaunchControls.Push(checkboxAutoStartWithGame)

        ; 已识别区服路径总览（只读 Edit，便于用户选择复制到上方 GamePath 输入框）
        this.ServerPathsText := this.MainGui.Add("Edit", "xs y+6 w530 r4 ReadOnly vServerPathsText", this._BuildServerPathsText())
        this.LaunchControls.Push(this.ServerPathsText)

        ; 当前运行客户端总览（只读 Edit）
        this.RunningClientsText := this.MainGui.Add("Edit", "xs y+6 w530 r3 ReadOnly vRunningClientsText", this._BuildRunningClientsText())
        this.LaunchControls.Push(this.RunningClientsText)

        ; 分类"更新"
        sepUpdate := this.MainGui.Add("Text", "x160 y48 w530 h1 Backgroundd0d0d0 Center Section")
        sepUpdateTxt := this.MainGui.Add("Text", "xs+40 y+-9 Center ca0a0a0", I18n.T("  更新设置  "))
        this.UpdateControls.Push(sepUpdate)
        this.UpdateControls.Push(sepUpdateTxt)

        ; 更新渠道
        txtUpdateChannel := this.MainGui.Add("Text", "xs y+10", I18n.T("更新渠道"))
        dropdownUpdateChannel := this.MainGui.Add("DropDownList", "x+10 yp-2 w120 vUpdateChannel AltSubmit", [I18n.T("正式版"), I18n.T("测试版")])
        dropdownUpdateChannel.OnEvent("Change", (*) => this.TrackChange("UpdateChannel"))
        dropdownUpdateChannel.Value := Config.GetImportant("UpdateChannel")
        this.UpdateControls.Push(txtUpdateChannel)
        this.UpdateControls.Push(dropdownUpdateChannel)

        ; 更新源
        txtUpdateSource := this.MainGui.Add("Text", "xs y+10", I18n.T("更新源"))
        dropdownUpdateSource := this.MainGui.Add("DropDownList", "x+10 yp-2 w120 vUpdateSource AltSubmit", [I18n.T("国内源"), I18n.T("GitHub")])
        dropdownUpdateSource.OnEvent("Change", (*) => this.TrackChange("UpdateSource"))
        ; 选择国内源时自动灰掉 GitHub Token 行
        dropdownUpdateSource.OnEvent("Change", (*) => this._OnUpdateSourceChange())
        dropdownUpdateSource.Value := Config.GetImportant("UpdateSource")
        this.UpdateControls.Push(txtUpdateSource)
        this.UpdateControls.Push(dropdownUpdateSource)

        ; 自动检查更新
        checkboxAutoUpdate := this.MainGui.Add("Checkbox", "xs y+10 h24 vAutoUpdate", I18n.T(" 自动检查更新"))
        checkboxAutoUpdate.OnEvent("Click", (*) => this.TrackChange("AutoUpdate"))
        this.MainGui["AutoUpdate"].Value := Config.GetImportant("AutoUpdate")
        this.UpdateControls.Push(checkboxAutoUpdate)

        ; 手动检查更新
        this.BtnCheckUpdate := this.MainGui.Add("Button", "xs y+10 w" Max(this.BtnW, Metrics.TextWidth(I18n.T("手动检查更新")) + 14) " h24", I18n.T("手动检查更新"))
        this.BtnCheckUpdate.OnEvent("Click", (*) => this.OnManualCheckClick())
        this.BtnManualDownload := this.MainGui.Add("Button", "x+10 yp w" Max(this.BtnW, Metrics.TextWidth(I18n.T("手动下载更新")) + 14) " h24", I18n.T("手动下载更新"))
        this.BtnManualDownload.OnEvent("Click", (*) => UpdateUI.RequestManualDownload())
        this.UpdateControls.Push(this.BtnCheckUpdate)
        this.UpdateControls.Push(this.BtnManualDownload)

        ; github token
        checkboxUseGitHubToken := this.MainGui.Add("Checkbox", "xs y+10 h24 vUseGitHubToken", I18n.T(" 使用GitHub Token: "))
        checkboxUseGitHubToken.OnEvent("Click", (*) => this.TrackChange("UseGitHubToken"))
        this.MainGui["UseGitHubToken"].Value := Config.GetImportant("UseGitHubToken")
        checkboxUseGitHubToken.OnEvent("Click", (*) => this.SetEditDisabled(editGithubToken, checkboxUseGitHubToken.Value
        ))
        editGithubToken := this.MainGui.Add("Edit", "x+10 yp+2 w382 h20 vGitHubToken Password -Multi +0x1", Config.GetImportant(
            "GitHubToken"))
        editGithubToken.OnEvent("Change", (*) => this.TrackChange("GitHubToken"))
        this.SetEditDisabled(editGithubToken, checkboxUseGitHubToken.Value)
        this.HintGithubToken := this.MainGui.Add("Text", "xs y+6 c9c9c9c", I18n.T("只要没有提示API配额超限，就不需要使用GitHub Token"))
        this.UpdateControls.Push(checkboxUseGitHubToken)
        this.UpdateControls.Push(editGithubToken)
        this.UpdateControls.Push(this.HintGithubToken)

        ; 标签页设置（Hidden 表单变量，供标签管理器读写；置于布局链之前避免破坏"自定义"左列 y 定位）
        this.MainGui.Add("Edit", "Hidden vTabOrder", Config.GetImportant("TabOrder"))
        this.MainGui.Add("Edit", "Hidden vHiddenTabs", Config.GetImportant("HiddenTabs"))

        ; 分类"自定义"
        sepCustom := this.MainGui.Add("Text", "x160 y48 w530 h1 Backgroundd0d0d0 Center Section")
        sepCustomTxt := this.MainGui.Add("Text", "xs+40 y+-9 Center ca0a0a0", I18n.T("  自定义设置  "))
        this.CustomControls.Push(sepCustom)
        this.CustomControls.Push(sepCustomTxt)

        ; 点击延迟设置
        txtClickDelay := this.MainGui.Add("Text", "xs y+10 Section", I18n.T("点击延迟"))
        this.ClickDelay := this.MainGui.Add("Edit", "x+15 y+-18 w120 h21 vClickDelay Number", Config.GetCustom(
            "ClickDelay"))
        this.ClickDelay.OnEvent("Change", (*) => this.TrackChange("ClickDelay"))
        updownClickDelay := this.MainGui.Add("UpDown", , Config.GetCustom("ClickDelay"))
        hintClickDelay := this.MainGui.Add("Text", "xs y+6 h17 Wrap c9c9c9c", I18n.T("从选中单位到按下【技能】【撤退】【出售】的间隔，单位为毫秒，太短点击会失灵"))
        this.CustomControls.Push(txtClickDelay)
        this.CustomControls.Push(this.ClickDelay)
        this.CustomControls.Push(updownClickDelay)
        this.CustomControls.Push(hintClickDelay)

        ; 启用/禁用热键快捷键
        txtSwitchHotkey := this.MainGui.Add("Text", "xs y+16 Right +0x200", I18n.T("启用/禁用热键快捷键"))
        this.SwitchHotkey := this.MainGui.Add("Edit", "x+10 yp-4 w140 Center -TabStop Uppercase vSwitchHotkey", Config.GetCustom(
            "SwitchHotkey"))
        this.CustomControls.Push(txtSwitchHotkey)
        this.CustomControls.Push(this.SwitchHotkey)

        ; 过帧档位1延迟
        txtFrameSkip1 := this.MainGui.Add("Text", "xs y+16 Section", I18n.T("过帧档位1"))
        editFrameSkip1 := this.MainGui.Add("Edit", "x+15 yp-2 w120 h21 vFrameSkip16msDelay Number", Config.GetCustom(
            "FrameSkip16msDelay"))
        editFrameSkip1.OnEvent("Change", (*) => this.TrackChange("FrameSkip16msDelay"))
        this.CustomControls.Push(txtFrameSkip1)
        this.CustomControls.Push(editFrameSkip1)

        ; 过帧档位2延迟
        txtFrameSkip2 := this.MainGui.Add("Text", "xs y+10", I18n.T("过帧档位2"))
        editFrameSkip2 := this.MainGui.Add("Edit", "x+15 yp-2 w120 h21 vFrameSkip33msDelay Number", Config.GetCustom(
            "FrameSkip33msDelay"))
        editFrameSkip2.OnEvent("Change", (*) => this.TrackChange("FrameSkip33msDelay"))
        this.CustomControls.Push(txtFrameSkip2)
        this.CustomControls.Push(editFrameSkip2)

        ; 过帧档位3延迟
        txtFrameSkip3 := this.MainGui.Add("Text", "xs y+10", I18n.T("过帧档位3"))
        editFrameSkip3 := this.MainGui.Add("Edit", "x+15 yp-2 w120 h21 vFrameSkip166msDelay Number", Config.GetCustom(
            "FrameSkip166msDelay"))
        editFrameSkip3.OnEvent("Change", (*) => this.TrackChange("FrameSkip166msDelay"))
        this.CustomControls.Push(txtFrameSkip3)
        this.CustomControls.Push(editFrameSkip3)

        ; 失焦悬停操作热键开关（#213 功能开关，默认开启；保存/应用后生效）。整行通栏，宽度按语言自适应不换行。
        checkboxHoverOperate := this.MainGui.Add("Checkbox", "xs y+14 w" Max(290, Metrics.TextWidth(I18n.T("游戏窗口未激活时允许鼠标悬停在窗口上触发热键")) + 24) " h24 vHoverOperate", I18n.T("游戏窗口未激活时允许鼠标悬停在窗口上触发热键"))
        checkboxHoverOperate.OnEvent("Click", (*) => this.TrackChange("HoverOperate"))
        this.MainGui["HoverOperate"].Value := Config.GetCustom("HoverOperate")
        this.CustomControls.Push(checkboxHoverOperate)

        ; 标签页可见性与顺序（右列标题动态对齐左列第一项）
        tabManagerTitle := this.MainGui.Add("Text", "x" this.TabManagerX " y" this.TabManagerTitleY " w" this.TabManagerRowWidth
            " h20 c333333", I18n.T("顶部标签页"))
        tabManagerTitle.SetFont("bold")
        tabManagerHint := this.MainGui.Add("Text", "xp y" (this.TabManagerTitleY + 20) " w258 c8a8a8a", I18n.T("拖拽调整顺序，点击眼睛切换显示/隐藏"))
        ; 首行 y 跟随提示实际高度（不固定 h，长文案换行时自动增高，行首下移避免重叠）
        tabManagerHint.GetPos(, , , &tabHintH)
        this.TabManagerRowStartY := this.TabManagerTitleY + 20 + tabHintH + 7
        this.DisplayControls.Push(tabManagerTitle)
        this.DisplayControls.Push(tabManagerHint)
        for index, tabItem in this.TabItems {
            rowY := this.TabManagerRowStartY + (index - 1) * this.TabManagerRowHeight
            tabItem.RowBackground := this.MainGui.Add("Text", "x" this.TabManagerX " y" rowY
                " w" this.TabManagerRowWidth " h26 BackgroundF5F7FA +0x100")
            ; 高亮层：与背景层同位置叠放，通过 Visible 切换（AHK 对 Text 控件运行时改背景色不可靠，故用双控件）
            tabItem.RowHighlight := this.MainGui.Add("Text", "x" this.TabManagerX " y" rowY
                " w" this.TabManagerRowWidth " h26 BackgroundEAF2FB +0x100")
            tabItem.RowHighlight.Visible := false
            tabItem.DragControl := this.MainGui.Add("Text", "x" (this.TabManagerX + 9) " y" (rowY + 4)
                " w24 h18 Center cA8ADB5 +0x100", "⋮⋮")
            tabItem.ManagerLabel := this.MainGui.Add("Text", "x" (this.TabManagerX + 40) " y" (rowY + 4)
                " w150 h18 +0x100", tabItem.Label)
            tabItem.EyeControl := this.MainGui.Add("Text", "x" (this.TabManagerX + 201) " y" (rowY + 4)
                " w24 h18 Center +0x100", Chr(0xE890))
            tabItem.EyeControl.SetFont("s11 c1994d2", "Segoe MDL2 Assets")
            this.DisplayControls.Push(tabItem.RowBackground)
            this.DisplayControls.Push(tabItem.RowHighlight)
            this.DisplayControls.Push(tabItem.DragControl)
            this.DisplayControls.Push(tabItem.ManagerLabel)
            this.DisplayControls.Push(tabItem.EyeControl)
        }

        ; 分类"日志"
        sepLog := this.MainGui.Add("Text", "x160 y48 w530 h1 Backgroundd0d0d0 Center Section")
        sepLogTxt := this.MainGui.Add("Text", "xs+40 y+-9 Center ca0a0a0", I18n.T("  日志设置  "))
        this.LogControls.Push(sepLog)
        this.LogControls.Push(sepLogTxt)

        logButtonX := 160 + (530 - 160) // 2
        logButtonW := Max(160, Metrics.TextWidth(I18n.T("生成日志压缩包")) + 14, Metrics.TextWidth(I18n.T("打开日志文件夹")) + 14)
        btnCreateLogArchive := this.MainGui.Add("Button", "x" logButtonX " y+16 w" logButtonW " h28", I18n.T("生成日志压缩包"))
        btnCreateLogArchive.OnEvent("Click", (*) => LogExporter.CreateArchiveInteractive())
        this.LogControls.Push(btnCreateLogArchive)

        btnOpenLogDirectory := this.MainGui.Add("Button", "x" logButtonX " y+8 w" logButtonW " h28", I18n.T("打开日志文件夹"))
        btnOpenLogDirectory.OnEvent("Click", (*) => LogExporter.OpenLogDirectory())
        this.LogControls.Push(btnOpenLogDirectory)

        chkDebug := this.MainGui.Add("Checkbox", "xs y+16 h24 vDebugEnabled", I18n.T(" 启用调试模式（实时日志窗口，日志额外记录调试信息）"))
        chkDebug.OnEvent("Click", (*) => this.TrackChange("DebugEnabled"))
        this.MainGui["DebugEnabled"].Value := Config.GetImportant("DebugEnabled")
        this.LogControls.Push(chkDebug)

        ; 分类"关于"
        logoPath := FileExtractor.LogoPath

        this.MainGui.Add("Text", "x160 y48 w0 h0 Section")
        logoSize := 192
        logoX := 160 + (530 - logoSize) / 2
        aboutLogo := this.MainGui.Add("Picture", "x" logoX " y48 w" logoSize " h" logoSize, logoPath)
        this.AboutControls.Push(aboutLogo)

        this.MainGui.SetFont("s12 bold", Metrics.FontFor(I18n.GetCurrent()))
        aboutVersion := this.MainGui.Add("Text", "xs y+10 w530 Center", Version.Get())
        this.MainGui.SetFont("s9 c0645AD underline", Metrics.FontFor(I18n.GetCurrent()))
        this.AboutControls.Push(aboutVersion)

        aboutChangelog := this.MainGui.Add("Text", "xs y+15 w530 Center", I18n.T("更新公告"))
        aboutChangelog.OnEvent("Click", (*) => this._ShowChangelog())
        this.AboutControls.Push(aboutChangelog)

        aboutRepo := this.MainGui.Add("Text", "xs y+8 w530 Center", I18n.T("GitHub仓库"))
        aboutRepo.OnEvent("Click", (*) => Run("https://github.com/CloudTracey/arknights-frame-assistant"))
        this.AboutControls.Push(aboutRepo)

        aboutFeedback := this.MainGui.Add("Text", "xs y+8 w530 Center", I18n.T("反馈与建议"))
        aboutFeedback.OnEvent("Click", (*) => Run("https://github.com/CloudTracey/arknights-frame-assistant/issues"))
        this.AboutControls.Push(aboutFeedback)

        aboutBilibili := this.MainGui.Add("Text", "xs y+8 w530 Center", I18n.T("我的B站主页"))
        aboutBilibili.OnEvent("Click", (*) => Run("https://space.bilibili.com/34961731"))
        this.AboutControls.Push(aboutBilibili)

        aboutArtist := this.MainGui.Add("Text", "xs y+8 w530 Center", I18n.T("图标画师"))
        aboutArtist.OnEvent("Click", (*) => Run("https://www.mihuashi.com/profiles/8282001?role=painter"))
        this.AboutControls.Push(aboutArtist)

        this.MainGui.SetFont("s9 cDefault norm", Metrics.FontFor(I18n.GetCurrent()))

        ; 隐藏非默认分类的控件
        this._HideOtherCategories()
        this._ShowControls(this.LaunchControls)  ; 默认显示"启动与退出"

        ; 底部按钮区域锚点，"常规作战"帧率提示底部 + 20px 间距
        this.MainGui.Add("Text", "xm y" this._BottomBaseY + 20 " w0 h0 Section")

        ; -- 底部按钮 --
        BtnMargin := 15
        BtnX_DefaultHotkeys := 30
        BtnX_Save := this.GuiWidth - (this.BtnW * 3) - BtnMargin * 2 - BtnX_DefaultHotkeys
        BtnX_Apply := this.GuiWidth - (this.BtnW * 2) - BtnMargin * 1 - BtnX_DefaultHotkeys
        BtnX_Cancel := this.GuiWidth - this.BtnW - BtnX_DefaultHotkeys

        this.BtnDefaultHotkeys := this.MainGui.Add("Button", "x" BtnX_DefaultHotkeys " ys+15 w" this.BtnW " h32",
            I18n.T("重置按键")) ; 仅在按键相关标签下显示
        this.BtnDefaultHotkeys.OnEvent("Click", (*) => EventBus.Publish("SettingsResetRequested"))
        this.NotOtherControls.Push(this.BtnDefaultHotkeys)

        this.BtnSave := this.MainGui.Add("Button", "x" BtnX_Save " yp w" this.BtnW " h32 Default Disabled", I18n.T("保存并关闭"))
        this.BtnSave.OnEvent("Click", (*) => EventBus.Publish("SettingsSaveRequested"))
        this.BtnApply := this.MainGui.Add("Button", "x" BtnX_Apply " yp w" this.BtnW " h32 Default Disabled", I18n.T("应用设置"))
        this.BtnApply.OnEvent("Click", (*) => EventBus.Publish("SettingsApplyRequested"))
        this.BtnCancel := this.MainGui.Add("Button", "x" BtnX_Cancel " yp w" this.BtnW " h32", I18n.T("取消"))
        this.BtnCancel.OnEvent("Click", (*) => EventBus.Publish("SettingsCancelRequested"))
        ; 底部提示宽度按当前语言最长文案动态计算，且避免与左侧"重置按键"按钮重叠
        hintUnsavedW := Max(Metrics.TextWidth(I18n.T("存在按键冲突")), Metrics.TextWidth(I18n.T("修改尚未保存或应用")), Metrics.TextWidth(I18n.T("修改尚未保存或应用！"))) + 10
        this.HintUnsaved := this.MainGui.Add("Text", "x" (BtnX_Save - hintUnsavedW - 10) " yp+8 w" hintUnsavedW " h24 Right cFF0000 Hidden",
        I18n.T("修改尚未保存或应用！"))

        ; 空白占位
        this.MainGui.Add("Text", "xm y+15 w1 h1")
    }

    ; 内部：更新热键控件值（从配置）
    static _UpdateHotkeyControlsFromConfig() {
        for key, value in Config.AllHotkeys {
            try {
                value := KeyFormat.VirtualNewkeyFormat(value)
                this.MainGui[key].Value := value
            }
        }
        this._UpdateFrameSkipLabels()
    }

    static _UpdateFrameSkipLabels() {
        try this.FrameSkipLabels["16ms"].Text := I18n.T("前进 {1}ms", this.MainGui["FrameSkip16msDelay"].Value)
        try this.FrameSkipLabels["33ms"].Text := I18n.T("前进 {1}ms", this.MainGui["FrameSkip33msDelay"].Value)
        try this.FrameSkipLabels["166ms"].Text := I18n.T("前进 {1}ms", this.MainGui["FrameSkip166msDelay"].Value)
    }

    ; 内部：预建一行自定义按键控件（label + 绑定 Edit + 齿轮 + ✕，初始隐藏）
    ; 事件用 ObjBindMethod 绑定行号，避免 for 循环闭包变量捕获陷阱。
    static _CreateCustomHotkeyRow(i) {
        half := Constants.CustomHotkeyMax / 2
        colX := (i <= half) ? 0 : this.ColWidth
        rowY := this.CustomHotkeyRowStartY + Mod(i - 1, half) * this.CustomHotkeyRowHeight
        label := this.MainGui.Add("Text", "x" colX " y" rowY " w135 Right +0x200 Hidden", "")
        edit := this.MainGui.Add("Edit", "x" (colX + 155) " y" (rowY - 4) " w120 Center -TabStop Uppercase vCustomHotkey" i "Key Hidden", "")
        gear := this.MainGui.Add("Button", "x" (colX + 281) " y" (rowY - 4) " w20 h20 vCustomHotkey" i "Gear Hidden", Chr(0xE713))
        gear.SetFont("s11 c1994d2", "Segoe MDL2 Assets")
        del := this.MainGui.Add("Button", "x" (colX + 305) " y" (rowY - 4) " w20 h20 vCustomHotkey" i "Del Hidden", "✕")
        gear.OnEvent("Click", ObjBindMethod(GuiManager, "_OnCustomGearClick", i))
        del.OnEvent("Click", ObjBindMethod(GuiManager, "_OnCustomDelClick", i))
        row := {Label: label, Edit: edit, Gear: gear, Del: del}
        this.CustomRows.Push(row)
        this.CustomKeyControls.Push(label)
        this.CustomKeyControls.Push(edit)
        this.CustomKeyControls.Push(gear)
        this.CustomKeyControls.Push(del)
    }

    ; 从 Config 工作副本刷新全部自定义行（显隐、名称标签、绑定值、新增按钮可用态）
    static _RefreshCustomHotkeyRows() {
        entries := Config.AllCustomHotkeys
        count := entries.Length
        for i, row in this.CustomRows {
            visible := i <= count
            try row.Label.Visible := visible
            try row.Edit.Visible := visible
            try row.Gear.Visible := visible
            try row.Del.Visible := visible
            if visible {
                name := Trim(entries[i].Name)
                row.Label.Text := name != "" ? name : I18n.T("自定义按键 {1}", i)
                row.Edit.Value := KeyFormat.VirtualNewkeyFormat(entries[i].Key)
            }
        }
        try this.MainGui["BtnAddCustom"].Enabled := count < Constants.CustomHotkeyMax
    }

    ; 编辑窗口保存后刷新单行标签（供 CustomKeyEditor 回调）
    static RefreshCustomRow(index) {
        if index < 1 || index > this.CustomRows.Length
            return
        entries := Config.AllCustomHotkeys
        if index > entries.Length
            return
        name := Trim(entries[index].Name)
        this.CustomRows[index].Label.Text := name != "" ? name : I18n.T("自定义按键 {1}", index)
    }

    ; 点击"新增按键"
    static _OnAddCustomHotkey() {
        if Config.CustomHotkeyCount() >= Constants.CustomHotkeyMax {
            MessageBox.Info(I18n.T("最多可添加 {1} 个自定义按键", Constants.CustomHotkeyMax), I18n.T("提示"))
            return
        }
        CustomKeyEditor.Close()   ; D11：行集合变化前先关编辑窗口
        Config.AddCustomHotkey()
        this._RefreshCustomHotkeyRows()
        this.TrackCustomHotkeysChange()
        this.RefreshHotkeyConflicts()
    }

    ; 点击某行的 ✕（删除确认后移除并前移后续行）
    static _OnCustomDelClick(index, ctrl, info) {
        result := MessageBox.Confirm(I18n.T("确定删除该自定义按键吗？"), I18n.T("删除自定义按键"))
        if result != "Yes"
            return
        CustomKeyEditor.Close()   ; D11
        Config.RemoveCustomHotkeyAt(index)
        this._RefreshCustomHotkeyRows()
        this.TrackCustomHotkeysChange()
        this.RefreshHotkeyConflicts()
    }

    ; 点击某行的齿轮（单编辑窗口：未保存修改丢弃，直接切换目标行）
    static _OnCustomGearClick(index, ctrl, info) {
        CustomKeyEditor.Open(index)
    }

    ; 快照深拷贝（自定义按键工作副本 → 字符串对象数组）
    static _CloneCustomHotkeys(entries) {
        result := []
        for entry in entries
            result.Push({Key: entry.Key, Name: entry.Name, Script: entry.Script, Type: entry.Type})
        return result
    }

    ; 自定义按键工作副本与快照逐行对比
    static _CustomHotkeysEqual(a, b) {
        if a.Length != b.Length
            return false
        loop a.Length {
            if a[A_Index].Key != b[A_Index].Key
                || a[A_Index].Name != b[A_Index].Name
                || a[A_Index].Script != b[A_Index].Script
                || a[A_Index].Type != b[A_Index].Type
                return false
        }
        return true
    }

    ; 自定义按键变更后的脏值评估（绑定改键/编辑窗口保存/增删行后调用）
    static TrackCustomHotkeysChange() {
        if !this._CustomHotkeysEqual(Config.AllCustomHotkeys, this._InitialCustomHotkeys) {
            this.SetIsModifiedTrue()
            return
        }
        if this._AllControlsMatchSnapshot()
            this.SetIsModifiedFalse()
    }

    ; 冲突检测用投影：工作副本 → Array<{Index, Key, Type}>
    static _ProjectCustomHotkeys() {
        result := []
        for i, entry in Config.AllCustomHotkeys
            result.Push({Index: i, Key: entry.Key, Type: entry.Type})
        return result
    }

    ; 内部：更新其他控件值（从配置）
    static _UpdateImportantControlsFromConfig() {
        tabSettingsChanged := false
        try {
            tabSettingsChanged := (
                this.MainGui["TabOrder"].Value != Config.GetImportant("TabOrder")
                || this.MainGui["HiddenTabs"].Value != Config.GetImportant("HiddenTabs")
            )
        }
        for key, value in Config.AllImportant {
            try {
                if (key = "Frame") {
                    this.MainGui[key].Value := this._FrameTextToIndex(Config.GetImportant("Frame"))
                } else if (key = "Language") {
                    this.MainGui[key].Value := this._LanguageToIndex(Config.GetImportant("Language"))
                } else {
                    this.MainGui[key].Value := value
                }
            }
        }
        if tabSettingsChanged {
            this.LoadTabSettingsFromConfig()
            this.ApplyTabSettings()
        }
    }

    ; 内部：更新其他控件值（从配置）
    static _UpdateCustomControlsFromConfig() {
        for key, value in Config.AllCustom {
            try {
                value := KeyFormat.VirtualNewkeyFormat(value)
                this.MainGui[key].Value := value
            }
        }
        this.RefreshHotkeyConflicts()
    }

    ; 计算热键绑定行的标签列宽：用独立临时窗口探测各语言标签的**真实**像素宽度（避免估算误差导致换行），
    ; 标签右缘固定 135（右对齐，可向左延长不越窗口左缘），下限 120 保证中文基准不变。
    static _ComputeBindLabelWidth() {
        maxW := 0
        probeGui := Gui()
        probeGui.SetFont("s9", Metrics.FontFor(I18n.GetCurrent()))
        for item in HotkeySchema.Items {
            probe := probeGui.Add("Text", , I18n.T(item.nameKey))
            probe.GetPos(, , &pw)
            if (pw > maxW)
                maxW := pw
        }
        probeGui.Destroy()
        return Min(Max(maxW + 6, 120), 135)
    }

    ; 内部：按分组返回 Schema 热键项（排除 GUI 特殊行 AutoBeginPauseSwitch，由手工布局创建）
    static _GetSchemaItems(group) {
        result := []
        for item in HotkeySchema.Items {
            if (item.group = group && item.id != "AutoBeginPauseSwitch")
                result.Push(item)
        }
        return result
    }

    ; 内部：订阅事件总线（幂等，重建时不会重复订阅）
    static _SubscribeEvents() {
        if (this._EventsSubscribed)
            return
        this._EventsSubscribed := true
        ; Legacy 旧事件（仅 Bootstrap 启动时发布；内部标签切换直接调用刷新方法，不再自发布）
        EventBus.Subscribe("GuiUpdateHotkeyControls", (*) => this._UpdateHotkeyControlsFromConfig())    ; Legacy
        EventBus.Subscribe("GuiUpdateImportantControls", (*) => this._UpdateImportantControlsFromConfig()) ; Legacy
        EventBus.Subscribe("GuiUpdateCustomControls", (*) => this._UpdateCustomControlsFromConfig())      ; Legacy
        EventBus.Subscribe("HotkeyBindingsChanged", (*) => this.RefreshHotkeyConflicts())
        EventBus.Subscribe("KeyBindFocusCancel", (*) => this.FocusCancelButton())
        EventBus.Subscribe("GuiHideStopHook", HandleGuiHideStopHook)
        EventBus.Subscribe("UpdateCheckCompleted", (*) => this.OnCheckUpdateComplete())
        EventBus.Subscribe("UpdateCheckStarted", (*) => this.OnCheckUpdateStart())
        EventBus.Subscribe("SettingsShowRequested", (*) => this.Show())
        EventBus.Subscribe("HotkeyStateChanged", (data) => this._OnHotkeyStateChanged(data))
        EventBus.Subscribe("HotkeyGroupChanged", (data) => this._OnHotkeyGroupChanged(data))
        EventBus.Subscribe("SwitchKeyChanged", (data) => this._OnSwitchKeyChanged(data))
        EventBus.Subscribe("SettingsSaved", (*) => this._OnSettingsSaved())
        EventBus.Subscribe("SettingsApplied", (*) => this._OnSettingsApplied())
        EventBus.Subscribe("SettingsCancelled", (*) => this._OnSettingsCancelled())
        EventBus.Subscribe("SettingsReset", (*) => this._OnSettingsReset())
        EventBus.Subscribe("SettingsChanged", (data) => this._OnSettingsChanged(data))
        EventBus.Subscribe("GamePathNormalized", (data) => this.SetControlValue("GamePath", data.path))
        EventBus.Subscribe("GamePathDetected", (data) => this._OnGamePathDetected(data))
        EventBus.Subscribe("SettingsViewRefreshRequested", (data) => this._OnSettingsViewRefreshRequested(data))
        EventBus.Subscribe("ConsoleOpened", (*) => this._OnConsoleOpened())
        EventBus.Subscribe("ChangelogAvailable", (*) => this._OnChangelogAvailable())
        EventBus.Subscribe("LocaleChanged", (data) => this._OnLocaleChanged(data))
        EventBus.Subscribe("GameClientsChanged", (data) => this._OnGameClientsChanged(data))
        EventBus.Subscribe("ForegroundClientChanged", (data) => this._OnForegroundClientChanged(data))
    }

    static _OnGameClientsChanged(data) {
        Logger.Debug("Gui", "游戏客户端集合变化，数量=" data.clients.Length)
        this._RefreshServerPathsText()
        this._RefreshRunningClientsText()
    }

    static _OnForegroundClientChanged(data) {
        Logger.Debug("Gui", "前台客户端变化：serverId=" data.serverId ", pid=" data.pid)
        this._RefreshRunningClientsText()
        this._UpdateTrayServer(data.serverId)
    }

    ; 托盘提示带当前前台区服。
    ; 只有前台确实是游戏客户端时才更新；切到桌面/非游戏窗口时保留上次游戏区服，避免显示“未知区服”。
    static _UpdateTrayServer(serverId) {
        if (serverId = "")
            return
        serverName := I18n.T("未知区服")
        profile := ServerProfile.Get(serverId)
        if (profile != "")
            serverName := I18n.T(profile.DisplayNameKey)
        state := HotkeyService.HotkeyState ? I18n.T("热键已启用") : I18n.T("热键已禁用")
        A_IconTip := "AFA`n" serverName " - " state
    }

    ; 语言切换：记录变更，保存/应用后统一重建
    static _OnLocaleChanged(data) {
        Logger.Info("Gui", "语言切换：" data.previous " -> " data.locale)
        if (data.locale != data.previous)
            this._LanguageChanged := true
        if (this.MainGui != "")
            this.MainGui.Title := I18n.T("明日方舟帧操小助手 ArknightsFrameAssistant - {1}", Version.Get())
    }

    ; 处理热键总开关状态变化（托盘文案/提示由 UI 负责）
    static _OnHotkeyStateChanged(data) {
        HideTrayTip()
        SetTimer HideTrayTip, 0
        if (data.enabled) {
            A_IconTip := "AFA`n" I18n.T("热键已启用")
            ShowTrayTip(I18n.T("热键已启用"), "AFA", "Mute")
        } else {
            A_IconTip := "AFA`n" I18n.T("热键已禁用")
            ShowTrayTip(I18n.T("热键已禁用"), "AFA", "Mute")
        }
        SetTimer HideTrayTip, -3000
    }

    ; 处理热键组变化（卫戍协议/常规作战切换提示）
    static _OnHotkeyGroupChanged(data) {
        isStrongHold := data.group = "strongHoldProtocol"
        if (this.IsOnStrongHoldProtocol != isStrongHold) {
            this.IsOnStrongHoldProtocol := isStrongHold
            ; 热键禁用时不弹提示（与旧逻辑一致）
            if (!HotkeyService.HotkeyState)
                return
            HideTrayTip()
            SetTimer HideTrayTip, 0
            if (isStrongHold)
                ShowTrayTip(I18n.T("已启用卫戍协议方案"), "AFA", "Mute")
            else
                ShowTrayTip(I18n.T("已退出卫戍协议方案"), "AFA", "Mute")
            SetTimer HideTrayTip, -3000
        }
    }

    ; 处理切换键变化（托盘菜单文案）
    static _OnSwitchKeyChanged(data) {
        if (data.key = "")
            A_TrayMenu.Rename("2&", I18n.T("启用/禁用热键"))
        else
            A_TrayMenu.Rename("2&", I18n.T("启用/禁用热键") "(" KeyFormat.VirtualNewkeyFormat(data.key) ")")
    }

    ; 处理设置已保存
    static _OnSettingsSaved() {
        if (this._LanguageChanged) {
            this._LanguageChanged := false
            this.Hide()
            this.Rebuild()
            this.Hide()
            return
        }
        this.CommitTabSettings()
        this.SetIsModifiedFalse()
        this.CaptureInitialSnapshot()
        this.Hide()
    }

    ; 处理设置已应用
    static _OnSettingsApplied() {
        if (this._LanguageChanged) {
            this._LanguageChanged := false
            this.Rebuild()
            return
        }
        this.CommitTabSettings()
        this.SetIsModifiedFalse()
        this.CaptureInitialSnapshot()
    }

    ; 处理设置已取消
    static _OnSettingsCancelled() {
        this._UpdateHotkeyControlsFromConfig()
        this._UpdateImportantControlsFromConfig()
        this._UpdateCustomControlsFromConfig()
        this._RefreshCustomHotkeyRows()
        this.SetIsModifiedFalse()
        this.CaptureInitialSnapshot()
        this.Hide()
    }

    ; 处理按键已重置
    static _OnSettingsReset() {
        ; 重置只持久化热键相关项；非热键未保存修改应继续保持“已修改”状态。
        ; 自定义按键不受重置影响（访谈决策：重置不动自定义按键），行刷新保持原状。
        this._UpdateHotkeyControlsFromConfig()
        this._UpdateCustomControlsFromConfig()
        this._RefreshCustomHotkeyRows()
        ; 仅把热键与 SwitchHotkey 的初始快照更新为已保存的默认值
        for key in Config.AllHotkeys {
            try this._InitialValues[key] := this.MainGui[key].Value
        }
        try this._InitialValues["SwitchHotkey"] := this.MainGui["SwitchHotkey"].Value
        ; 重新评估脏状态：若还有其他未保存的非热键修改，保持 IsModified=true
        this.TrackChange("SwitchHotkey")
    }

    ; 处理单键设置变更（外部写入后同步对应控件，不标记脏值）
    static _OnSettingsChanged(data) {
        try {
            if (data.key = "Frame") {
                this.MainGui["Frame"].Value := this._FrameTextToIndex(data.value)
                return
            }
            if (data.key = "AutoBeginPause") {
                this.MainGui["AutoBeginPause"].Value := (data.value = "1" || data.value = 1) ? 1 : 0
                return
            }
            if (data.key = "Language") {
                this.MainGui["Language"].Value := this._LanguageToIndex(data.value)
                return
            }
            value := data.value
            if (Config.AllHotkeys.Has(data.key) || data.key = "SwitchHotkey")
                value := KeyFormat.VirtualNewkeyFormat(value)
            this.MainGui[data.key].Value := value
        }
    }

    ; 生成“已识别区服路径”多行文本
    static _BuildServerPathsText() {
        text := I18n.T("已识别区服路径：")
        found := false
        for serverId in ["CN", "JP", "KR", "EN"] {
            path := Config.GetImportant("GamePath" serverId)
            if (path != "") {
                text .= "`n" serverId ": " path
                found := true
            }
        }
        if (!found)
            text .= "`n" I18n.T("（尚未识别到区服路径）")
        return text
    }

    ; 刷新已识别区服路径总览
    static _RefreshServerPathsText() {
        if (this.ServerPathsText != "")
            this.ServerPathsText.Value := this._BuildServerPathsText()
    }

    ; 生成“当前运行客户端”多行文本
    static _BuildRunningClientsText() {
        clients := GameClientRegistry.GetClients()
        text := I18n.T("当前运行客户端：")
        if (clients.Length = 0) {
            text .= "`n" I18n.T("（无）")
            return text
        }
        for client in clients {
            serverName := I18n.T("未知区服")
            profile := ServerProfile.Get(client.serverId)
            if (profile != "")
                serverName := I18n.T(profile.DisplayNameKey)
            text .= "`n" serverName " (pid=" client.pid ", hwnd=" client.hwnd ")"
        }
        return text
    }

    ; 刷新当前运行客户端总览
    static _RefreshRunningClientsText() {
        if (this.RunningClientsText != "")
            this.RunningClientsText.Value := this._BuildRunningClientsText()
    }

    ; 处理游戏路径检测到事件：仅在 GamePath 为空时填充，避免覆盖用户已有默认启动路径
    static _OnGamePathDetected(data) {
        if (Config.GetImportant("GamePath") = "") {
            this.SetControlValue("GamePath", data.path)
            this.TrackChange("GamePath")
        }
        this._RefreshServerPathsText()
    }

    ; 处理设置视图刷新请求
    static _OnSettingsViewRefreshRequested(data) {
        this._UpdateHotkeyControlsFromConfig()
        this._UpdateImportantControlsFromConfig()
        this._UpdateCustomControlsFromConfig()
        this._RefreshCustomHotkeyRows()
        this._RefreshServerPathsText()
        this._RefreshRunningClientsText()
    }

    ; 处理调试控制台打开事件
    static _OnConsoleOpened() {
        ShowTrayTip(I18n.T("调试日志控制台已打开"), "AFA", "Mute")
        SetTimer HideTrayTip, -3000
    }

    ; 处理更新公告可用事件（展示由 ChangelogUI 负责，此处预留）
    static _OnChangelogAvailable() {
    }

    ; 点击"手动检查更新"按钮
    static OnManualCheckClick() {
        EventBus.Publish("UpdateCheckRequested")
    }

    ; 检查完成，恢复按钮
    static OnCheckUpdateComplete() {
        try {
            this.BtnCheckUpdate.Opt("-Disabled")
            this.BtnCheckUpdate.Text := I18n.T("手动检查更新")
        }
    }

    ; 检查开始，禁用按钮
    static OnCheckUpdateStart() {
        try {
            this.BtnCheckUpdate.Opt("+Disabled")
            this.BtnCheckUpdate.Text := I18n.T("检查中...")
        }
    }

    ; 显示GUI窗口
    static Show() {
        this.MainGui.Show()
        this.CaptureInitialSnapshot()
        this.RefreshHotkeyConflicts()
        this.SetIsModifiedFalse()  ; 确保按钮为禁用状态
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

    ; 聚焦取消按钮
    static FocusCancelButton() {
        this.BtnCancel.Focus()
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

    ; 更新源切换时联动 Token 行的启用/禁用
    static _OnUpdateSourceChange() {
        try {
            isGitHub := (this.MainGui["UpdateSource"].Value == 2)  ; 2 = GitHub
            this.MainGui["UseGitHubToken"].Enabled := isGitHub
            this.MainGui["GitHubToken"].Enabled := isGitHub
            this.HintGithubToken.Enabled := isGitHub
        }
    }

    ; 将修改状态改为已修改
    static SetIsModifiedTrue() {
        this.IsModified := true
        this.UpdateSaveButtonState()
    }

    ; 将修改状态改为未修改
    static SetIsModifiedFalse() {
        this.IsModified := false
        this.UpdateSaveButtonState()
    }

    ; 根据修改状态和冲突状态更新提示与保存按钮。
    static UpdateSaveButtonState() {
        canSave := this.IsModified && !this.HasHotkeyConflicts

        ; #287：若当前焦点在即将被禁用的“保存/应用”按钮上，先移到始终可用的“取消”，
        ; 否则系统会按 Tab 顺序把焦点甩到当前分类第一个可聚焦控件（自定义页即“点击延迟”）。
        if (!canSave
            && IsObject(this.BtnSave) && IsObject(this.BtnApply)
            && (this.BtnSave.Focused || this.BtnApply.Focused)) {
            try this.BtnCancel.Focus()
        }

        try this.BtnSave.Enabled := canSave
        try this.BtnApply.Enabled := canSave

        try {
            if this.HasHotkeyConflicts {
                this.HintUnsaved.Text := I18n.T("存在按键冲突")
                this.HintUnsaved.Visible := true
            } else {
                this.HintUnsaved.Text := I18n.T("修改尚未保存或应用")
                this.HintUnsaved.Visible := this.IsModified
            }
        }
    }

    ; 重新计算冲突并增量标红冲突输入框，避免全量控件闪烁。
    static RefreshHotkeyConflicts() {
        result := HotkeyConflictValidator.FindAll(
            Config.AllHotkeys,
            Config.AllCustom,
            this._ProjectCustomHotkeys()
        )

        ; 构建本次冲突控件集合
        newConflicted := Map()
        for controlName, _ in result.ByControl
            newConflicted[controlName] := true

        ; 仅恢复不再冲突的控件颜色
        for controlName, _ in this._PrevConflictedControls {
            if !newConflicted.Has(controlName)
                try this.MainGui[controlName].SetFont("cDefault")
        }

        ; 仅标红新增的冲突控件
        for controlName, _ in newConflicted {
            if !this._PrevConflictedControls.Has(controlName)
                try this.MainGui[controlName].SetFont("cD93025")
        }

        this._PrevConflictedControls := newConflicted
        this.HasHotkeyConflicts := result.HasConflicts
        this.UpdateSaveButtonState()
    }

    ; 捕获初始值快照（从当前 GUI 控件值读取）
    static CaptureInitialSnapshot() {
        this._InitialValues := Map()
        ; 热键控件 — GUI 显示的是 VirtualNewkeyFormat 后的值
        for key in Config.AllHotkeys {
            try {
                this._InitialValues[key] := this.MainGui[key].Value
            }
        }
        ; Important 设置
        for key in this.GuiImportantKeys {
            try {
                this._InitialValues[key] := this.MainGui[key].Value
            }
        }
        ; Custom 设置
        try {
            this._InitialValues["SwitchHotkey"] := this.MainGui["SwitchHotkey"].Value
        }
        try {
            this._InitialValues["ClickDelay"] := this.MainGui["ClickDelay"].Value
        }
        for key in this.FrameSkipDelayKeys {
            try {
                this._InitialValues[key] := this.MainGui[key].Value
            }
        }
        ; 失焦悬停操作开关
        try {
            this._InitialValues["HoverOperate"] := this.MainGui["HoverOperate"].Value
        }
        ; 自定义按键（深拷贝快照，供 TrackCustomHotkeysChange 对比）
        this._InitialCustomHotkeys := this._CloneCustomHotkeys(Config.AllCustomHotkeys)
    }

    ; 跟踪控件变更——与初始快照对比，决定按钮启用/禁用
    static TrackChange(controlName) {
        ; 自定义按键绑定控件：委托给自定义行对比逻辑
        if RegExMatch(controlName, "^CustomHotkey\d+Key$") {
            this.TrackCustomHotkeysChange()
            return
        }
        try {
            currentValue := this.MainGui[controlName].Value
        } catch {
            return
        }
        ; 将当前值同步到 Config 内存，确保切换标签页后编辑不丢失
        ; 热键控件和 SwitchHotkey 已由 KeyBinder.EndChange 提前写入，此处仅处理其余控件
        if (Config.AllImportant.Has(controlName)) {
            if (controlName = "Frame")
                Config.SetImportant("Frame", Constants.FrameOptions[currentValue])
            else if (controlName = "Language") {
                Config.SetImportant("Language", this.LanguageCodes[currentValue])
            }
            else
                Config.SetImportant(controlName, currentValue)
        }
        else if (Config.AllCustom.Has(controlName) && controlName != "SwitchHotkey") {
            Config.SetCustom(controlName, currentValue)
        }
        if (this._InitialValues.Has(controlName) && currentValue == this._InitialValues[controlName]) {
            ; 该控件值已恢复初始——检查所有控件是否全部一致
            if this._AllControlsMatchSnapshot()
                this.SetIsModifiedFalse()
        } else {
            ; 有差异
            this.SetIsModifiedTrue()
        }
    }

    ; 所有控件（热键/重要/自定义/自定义按键）是否与初始快照一致
    static _AllControlsMatchSnapshot() {
        for key in Config.AllHotkeys {
            try {
                if (this.MainGui[key].Value != this._InitialValues[key])
                    return false
            }
        }
        for key in this.GuiImportantKeys {
            try {
                if (this.MainGui[key].Value != this._InitialValues[key])
                    return false
            }
        }
        try {
            if (this.MainGui["SwitchHotkey"].Value != this._InitialValues["SwitchHotkey"])
                return false
        }
        try {
            if (this.MainGui["ClickDelay"].Value != this._InitialValues["ClickDelay"])
                return false
        }
        for key in this.FrameSkipDelayKeys {
            try {
                if (this.MainGui[key].Value != this._InitialValues[key])
                    return false
            }
        }
        try {
            if (this.MainGui["HoverOperate"].Value != this._InitialValues["HoverOperate"])
                return false
        }
        if !this._CustomHotkeysEqual(Config.AllCustomHotkeys, this._InitialCustomHotkeys)
            return false
        return true
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
        for ctrl in this.CustomKeyControls {
            if (IsObject(ctrl)) {
                try ctrl.Visible := false
            }
        }
        for ctrl in this.OtherSettingsControls {
            if (IsObject(ctrl)) {
                try ctrl.Visible := false
            }
        }
        this._HideOtherCategories()
    }

    ; 语言配置→下拉框索引
    static _LanguageToIndex(lang) {
        for i, item in this.LanguageCodes {
            if (item = lang)
                return i
        }
        return 1
    }

    ; 生成语言下拉框显示文本：固定使用各语言自己的写法
    static _BuildLanguageLabels() {
        labels := []
        for code in this.LanguageCodes
            labels.Push(this.LanguageDisplayNames[code])
        return labels
    }

    ; 帧率文本值→下拉框索引
    static _FrameTextToIndex(frameText) {
        for i, opt in Constants.FrameOptions {
            if (opt = frameText)
                return i
        }
        return 3  ; 默认"90"
    }

    ; 内部：显示指定控件组
    static _ShowControls(controls) {
        for ctrl in controls {
            if (IsObject(ctrl)) {
                try ctrl.Visible := true
            }
        }
    }

    ; 按 id 数组构建标签顺序：按给定顺序去重取已有项，再追加未出现的项（未来新增标签自动落尾）。
    static _BuildOrderedTabsFromIds(idList) {
        tabById := Map()
        for tabItem in this.TabItems
            tabById[tabItem.Id] := tabItem

        orderedTabs := []
        addedIds := Map()
        for tabId in idList {
            tabId := Trim(tabId)
            if (tabId != "" && tabById.Has(tabId) && !addedIds.Has(tabId)) {
                orderedTabs.Push(tabById[tabId])
                addedIds[tabId] := true
            }
        }
        for tabItem in this.TabItems {
            if !addedIds.Has(tabItem.Id)
                orderedTabs.Push(tabItem)
        }
        return orderedTabs
    }

    ; 从配置恢复标签顺序与可见性；未知项会被忽略，新增项自动追加。
    static LoadTabSettingsFromConfig() {
        orderedTabs := this._BuildOrderedTabsFromIds(StrSplit(Config.GetImportant("TabOrder"), ","))

        hiddenIds := Map()
        for tabId in StrSplit(Config.GetImportant("HiddenTabs"), ",") {
            tabId := Trim(tabId)
            if (tabId != "")
                hiddenIds[tabId] := true
        }
        for tabItem in orderedTabs
            tabItem.Visible := !tabItem.CanHide || !hiddenIds.Has(tabItem.Id)

        this.TabItems := orderedTabs
    }

    ; 将标签管理器中的状态同步到隐藏表单控件与内存配置。
    static SyncTabSettings() {
        orderParts := []
        hiddenParts := []
        for tabItem in this.TabItems {
            orderParts.Push(tabItem.Id)
            if (tabItem.CanHide && !tabItem.Visible)
                hiddenParts.Push(tabItem.Id)
        }
        this.MainGui["TabOrder"].Value := this.JoinTabSettingParts(orderParts)
        this.MainGui["HiddenTabs"].Value := this.JoinTabSettingParts(hiddenParts)
        this.TrackChange("TabOrder")
        this.TrackChange("HiddenTabs")
    }

    static JoinTabSettingParts(parts) {
        result := ""
        for index, part in parts
            result .= (index > 1 ? "," : "") part
        return result
    }

    static IsTabVisible(tabName) {
        if this.AppliedTabSettings.Visibility.Has(tabName)
            return this.AppliedTabSettings.Visibility[tabName]
        for tabItem in this.TabItems {
            if (tabItem.Id = tabName)
                return tabItem.Visible
        }
        return false
    }

    ; 将标签管理列表中的待保存顺序与可见性作为一个整体提交。
    ; 仅当顺序或可见性与已应用快照不一致时才触发界面重建（ApplyTabSettings），
    ; 避免保存/应用设置时在顶部标签页未变更的情况下无谓地刷新全部控件。
    static CommitTabSettings(refreshUi := true) {
        appliedOrder := []
        appliedVisibility := Map()
        for tabItem in this.TabItems {
            appliedOrder.Push(tabItem.Id)
            appliedVisibility[tabItem.Id] := !tabItem.CanHide || tabItem.Visible
        }

        tabSettingsChanged := !this._TabSettingsEqual(appliedOrder, appliedVisibility)

        this.AppliedTabSettings := {
            Order: appliedOrder,
            Visibility: appliedVisibility
        }

        if refreshUi && tabSettingsChanged
            this.ApplyTabSettings()
    }

    ; 判断待提交的标签顺序与可见性与已应用快照是否一致。
    static _TabSettingsEqual(order, visibility) {
        if (this.AppliedTabSettings.Order.Length != order.Length)
            return false
        for index, id in order {
            if (this.AppliedTabSettings.Order[index] != id)
                return false
        }
        ; 双向比对可见性键集合，使相等性判断对称：既检测新集合相对快照的差异，也检测快照中已不存在的额外 ID
        for id, visible in visibility {
            if !this.AppliedTabSettings.Visibility.Has(id)
                return false
            if this.AppliedTabSettings.Visibility[id] != visible
                return false
        }
        for id, visible in this.AppliedTabSettings.Visibility {
            if !visibility.Has(id)
                return false
            if visibility[id] != visible
                return false
        }
        return true
    }

    ; 按已应用顺序返回标签对象，并为未来新增标签提供自动追加兜底。
    static GetTabsInAppliedOrder() {
        return this._BuildOrderedTabsFromIds(this.AppliedTabSettings.Order)
    }

    ; 获取排序最靠前的可见标签；功能标签不包含“其他设置”。
    static GetFirstVisibleTab(functionalOnly := false) {
        for tabItem in this.GetTabsInAppliedOrder() {
            if (this.IsTabVisible(tabItem.Id) && (!functionalOnly || tabItem.Id != "other"))
                return tabItem.Id
        }
        return ""
    }

    ; 根据可见标签数组等分并排列顶部标签。
    static LayoutTopTabs() {
        visibleTabs := []
        for tabItem in this.GetTabsInAppliedOrder() {
            isVisible := this.IsTabVisible(tabItem.Id)
            ; 仅当可见性实际变化时才赋值，避免切换标签时对相同状态无谓重绘
            if (tabItem.TextControl.Visible != isVisible)
                tabItem.TextControl.Visible := isVisible
            if (tabItem.ClickControl.Visible != isVisible)
                tabItem.ClickControl.Visible := isVisible
            if isVisible
                visibleTabs.Push(tabItem)
        }

        if (visibleTabs.Length == 0)
            return

        tabWidth := this.GuiWidth / visibleTabs.Length
        for index, tabItem in visibleTabs {
            tabX := tabWidth * (index - 1)
            ; 仅当位置或尺寸实际变化时才 Move，避免切换标签时对相同布局无谓重绘导致文字闪烁
            tabItem.TextControl.GetPos(&curX, &curY, &curW, &curH)
            if (curX != tabX || curY != 5 || curW != tabWidth || curH != 20) {
                tabItem.TextControl.Move(tabX, 5, tabWidth, 20)
                ; Move 改变宽度后文字需强制重绘——AHK 对控件变更延迟重绘，
                ; 可见标签数变化时若不加 Redraw，文字可能按旧宽度绘制出现错位/缺字残影。
                tabItem.TextControl.Redraw()
            }
            tabItem.ClickControl.GetPos(&curX, &curY, &curW, &curH)
            if (curX != tabX || curY != 0 || curW != tabWidth || curH != 25)
                tabItem.ClickControl.Move(tabX, 0, tabWidth, 25)
        }

        try this.MainGui["DefaultStrongHoldProtocol"].Enabled := this.IsTabVisible("strongHoldProtocol")
        this.TabIndicator.GetPos(&indicatorX, &indicatorY, &indicatorW, &indicatorH)
        if (indicatorW != tabWidth)
            this.TabIndicator.Move(indicatorX, 23, tabWidth, 2)
    }

    ; 解析回退标签：优先功能标签（排除"其他设置"），仅剩"其他设置"时返回它。
    static _ResolveFallbackTab() {
        fallbackTab := this.GetFirstVisibleTab(true)
        if (fallbackTab = "")
            fallbackTab := this.GetFirstVisibleTab()
        return fallbackTab
    }

    ; 统计当前可见的功能标签数量（排除"其他设置"）。
    ; 直接读 tabItem.Visible（工作态），而非 IsTabVisible（读已应用快照），确保未应用时保护也生效。
    static _CountVisibleFunctionalTabs() {
        count := 0
        for tabItem in this.TabItems {
            if (tabItem.Id != "other" && tabItem.Visible)
                count++
        }
        return count
    }

    ; 应用标签管理器状态；当前页被隐藏时切到排序最靠前的可见页。
    static ApplyTabSettings() {
        this.RenderTabManager()
        if (this.CurrentTab != "" && !this.IsTabVisible(this.CurrentTab)) {
            this.SwitchTab(this._ResolveFallbackTab())
            return
        }

        if !this.IsTabVisible(this.LastActiveTab) {
            fallbackTab := this._ResolveFallbackTab()
            if (fallbackTab != "") {
                this.LastActiveTab := fallbackTab
                this.IsOnStrongHoldProtocol := fallbackTab = "strongHoldProtocol"
                EventBus.Publish("ActiveTabChangeRequested", {tabName: fallbackTab})
            }
        }

        if (this.CurrentTab != "") {
            ; 当前页仍可见：仅刷新顶部标签栏（布局/勾叉/指示线），不重建页面控件，
            ; 标签设置变更不应导致全部控件无谓刷新。
            this.LayoutTopTabs()
            this._UpdateTopTabBar(this.CurrentTab)
            if !this.IsTabVisible("strongHoldProtocol") {
                for ctrl in this.StrongHoldConflictHints
                    try ctrl.Visible := false
            }
        }
        else
            this.LayoutTopTabs()
    }

    ; 刷新“自定义”页中的标签管理器行。
    static RenderTabManager() {
        for index, tabItem in this.TabItems {
            rowY := this.TabManagerRowStartY + (index - 1) * this.TabManagerRowHeight
            ; 背景层固定 F5F7FA；高亮层通过 Visible 切换，避免 Opt 改色对 Text 控件不可靠的问题
            tabItem.RowBackground.Move(this.TabManagerX, rowY, this.TabManagerRowWidth, 26)
            tabItem.RowHighlight.Move(this.TabManagerX, rowY, this.TabManagerRowWidth, 26)
            tabItem.RowHighlight.Visible := index = this.TabDragIndex
            ; 行内控件相对行左边缘的偏移：拖动手柄 +9、标签 +40、眼睛图标 +201
            tabItem.DragControl.Move(this.TabManagerX + 9, rowY + 4, 24, 18)
            tabItem.ManagerLabel.Move(this.TabManagerX + 40, rowY + 4, 150, 18)
            tabItem.EyeControl.Move(this.TabManagerX + 201, rowY + 4, 24, 18)

            tabItem.ManagerLabel.Text := tabItem.Label (tabItem.CanHide ? "" : I18n.T("（无法隐藏）"))
            tabItem.ManagerLabel.SetFont(tabItem.Visible ? "c333333" : "cA0A0A0")
            ; 眼睛图标统一用 U+E890（睁眼，MDL2 中确定存在），用颜色区分状态：蓝=显示，灰=隐藏。
            ; （不依赖"闭眼"字形——MDL2 无此字形，E9CE/E8F4 等均不可靠，可能显示为问号。）
            tabItem.EyeControl.Text := Chr(0xE890)
            tabItem.EyeControl.SetFont(tabItem.Visible ? "s11 c1994d2" : "s11 cA0A0A0", "Segoe MDL2 Assets")
        }
    }

    static RegisterTabManagerMouseHandlers() {
        ; 幂等守卫：重复调用不会叠加监听
        if (this._TabManagerHandlersRegistered)
            return
        this._TabManagerHandlersRegistered := true

        ; 同时监听 WM_LBUTTONDOWN(0x0201) 和 WM_LBUTTONDBLCLK(0x0203)：
        ; 窗口类带 CS_DBLCLKS 样式时，快速双击的第二次按下会发 0x0203 而非 0x0201，
        ; 若只监听 0x0201，快速点击同一眼睛时会漏掉第二次点击。
        OnMessage(0x0201, ObjBindMethod(GuiManager, "HandleTabManagerMouseDown"))
        OnMessage(0x0203, ObjBindMethod(GuiManager, "HandleTabManagerMouseDown"))
        OnMessage(0x0200, ObjBindMethod(GuiManager, "HandleTabManagerMouseMove"))
        OnMessage(0x0202, ObjBindMethod(GuiManager, "HandleTabManagerMouseUp"))
    }

    static GetTabManagerHit(controlHwnd) {
        for index, tabItem in this.TabItems {
            if (controlHwnd = tabItem.EyeControl.Hwnd)
                return {Index: index, IsEye: true}
            if (controlHwnd = tabItem.RowBackground.Hwnd
                || controlHwnd = tabItem.RowHighlight.Hwnd
                || controlHwnd = tabItem.DragControl.Hwnd
                || controlHwnd = tabItem.ManagerLabel.Hwnd)
                return {Index: index, IsEye: false}
        }
        return ""
    }

    ; MouseGetPos 返回物理像素，而 TabManagerRowStartY/RowHeight 为逻辑像素（Gui 默认 DPI 缩放）。
    ; 统一换算为逻辑像素，避免 150% 等系统缩放下拖拽位置偏移。
    static GetTabManagerLogicalY() {
        MouseGetPos(, &mouseY)
        return mouseY * 96 / A_ScreenDPI
    }

    static HandleTabManagerMouseDown(wParam, lParam, msg, hwnd) {
        MouseGetPos(, , , &controlHwnd, 2)
        hit := this.GetTabManagerHit(controlHwnd)
        if !IsObject(hit)
            return

        tabItem := this.TabItems[hit.Index]
        if hit.IsEye {
            if tabItem.CanHide {
                ; 边界保护：禁止隐藏最后一个可见功能标签，避免"仅剩其他设置"导致热键方案绑定到不可达标签。
                if tabItem.Visible && this._CountVisibleFunctionalTabs() <= 1 {
                    MessageBox.Info(I18n.T("至少保留一个功能标签页，不能隐藏全部功能标签。"), I18n.T("提示"))
                } else {
                    tabItem.Visible := !tabItem.Visible
                    this.SyncTabSettings()
                    this.RenderTabManager()
                }
            }
            return
        }

        this.TabDragIndex := hit.Index
        this.TabDragStartY := this.GetTabManagerLogicalY()
        this.TabDragMoved := false
        this.RenderTabManager()
        DllCall("SetCapture", "Ptr", this.MainGui.Hwnd)
    }

    static HandleTabManagerMouseMove(wParam, lParam, msg, hwnd) {
        if (this.TabDragIndex = 0)
            return

        mouseY := this.GetTabManagerLogicalY()
        if (!this.TabDragMoved && Abs(mouseY - this.TabDragStartY) < 4)
            return
        this.TabDragMoved := true

        targetIndex := Floor(
            (mouseY - this.TabManagerRowStartY) / this.TabManagerRowHeight
        ) + 1
        targetIndex := Max(1, Min(this.TabItems.Length, targetIndex))
        if (targetIndex = this.TabDragIndex)
            return

        movedItem := this.TabItems.RemoveAt(this.TabDragIndex)
        this.TabItems.InsertAt(targetIndex, movedItem)
        this.TabDragIndex := targetIndex
        this.RenderTabManager()
    }

    static HandleTabManagerMouseUp(wParam, lParam, msg, hwnd) {
        if (this.TabDragIndex = 0)
            return

        DllCall("ReleaseCapture")
        moved := this.TabDragMoved
        this.TabDragIndex := 0
        this.TabDragStartY := 0
        this.TabDragMoved := false
        if moved {
            this.SyncTabSettings()
        }
        this.RenderTabManager()
    }

    ; 内部：隐藏所有其他设置分类控件
    static _HideOtherCategories() {
        for _, info in this.OtherCategories {
            for ctrl in info[1] {
                if (IsObject(ctrl)) {
                    try ctrl.Visible := false
                }
            }
        }
    }

    ; 内部：更新标签页UI
    ; 仅当目标颜色与 TabFontState 记录不一致时才 SetFont，避免重复重建字体触发文字重绘闪烁。
    static _SetTabFontOnce(tabName, color) {
        ; 键缺失视为无历史值，保证首次调用（及未来新增标签）总会执行 SetFont
        prevColor := this.TabFontState.Has(tabName) ? this.TabFontState[tabName] : ""
        if (prevColor != color) {
            this.TabFontState[tabName] := color
            switch tabName {
                case "keyBind":
                    this.TxtKeybind.SetFont(color)
                case "quick":
                    this.TxtQuick.SetFont(color)
                case "strongHoldProtocol":
                    this.TxtStrongHoldProtocol.SetFont(color)
                case "customKeys":
                    this.TxtCustomKeys.SetFont(color)
                default:
                    this.TxtOther.SetFont(color)
            }
        }
    }

    ; 更新顶部标签栏的选中样式、勾叉文本与指示线位置。
    ; 与页面控件刷新解耦：顶部标签设置变更时可单独调用，避免重建全部页面控件。
    static _UpdateTopTabBar(tabName) {
        showModeStatus := this.IsTabVisible("strongHoldProtocol")
        isStrongHold := tabName = "strongHoldProtocol"
        ; "其他设置"与"自定义按键"均为管理型标签页：自身不显示 ✓/✗，其余标签按 LastActiveTab 标注
        isOther := tabName = "other" || tabName = "customKeys"

        ; 更新标签样式：仅当目标颜色与记录不一致时才 SetFont，
        ; 避免对相同颜色重复重建字体触发文字重绘闪烁。
        this._SetTabFontOnce("keyBind", tabName = "keyBind" ? "c1994d2" : "cDefault")
        this._SetTabFontOnce("quick", tabName = "quick" ? "c1994d2" : "cDefault")
        this._SetTabFontOnce("strongHoldProtocol", isStrongHold ? "c1994d2" : "cDefault")
        this._SetTabFontOnce("other", isOther ? "c1994d2" : "cDefault")

        ; 计算目标文本：卫戍协议页固定显示；功能页随卫戍协议可见性；"其他设置"页额外随上次活动功能页。
        ; 先算后比，仅当实际变化时才赋值，避免相同值触发重绘闪烁。
        if isStrongHold {
            keybindText := I18n.T("常规作战") " ✗"
            quickText := I18n.T("快捷操作") " ✗"
            strongHoldText := I18n.T("卫戍协议") " ✓"
        } else if isOther {
            if !showModeStatus {
                keybindText := I18n.T("常规作战")
                quickText := I18n.T("快捷操作")
                strongHoldText := I18n.T("卫戍协议")
            } else if (this.LastActiveTab = "strongHoldProtocol") {
                keybindText := I18n.T("常规作战") " ✗"
                quickText := I18n.T("快捷操作") " ✗"
                strongHoldText := I18n.T("卫戍协议") " ✓"
            } else {
                keybindText := I18n.T("常规作战") " ✓"
                quickText := I18n.T("快捷操作") " ✓"
                strongHoldText := I18n.T("卫戍协议") " ✗"
            }
        } else {
            keybindText := showModeStatus ? I18n.T("常规作战") " ✓" : I18n.T("常规作战")
            quickText := showModeStatus ? I18n.T("快捷操作") " ✓" : I18n.T("快捷操作")
            strongHoldText := showModeStatus ? I18n.T("卫戍协议") " ✗" : I18n.T("卫戍协议")
        }
        if (this.TxtKeybind.Text != keybindText)
            this.TxtKeybind.Text := keybindText
        if (this.TxtQuick.Text != quickText)
            this.TxtQuick.Text := quickText
        if (this.TxtStrongHoldProtocol.Text != strongHoldText)
            this.TxtStrongHoldProtocol.Text := strongHoldText

        ; 移动指示线到当前选中的标签
        if (tabName = "keyBind") {
            this.TxtKeybind.GetPos(&x)
            this.TabIndicator.Move(x, 23)
        } else if (tabName = "quick") {
            this.TxtQuick.GetPos(&x)
            this.TabIndicator.Move(x, 23)
        } else if isStrongHold {
            this.TxtStrongHoldProtocol.GetPos(&x)
            this.TabIndicator.Move(x, 23)
        } else if (tabName = "customKeys") {
            this.TxtCustomKeys.GetPos(&x)
            this.TabIndicator.Move(x, 23)
        } else {
            this.TxtOther.GetPos(&x)
            this.TabIndicator.Move(x, 23)
        }
    }

    static _UpdateTabUI(tabName) {
        ; 首先隐藏所有标签页的控件
        this._HideAllControls()
        this.LayoutTopTabs()

        ; 切换到常规作战页
        if (tabName = "keyBind") {
            ; 更新标签样式与指示线
            this._UpdateTopTabBar("keyBind")

            ; 显示常规作战控件
            this._ShowControls(this.KeybindControls)
            ; 显示仅非其他设置控件
            this._ShowControls(this.NotOtherControls)
        }

        ; 切换到快捷操作页
        else if (tabName = "quick") {
            this._UpdateTopTabBar("quick")
            this._ShowControls(this.QuickControls)
            this._ShowControls(this.NotOtherControls)
        }

        ; 切换到卫戍协议页
        else if (tabName = "strongHoldProtocol") {
            this._UpdateTopTabBar("strongHoldProtocol")
            this._ShowControls(this.StrongHoldProtocolControls)
            this._ShowControls(this.NotOtherControls)
        }

        ; 切换到自定义按键页（管理型标签页：不改变热键组）
        else if (tabName = "customKeys") {
            this._UpdateTopTabBar("customKeys")
            this._ShowControls(this.CustomKeyControls)
            this._ShowControls(this.NotOtherControls)
        }

        ; 切换到其他设置页
        else if (tabName = "other") {
            this._UpdateTopTabBar("other")
            this._SwitchOtherCategory(this.CurrentOtherCategory, true)
            this._HideAllControls("NotOther")
        }
        if !this.IsTabVisible("strongHoldProtocol") {
            for ctrl in this.StrongHoldConflictHints
                try ctrl.Visible := false
        }
        ; 标签页内部刷新直接调用自身方法，避免自发布 Legacy GuiUpdate* 事件
        this._UpdateHotkeyControlsFromConfig()
        this._UpdateImportantControlsFromConfig()
        this._UpdateCustomControlsFromConfig()
        this._RefreshCustomHotkeyRows()
    }

    ; 内部：切换其他设置页面的分类
    static _SwitchOtherCategory(categoryName, force := false) {
        if (!force && categoryName = this.CurrentOtherCategory)
            return
        this.CurrentOtherCategory := categoryName

        ; 确保导航元素可见
        this._ShowControls(this.OtherSettingsControls)

        ; _ShowControls 会把所有导航竖线一并点亮，这里紧接收敛为仅目标项可见，
        ; 避免切换分类时出现"每个分类左侧蓝条快速闪烁一次"的中间状态。
        info := this.OtherCategories[categoryName]
        targetIndex := info[2]
        for i, indicator in this.NavIndicators {
            try indicator.Visible := (i = targetIndex)
        }

        ; 隐藏所有分类控件
        this._HideOtherCategories()

        ; 显示目标分类控件
        for ctrl in info[1] {
            try ctrl.Visible := true
        }
        ; 上面遍历会把 CustomControls 内所有控件设为可见（含 RowHighlight 高亮层），
        ; 重绘管理器将其恢复为 TabDragIndex 决定的正确状态，避免启动后全部标签误高亮。
        if (categoryName = "Display")
            this.RenderTabManager()
        ; 切换到更新分类时，同步 Token 行状态
        if (categoryName = "Update") {
            this._OnUpdateSourceChange()
        }

        ; 更新导航项样式
        for i, navItem in this.NavItems {
            if (i = targetIndex) {
                navItem.SetFont("c1994d2")
            } else {
                navItem.SetFont("cDefault")
            }
        }
    }

    ; 切换标签页
    static SwitchTab(tabName) {
        isInitialSwitch := this.CurrentTab = ""
        if !this.IsTabVisible(tabName) {
            tabName := this._ResolveFallbackTab()
        }
        if (tabName = this.CurrentTab)
            return
        this.CurrentTab := tabName

        ; 记录最后选中的功能标签页（排除"其他设置"与"自定义按键"两个管理型标签页）
        if (tabName != "other" && tabName != "customKeys") {
            this.LastActiveTab := tabName
        }

        ; 通知 HotkeyService 更新内部 ActiveTab/Group（热键禁用时也只记录不重建）
        EventBus.Publish("ActiveTabChangeRequested", {tabName: tabName})

        ; 更新UI
        this._UpdateTabUI(tabName)
    }

    static _ShowChangelog() {
        configDir := A_AppData "\ArknightsFrameAssistant\PC"
        changelogFile := configDir "\changelog.json"
        if (!FileExist(changelogFile)) {
            MessageBox.Info(I18n.T("暂无更新公告，请先连接网络检查更新。"), I18n.T("提示"))
            return
        }
        ChangelogChecker.ChangelogFile := changelogFile
        body := ChangelogChecker._ReadAndBuildBody()
        if (body != "")
            ChangelogUI.Show(Version.Get(), body)
        else
            MessageBox.Info(I18n.T("暂无更新公告。"), I18n.T("提示"))
    }

    ; 启动 GUI 并注册 Alt+F4 退出热键（原为文件末尾顶层副作用）
    static Start() {
        this.Init()
        if (this._AltF4Registered)
            return
        this._AltF4Registered := true
        HotIf(IsSettingsWindowActive)
        Hotkey("!F4", HandleSettingsAltF4, "On")
        HotIf
    }

    ; 重建设置窗口（语言切换等场景）。当前实现保证可重建主窗口；
    ; 控件数组原地清空以保持 OtherCategories 引用有效。
    static Rebuild() {
        CustomKeyEditor.Close()   ; D11：主窗口重建（切换语言）前先关闭编辑窗口
        if (this.MainGui = "") {
            this.Init()
            return
        }
        oldGui := this.MainGui
        this.MainGui := ""
        oldGui.Destroy()
        this._ClearControlArrays()
        this.Init()
    }

    ; 原地清空所有动态控件数组/Map，避免重建时重复追加。
    static _ClearControlArrays() {
        for arr in [
            this.KeybindControls,
            this.QuickControls,
            this.StrongHoldProtocolControls,
            this.CustomKeyControls,
            this.CustomRows,
            this.OtherSettingsControls,
            this.NavItems,
            this.NavIndicators,
            this.GeneralControls,
            this.DisplayControls,
            this.LaunchControls,
            this.UpdateControls,
            this.CustomControls,
            this.AboutControls,
            this.LogControls,
            this.NotOtherControls,
            this.StrongHoldConflictHints,
            this.TabItems,
            this.TabFontState,
            this.FrameSkipLabels
        ] {
            if (IsObject(arr) && Type(arr) = "Array") {
                while (arr.Length > 0)
                    arr.Pop()
            }
        }
        this._PrevConflictedControls := Map()
        this.TabFontState := Map()
        this.FrameSkipLabels := Map()
        this._InitialCustomHotkeys := []
        this.AppliedTabSettings := {Order: [], Visibility: Map()}
        this.CurrentTab := ""
    }
}

; 设置窗口是否为当前活动窗口（供 Alt+F4 热键使用，命名函数保证幂等）
IsSettingsWindowActive(*) {
    return GuiManager.MainGui != "" && WinActive("ahk_id " GuiManager.MainGui.Hwnd)
}

; Alt+F4 始终退出设置窗口
HandleSettingsAltF4(*) {
    ExitApp()
}

; 处理GUI隐藏时停止Hook的事件
HandleGuiHideStopHook(*) {
    KeyBinder.StopHook()
}
