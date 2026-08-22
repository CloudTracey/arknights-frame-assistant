; == 游戏按键注册表识别（多区服） ==
; 从各服注册表读取明日方舟游戏内按键设置，动态适配用户自定义按键。
; 每个区服维护独立映射；热键路径按前台区服取映射；拦截正则取所有已安装区服的并集。

class GameKeys {

    ; ── 公开 API ──

    ; 初始化：首次读取所有已知区服 + 启动 10s 轮询
    static Init() {
        if (this._HasInitialized)
            return
        this._HasInitialized := true

        this._InitUnityKeyMap()
        this._InitDefaults()

        ; 首次读取全部已知区服
        for serverId in ServerProfile.Ids() {
            result := this._ReadServer(serverId)
            if (result.success) {
                this._ServerBindings[serverId] := this._MergeDefaults(result.bindings)
                this._ServerLastHex[serverId] := result.hex
                this._ServerReadSuccess[serverId] := true
                this._LogBindings(serverId)
            } else {
                this._ServerReadSuccess[serverId] := false
                if (result.rootExists) {
                    ; 注册表根存在但读取失败：按该服默认值兜底，并只提示一次
                    this._ServerBindings[serverId] := this._MergeDefaults(Map())
                    this._ShowWarning(serverId)
                }
            }
        }

        ; 兼容旧字段：默认指向 CN（或 PreferredServer）
        this._Bindings := this._GetBindingsForServer(this._ResolveServerId())

        EventBus.Subscribe("ForegroundClientChanged", (data) => this._HandleForegroundClientChanged(data))

        SetTimer ObjBindMethod(GameKeys, "_OnPoll"), 10000
    }

    ; 获取某功能的 AHK 键名（按前台区服解析）
    static Get(gameFunc) {
        serverId := this._ResolveServerId()
        bindings := this._GetBindingsForServer(serverId)
        if (bindings.Has(gameFunc))
            return bindings[gameFunc]
        if (this._Defaults.Has(gameFunc))
            return this._Defaults[gameFunc]
        return ""
    }

    ; 发送按键按下
    static SendDown(gameFunc) {
        key := this.Get(gameFunc)
        if (key != "")
            Send "{" key " Down}"
    }

    ; 发送按键释放
    static SendUp(gameFunc) {
        key := this.Get(gameFunc)
        if (key != "")
            Send "{" key " Up}"
    }

    ; 发送完整点击（Down → 延迟 → Up），仅用于单键场景
    static Tap(gameFunc, delay := 50) {
        key := this.Get(gameFunc)
        if (key != "") {
            Send "{" key " Down}"
            USleep(delay)
            Send "{" key " Up}"
        }
    }

    ; 返回拦截正则字符串，供 hotkey_service.ahk 使用。
    ; 只纳入“注册表存在的服”的实际绑定 ∪ 各服缺失功能组默认值；未安装的服不纳入。
    static GetInterceptPattern() {
        keys := ""
        seen := Map()

        addedAny := false
        for serverId in ServerProfile.Ids() {
            if (this._ServerReadSuccess.Has(serverId) && this._ServerReadSuccess[serverId]) {
                bindings := this._GetBindingsForServer(serverId)
                for _, key in bindings {
                    if (key != "" && !seen.Has(key)) {
                        keys .= this._EscapeRegex(key) . "|"
                        seen[key] := true
                        addedAny := true
                    }
                }
            }
        }

        ; 没有任何区服注册表可读时回退 CN 默认，保持旧版行为不回归
        if (!addedAny) {
            bindings := this._MergeDefaults(Map())
            for _, key in bindings {
                if (key != "" && !seen.Has(key)) {
                    keys .= this._EscapeRegex(key) . "|"
                    seen[key] := true
                }
            }
        }

        ; 追加不可重新绑定的游戏键和鼠标键
        keys .= "Escape|RButton|MButton"
        return "i)\b(" keys ")\b$"
    }

