; == 热键冲突验证器 ==

; 统一提供设置界面实时提示和保存阶段最终校验使用的冲突规则。
class HotkeyConflictValidator {
    ; 检查当前内存中的按键设置，返回全部冲突。
    ; 返回：{HasConflicts, Items, ByControl}
    static FindAll(hotkeys, customSettings) {
        bindings := hotkeys.Clone()
        bindings["SwitchHotkey"] := customSettings.Has("SwitchHotkey")
            ? customSettings["SwitchHotkey"]
            : ""

        conflicts := []
        byControl := Map()

        this._FindGroupConflicts(
            [Constants.CombatHotkeys, Constants.QuickHotkeys],
            bindings,
            conflicts,
            byControl
        )
        this._FindGroupConflicts(
            [Constants.StrongHoldHotkeys],
            bindings,
            conflicts,
            byControl
        )

        return {
            HasConflicts: conflicts.Length > 0,
            Items: conflicts,
            ByControl: byControl
        }
    }

    ; 在同时启用的热键组及切换热键中查找重复按键。
    static _FindGroupConflicts(hotkeyGroups, bindings, conflicts, byControl) {
        usedKeys := Map()

        for hotkeyGroup in hotkeyGroups {
            for controlName, _ in hotkeyGroup
                this._CheckControlConflict(controlName, bindings, usedKeys, conflicts, byControl)
        }
        this._CheckControlConflict("SwitchHotkey", bindings, usedKeys, conflicts, byControl)
    }

    ; 检查单个控件，并记录与组内已有按键的冲突关系。
    static _CheckControlConflict(controlName, bindings, usedKeys, conflicts, byControl) {
        if !bindings.Has(controlName)
            return

        displayKey := bindings[controlName]
        normalizedKey := StrLower(Trim(displayKey))
        if (normalizedKey = "")
            return

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

    ; 将冲突关系按控件名称建立索引，便于 GUI 同时标红双方。
    static _AddControlConflict(byControl, controlName, conflict) {
        if !byControl.Has(controlName)
            byControl[controlName] := []
        byControl[controlName].Push(conflict)
    }

    ; 获取设置界面显示名称，用于保存阶段的错误提示。
    static GetDisplayName(controlName) {
        if Constants.KeyNames.Has(controlName)
            return I18n.T(Constants.KeyNames[controlName])
        if Constants.CustomNames.Has(controlName)
            return I18n.T(Constants.CustomNames[controlName])
        return controlName
    }
}
