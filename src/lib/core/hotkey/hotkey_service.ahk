; == 热键控制 ==
; 热键上下文判定（HotIf 回调）：Up 变体查状态、鼠标键查悬停、键盘键查活动窗口
; 背景：点击任务栏/桌面等不抢占前台的区域时，游戏仍是"活动窗口"，旧判定 HotIfWinActive
; 会把窗口外的鼠标按下误判为游戏内操作——绑定在鼠标键上的热键被误触发，且因无 ~ 前缀
; 在钩子层吞掉点击，导致窗口外右键无法正常到达任务栏/桌面。
; HotIf.htm：条件不成立时热键执行原生功能（像没有这个热键一样透传给系统）。
; - Up 变体（守卫拦截补发）：若该键 down 已被 AFA 主热键处理过（DownHandled 有记录），放行补发 key up
;   ——与窗口状态无关，解决"按住从游戏内拖出/Alt+Tab 切走后再松开"的卡键（含上次遗留的失焦边界）。
; - 鼠标键/滚轮：鼠标悬停在游戏窗口上才触发（窗口外点击透传给系统）。
; - 键盘键：游戏窗口为活动窗口，或（启用失焦悬停操作时）鼠标悬停在游戏窗口上才触发——失焦悬停开关
;   （HotkeyService._HoverOperate，由"自定义"页复选框控制，保存/应用后生效）关闭后键盘键仅当游戏为活动窗口时才触发；
;   动作层统一包装负责激活游戏窗口并恢复原窗口。鼠标键/滚轮不受开关影响，仍只受悬停判定约束。
HotkeyContext(hotkeyName) {
    pureKey := KeyForward.PureKeyName(hotkeyName)
    if (pureKey = "")
        return false
    ; Up 变体（守卫补发型）：仅当该键的 down 已被 AFA 主热键处理过（DownHandled 有记录，无论守卫放行/拦截）
    ; 才放行补发 key up——覆盖失焦/拖出卡键；游戏外主热键不触发（down 透传）则不放行，物理 up 正常透传（打字不受影响）。
    if RegExMatch(hotkeyName, " Up$") {
        ; 补发 up 期间钩子会捕获 Send 注入的 up，若仍放行会递归触发 Up 变体无限循环（游戏外按键失灵）。
        ; 仅抑制同名键（键级作用域）——全局布尔会在多键同松时误挡其它键的 Up 变体（卡键），须按键判断。
        if KeyForward.SuppressUp.Has(pureKey)
            return false
        if KeyForward.DownHandled.Has(pureKey)
            return true
    }
    ; 鼠标键/滚轮：悬停判定
    if (pureKey ~= "i)^(lbutton|rbutton|mbutton|xbutton1|xbutton2|wheel)")
        return IsMouseInClient()
    ; 键盘键：游戏窗口为活动窗口，或（启用失焦悬停操作时）鼠标悬停在游戏窗口上才触发；
    ; 动作层统一包装负责激活游戏窗口并恢复原窗口（判定层不做副作用）
    if WinActive("ahk_exe Arknights.exe")
        return true
    return HotkeyService.GetHoverOperate() && IsMouseInClient()
}

class HotkeyService {
    ; 热键状态
    static HotkeyState := true

    ; 游戏失焦悬停操作开关（从 State 收归；由 Loader/SettingsService 刷新）
    static _HoverOperate := true

    static SetHoverOperate(value) {
        this._HoverOperate := value
    }

    static GetHoverOperate() {
        return this._HoverOperate
    }

    ; 热键域内部状态（从 GuiManager/State 收归）
    static _ActiveTab := "keyBind"
    static _Group := "combatQuick"
    static _SwitchKey := ""

    ; 初始化热键服务
    static Init() {
        HotkeyService._SubscribeEvents()
    }

    ; 内部：订阅热键事件（保留旧事件兼容，同时接入新事件契约）
    static _SubscribeEvents() {
        ; Legacy 旧事件（迁移期保留闭环，勿新增发布者）
        EventBus.Subscribe("HotkeyOff", (*) => this.HotkeyOff())          ; Legacy
        EventBus.Subscribe("UnsetSwitchKey", (*) => this.UnsetSwitchKey()) ; Legacy
        EventBus.Subscribe("SetSwitchKey", (*) => this.SetSwitchKey())     ; Legacy
        ; 新事件契约
        EventBus.Subscribe("GameKeysChanged", (data) => this._HandleGameKeysChanged(data))
        EventBus.Subscribe("ActiveTabChangeRequested", (data) => this._HandleActiveTabChangeRequested(data))
        EventBus.Subscribe("HotkeyToggleRequested", (*) => this.SwitchHotkey())
        EventBus.Subscribe("InLevelChanged", (data) => this._HandleInLevelChanged(data))
        EventBus.Subscribe("SettingsChanged", (data) => this._HandleSettingsChanged(data))
        EventBus.Subscribe("SettingsSaved", (*) => this._HandleSettingsSavedOrApplied())
        EventBus.Subscribe("SettingsApplied", (*) => this._HandleSettingsSavedOrApplied())
        EventBus.Subscribe("SettingsReset", (*) => this._HandleSettingsSavedOrApplied())
    }

