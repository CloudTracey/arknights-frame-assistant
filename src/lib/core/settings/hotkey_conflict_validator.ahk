; == 热键冲突验证器 ==

class HotkeyConflictValidator {
    ; 检查按键设置并返回全部冲突
    ; 返回 {HasConflicts, Items, ByControl}
    static FindAll(hotkeys, customSettings, customHotkeys := "") {
        bindings := hotkeys.Clone()
        bindings["SwitchHotkey"] := customSettings.Has("SwitchHotkey")
            ? customSettings["SwitchHotkey"]
            : ""

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
        seen := Map()  ; 同对冲突在两组各命中一次时去重

        ; 方案切换和音量组在常规/快捷/卫戍三个功能页都启用，故同时并入两组检查
        this._FindGroupConflicts(
            [Constants.CombatHotkeys, Constants.QuickHotkeys, Constants.ModeHotkeys, Constants.VolumeHotkeys, customCombatQuick],
            bindings,
            conflicts,
            byControl,
            seen
        )
        this._FindGroupConflicts(
            [Constants.StrongHoldHotkeys, Constants.ModeHotkeys, Constants.VolumeHotkeys, customStrongHold],
            bindings,
            conflicts,
            byControl,
            seen
        )

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

    ; 在同时启用的热键组及切换热键中查找重复按键
    static _FindGroupConflicts(hotkeyGroups, bindings, conflicts, byControl, seen) {
        usedKeys := Map()

        for hotkeyGroup in hotkeyGroups {
            for controlName, _ in hotkeyGroup
                this._CheckControlConflict(controlName, bindings, usedKeys, conflicts, byControl, seen)
        }
        this._CheckControlConflict("SwitchHotkey", bindings, usedKeys, conflicts, byControl, seen)
    }

    ; 检查单个控件并记录冲突关系
    static _CheckControlConflict(controlName, bindings, usedKeys, conflicts, byControl, seen) {
        if !bindings.Has(controlName)
            return

        displayKey := bindings[controlName]
        normalizedKey := StrLower(Trim(displayKey))
        if (normalizedKey = "")
            return

        if usedKeys.Has(normalizedKey) {
            firstControl := usedKeys[normalizedKey]
            ; 不能用 <=（数值比较，字符串会抛 Expected a Number），须用 StrCompare
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

    ; 将冲突关系按控件名称建立索引
    static _AddControlConflict(byControl, controlName, conflict) {
        if !byControl.Has(controlName)
            byControl[controlName] := []
        byControl[controlName].Push(conflict)
    }

    ; 设置界面显示名称（错误提示用）
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
