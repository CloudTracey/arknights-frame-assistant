; == 热键控制 ==
class HotkeyController {
    ; 热键状态
    static HotkeyState := true

    ; 初始化热键控制器
    static Init() {
        HotkeyController._SubscribeEvents()
    }

    ; 内部：订阅热键事件
    static _SubscribeEvents() {
        EventBus.Subscribe("HotkeyOff", (*) => this.HotkeyOff())
        EventBus.Subscribe("UnsetSwitchKey", (*) => this.UnsetSwitchKey())
        EventBus.Subscribe("HotkeyOn", (*) => this.HotkeyOn())
        EventBus.Subscribe("SetSwitchKey", (*) => this.SetSwitchKey())
        EventBus.Subscribe("SwitchHotkey", (*) => this.SwitchHotkey())
    }

    ; 热键回调映射表（profile.Fn 回调；profile.Guarded 有关卡守卫——拦截键注册 Up 变体补发透传；profile.OnUp 功能在松开时触发）
    static ActionCallbacks := Map(
        ; 常规作战（有守卫）
        "PressPause", {Fn: ActionPressPause, Guarded: true},
        "ReleasePause", {Fn: ActionReleasePause, OnUp: true},  ; 松开时触发（Up 变体注册）
        "GameSpeed", {Fn: ActionGameSpeed, Guarded: true},
        "16ms", {Fn: Action16ms, Guarded: true},
        "33ms", {Fn: Action33ms, Guarded: true},
        "166ms", {Fn: Action166ms, Guarded: true},
        "PauseSelect", {Fn: ActionPauseSelect, Guarded: true},
        "Skill", {Fn: ActionSkill, Guarded: true},
        "Retreat", {Fn: ActionRetreat, Guarded: true},
        "OneClickSkill", {Fn: ActionOneClickSkill, Guarded: true},
        "OneClickRetreat", {Fn: ActionOneClickRetreat, Guarded: true},
        "PauseSkill", {Fn: ActionPauseSkill, Guarded: true},
        "PauseRetreat", {Fn: ActionPauseRetreat, Guarded: true},
        "SwitchView", {Fn: ActionSwitchView, Guarded: true},
        "BeginPause", {Fn: ActionBeginPauseSwitch},
        "AutoBeginPauseSwitch", {Fn: ActionBeginPauseSwitch},
        ; 快捷操作
        "LButtonClick", {Fn: ActionLButtonClick},
        "CeaseOperations", {Fn: ActionCeaseOperations},
        "Skip", {Fn: ActionSkip},
        "Back", {Fn: ActionBack},
        "Harvest", {Fn: ActionHarvest},
        "CollectCollectibles", {Fn: ActionCollectCollectibles},
        ; 卫戍协议
        "CheckEnemies", {Fn: ActionCheckEnemies},
        "DispatchCenter", {Fn: ActionDispatchCenter},
        "Freeze", {Fn: ActionFreeze},
        "Refresh", {Fn: ActionRefresh},
        "Upgrade", {Fn: ActionUpgrade},
        "Sell", {Fn: ActionSell},
        "Ready", {Fn: ActionReady},
        "StrongHoldProtocolLButtonClick", {Fn: ActionLButtonClick},
        "StrongHoldProtocolRetreat", {Fn: ActionRetreat},
        "StrongHoldProtocolOneClickRetreat", {Fn: ActionOneClickRetreat},
        "OneClickSell", {Fn: ActionOneClickSell},
        "OneClickPurchase", {Fn: ActionOneClickPurchase}
    )

    ; 已激活热键映射表
    static ActiveHotkeys := Map()

    ; 已激活启用/禁用热键快捷键
    static ActiveSwitchHotkey := ""

    ; 注册单个热键（数据驱动：profile.OnUp=功能在松开时触发；profile.Guarded=拦截键注册 Up 变体补发透传）
    ; 注意：属性访问用 HasOwnProp 判断——profile 无 OnUp/Guarded 属性时直接访问会抛 PropertyError
    static _RegisterOne(hotkeyValue, profile, pattern) {
        if (profile.HasOwnProp("OnUp") && !InStr(hotkeyValue, "Wheel")) {
            ; 松开暂停：功能在松开时触发（Up 变体注册）
            reg := (hotkeyValue ~= pattern) ? hotkeyValue " Up" : "~" hotkeyValue " Up"
            Hotkey(reg, profile.Fn, "On")
            HotkeyController.ActiveHotkeys.Set(reg, reg)
            return
        }
        intercept := hotkeyValue ~= pattern
        reg := intercept ? hotkeyValue : "~" hotkeyValue
        Hotkey(reg, profile.Fn, "On")
        HotkeyController.ActiveHotkeys.Set(reg, reg)
        ; 有守卫的拦截键（非滚轮）：注册 Up 变体，松开时由 ActionUpForward 补发 key up
        if (profile.HasOwnProp("Guarded") && intercept && !InStr(hotkeyValue, "Wheel")) {
            Hotkey(hotkeyValue " Up", ActionUpForward, "On")
            HotkeyController.ActiveHotkeys.Set(hotkeyValue " Up", hotkeyValue " Up")
        }
    }