    ; 处理关卡状态变化（目前仅记录调试日志；守卫判定走 LevelDetector.IsInLevel() getter）
    static _HandleInLevelChanged(data) {
        Logger.Debug("Hotkey", "关卡状态变化：inLevel=" data.inLevel)
    }

    ; 处理游戏按键变更：总开关开启时才重建，修复“禁用后被注册表变更恢复”的 bug
    static _HandleGameKeysChanged(data) {
        if (!this.HotkeyState)
            return
        Logger.Info("Hotkey", "收到 GameKeysChanged，重建热键")
        this.EnableByTab(this._ActiveTab)
        this.SetSwitchKey()
    }

    ; 处理 UI 标签页切换请求
    static _HandleActiveTabChangeRequested(data) {
        ; “其他设置”页不是功能标签页，不改变热键组/不重建热键
        if (data.tabName = "other")
            return
        this._ActiveTab := data.tabName
        if (this._ActiveTab = "strongHoldProtocol")
            this._Group := "strongHoldProtocol"
        else
            this._Group := "combatQuick"
        if (this.HotkeyState)
            this.EnableByTab(this._ActiveTab)
        EventBus.Publish("HotkeyGroupChanged", {group: this._Group})
    }

    ; 处理设置变更：HoverOperate/SwitchHotkey 等热键相关配置即时刷新
    static _HandleSettingsChanged(data) {
        if (data.key = "HoverOperate")
            this.SetHoverOperate(data.value == "1")
        else if (data.key = "SwitchHotkey")
            this.SetSwitchKey()
        else if (Config.AllHotkeys.Has(data.key) && this.HotkeyState)
            this.EnableByTab(this._ActiveTab)
    }

    ; 处理保存/应用/重置完成：从 INI 刷新热键相关配置并重建热键
    static _HandleSettingsSavedOrApplied() {
        this.SetHoverOperate(Config.ReadCustomFromIni("HoverOperate") == "1")
        if (this.HotkeyState)
            this.EnableByTab(this._ActiveTab)
        this.SetSwitchKey()
    }

    ; 当前激活的功能标签页（供设置域临时处理器重建热键）
    static GetActiveTab() {
        return this._ActiveTab
    }

