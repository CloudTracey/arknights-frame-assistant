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
        "33ms", Action33ms,
        "166ms", Action166ms,
        "PauseSelect", ActionPauseSelect,
        "Skill", ActionSkill,
        "Retreat", ActionRetreat,
        "OneClickSkill", ActionOneClickSkill,
        "OneClickRetreat", ActionOneClickRetreat,
        "PauseSkill", ActionPauseSkill,
        "PauseRetreat", ActionPauseRetreat,
        "LButtonClick", ActionLButtonClick,
        "CeaseOperations", ActionCeaseOperations,
        "Skip", ActionSkip,
        "Back", ActionBack,
        "Harvest", ActionHarvest,
        "CollectCollectibles", ActionCollectCollectibles,
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

    ; 热键分组定义
    static CombatHotkeys := Map(
        "PressPause", true,
        "ReleasePause", true,
        "GameSpeed", true,
        "PauseSelect", true,
        "Skill", true,
        "Retreat", true,
        "33ms", true,
        "166ms", true,
        "OneClickSkill", true,
        "OneClickRetreat", true,
        "PauseSkill", true,
        "PauseRetreat", true
    )

    static QuickHotkeys := Map(
        "LButtonClick", true,
        "CeaseOperations", true,
        "Skip", true,
        "Back", true,
        "Harvest", true,
        "CollectCollectibles", true
    )

    static StrongHoldHotkeys := Map(
        "CheckEnemies", true,
        "DispatchCenter", true,
        "Freeze", true,
        "Refresh", true,
        "Upgrade", true,
        "Sell", true,
        "Ready", true,
        "StrongHoldProtocolLButtonClick", true,
        "StrongHoldProtocolRetreat", true,
        "StrongHoldProtocolOneClickRetreat", true,
        "OneClickSell", true,
        "OneClickPurchase", true
    )

    ; 已激活热键映射表
    static ActiveHotkeys := Map()

    ; 已激活启用/禁用热键快捷键
    static ActiveSwitchHotkey := ""

    ; 启用热键
    static HotkeyOn(*) {
        HotIfWinActive("ahk_exe Arknights.exe")
        for keyVar, _ in Constants.KeyNames {
            hotkeyValue := Config.GetHotkey(keyVar)
            if (hotkeyValue != "" && this.ActionCallbacks.Has(keyVar)) {
                callback := this.ActionCallbacks[keyVar]
                if (keyVar == "ReleasePause" && !InStr(hotkeyValue, "Wheel")) {
                    if (hotkeyValue ~= "i)\b(E|Q|F|G|V|W|A|S|D|G|X|C|RButton|MButton|Space|Escape|Tab)\b$") {
                        Hotkey(hotkeyValue " Up", callback, "On")
                        HotkeyController.ActiveHotkeys.Set(hotkeyValue " Up", hotkeyValue " Up")
                    }
                    else {
                        Hotkey("~" hotkeyValue " Up", callback, "On")
                        HotkeyController.ActiveHotkeys.Set("~" hotkeyValue " Up", "~" hotkeyValue " Up")
                    }
                } else {
                    if (hotkeyValue ~= "i)\b(E|Q|F|G|V|W|A|S|D|G|X|C|RButton|MButton|Space|Escape|Tab)\b$") {
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

    ; 禁用热键
    static HotkeyOff(*) {
        HotIfWinActive("ahk_exe Arknights.exe")
        for _ , hotkeyValue in HotkeyController.ActiveHotkeys {
            Hotkey(hotkeyValue, , "Off")
        }
        HotkeyController.ActiveHotkeys := Map()
        HotIf
    }

    ; 启用指定组的热键
    static EnableGroup(groupMap) {
        HotIfWinActive("ahk_exe Arknights.exe")
        for keyVar, _ in groupMap {
            hotkeyValue := Config.GetHotkey(keyVar)
            if (hotkeyValue != "" && this.ActionCallbacks.Has(keyVar)) {
                callback := this.ActionCallbacks[keyVar]
                if (keyVar == "ReleasePause" && !InStr(hotkeyValue, "Wheel")) {
                    if (hotkeyValue ~= "i)\b(E|Q|F|G|V|W|A|S|D|G|X|C|RButton|MButton|Space|Escape|Tab)\b$") {
                        Hotkey(hotkeyValue " Up", callback, "On")
                        HotkeyController.ActiveHotkeys.Set(hotkeyValue " Up", hotkeyValue " Up")
                    }
                    else {
                        Hotkey("~" hotkeyValue " Up", callback, "On")
                        HotkeyController.ActiveHotkeys.Set("~" hotkeyValue " Up", "~" hotkeyValue " Up")
                    }
                } else {
                    if (hotkeyValue ~= "i)\b(E|Q|F|G|V|W|A|S|D|G|X|C|RButton|MButton|Space|Escape|Tab)\b$") {
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
            hotkeyValue := Config.GetHotkey(keyVar)
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
        this.HotkeyOff()  ; 先禁用所有热键
        if (tabName = "keyBind" || tabName = "quick") {
            this.EnableGroup(this.CombatHotkeys)
            this.EnableGroup(this.QuickHotkeys)
        }
        else if (tabName = "strongHoldProtocol") {
            this.EnableGroup(this.StrongHoldHotkeys)
        }
    }

    ; 切换热键启用/禁用
    static SwitchHotkey() {
        if(HotkeyController.HotkeyState == true) {
            HotkeyController.HotkeyOff()
            HotkeyController.HotkeyState := false
            GuiManager.IsOnStrongHoldProtocol := false
            TrayTip
            TrayTip("热键已禁用", "AFA")
            A_IconTip := "AFA`n热键已禁用"
            return
        }
        if(HotkeyController.HotkeyState == false) {
            HotkeyController.HotkeyState := true
            ; 根据最后选中的标签页启用对应热键组
            this.EnableByTab(GuiManager.LastActiveTab)
            if (GuiManager.LastActiveTab == "strongHoldProtocol")
                GuiManager.IsOnStrongHoldProtocol := true
            TrayTip
            TrayTip("热键已启用", "AFA")
            A_IconTip := "AFA`n热键已启用"
            return
        }
    }

    ; 设置热键启用/禁用快捷键
    static SetSwitchKey() {
        HotIfWinActive("ahk_exe Arknights.exe")
        switchKey := Config.GetCustom("SwitchHotkey")
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