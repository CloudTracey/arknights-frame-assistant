; == 游戏按键注册表识别 ==
; 从注册表读取明日方舟游戏内按键设置，动态适配用户自定义按键
; 每 10 秒轮询注册表检测变更，多层防御回退到默认值

class GameKeys {
    ; ── 公开 API ──

    ; 初始化：首次读取注册表 + 启动 10s 轮询
    static Init() {
        if (this._HasInitialized)
            return
        this._HasInitialized := true

        ; 初始化 Unity KeyId → AHK 键名映射
        this._InitUnityKeyMap()

        ; 初始化默认映射
        this._InitDefaults()

        ; 首次读取
        bindings := this._ReadFromRegistry()
        if (bindings.Count > 0) {
            this._Bindings := bindings
            this._LastReadSuccess := true
        } else {
            this._Bindings := this._Defaults.Clone()
            this._LastReadSuccess := false
            this._ShowWarning()
        }

        ; 输出完整按键映射（Info）
        this._LogBindings()

        ; 启动 10 秒轮询定时器
        SetTimer ObjBindMethod(GameKeys, "_OnPoll"), 10000
    }

    ; 获取某功能的 AHK 键名
    static Get(gameFunc) {
        if (this._Bindings.Has(gameFunc))
            return this._Bindings[gameFunc]
        ; 兜底：返回默认值
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
            Thread "NoTimers"
            Send "{" key " Down}"
            USleep(delay)
            Send "{" key " Up}"
            Thread "NoTimers", false
        }
    }

    ; 返回拦截正则字符串，供 hotkey_control.ahk 使用
    static GetInterceptPattern() {
        keys := ""
        seen := Map()
        for _, key in this._Bindings {
            if (key != "" && !seen.Has(key)) {
                keys .= this._EscapeRegex(key) . "|"
                seen[key] := true
            }
        }
        ; 追加不可重新绑定的游戏键和鼠标键
        keys .= "Escape|RButton|MButton"
        return "i)\b(" keys ")\b$"
    }

    ; ── 内部状态 ──
    static _Bindings := Map()        ; gameFunc → AHK 键名
    static _LastHex := ""            ; 上次读取的注册表原始 hex，用于变更检测
    static _Defaults := Map()        ; 硬编码默认映射
    static _UnityKeyMap := Map()     ; Unity keyId → AHK 键名
    static _HasInitialized := false
    static _HasWarned := false       ; 每会话仅弹一次警告
    static _LastReadSuccess := true  ; 上次读取是否成功

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
            ; 注意：{、}、|、: 等是 Shift+物理键的组合字符，映射到物理键
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
            "charLeftCurlyBracket", "[",     ; { 的物理键是 [
            "charRightCurlyBracket", "]",     ; } 的物理键是 ]
            "charlLeftCurlyBracket", "[",     ; { 的小写+l变体
            "charlRightCurlyBracket", "]",    ; } 的小写+l变体
            "charPipe", "\",                  ; | 的物理键是 \
            "charColon", ";",                 ; : 的物理键是 ;
            "charLess", ",",                  ; < 的物理键是 ,
            "charGreater", ".",               ; > 的物理键是 .
            "charQuestion", "/",              ; ? 的物理键是 /
            "charBackQuote", "``",
            "charTilde", "``",                ; ~ 的物理键是 `
            "charExclaim", "1",               ; ! 的物理键是 1
            "charAt", "2",                    ; @ 的物理键是 2
            "charHash", "3",                  ; # 的物理键是 3
            "charDollar", "4",                ; $ 的物理键是 4
            "charPercent", "5",               ; % 的物理键是 5
            "charCaret", "6",                 ; ^ 的物理键是 6
            "charAmpersand", "7",             ; & 的物理键是 7
            "charAsterisk", "8",              ; * 的物理键是 8
            "charLeftParen", "9",             ; ( 的物理键是 9
            "charRightParen", "0",            ; ) 的物理键是 0
            "charUnderscore", "-",            ; _ 的物理键是 -

            ; === 修饰键（可能被绑定为游戏按键） ===
            "keyShift", "Shift",
            "keyAlt", "Alt",
            "keyControl", "Control",
            "keyLCtrl", "LCtrl",
            "keyRCtrl", "RCtrl",
            "keyLShift", "LShift",
            "keyRShift", "RShift",
            "keyLAlt", "LAlt",
            "keyRAlt", "RAlt",

            ; === 功能键 keyF1 - keyF12 → F1 - F12 ===
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
            ; 明日方舟自定义名（设置界面仅图标无文本）：Forward=前进/屏幕侧→XButton2，Back=后退/身体侧→XButton1
            "mouseLeft", "LButton",
            "mouseRight", "RButton",
            "mouseMiddle", "MButton",
            "mouseForward", "XButton2",     ; 侧键前进（Browser_Forward，第 5 键）
            "mouseBack", "XButton1",        ; 侧键后退（Browser_Back，第 4 键）
            ; 标准 Unity KeyCode（防御性）：Mouse0-2=左/右/中，Mouse3-4=第 4/5 键
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

            ; === 全小写变体（兼容不同游戏版本） ===
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
            ; normalBattle
            "changeSpeed", "f",
            "releaseSkill", "e",
            "retreatChar", "q",
            "pauseBattle", "Space",
            "battleLeftPopup", "v",
            ; normalFunc
            "homeKey", "Tab",
            ; autoChess
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
    ; 返回解析后的 Map，失败返回空 Map
    static _ReadFromRegistry() {
        try {
            ; 先用已知键名直接读取（避免 Loop Reg 兼容性问题）
            hexStr := ""
            targetValueName := ""

            ; 枚举注册表值，找 KEYBOARD_SETTING_V* 前缀，找到即停
            try {
                Loop Reg, "HKCU\Software\HyperGryph\Arknights", "V"
                {
                    if (InStr(A_LoopRegName, "KEYBOARD_SETTING_V") = 1) {
                        targetValueName := A_LoopRegName
                        Logger.Debug("GameKeys", "找到键值：" targetValueName)
                        break
                    }
                }
            } catch Error as loopErr {
                if (targetValueName = "")
                    Logger.Warn("GameKeys", "注册表枚举异常：" loopErr.Message)
            }

            ; 如果枚举没找到，尝试已知键名
            if (targetValueName = "") {
                Logger.Debug("GameKeys", "枚举未找到，尝试已知键名")
                knownKeys := ["KEYBOARD_SETTING_V2_h476498874"]
                for keyName in knownKeys {
                    try {
                        testRead := RegRead("HKCU\Software\HyperGryph\Arknights", keyName)
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
                Logger.Warn("GameKeys", "未找到任何 KEYBOARD_SETTING_V* 键值")
                return Map()
            }

            Logger.Debug("GameKeys", "选用键值：" targetValueName)

            ; RegRead 对于 REG_BINARY 返回 hex 字符串
            try {
                hexStr := RegRead("HKCU\Software\HyperGryph\Arknights", targetValueName)
            } catch Error as readErr {
                Logger.Warn("GameKeys", "RegRead 调用失败：" readErr.Message)
                return Map()
            }

            if (hexStr = "") {
                Logger.Warn("GameKeys", "RegRead 返回空字符串")
                return Map()
            }

            Logger.Debug("GameKeys", "读取成功，hex 长度：" StrLen(hexStr))
            this._LastHex := hexStr

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
                Logger.Warn("GameKeys", "hex→文本转换为空")
                return Map()
            }

            Logger.Debug("GameKeys", "原始 JSON：" jsonStr)

            result := this._ParseJson(jsonStr)
            Logger.Debug("GameKeys", "解析完成，共 " result.Count " 个映射")
            return result
        } catch Error as e {
            Logger.Error("GameKeys", "整体异常：" e.Message "，行号：" e.Line)
            return Map()
        }
    }

    ; ── 从 JSON 字符串解析按键映射 ──
    ; 使用正则提取所有 "funcName":{"keyId":"xxx"} 模式
    static _ParseJson(jsonStr) {
        result := Map()
        ; 匹配模式: "funcName":{"keyId":"alphaX"} 或 "funcName":{"keyId":"keyXxx"}
        ; 不依赖 JSON 的嵌套结构，直接提取所有 keyId 对
        pos := 1
        while (pos := RegExMatch(jsonStr, '"(\w+)":\{"keyId":"([^"]+)"\}', &match, pos)) {
            funcName := match[1]
            keyId := match[2]

            ; 转换 Unity keyId → AHK 键名
            ahkKey := this._ConvertKeyId(keyId)
            if (ahkKey != "") {
                result[funcName] := ahkKey
            } else {
                Logger.Warn("GameKeys", "未知 keyId：" keyId "（功能：" funcName "），使用默认值")
            }

            pos += match.Len[0]
        }

        if (result.Count = 0) {
            Logger.Warn("GameKeys", "JSON 解析结果为空，原始内容：" jsonStr)
        }

        return result
    }

    ; ── 转义正则特殊字符（用于 GetInterceptPattern） ──
    static _EscapeRegex(str) {
        return RegExReplace(str, "[.^$*+?()[{\\|]", "\$0")
    }

    ; ── 转换 Unity keyId → AHK 键名 ──
    static _ConvertKeyId(keyId) {
        ; 1. 精确匹配
        if (this._UnityKeyMap.Has(keyId))
            return this._UnityKeyMap[keyId]

        ; 2. 全小写匹配（兼容不同游戏版本的驼峰/全小写变体）
        lowerId := StrLower(keyId)
        if (this._UnityKeyMap.Has(lowerId))
            return this._UnityKeyMap[lowerId]

        ; 3. 模式匹配：numX → 数字键
        if (SubStr(lowerId, 1, 3) = "num" && StrLen(lowerId) = 4) {
            digit := SubStr(lowerId, 4, 1)
            if (RegExMatch(digit, "^[0-9]$"))
                return digit
        }

        ; 4. 模式匹配：alphaX → 字母键
        if (SubStr(lowerId, 1, 5) = "alpha" && StrLen(lowerId) = 6) {
            letter := SubStr(lowerId, 6, 1)
            if (RegExMatch(letter, "^[a-z]$"))
                return letter
        }

        ; 5. 模式匹配：char* → 从已知符号表查找
        if (SubStr(lowerId, 1, 4) = "char") {
            suffix := SubStr(lowerId, 5)  ; 去掉 "char"
            ; 处理可能的 "l" 前缀变体（charlXxx → charXxx）
            if (SubStr(suffix, 1, 1) = "l" && StrLen(suffix) > 1) {
                altSuffix := SubStr(suffix, 2)
                ; 尝试 camelCase 形式："char" . "LeftCurlyBracket"
                camelKey := "char" . Format("{:U}", SubStr(altSuffix, 1, 1)) . SubStr(altSuffix, 2)
                if (this._UnityKeyMap.Has(camelKey))
                    return this._UnityKeyMap[camelKey]
                ; 再尝试全小写形式
                lowerKey := "char" . altSuffix
                if (this._UnityKeyMap.Has(lowerKey))
                    return this._UnityKeyMap[lowerKey]
            }
        }

        ; 6. 单字符 keyId（如 "a", "4", "-"）
        if (StrLen(keyId) = 1)
            return keyId

        Logger.Warn("GameKeys", "未知 keyId：" keyId)
        return ""
    }

    ; ── 定时器回调：检测注册表变更 ──
    static _OnPoll() {
        try {
            ; 枚举找到 KEYBOARD_SETTING_V* 键值，找到即停
            targetValueName := ""
            try {
                Loop Reg, "HKCU\Software\HyperGryph\Arknights", "V"
                {
                    if (InStr(A_LoopRegName, "KEYBOARD_SETTING_V") = 1) {
                        targetValueName := A_LoopRegName
                        break
                    }
                }
            } catch {
                ; 枚举异常且未找到则跳过本轮
            }

            if (targetValueName = "") {
                ; 注册表键突然消失
                if (this._LastReadSuccess) {
                    this._LastReadSuccess := false
                    this._Bindings := this._Defaults.Clone()
                    this._ShowWarning("注册表键值不存在")
                }
                return
            }

            ; RegRead 对于 REG_BINARY 返回 hex 字符串
            hexStr := RegRead("HKCU\Software\HyperGryph\Arknights", targetValueName)
            if (hexStr = "") {
                if (this._LastReadSuccess) {
                    this._LastReadSuccess := false
                    this._Bindings := this._Defaults.Clone()
                    this._ShowWarning("RegRead 返回空值")
                }
                return
            }

            ; 与上次比对，相同则直接返回
            if (hexStr = this._LastHex)
                return

            ; 有变更，将 hex 转为 UTF-8 文本
            bufSize := StrLen(hexStr) // 2
            buf := Buffer(bufSize)
            Loop bufSize {
                byteHex := SubStr(hexStr, (A_Index - 1) * 2 + 1, 2)
                byteVal := Integer("0x" byteHex)
                NumPut("UChar", byteVal, buf, A_Index - 1)
            }
            jsonStr := StrGet(buf, bufSize, "UTF-8")
            if (jsonStr = "") {
                Logger.Warn("GameKeys", "轮询：hex→文本转换失败")
                this._LastHex := hexStr  ; 标记已处理，避免重复解析
                return
            }

            newBindings := this._ParseJson(jsonStr)
            if (newBindings.Count = 0) {
                Logger.Warn("GameKeys", "轮询：JSON 解析结果为空")
                this._LastHex := hexStr  ; 标记已处理，避免重复解析
                return
            }

            ; 更新绑定
            this._Bindings := newBindings
            this._LastHex := hexStr
            this._LogBindings()

            ; 如果之前是失败状态，现在恢复了
            if (!this._LastReadSuccess) {
                this._LastReadSuccess := true
                Logger.Info("GameKeys", "注册表读取已恢复")
            }

            ; 重建热键（按当前标签页重新注册，新拦截正则生效）
            Logger.Info("GameKeys", "检测到按键变更，重建热键")
            HotkeyController.HotkeyOff()
            HotkeyController.EnableByTab(GuiManager.LastActiveTab)
            ; 重新设置切换键
            EventBus.Publish("SetSwitchKey")
        } catch Error as e {
            Logger.Error("GameKeys", "轮询异常：" e.Message)
        }
    }

    ; ── 输出完整按键映射（Info）——启动首次读取与每次重建/恢复后调用 ──
    static _LogBindings() {
        mapText := ""
        for funcName, key in this._Bindings
            mapText .= (mapText = "" ? "" : " | ") funcName "=" key
        Logger.Info("GameKeys", "完整按键映射：" mapText)
    }

    ; ── 弹出读取失败警告 ──
    static _ShowWarning(detail := "") {
        if (this._HasWarned)
            return
        this._HasWarned := true
        Logger.Warn("GameKeys", "读取失败，回退默认按键" (detail != "" ? "，原因：" detail : ""))

        msg := "无法读取游戏按键配置，AFA 将使用默认按键。"
            . "如果您的游戏内按键为自定义设置，可能无法正常工作。"
        if (detail != "")
            msg .= "`n`n失败原因：" detail
        msg .= "`n`n请尝试恢复游戏默认按键或联系 AFA 开发者进行修复。"

        ; 延迟 100ms 执行，避免与启动流程冲突
        fullMsg := msg
        warnFunc := (*) => MessageBox.Warning(
            fullMsg,
            "AFA - 游戏按键读取失败"
        )
        SetTimer warnFunc, -100
    }
}