    ; 热键回调映射表（profile.Fn 回调；profile.Guarded 有关卡守卫——拦截键注册 Up 变体补发透传；profile.OnUp 功能在松开时触发）
    static ActionCallbacks := Map(
        ; 常规作战（有守卫）
        "PressPause", {Fn: HotkeyActions.ActionPressPause.Bind(HotkeyActions), Guarded: true},
        "ReleasePause", {Fn: HotkeyActions.ActionReleasePause.Bind(HotkeyActions), OnUp: true},  ; 松开时触发（Up 变体注册）
        "GameSpeed", {Fn: HotkeyActions.ActionGameSpeed.Bind(HotkeyActions), Guarded: true},
        "16ms", {Fn: HotkeyActions.Action16ms.Bind(HotkeyActions), Guarded: true},
        "33ms", {Fn: HotkeyActions.Action33ms.Bind(HotkeyActions), Guarded: true},
        "166ms", {Fn: HotkeyActions.Action166ms.Bind(HotkeyActions), Guarded: true},
        "PauseSelect", {Fn: HotkeyActions.ActionPauseSelect.Bind(HotkeyActions), Guarded: true},
        "Skill", {Fn: HotkeyActions.ActionSkill.Bind(HotkeyActions), Guarded: true},
        "Retreat", {Fn: HotkeyActions.ActionRetreat.Bind(HotkeyActions), Guarded: true},
        "OneClickSkill", {Fn: HotkeyActions.ActionOneClickSkill.Bind(HotkeyActions), Guarded: true},
        "OneClickRetreat", {Fn: HotkeyActions.ActionOneClickRetreat.Bind(HotkeyActions), Guarded: true},
        "PauseSkill", {Fn: HotkeyActions.ActionPauseSkill.Bind(HotkeyActions), Guarded: true},
        "PauseRetreat", {Fn: HotkeyActions.ActionPauseRetreat.Bind(HotkeyActions), Guarded: true},
        "SwitchView", {Fn: HotkeyActions.ActionSwitchView.Bind(HotkeyActions), Guarded: true},
        "BeginPause", {Fn: HotkeyActions.ActionBeginPauseSwitch.Bind(HotkeyActions), NoActivate: true},  ; 设置开关，不激活游戏窗口（避免焦点跳转）
        "AutoBeginPauseSwitch", {Fn: HotkeyActions.ActionBeginPauseSwitch.Bind(HotkeyActions), NoActivate: true},
        ; 快捷操作
        "LButtonClick", {Fn: HotkeyActions.ActionLButtonClick.Bind(HotkeyActions)},
        "CeaseOperations", {Fn: HotkeyActions.ActionCeaseOperations.Bind(HotkeyActions)},
        "Skip", {Fn: HotkeyActions.ActionSkip.Bind(HotkeyActions)},
        "Back", {Fn: HotkeyActions.ActionBack.Bind(HotkeyActions)},
        "Harvest", {Fn: HotkeyActions.ActionHarvest.Bind(HotkeyActions)},
        "CollectCollectibles", {Fn: HotkeyActions.ActionCollectCollectibles.Bind(HotkeyActions)},
        ; 卫戍协议
        "CheckEnemies", {Fn: HotkeyActions.ActionCheckEnemies.Bind(HotkeyActions)},
        "DispatchCenter", {Fn: HotkeyActions.ActionDispatchCenter.Bind(HotkeyActions)},
        "Freeze", {Fn: HotkeyActions.ActionFreeze.Bind(HotkeyActions)},
        "Refresh", {Fn: HotkeyActions.ActionRefresh.Bind(HotkeyActions)},
        "Upgrade", {Fn: HotkeyActions.ActionUpgrade.Bind(HotkeyActions)},
        "Sell", {Fn: HotkeyActions.ActionSell.Bind(HotkeyActions)},
        "Ready", {Fn: HotkeyActions.ActionReady.Bind(HotkeyActions)},
        "StrongHoldProtocolLButtonClick", {Fn: HotkeyActions.ActionLButtonClick.Bind(HotkeyActions)},
        "StrongHoldProtocolRetreat", {Fn: HotkeyActions.ActionRetreat.Bind(HotkeyActions)},
        "StrongHoldProtocolOneClickRetreat", {Fn: HotkeyActions.ActionOneClickRetreat.Bind(HotkeyActions)},
        "OneClickSell", {Fn: HotkeyActions.ActionOneClickSell.Bind(HotkeyActions)},
        "OneClickPurchase", {Fn: HotkeyActions.ActionOneClickPurchase.Bind(HotkeyActions)}
    )

    ; 已激活热键映射表
    static ActiveHotkeys := Map()

    ; 已激活启用/禁用热键快捷键
    static ActiveSwitchHotkey := ""

    ; 包装动作回调（#213）：游戏失焦时鼠标悬停游戏即可操作——执行动作前激活游戏窗口（超时跳过）。
    ; 激活后不恢复原窗口（焦点留在游戏，由用户自行切换回，避免焦点闪回影响观感）。
    ; 判定层（HotkeyContext）负责判定触发，此处负责副作用（焦点切换），职责分离。
    ; 用嵌套函数（闭包）捕获 fn 作为 Hotkey 回调（AHK 文档：闭包可用于 Hotkey，见 Functions.htm#closures）。
    ; fn 是函数对象——AHK v2 中函数定义即同名只读变量（含 Func 对象），ActionCallbacks 的 Fn 存的是函数引用而非字符串，可直接调用。
    static _WrapAction(fn) {
        Wrapped(ThisHotkey) {
            ; 防御性检查：游戏窗口不存在则跳过（正常触发路径已由判定层保证存在，此处防异常阻塞）
            if !WinExist("ahk_exe Arknights.exe")
                return
            WinActivate("ahk_exe Arknights.exe")
            ; 激活超时（游戏窗口异常不可激活）则跳过动作，避免按键发往非游戏窗口
            if !WinWaitActive("ahk_exe Arknights.exe", , 500)
                return
            try {
                fn(ThisHotkey)
            } catch Error as e {
                ; 记录异常而非静默——动作内部出错需可排查（此前空 catch 会掩盖动作内部真实异常）
                Logger.Error("Hotkey", "动作执行失败：fn=" (IsObject(fn) ? fn.Name : fn) ", error=" e.Message)
            }
        }
        return Wrapped
    }