    ; ── 内部状态 ──
    static _Bindings := Map()        ; 兼容旧字段：当前前台/首选服的映射
    static _ServerBindings := Map()  ; serverId → gameFunc → AHK 键名
    static _ServerLastHex := Map()   ; serverId → 上次原始 hex
    static _ServerReadSuccess := Map() ; serverId → bool
    static _ServerWarned := Map()    ; serverId → bool（每服每会话只提示一次）
    static _PendingWarningServers := [] ; 待汇总的读取失败区服
    static _WarningScheduled := false   ; 是否已安排汇总弹窗定时器
    static _Defaults := Map()        ; 硬编码默认映射
    static _UnityKeyMap := Map()     ; Unity keyId → AHK 键名
    static _HasInitialized := false

    ; ── 区服解析 ──

    ; 解析当前应使用的区服：优先前台客户端，其次 PreferredServer，
    ; 再其次上次成功识别的 LastActiveServer，最后 CN。
    static _ResolveServerId() {
        serverId := GameClientRegistry.GetForegroundServerId()
        if (serverId != "" && this._ServerBindings.Has(serverId))
            return serverId

        preferred := Config.GetImportant("PreferredServer")
        if (preferred = "") {
            last := Config.GetImportant("LastActiveServer")
            if (last != "" && this._ServerBindings.Has(last))
                preferred := last
        }
        if (preferred != "" && this._ServerBindings.Has(preferred))
            return preferred

        if (this._ServerBindings.Has("CN"))
            return "CN"
        return "CN"
    }

    static _GetBindingsForServer(serverId) {
        if (this._ServerBindings.Has(serverId))
            return this._ServerBindings[serverId]
        return this._MergeDefaults(Map())
    }

    ; 前台客户端变化时更新 LastActiveServer（仅内存，避免热路径写 IO）
    static _HandleForegroundClientChanged(data) {
        if (data.serverId != "" && this._ServerBindings.Has(data.serverId)) {
            this._Bindings := this._GetBindingsForServer(data.serverId)
            if (Config.AllImportant.Has("LastActiveServer"))
                Config.SetImportant("LastActiveServer", data.serverId)
            Logger.Debug("GameKeys", "前台区服切换：" data.serverId)
        }
    }

