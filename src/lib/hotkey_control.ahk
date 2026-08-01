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

    ; 热键回调函数映射表
    static ActionCallbacks := Map(
        "PressPause", ActionPressPause,
        "ReleasePause", ActionReleasePause,
        "GameSpeed", ActionGameSpeed,
        "16ms", Action16ms,
        "33ms", Action33ms,
        "166ms", Action166ms,
        "PauseSelect", ActionPauseSelect,
        "Skill", ActionSkill,
        "Retreat", ActionRetreat,
        "OneClickSkill", ActionOneClickSkill,
        "OneClickRetreat", ActionOneClickRetreat,
        "PauseSkill", ActionPauseSkill,
        "PauseRetreat", ActionPauseRetreat,
        "AutoBeginPauseSwitch", ActionBeginPauseSwitch,
        "LButtonClick", ActionLButtonClick,
        "CeaseOperations", ActionCeaseOperations,
        "Skip", ActionSkip,
        "Back", ActionBack,
        "Harvest", ActionHarvest,
        "CollectCollectibles", ActionCollectCollectibles,
        "SwitchView", ActionSwitchView,
        "BeginPause", ActionBeginPauseSwitch,
        "CheckEnemies", ActionCheckEnemies,
        "DispatchCenter", ActionDispatchCenter,
        "Freeze", ActionFreeze,
        "Refresh", ActionRefresh,
        "Upgrade", ActionUpgrade,
        "Sell", ActionSell,
        "Ready", ActionReady,
        "StrongHoldProtocolLButtonClick", ActionLButtonClick,
        "StrongHoldProtocolRetreat", ActionRetreat,
        "StrongHoldProtocolOneClickRetreat", ActionOneClickRetreat,
        "OneClickSell", ActionOneClickSell,
        "OneClickPurchase", ActionOneClickPurchase
    )

    ; 有关卡检测守卫的常规作战功能（守卫拦截时透传 key down/up：注册 Up 变体热键补发 key up）
    ; 不含 ReleasePause（其功能本身即 Up 变体注册，走独立分支）
    static LevelGuardedKeys := Map(
        "PressPause", true, "GameSpeed", true, "16ms", true, "33ms", true, "166ms", true,
        "PauseSelect", true, "Skill", true, "Retreat", true,
        "OneClickSkill", true, "OneClickRetreat", true, "PauseSkill", true, "PauseRetreat", true,
        "SwitchView", true
    )

    ; 已激活热键映射表
    static ActiveHotkeys := Map()

    ; 已激活启用/禁用热键快捷键
    static ActiveSwitchHotkey := ""

    ; 启用热键
    static HotkeyOn(*) {
        HotIfWinActive("ahk_exe Arknights.exe")
        for keyVar, _ in Constants.KeyNames {
            hotkeyValue := Config.ReadHotkeyFromIni(keyVar)
            if (hotkeyValue != "" && this.ActionCallbacks.Has(keyVar)) {
                callback := this.ActionCallbacks[keyVar]
                try {
                    if (keyVar == "ReleasePause" && !InStr(hotkeyValue, "Wheel")) {
                        if (hotkeyValue ~= GameKeys.GetInterceptPattern()) {
                            Hotkey(hotkeyValue " Up", callback, "On")
                            HotkeyController.ActiveHotkeys.Set(hotkeyValue " Up", hotkeyValue " Up")
                        }
                        else {
                            Hotkey("~" hotkeyValue " Up", callback, "On")
                            HotkeyController.ActiveHotkeys.Set("~" hotkeyValue " Up", "~" hotkeyValue " Up")
                        }
                    } else if (this.LevelGuardedKeys.Has(keyVar) && !InStr(hotkeyValue, "Wheel") && hotkeyValue ~= GameKeys.GetInterceptPattern()) {
                        ; 有守卫的常规作战功能（拦截键）：注册 down 热键 + Up 变体（Up 回调补发 key up，事件驱动透传）
                        Hotkey(hotkeyValue, callback, "On")
                        HotkeyController.ActiveHotkeys.Set(hotkeyValue, hotkeyValue)
                        Hotkey(hotkeyValue " Up", ActionUpForward, "On")
                        HotkeyController.ActiveHotkeys.Set(hotkeyValue " Up", hotkeyValue " Up")
                    } else {
                        if (hotkeyValue ~= GameKeys.GetInterceptPattern()) {
                            Hotkey(hotkeyValue, callback, "On")
                            HotkeyController.ActiveHotkeys.Set(hotkeyValue, hotkeyValue)
                        }
                        else {
                            Hotkey("~" hotkeyValue, callback, "On")
                            HotkeyController.ActiveHotkeys.Set("~" hotkeyValue, "~" hotkeyValue)
                        }
                    }
                } catch Error as e {
                    Logger.Error("Hotkey", "注册热键失败：key=" keyVar ", value=" hotkeyValue ", callback=" callback.Name ", error=" e.Message)
                }
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
        for keyVar, _ in groupMap {
            hotkeyValue := Config.ReadHotkeyFromIni(keyVar)
            if (hotkeyValue != "" && this.ActionCallbacks.Has(keyVar)) {
                callback := this.ActionCallbacks[keyVar]
                try {
                    if (keyVar == "ReleasePause" && !InStr(hotkeyValue, "Wheel")) {
                        if (hotkeyValue ~= GameKeys.GetInterceptPattern()) {
                            Hotkey(hotkeyValue " Up", callback, "On")
                            HotkeyController.ActiveHotkeys.Set(hotkeyValue " Up", hotkeyValue " Up")
                        }
                        else {
                            Hotkey("~" hotkeyValue " Up", callback, "On")
                            HotkeyController.ActiveHotkeys.Set("~" hotkeyValue " Up", "~" hotkeyValue " Up")
                        }
                    } else if (this.LevelGuardedKeys.Has(keyVar) && !InStr(hotkeyValue, "Wheel") && hotkeyValue ~= GameKeys.GetInterceptPattern()) {
                        ; 有守卫的常规作战功能（拦截键）：注册 down 热键 + Up 变体（Up 回调补发 key up，事件驱动透传）
                        Hotkey(hotkeyValue, callback, "On")
                        HotkeyController.ActiveHotkeys.Set(hotkeyValue, hotkeyValue)
                        Hotkey(hotkeyValue " Up", ActionUpForward, "On")
                        HotkeyController.ActiveHotkeys.Set(hotkeyValue " Up", hotkeyValue " Up")
                    } else {
                        if (hotkeyValue ~= GameKeys.GetInterceptPattern()) {
                            Hotkey(hotkeyValue, callback, "On")
                            HotkeyController.ActiveHotkeys.Set(hotkeyValue, hotkeyValue)
                        }
                        else {
                            Hotkey("~" hotkeyValue, callback, "On")
                            HotkeyController.ActiveHotkeys.Set("~" hotkeyValue, "~" hotkeyValue)
                        }
                    }
                } catch Error as e {
                    Logger.Error("Hotkey", "注册热键失败：key=" keyVar ", value=" hotkeyValue ", callback=" callback.Name ", error=" e.Message)
                }
            }
        }
        HotIf
    }

    ; 禁用指定组的热键
    static DisableGroup(groupMap) {
        HotIfWinActive("ahk_exe Arknights.exe")
        for keyVar, _ in groupMap {
            hotkeyValue := Config.ReadHotkeyFromIni(keyVar)
            if (hotkeyValue != "") {
                try Hotkey(hotkeyValue, , "Off")
                try Hotkey("~" hotkeyValue, , "Off")
                try Hotkey(hotkeyValue " Up", , "Off")
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