    ; 注册单个热键（数据驱动：profile.OnUp=功能在松开时触发；profile.Guarded=拦截键注册 Up 变体补发透传）
    ; 注意：属性访问用 HasOwnProp 判断——profile 无 OnUp/Guarded 属性时直接访问会抛 PropertyError
    static _RegisterOne(hotkeyValue, profile, pattern) {
        if (profile.HasOwnProp("OnUp") && !InStr(hotkeyValue, "Wheel")) {
            ; 松开暂停：功能在松开时触发（Up 变体注册）
            reg := (hotkeyValue ~= pattern) ? hotkeyValue " Up" : "~" hotkeyValue " Up"
            Hotkey(reg, profile.HasOwnProp("NoActivate") ? profile.Fn : this._WrapAction(profile.Fn), "On")
            HotkeyService.ActiveHotkeys.Set(reg, reg)
            return
        }
        intercept := hotkeyValue ~= pattern
        reg := intercept ? hotkeyValue : "~" hotkeyValue
        Hotkey(reg, profile.HasOwnProp("NoActivate") ? profile.Fn : this._WrapAction(profile.Fn), "On")
        HotkeyService.ActiveHotkeys.Set(reg, reg)
        ; 有守卫的拦截键（非滚轮）：注册 Up 变体，松开时由 KeyForward.ActionUpForward 补发 key up
        ; 注意：类静态方法引用需 Bind(KeyForward)——方法的 MinParams 含 self，直接传引用 Hotkey 回调验证会失败（Invalid callback function）
        if (profile.HasOwnProp("Guarded") && intercept && !InStr(hotkeyValue, "Wheel")) {
            Hotkey(hotkeyValue " Up", KeyForward.ActionUpForward.Bind(KeyForward), "On")
            HotkeyService.ActiveHotkeys.Set(hotkeyValue " Up", hotkeyValue " Up")
        }
    }

    ; 启用热键
    static HotkeyOn(*) {
        KeyForward.DownHandled.Clear()  ; 重建前清空运行时标记（保留 CaseSense）
        KeyForward.SuppressUp.Clear()
        HotIf(HotkeyContext)
        pattern := GameKeys.GetInterceptPattern()
        for keyVar, _ in Constants.KeyNames {
            hotkeyValue := Config.ReadHotkeyFromIni(keyVar)
            if (hotkeyValue != "" && this.ActionCallbacks.Has(keyVar)) {
                try this._RegisterOne(hotkeyValue, this.ActionCallbacks[keyVar], pattern)
                catch Error as e
                    Logger.Error("Hotkey", "注册热键失败：key=" keyVar ", value=" hotkeyValue ", callback=" this.ActionCallbacks[keyVar].Fn.Name ", error=" e.Message)
            }
        }
        HotIf
        Logger.Info("Hotkey", "热键已启用，数量=" this.ActiveHotkeys.Count ", 明细: " this._BuildDetailList(Constants.KeyNames))
    }

    ; 禁用热键
    static HotkeyOff(silent := false, *) {
        HotIf(HotkeyContext)
        for _ , hotkeyValue in HotkeyService.ActiveHotkeys {
            try Hotkey(hotkeyValue, , "Off")
            catch Error as e
                Logger.Error("Hotkey", "关闭热键失败：" hotkeyValue " - " e.Message)
        }
        HotkeyService.ActiveHotkeys := Map()
        KeyForward.DownHandled.Clear()
        KeyForward.SuppressUp.Clear()
        HotIf
        if !silent
            Logger.Info("Hotkey", "热键已禁用")
    }

    ; 启用指定组的热键
    static EnableGroup(groupMap) {
        HotIf(HotkeyContext)
        pattern := GameKeys.GetInterceptPattern()
        for keyVar, _ in groupMap {
            hotkeyValue := Config.ReadHotkeyFromIni(keyVar)
            if (hotkeyValue != "" && this.ActionCallbacks.Has(keyVar)) {
                try this._RegisterOne(hotkeyValue, this.ActionCallbacks[keyVar], pattern)
                catch Error as e
                    Logger.Error("Hotkey", "注册热键失败：key=" keyVar ", value=" hotkeyValue ", callback=" this.ActionCallbacks[keyVar].Fn.Name ", error=" e.Message)
            }
        }
        HotIf
    }