    ; ── 初始化 Unity KeyId → AHK 键名映射 ──
    static _InitUnityKeyMap() {
        this._UnityKeyMap := Map(
            ; === 字母键 alphaA - alphaZ → a - z ===
            "alphaA", "a", "alphaB", "b", "alphaC", "c", "alphaD", "d",
            "alphaE", "e", "alphaF", "f", "alphaG", "g", "alphaH", "h",
            "alphaI", "i", "alphaJ", "j", "alphaK", "k", "alphaL", "l",
            "alphaM", "m", "alphaN", "n", "alphaO", "o", "alphaP", "p",
            "alphaQ", "q", "alphaR", "r", "alphaS", "s", "alphaT", "t",
            "alphaU", "u", "alphaV", "v", "alphaW", "w", "alphaX", "x",
            "alphaY", "y", "alphaZ", "z",

            ; === 主键盘数字键 num0 - num9 → 0 - 9 ===
            "num0", "0", "num1", "1", "num2", "2", "num3", "3",
            "num4", "4", "num5", "5", "num6", "6", "num7", "7",
            "num8", "8", "num9", "9",

            ; === 也兼容 alpha0 - alpha9（旧版/标准 Unity KeyCode） ===
            "alpha0", "0", "alpha1", "1", "alpha2", "2", "alpha3", "3",
            "alpha4", "4", "alpha5", "5", "alpha6", "6", "alpha7", "7",
            "alpha8", "8", "alpha9", "9",

            ; === 符号键 char* → 对应 AHK 物理键名 ===
            "charMinus", "-",
            "charPlus", "=",
            "charEquals", "=",
            "charPeriod", ".",
            "charComma", ",",
            "charSlash", "/",
            "charBackslash", "\",
            "charSemicolon", ";",
            "charQuote", "'",
            "charLeftBracket", "[",
            "charRightBracket", "]",
            "charLeftCurlyBracket", "[",
            "charRightCurlyBracket", "]",
            "charlLeftCurlyBracket", "[",
            "charlRightCurlyBracket", "]",
            "charPipe", "\",
            "charColon", ";",
            "charLess", ",",
            "charGreater", ".",
            "charQuestion", "/",
            "charBackQuote", "``",
            "charTilde", "``",
            "charExclaim", "1",
            "charAt", "2",
            "charHash", "3",
            "charDollar", "4",
            "charPercent", "5",
            "charCaret", "6",
            "charAmpersand", "7",
            "charAsterisk", "8",
            "charLeftParen", "9",
            "charRightParen", "0",
            "charUnderscore", "-",

            ; === 修饰键 ===
            "keyShift", "Shift",
            "keyAlt", "Alt",
            "keyControl", "Control",
            "keyLCtrl", "LCtrl",
            "keyRCtrl", "RCtrl",
            "keyLShift", "LShift",
            "keyRShift", "RShift",
            "keyLAlt", "LAlt",
            "keyRAlt", "RAlt",

            ; === 功能键 ===
            "keyF1", "F1", "keyF2", "F2", "keyF3", "F3", "keyF4", "F4",
            "keyF5", "F5", "keyF6", "F6", "keyF7", "F7", "keyF8", "F8",
            "keyF9", "F9", "keyF10", "F10", "keyF11", "F11", "keyF12", "F12",

            ; === 特殊功能键 ===
            "keySpace", "Space",
            "keyTab", "Tab",
            "keyEsc", "Escape",
            "keyEnter", "Enter",
            "keyReturn", "Enter",
            "keyBackspace", "Backspace",
            "keyDelete", "Delete",
            "keyInsert", "Insert",
            "keyHome", "Home",
            "keyEnd", "End",
            "keyPageUp", "PgUp",
            "keyPageDown", "PgDn",
            "keyCapsLock", "CapsLock",
            "keyPrint", "PrintScreen",
            "keyPause", "Pause",
            "keyScrollLock", "ScrollLock",

            ; === 方向键 ===
            "keyUp", "Up", "keyDown", "Down",
            "keyLeft", "Left", "keyRight", "Right",

            ; === 鼠标键 ===
            "mouseLeft", "LButton",
            "mouseRight", "RButton",
            "mouseMiddle", "MButton",
            "mouseForward", "XButton2",
            "mouseBack", "XButton1",
            "mouse0", "LButton",
            "mouse1", "RButton",
            "mouse2", "MButton",
            "mouse3", "XButton1",
            "mouse4", "XButton2",

            ; === 小键盘 ===
            "keyAlpha0", "Numpad0", "keyAlpha1", "Numpad1",
            "keyAlpha2", "Numpad2", "keyAlpha3", "Numpad3",
            "keyAlpha4", "Numpad4", "keyAlpha5", "Numpad5",
            "keyAlpha6", "Numpad6", "keyAlpha7", "Numpad7",
            "keyAlpha8", "Numpad8", "keyAlpha9", "Numpad9",
            "keypad0", "Numpad0", "keypad1", "Numpad1",
            "keypad2", "Numpad2", "keypad3", "Numpad3",
            "keypad4", "Numpad4", "keypad5", "Numpad5",
            "keypad6", "Numpad6", "keypad7", "Numpad7",
            "keypad8", "Numpad8", "keypad9", "Numpad9",
            "keypadPeriod", "NumpadDot",
            "keypadDivide", "NumpadDiv",
            "keypadMultiply", "NumpadMult",
            "keypadMinus", "NumpadSub",
            "keypadPlus", "NumpadAdd",
            "keypadEnter", "NumpadEnter",

            ; === 标准 Unity KeyCode（小写兼容） ===
            "a", "a", "b", "b", "c", "c", "d", "d", "e", "e", "f", "f",
            "g", "g", "h", "h", "i", "i", "j", "j", "k", "k", "l", "l",
            "m", "m", "n", "n", "o", "o", "p", "p", "q", "q", "r", "r",
            "s", "s", "t", "t", "u", "u", "v", "v", "w", "w", "x", "x",
            "y", "y", "z", "z",
            "space", "Space", "tab", "Tab", "escape", "Escape",
            "enter", "Enter", "return", "Enter",
            "backspace", "Backspace", "delete", "Delete",
            "up", "Up", "down", "Down", "left", "Left", "right", "Right",
            "minus", "-", "equals", "=", "period", ".", "comma", ",",
            "slash", "/", "backslash", "\", "semicolon", ";", "quote", "'",
            "leftbracket", "[", "rightbracket", "]", "backquote", "``",
            "f1", "F1", "f2", "F2", "f3", "F3", "f4", "F4",
            "f5", "F5", "f6", "F6", "f7", "F7", "f8", "F8",
            "f9", "F9", "f10", "F10", "f11", "F11", "f12", "F12",

            ; === 全小写变体 ===
            "keybackspace", "Backspace", "keydelete", "Delete",
            "keyinsert", "Insert", "keyhome", "Home", "keyend", "End",
            "keypageup", "PgUp", "keypagedown", "PgDn",
            "keycapslock", "CapsLock", "keyprint", "PrintScreen",
            "keypause", "Pause", "keyscrolllock", "ScrollLock",
            "keyreturn", "Enter", "keyspace", "Space",
            "keytab", "Tab", "keyesc", "Escape", "keyenter", "Enter",
            "keyup", "Up", "keydown", "Down",
            "keyleft", "Left", "keyright", "Right",
            "keyshift", "Shift", "keyalt", "Alt", "keycontrol", "Control",
            "keyf1", "F1", "keyf2", "F2", "keyf3", "F3", "keyf4", "F4",
            "keyf5", "F5", "keyf6", "F6", "keyf7", "F7", "keyf8", "F8",
            "keyf9", "F9", "keyf10", "F10", "keyf11", "F11", "keyf12", "F12",
            "keynumlock", "NumLock"
        )
    }

