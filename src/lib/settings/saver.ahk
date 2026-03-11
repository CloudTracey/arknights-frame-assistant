; == 设置保存器 ==
class Saver {
    ; 记录设置并写入配置文件
    static SettingsIniWrite() {
        EventBus.Publish("SettingsWillSave")
        SavedObj := GuiManager.Submit()
        
        ; 检查按键冲突
        if (!this._CheckKeyConflicts(SavedObj)) {
            Exit
        }
        
        ; 验证GitHub Token（如果输入了的话）
        if (SavedObj.HasProp("GitHubToken") && SavedObj.GitHubToken != "") {
            ; 如果Token与当前保存的不同，需要验证
            currentToken := Config.GetImportant("GitHubToken")
            if (SavedObj.GitHubToken != currentToken) {
                ; 验证新Token
                tokenResult := VersionChecker.ValidateToken(SavedObj.GitHubToken)
                if (!tokenResult.valid) {
                    result := MessageBox.Confirm("GitHub Token验证失败：" tokenResult.message "`n`n是否仍要保存此Token？", "Token验证失败")
                    if (result = "No") {
                        Exit
                    }
                } else {
                    ; Token有效，更新验证状态
                    VersionChecker.TokenValidated := true
                    MessageBox.Info("GitHub Token验证成功！`n用户: " tokenResult.username "`nAPI配额: " tokenResult.rateLimit, "Token有效")
                }
            }
        }
        
        ; 验证游戏路径
        if (SavedObj.HasProp("GamePath") && SavedObj.GamePath != "") {
            if !FileExist(SavedObj.GamePath) {
                result := MessageBox.Confirm("游戏路径不存在：`n" SavedObj.GamePath "`n`n是否仍要保存？", "路径不存在")
                if (result = "No") {
                    Exit
                }
            } else {
                ; 验证是否为 Arknights.exe
                SplitPath(SavedObj.GamePath, &fileName)
                if (fileName != "Arknights.exe") {
                    result := MessageBox.Confirm("游戏路径不正确：`n" SavedObj.GamePath "`n`n目标文件不是 Arknights.exe，请确保选择正确的游戏可执行文件。`n`n是否仍要保存？", "路径不正确")
                    if (result = "No") {
                        Exit
                    }
                }
            }
        }

        ; 保存到INI
        Config.SaveToIni(SavedObj)
    }

    ; 内部：检查按键冲突
    ; 检测规则：
    ; 1. 常规作战 + 快捷功能 + SwitchHotkey 互相检测
    ; 2. 卫戍协议按键 + SwitchHotkey 互相检测
    ; 3. 卫戍协议按键不与作战/快捷功能检测冲突
    static _CheckKeyConflicts(SavedObj) {
        ; 定义按键分组
        battleKeys := ["PressPause", "ReleasePause", "GameSpeed", "PauseSelect",
                       "Skill", "Retreat", "33ms", "166ms", "OneClickSkill",
                       "OneClickRetreat", "PauseSkill", "PauseRetreat",
                       "LButtonClick", "CeaseOperations", "Skip", "Back",
                       "Harvest", "CollectCollectibles"]

        strongholdKeys := ["CheckEnemies", "DispatchCenter", "Freeze", "Refresh",
                          "Upgrade", "Sell", "Ready", "StrongHoldProtocolLButtonClick",
                          "StrongHoldProtocolRetreat", "StrongHoldProtocolOneClickRetreat",
                          "OneClickSell", "OneClickPurchase"]

        ; 获取SwitchHotkey值
        switchHotkey := SavedObj.HasProp("SwitchHotkey") ? SavedObj.SwitchHotkey : ""

        ; 检测组A：作战+快捷
        battleUsed := Map()
        for keyVar in battleKeys {
            if (!SavedObj.HasProp(keyVar))
                continue
            currentKey := SavedObj.%keyVar%
            if (currentKey != "") {
                if (battleUsed.Has(currentKey)) {
                    this._ShowConflictError(currentKey, battleUsed[currentKey], Constants.KeyNames[keyVar])
                    return false
                }
                battleUsed[currentKey] := Constants.KeyNames[keyVar]
            }
        }
        ; 将SwitchHotkey加入组A检测
        if (switchHotkey != "") {
            if (battleUsed.Has(switchHotkey)) {
                this._ShowConflictError(switchHotkey, battleUsed[switchHotkey], "启用/禁用热键")
                return false
            }
        }

        ; 检测组B：卫戍协议
        strongholdUsed := Map()
        for keyVar in strongholdKeys {
            if (!SavedObj.HasProp(keyVar))
                continue
            currentKey := SavedObj.%keyVar%
            if (currentKey != "") {
                if (strongholdUsed.Has(currentKey)) {
                    this._ShowConflictError(currentKey, strongholdUsed[currentKey], Constants.KeyNames[keyVar])
                    return false
                }
                strongholdUsed[currentKey] := Constants.KeyNames[keyVar]
            }
        }
        ; 将SwitchHotkey加入组B检测
        if (switchHotkey != "") {
            if (strongholdUsed.Has(switchHotkey)) {
                this._ShowConflictError(switchHotkey, strongholdUsed[switchHotkey], "启用/禁用热键")
                return false
            }
        }

        return true
    }

    ; 内部：显示冲突错误
    static _ShowConflictError(conflictKey, prevName, currentName) {
        MessageBox.Error("按键冲突！`n【" conflictKey "】`n已被【" prevName "】使用，与【" currentName "】冲突`n`n请先修改重复的按键。", "保存失败")
    }

    ; 重置游戏状态
    static ResetGameStateIfNeeded(*) {
        if (Config.GetImportant("AutoExit") == "1" && !WinExist("ahk_exe Arknights.exe")) {
            State.GameHasStarted := false
        }
    }
}