    ; 禁用指定组的热键
    static DisableGroup(groupMap) {
        HotIf(HotkeyContext)
        pattern := GameKeys.GetInterceptPattern()
        for keyVar, _ in groupMap {
            hotkeyValue := Config.ReadHotkeyFromIni(keyVar)
            if (hotkeyValue != "") {
                try Hotkey(hotkeyValue, , "Off")
                try Hotkey("~" hotkeyValue, , "Off")
                ; 仅注销并删除实际注册过的 Up 变体（与 _RegisterOne 同规则派生，保持 ActiveHotkeys 与实际注册一致）
                if (this.ActionCallbacks.Has(keyVar)) {
                    profile := this.ActionCallbacks[keyVar]
                    if ((profile.HasOwnProp("OnUp") || profile.HasOwnProp("Guarded")) && !InStr(hotkeyValue, "Wheel") && hotkeyValue ~= pattern) {
                        try Hotkey(hotkeyValue " Up", , "Off")
                        this.ActiveHotkeys.Delete(hotkeyValue " Up")
                    }
                }
                this.ActiveHotkeys.Delete(hotkeyValue)
                this.ActiveHotkeys.Delete("~" hotkeyValue)
                this.ActiveHotkeys.Delete("~" hotkeyValue " Up")
            }
        }
        HotIf
    }

    ; 构建热键明细列表（用于日志）
    static _BuildDetailList(keyMap) {
        list := ""
        for keyVar, _ in keyMap {
            hotkeyValue := Config.ReadHotkeyFromIni(keyVar)
            if (hotkeyValue != "" && this.ActionCallbacks.Has(keyVar))
                list .= keyVar "=" hotkeyValue ", "
        }
        if (list != "")
            return SubStr(list, 1, -2)
        return "(无)"
    }

    ; 构建当前活跃标签页的热键明细列表（用于日志）
    static _BuildDetailForActiveTab(tabName) {
        if (tabName = "keyBind" || tabName = "quick")
            return "战斗=" this._BuildDetailList(Constants.CombatHotkeys) " | 快捷=" this._BuildDetailList(Constants.QuickHotkeys)
        else if (tabName = "strongHoldProtocol")
            return "卫戍=" this._BuildDetailList(Constants.StrongHoldHotkeys)
        return ""
    }

    ; 根据标签页启用对应热键组
    static EnableByTab(tabName) {
        this.HotkeyOff(true)  ; 先静默禁用所有热键，重建完成后记录最终状态
        if (tabName = "keyBind" || tabName = "quick") {
            this.EnableGroup(Constants.CombatHotkeys)
            this.EnableGroup(Constants.QuickHotkeys)
        }
        else if (tabName = "strongHoldProtocol") {
            this.EnableGroup(Constants.StrongHoldHotkeys)
        }
        Logger.Info("Hotkey", "热键已重建，数量=" this.ActiveHotkeys.Count ", 标签页=" tabName ", 明细: " this._BuildDetailForActiveTab(tabName))
    }

    ; 切换热键启用/禁用（只发布事实，托盘文案/图标由 UI 订阅更新）
    static SwitchHotkey(*) {
        if(this.HotkeyState == true) {
            this.HotkeyOff()
            this.HotkeyState := false
            EventBus.Publish("HotkeyStateChanged", {enabled: false})
            Logger.Info("Hotkey", "用户禁用热键")
            return
        }
        if(this.HotkeyState == false) {
            this.HotkeyState := true
            ; 根据内部保存的标签页启用对应热键组
            this.EnableByTab(this._ActiveTab)
            EventBus.Publish("HotkeyStateChanged", {enabled: true})
            Logger.Info("Hotkey", "用户启用热键")
            return
        }
    }

    ; 设置热键启用/禁用快捷键
    static SetSwitchKey() {
        HotIf(HotkeyContext)
        switchKey := Config.ReadCustomFromIni("SwitchHotkey")
        if (switchKey != "") {
            try {
                Hotkey(switchKey, HotkeyService.SwitchHotkey.Bind(HotkeyService), "On")
                this.ActiveSwitchHotkey := switchKey
            } catch Error as e {
                Logger.Error("Hotkey", "注册SwitchKey失败：key=" switchKey ", callback=" this.SwitchHotkey.Name ", error=" e.Message)
            }
        }
        HotIf
        this._SwitchKey := switchKey
        EventBus.Publish("SwitchKeyChanged", {key: switchKey})
    }
    ; 解除设置热键启用/禁用快捷键
    static UnsetSwitchKey() {
        switchKey := this.ActiveSwitchHotkey
        if (switchKey != "") {
            HotIf(HotkeyContext)
            try Hotkey(switchKey, HotkeyService.SwitchHotkey.Bind(HotkeyService), "Off")
            catch Error as e
                Logger.Error("Hotkey", "关闭SwitchKey失败：" switchKey " - " e.Message)
            HotIf
        }
        this._SwitchKey := ""
        EventBus.Publish("SwitchKeyChanged", {key: ""})
    }
}