    ; ── 初始化默认映射 ──
    static _InitDefaults() {
        this._Defaults := Map(
            "changeSpeed", "f",
            "releaseSkill", "e",
            "retreatChar", "q",
            "pauseBattle", "Space",
            "battleLeftPopup", "v",
            "homeKey", "Tab",
            "autochessRefresh", "d",
            "autochessFreeze", "s",
            "autochessLevelUp", "g",
            "autochessShop", "a",
            "autochessReady", "c",
            "autochessSale", "x",
            "autochessViewEnemy", "w"
        )
    }

    ; ── 从注册表读取并解析 ──
    ; 返回 {success, bindings, hex, rootExists}
    static _ReadServer(serverId) {
        result := {success: false, bindings: Map(), hex: "", rootExists: false}
        root := ServerProfile.RegistryRoot(serverId)
        if (root = "")
            return result

        ; 先确认注册表根真实存在，避免未安装区服（如 KR/EN）也被当成“读取失败”反复弹窗
        if !ServerProfile.RegistryRootExists(serverId)
            return result
        result.rootExists := true

        targetValueName := ""
        try {
            Loop Reg, root, "V" {
                if (InStr(A_LoopRegName, "KEYBOARD_SETTING_V") = 1) {
                    targetValueName := A_LoopRegName
                    break
                }
            }
        } catch Error as loopErr {
            Logger.Debug("GameKeys", "区服 " serverId " 注册表枚举异常：" loopErr.Message)
            return result
        }

        ; 如果枚举没找到，尝试已知键名
        if (targetValueName = "") {
            knownKeys := ["KEYBOARD_SETTING_V2_h476498874", "KEYBOARD_SETTING_DISPLAY_h1323456836"]
            for keyName in knownKeys {
                try {
                    testRead := RegRead(root, keyName)
                    if (testRead != "") {
                        targetValueName := keyName
                        break
                    }
                } catch {
                    continue
                }
            }
        }

        if (targetValueName = "") {
            Logger.Debug("GameKeys", "区服 " serverId " 未找到 KEYBOARD_SETTING_V* 键值")
            return result
        }

        try {
            hexStr := RegRead(root, targetValueName)
            if (hexStr = "") {
                Logger.Warn("GameKeys", "区服 " serverId " RegRead 返回空字符串")
                return result
            }

            ; hex 字符串 → UTF-8 文本
            bufSize := StrLen(hexStr) // 2
            buf := Buffer(bufSize)
            Loop bufSize {
                byteHex := SubStr(hexStr, (A_Index - 1) * 2 + 1, 2)
                byteVal := Integer("0x" byteHex)
                NumPut("UChar", byteVal, buf, A_Index - 1)
            }
            jsonStr := StrGet(buf, bufSize, "UTF-8")
            if (jsonStr = "") {
                Logger.Warn("GameKeys", "区服 " serverId " hex→文本转换为空")
                return result
            }

            parsed := this._ParseJson(jsonStr)
            result.success := true
            result.bindings := parsed
            result.hex := hexStr
            return result
        } catch Error as e {
            Logger.Error("GameKeys", "区服 " serverId " 读取异常：" e.Message)
            return result
        }
    }

