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
        "BeginPause", ActionBeginPause,
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
                if (keyVar == "ReleasePause" && !InStr(hotkeyValue, "Wheel")) {
                    if (hotkeyValue ~= GameKeys.GetInterceptPattern()) {
                        Hotkey(hotkeyValue " Up", callback, "On")
                        HotkeyController.ActiveHotkeys.Set(hotkeyValue " Up", hotkeyValue " Up")
                    }
                    else {
                        Hotkey("~" hotkeyValue " Up", callback, "On")
                        HotkeyController.ActiveHotkeys.Set("~" hotkeyValue " Up", "~" hotkeyValue " Up")
                    }
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
            }
        }
        HotIf
        Logger.Info("Hotkey", "热键已启用，数量=" this.ActiveHotkeys.Count)
    }

    ; 禁用热键
    static HotkeyOff(silent := false, *) {
        HotIfWinActive("ahk_exe Arknights.exe")
        for _ , hotkeyValue in HotkeyController.ActiveHotkeys {
            Hotkey(hotkeyValue, , "Off")
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
                if (keyVar == "ReleasePause" && !InStr(hotkeyValue, "Wheel")) {
                    if (hotkeyValue ~= GameKeys.GetInterceptPattern()) {
                        Hotkey(hotkeyValue " Up", callback, "On")
                        HotkeyController.ActiveHotkeys.Set(hotkeyValue " Up", hotkeyValue " Up")
                    }
                    else {
                        Hotkey("~" hotkeyValue " Up", callback, "On")
                        HotkeyController.ActiveHotkeys.Set("~" hotkeyValue " Up", "~" hotkeyValue " Up")
                    }
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
                this.ActiveHotkeys.Delete(hotkeyValue)
                this.ActiveHotkeys.Delete("~" hotkeyValue)
            }
        }
        HotIf
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
        Logger.Info("Hotkey", "热键已重建，数量=" this.ActiveHotkeys.Count)
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
            Hotkey(switchKey, this.SwitchHotkey, "On")
            this.ActiveSwitchHotkey := switchKey
        }
        if (switchKey == "") {
            A_TrayMenu.Rename("2&", "启用/禁用热键")
            return
        }
        A_TrayMenu.Rename("2&", "启用/禁用热键(" KeyBinder.VirtualNewkeyFormat(switchKey) ")")
        HotIf
    }
    ; 解除设置热键启用/禁用快捷键
    static UnsetSwitchKey() {
        switchKey := this.ActiveSwitchHotkey
        if (switchKey != "")
            Hotkey(switchKey, this.SwitchHotkey, "Off")
        A_TrayMenu.Rename("2&", "启用/禁用热键")
    }
}
; 初始化热键控制器
HotkeyController.Init()