    ; 启用热键
    static HotkeyOn(*) {
        HotIfWinActive("ahk_exe Arknights.exe")
        pattern := GameKeys.GetInterceptPattern()
        for keyVar, _ in Constants.KeyNames {
            hotkeyValue := Config.ReadHotkeyFromIni(keyVar)
            if (hotkeyValue != "" && this.ActionCallbacks.Has(keyVar)) {
                try this._RegisterOne(hotkeyValue, this.ActionCallbacks[keyVar], pattern)
                catch Error as e
                    Logger.Error("Hotkey", "注册热键失败：key=" keyVar ", value=" hotkeyValue ", error=" e.Message)
            }
        }
        HotIf
        Logger.Info("Hotkey", "热键已启用，数量=" this.ActiveHotkeys.Count ", 明细: " this._BuildDetailList(Constants.KeyNames))
    }

    ; 禁用热键
    static HotkeyOff(silent := false, *) {
        HotIfWinActive("ahk_exe Arknights.exe")
        for _ , hotkeyValue in HotkeyController.ActiveHotkeys {
            try Hotkey(hotkeyValue, , "Off")
            catch Error as e
                Logger.Error("Hotkey", "关闭热键失败：" hotkeyValue " - " e.Message)
        }
        HotkeyController.ActiveHotkeys := Map()
        HotIf
        if !silent
            Logger.Info("Hotkey", "热键已禁用")
    }

    ; 启用指定组的热键
    static EnableGroup(groupMap) {
        HotIfWinActive("ahk_exe Arknights.exe")
        pattern := GameKeys.GetInterceptPattern()
        for keyVar, _ in groupMap {
            hotkeyValue := Config.ReadHotkeyFromIni(keyVar)
            if (hotkeyValue != "" && this.ActionCallbacks.Has(keyVar)) {
                try this._RegisterOne(hotkeyValue, this.ActionCallbacks[keyVar], pattern)
                catch Error as e
                    Logger.Error("Hotkey", "注册热键失败：key=" keyVar ", value=" hotkeyValue ", error=" e.Message)
            }
        }
        HotIf
    }

    ; 禁用指定组的热键
    static DisableGroup(groupMap) {
        HotIfWinActive("ahk_exe Arknights.exe")
        pattern := GameKeys.GetInterceptPattern()
        for keyVar, _ in groupMap {
            hotkeyValue := Config.ReadHotkeyFromIni(keyVar)
            if (hotkeyValue != "") {
                try Hotkey(hotkeyValue, , "Off")
                try Hotkey("~" hotkeyValue, , "Off")
                ; 仅注销实际注册过的 Up 变体（与 _RegisterOne 同规则派生，避免对未注册变体盲目注销）
                if (this.ActionCallbacks.Has(keyVar)) {
                    profile := this.ActionCallbacks[keyVar]
                    if ((profile.HasOwnProp("OnUp") || profile.HasOwnProp("Guarded")) && !InStr(hotkeyValue, "Wheel") && hotkeyValue ~= pattern)
                        try Hotkey(hotkeyValue " Up", , "Off")
                }
                this.ActiveHotkeys.Delete(hotkeyValue)
                this.ActiveHotkeys.Delete("~" hotkeyValue)
                this.ActiveHotkeys.Delete(hotkeyValue " Up")
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

    ; 切换热键启用/禁用
    static SwitchHotkey() {
        if(HotkeyController.HotkeyState == true) {
            HotkeyController.HotkeyOff()
            HotkeyController.HotkeyState := false
            GuiManager.IsOnStrongHoldProtocol := false
            TrayTip
            SetTimer HideTrayTip, 0
            TrayTip("热键已禁用", "AFA")
            SetTimer HideTrayTip, -4000
            Logger.Info("Hotkey", "用户禁用热键")
            A_IconTip := "AFA`n热键已禁用"
            return
        }
        if(HotkeyController.HotkeyState == false) {
            HotkeyController.HotkeyState := true
            ; 根据最后选中的标签页启用对应热键组
            HotkeyController.EnableByTab(GuiManager.LastActiveTab)
            if (GuiManager.LastActiveTab == "strongHoldProtocol")
                GuiManager.IsOnStrongHoldProtocol := true
            TrayTip
            SetTimer HideTrayTip, 0
            TrayTip("热键已启用", "AFA")
            SetTimer HideTrayTip, -4000
            Logger.Info("Hotkey", "用户启用热键")
            A_IconTip := "AFA`n热键已启用"
            return
        }
    }

    ; 设置热键启用/禁用快捷键
    static SetSwitchKey() {
        HotIfWinActive("ahk_exe Arknights.exe")
        switchKey := Config.ReadCustomFromIni("SwitchHotkey")
        if (switchKey != "") {
            try {
                Hotkey(switchKey, this.SwitchHotkey, "On")
                this.ActiveSwitchHotkey := switchKey
            } catch Error as e {
                Logger.Error("Hotkey", "注册SwitchKey失败：key=" switchKey ", callback=" this.SwitchHotkey.Name ", error=" e.Message)
            }
        }
        HotIf
        if (switchKey == "") {
            A_TrayMenu.Rename("2&", "启用/禁用热键")
            return
        }
        A_TrayMenu.Rename("2&", "启用/禁用热键(" KeyBinder.VirtualNewkeyFormat(switchKey) ")")
    }
    ; 解除设置热键启用/禁用快捷键
    static UnsetSwitchKey() {
        switchKey := this.ActiveSwitchHotkey
        if (switchKey != "") {
            HotIfWinActive("ahk_exe Arknights.exe")
            try Hotkey(switchKey, this.SwitchHotkey, "Off")
            catch Error as e
                Logger.Error("Hotkey", "关闭SwitchKey失败：" switchKey " - " e.Message)
            HotIf
        }
        A_TrayMenu.Rename("2&", "启用/禁用热键")
    }
}
; 初始化热键控制器
HotkeyController.Init()