    ; 合并默认值：注册表缺失的功能组/键全部用默认值补齐
    static _MergeDefaults(bindings) {
        result := Map()
        for funcName, key in bindings
            result[funcName] := key
        for funcName, key in this._Defaults {
            if !result.Has(funcName)
                result[funcName] := key
        }
        return result
    }

    ; ── 从 JSON 字符串解析按键映射 ──
    static _ParseJson(jsonStr) {
        result := Map()
        pos := 1
        while (pos := RegExMatch(jsonStr, '"(\w+)":\{"keyId":"([^"]+)"\}', &match, pos)) {
            funcName := match[1]
            keyId := match[2]
            ahkKey := this._ConvertKeyId(keyId)
            if (ahkKey != "") {
                result[funcName] := ahkKey
            } else {
                Logger.Warn("GameKeys", "未知 keyId：" keyId "（功能：" funcName "），使用默认值")
            }
            pos += match.Len[0]
        }
        if (result.Count = 0)
            Logger.Warn("GameKeys", "JSON 解析结果为空，原始内容：" jsonStr)
        return result
    }

    ; ── 转义正则特殊字符 ──
    static _EscapeRegex(str) {
        return RegExReplace(str, "[.^$*+?()[{\\|]", "\$0")
    }

    ; ── 转换 Unity keyId → AHK 键名 ──
    static _ConvertKeyId(keyId) {
        if (this._UnityKeyMap.Has(keyId))
            return this._UnityKeyMap[keyId]

        lowerId := StrLower(keyId)
        if (this._UnityKeyMap.Has(lowerId))
            return this._UnityKeyMap[lowerId]

        if (SubStr(lowerId, 1, 3) = "num" && StrLen(lowerId) = 4) {
            digit := SubStr(lowerId, 4, 1)
            if (RegExMatch(digit, "^[0-9]$"))
                return digit
        }

        if (SubStr(lowerId, 1, 5) = "alpha" && StrLen(lowerId) = 6) {
            letter := SubStr(lowerId, 6, 1)
            if (RegExMatch(letter, "^[a-z]$"))
                return letter
        }

        if (SubStr(lowerId, 1, 4) = "char") {
            suffix := SubStr(lowerId, 5)
            if (SubStr(suffix, 1, 1) = "l" && StrLen(suffix) > 1) {
                altSuffix := SubStr(suffix, 2)
                camelKey := "char" . Format("{:U}", SubStr(altSuffix, 1, 1)) . SubStr(altSuffix, 2)
                if (this._UnityKeyMap.Has(camelKey))
                    return this._UnityKeyMap[camelKey]
                lowerKey := "char" . altSuffix
                if (this._UnityKeyMap.Has(lowerKey))
                    return this._UnityKeyMap[lowerKey]
            }
        }

        if (StrLen(keyId) = 1)
            return keyId

        Logger.Warn("GameKeys", "未知 keyId：" keyId)
        return ""
    }

