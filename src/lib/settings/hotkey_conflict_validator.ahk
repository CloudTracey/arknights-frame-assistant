; == 热键冲突验证器 ==

; 统一提供设置界面实时提示和保存阶段最终校验使用的冲突规则。
class HotkeyConflictValidator {
    ; 常规作战、快捷操作和切换热键互相检测
    static BattleKeys := [
        "PressPause", "ReleasePause", "GameSpeed", "PauseSelect",
        "Skill", "Retreat", "16ms", "33ms", "166ms", "OneClickSkill",
        "OneClickRetreat", "PauseSkill", "PauseRetreat", "LButtonClick",
        "CeaseOperations", "Skip", "Back", "Harvest", "CollectCollectibles",
        "SwitchView", "BeginPause", "AutoBeginPauseSwitch", "SwitchHotkey"
    ]

    ; 卫戍协议和切换热键互相检测
    static StrongholdKeys := [
        "CheckEnemies", "DispatchCenter", "Freeze", "Refresh", "Upgrade",
        "Sell", "Ready", "StrongHoldProtocolLButtonClick",
        "StrongHoldProtocolRetreat", "StrongHoldProtocolOneClickRetreat",
        "OneClickSell", "OneClickPurchase", "SwitchHotkey"
    ]

    ; 检查当前内存中的按键设置，返回全部冲突。
    ; 返回：{HasConflicts, Items, ByControl}
    static FindAll(hotkeys, customSettings) {
        bindings := hotkeys.Clone()
        bindings["SwitchHotkey"] := customSettings.Has("SwitchHotkey")
            ? customSettings["SwitchHotkey"]
            : ""

        conflicts := []
        byControl := Map()

        this._FindGroupConflicts(this.BattleKeys, bindings, conflicts, byControl)
        this._FindGroupConflicts(this.StrongholdKeys, bindings, conflicts, byControl)

        return {
            HasConflicts: conflicts.Length > 0,
            Items: conflicts,
            ByControl: byControl
        }
    }

    ; 在单个冲突组内查找重复按键。
    static _FindGroupConflicts(controlNames, bindings, conflicts, byControl) {
        usedKeys := Map()

        for controlName in controlNames {
            if !bindings.Has(controlName)
                continue

            displayKey := bindings[controlName]
            normalizedKey := StrLower(Trim(displayKey))
            if (normalizedKey = "")
                continue

            if usedKeys.Has(normalizedKey) {
                firstControl := usedKeys[normalizedKey]
                conflict := {
                    Key: displayKey,
                    FirstControl: firstControl,
                    SecondControl: controlName
                }
                conflicts.Push(conflict)
                this._AddControlConflict(byControl, firstControl, conflict)
                this._AddControlConflict(byControl, controlName, conflict)
            } else {
                usedKeys[normalizedKey] := controlName
            }
        }
    }

    ; 将冲突关系按控件名称建立索引，便于 GUI 同时标红双方。
    static _AddControlConflict(byControl, controlName, conflict) {
        if !byControl.Has(controlName)
            byControl[controlName] := []
        byControl[controlName].Push(conflict)
    }

    ; 获取设置界面显示名称，用于保存阶段的错误提示。
    static GetDisplayName(controlName) {
        if Constants.KeyNames.Has(controlName)
            return Constants.KeyNames[controlName]
        if Constants.CustomNames.Has(controlName)
            return Constants.CustomNames[controlName]
        return controlName
    }
}
