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
        "LButtonClick", LButtonClick,
    )

    ; 已激活热键映射表
    static ActiveHotkeys := Map()

    ; 启用热键
    static HotkeyOn(*) {
        HotIfWinActive("ahk_exe Arknights.exe")
        for keyVar, _ in Constants.KeyNames {
            hotkeyValue := Config.GetHotkey(keyVar)
            if (hotkeyValue != "" && this.ActionCallbacks.Has(keyVar)) {
                callback := this.ActionCallbacks[keyVar]
                if (hotkeyValue ~= "i)\b(E|Q|F|G|RButton|MButton)\b$") {
                    Hotkey(hotkeyValue, callback, "On")
                    HotkeyController.ActiveHotkeys.Set(hotkeyValue, hotkeyValue)
                }
                else {
                    Hotkey("~" hotkeyValue, callback, "On")
                    HotkeyController.ActiveHotkeys.Set("~" hotkeyValue, "~" hotkeyValue)
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

    ; 切换热键启用/禁用
    static SwitchHotkey() {
        if(HotkeyController.HotkeyState == true) {
            HotkeyController.HotkeyOff()
            HotkeyController.HotkeyState := false
            TrayTip
            TrayTip("热键已禁用", "AFA")
            A_IconTip := "AFA`n热键已禁用"
            return
        }
        if(HotkeyController.HotkeyState == false) {
            HotkeyController.HotkeyOn()
            HotkeyController.HotkeyState := true
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
        if (switchKey != "")
            Hotkey(switchKey, this.SwitchHotkey, "On")
        HotIf
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