    ; ── 定时器回调：检测各服注册表变更 ──
    static _OnPoll() {
        try {
            changed := false
            for serverId in ServerProfile.Ids() {
                result := this._ReadServer(serverId)
                if (!result.rootExists) {
                    if (this._ServerReadSuccess.Has(serverId) && this._ServerReadSuccess[serverId]) {
                        this._ServerReadSuccess[serverId] := false
                        if (this._ServerBindings.Has(serverId))
                            this._ServerBindings.Delete(serverId)
                        if (this._ServerLastHex.Has(serverId))
                            this._ServerLastHex.Delete(serverId)
                        changed := true
                        Logger.Info("GameKeys", "区服 " serverId " 注册表根消失，已从拦截并集移除")
                    }
                    continue
                }

                if (result.success) {
                    if (!this._ServerReadSuccess.Has(serverId) || !this._ServerReadSuccess[serverId]) {
                        this._ServerReadSuccess[serverId] := true
                        this._ServerBindings[serverId] := this._MergeDefaults(result.bindings)
                        this._ServerLastHex[serverId] := result.hex
                        changed := true
                        this._LogBindings(serverId)
                        Logger.Info("GameKeys", "区服 " serverId " 注册表读取已恢复")
                        continue
                    }

                    if (this._ServerLastHex.Has(serverId) && this._ServerLastHex[serverId] = result.hex)
                        continue

                    this._ServerBindings[serverId] := this._MergeDefaults(result.bindings)
                    this._ServerLastHex[serverId] := result.hex
                    changed := true
                    this._LogBindings(serverId)
                } else {
                    if (this._ServerReadSuccess.Has(serverId) && this._ServerReadSuccess[serverId]) {
                        this._ServerReadSuccess[serverId] := false
                        this._ServerBindings[serverId] := this._MergeDefaults(Map())
                        changed := true
                        this._ShowWarning(serverId)
                    }
                }
            }

            if (changed) {
                this._Bindings := this._GetBindingsForServer(this._ResolveServerId())
                EventBus.Publish("GameKeysChanged", {bindings: this._Bindings, interceptPattern: this.GetInterceptPattern(), serverBindings: this._ServerBindings})
                Logger.Info("GameKeys", "检测到按键变更，发布 GameKeysChanged")
            }
        } catch Error as e {
            Logger.Error("GameKeys", "轮询异常：" e.Message)
        }
    }

    ; ── 输出完整按键映射（Info）──
    static _LogBindings(serverId) {
        bindings := this._GetBindingsForServer(serverId)
        mapText := ""
        for funcName, key in bindings
            mapText .= (mapText = "" ? "" : " | ") funcName "=" key
        Logger.Info("GameKeys", "区服 " serverId " 完整按键映射：" mapText)
    }

    ; ── 弹出读取失败警告（每服每会话只提示一次，多个区服合并为一个弹窗）──
    static _ShowWarning(serverId) {
        if (this._ServerWarned.Has(serverId) && this._ServerWarned[serverId])
            return
        this._ServerWarned[serverId] := true
        Logger.Warn("GameKeys", "区服 " serverId " 读取失败，回退默认按键")

        this._PendingWarningServers.Push(serverId)
        if (!this._WarningScheduled) {
            this._WarningScheduled := true
            ; 延迟到启动流程基本完成后弹出，避免在 GuiManager 建控件期间被定时器打断导致 MessageBox 控件销毁。
            SetTimer ObjBindMethod(GameKeys, "_FlushWarnings"), -3000
        }
    }

    ; 汇总所有读取失败区服后只弹一次窗，避免多个 MessageBox 互相覆盖
    static _FlushWarnings() {
        this._WarningScheduled := false
        if (this._PendingWarningServers.Length = 0)
            return

        servers := this._PendingWarningServers
        this._PendingWarningServers := []
        serverList := ""
        for serverId in servers
            serverList .= (serverList = "" ? "" : "`n") . "- " serverId
        msg := I18n.T("以下区服的游戏按键配置读取失败，AFA 将使用默认按键。`n`n{1}`n`n如果您的游戏内按键为自定义设置，可能无法正常工作。`n请尝试恢复游戏默认按键或联系 AFA 开发者进行修复。", serverList)

        try {
            MessageBox.Warning(msg, I18n.T("AFA - 游戏按键读取失败"))
        } catch Error as e {
            Logger.Error("GameKeys", "游戏按键读取失败提示弹出失败：" e.Message)
        }
    }
}
