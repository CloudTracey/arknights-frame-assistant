; == 热键冲突验证器 ==

; 统一提供设置界面实时提示和保存阶段最终校验使用的冲突规则。
class HotkeyConflictValidator {
    ; 检查当前内存中的按键设置，返回全部冲突。
    ; hotkeys: 标准热键工作副本；customSettings: 自定义设置工作副本；
    ; customHotkeys: 自定义按键投影 Array<{Index, Key, Type}>（可选，缺省视为无自定义按键）。
    ; 返回：{HasConflicts, Items, ByControl}
    static FindAll(hotkeys, customSettings, customHotkeys := "") {
        bindings := hotkeys.Clone()
        bindings["SwitchHotkey"] := customSettings.Has("SwitchHotkey")
            ? customSettings["SwitchHotkey"]
            : ""

        ; 自定义按键按"类型"并入同时启用的冲突组：
        ; global 始终生效 → 并入两组；combat/quick 并入常规组；strongHold 并入卫戍组。
        customCombatQuick := Map()
        customStrongHold := Map()
        if IsObject(customHotkeys) {
            for entry in customHotkeys {
                controlName := "CustomHotkey" entry.Index "Key"
                bindings[controlName] := entry.Key
                switch entry.Type {
                    case "global":
                        customCombatQuick[controlName] := true
                        customStrongHold[controlName] := true
                    case "combat", "quick":
                        customCombatQuick[controlName] := true
                    case "strongHold":
                        customStrongHold[controlName] := true
                }
            }
        }

        conflicts := []
        byControl := Map()
        seen := Map()  ; 同一对冲突在两组各命中一次时去重（如两条 global 互撞）

        this._FindGroupConflicts(
            [Constants.CombatHotkeys, Constants.QuickHotkeys, customCombatQuick],
            bindings,
            conflicts,
            byControl,
            seen
        )
        this._FindGroupConflicts(
            [Constants.StrongHoldHotkeys, customStrongHold],
            bindings,
            conflicts,
            byControl,
            seen
        )

        ; 有冲突时落 Info 级完整列表（无冲突不记录，避免每次绑定变更刷日志）。
        ; 用 Info 而非 Warn：改键途中的临时冲突是预期内场景（GUI 已标红提示），
        ; 不应进入关键日志轨（critical-*.log 5MiB 留给真正的错误/警告）；
        ; 若保存阶段因此中止，SettingsService 会另行记录 Warn。
        ; 冲突记录使用控件名（内部标识而非显示名），与 GUI 标红控件一一对应，便于定位「保存中止」原因。
        if (conflicts.Length > 0) {
            summary := ""
            for conflict in conflicts
                summary .= (summary = "" ? "" : "; ") conflict.FirstControl "=" conflict.Key " ↔ " conflict.SecondControl
            Logger.Info("Hotkeys", "检测到热键冲突 " conflicts.Length " 处：" summary)
        }

        return {
            HasConflicts: conflicts.Length > 0,
            Items: conflicts,
            ByControl: byControl
        }
    }

    ; 在同时启用的热键组及切换热键中查找重复按键。
    static _FindGroupConflicts(hotkeyGroups, bindings, conflicts, byControl, seen) {
        usedKeys := Map()

        for hotkeyGroup in hotkeyGroups {
            for controlName, _ in hotkeyGroup
                this._CheckControlConflict(controlName, bindings, usedKeys, conflicts, byControl, seen)
        }
        this._CheckControlConflict("SwitchHotkey", bindings, usedKeys, conflicts, byControl, seen)
    }

    ; 检查单个控件，并记录与组内已有按键的冲突关系。
    static _CheckControlConflict(controlName, bindings, usedKeys, conflicts, byControl, seen) {
        if !bindings.Has(controlName)
            return

        displayKey := bindings[controlName]
        normalizedKey := StrLower(Trim(displayKey))
        if (normalizedKey = "")
            return

        if usedKeys.Has(normalizedKey) {
            firstControl := usedKeys[normalizedKey]
            ; 去重：同一对控件可能在多个冲突组各命中一次，只记录第一次。
            ; 注意 AHK v2 的 <= 是数值比较，对字符串会抛"Expected a Number but got a String"，必须用 StrCompare。
            pairKey := (StrCompare(firstControl, controlName) <= 0)
                ? firstControl "|" controlName
                : controlName "|" firstControl
            if seen.Has(pairKey)
                return
            seen[pairKey] := true
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
        if RegExMatch(controlName, "^CustomHotkey(\d+)Key$", &m) {
            index := Integer(m[1])
            entries := Config.AllCustomHotkeys
            if index >= 1 && index <= entries.Length {
                name := Trim(entries[index].Name)
                if name != ""
                    return name
            }
            return I18n.T("自定义按键 {1}", index)
        }
        return controlName
    }
}
