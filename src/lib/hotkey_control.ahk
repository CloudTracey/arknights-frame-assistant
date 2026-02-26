; == 热键控制 ==
class HotkeyController {
    ; 热键状态
    static HotkeyState := false
    
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
        "LButtonClick", LButtonClick,
    )

    ; 启用热键
    static HotkeyOn(*) {
        HotIfWinActive("ahk_exe Arknights.exe")
        for keyVar, _ in Constants.KeyNames {
            hotkeyValue := Config.GetHotkey(keyVar)
            if (hotkeyValue != "" && this.ActionCallbacks.Has(keyVar)) {
                callback := this.ActionCallbacks[keyVar]
                if (hotkeyValue ~= "i)^(E|Q|F|G|RButton|MButton)$") {
                    Hotkey(hotkeyValue, callback, "On")
                }
                else {
                    Hotkey("~" hotkeyValue, callback, "On")
                }
            }
        }
        this.HotkeyState := true
        HotIf
    }

    ; 禁用热键
    static HotkeyOff(*) {
        HotIfWinActive("ahk_exe Arknights.exe")
        for keyVar, _ in Constants.KeyNames {
            hotkeyValue := Config.GetHotkey(keyVar)
            if (hotkeyValue != "" && this.ActionCallbacks.Has(keyVar)) {
                callback := this.ActionCallbacks[keyVar]
                if (hotkeyValue ~= "i)^(E|Q|F|G|RButton|MButton)$") {
                    Hotkey(hotkeyValue, callback, "Off")
                }
                else {
                    Hotkey("~" hotkeyValue, callback, "Off")
                }
            }
        }
        this.HotkeyState := false
        HotIf
    }

    ; 切换热键启用/禁用
    static SwitchHotkey() {
        if(HotkeyController.HotkeyState == true) {
            HotkeyController.HotkeyOff
            TrayTip("热键已禁用", "AFA", 4)
            A_IconTip := "AFA`n热键已禁用"
            return
        }
        if(HotkeyController.HotkeyState == false) {
            HotkeyController.HotkeyOn
            TrayTip("热键已启用", "AFA", 4)
            A_IconTip := "AFA`n热键已启用"
            return
        }
    }

    ; 设置热键启用/禁用快捷键
    static SetSwitchKey() {
        switchKey := Config.GetCustom("SwitchHotkey")
        if (switchKey != "")
            Hotkey(switchKey, this.SwitchHotkey, "On")
    }
    ; 解除设置热键启用/禁用快捷键
    static UnsetSwitchKey() {
        switchKey := Config.GetCustom("SwitchHotkey")
        if (switchKey != "")
            Hotkey(switchKey, this.SwitchHotkey, "Off")
    }
}
; 初始化热键控制器
HotkeyController.Init()