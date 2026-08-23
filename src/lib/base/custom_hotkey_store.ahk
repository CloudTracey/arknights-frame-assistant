; == 自定义按键存储（CustomHotkeys.json 唯一 owner） ==
; 独立于 Settings.ini 的用户数据文件：UTF-8 JSON，固定写入格式 + 严格读取 + 损坏备份兜底。
;   1. 写定式：键序固定（key/name/func/arg/type）、紧凑单行，字符串只转义 \ " 与 \r\n\t；
;   2. 字符集白名单（名称禁引号/反斜杠/控制字符，坐标文本天然不含），读取器可用严格正则完整解析；
;   3. 任何不一致 → 备份 .bak + Warn + 空列表（绝不抛异常、绝不崩溃）；
;   4. 写入走「临时文件 + ReplaceFileW」原子替换；清空写空数组而非删文件（规避 FileDelete 陷阱）。

class CustomHotkeyStore {
    static File := ""
    static BAK_SUFFIX := ".bak"
    static FORMAT_VERSION := 2  ; v2：条目字段 key/name/func/arg/type（func=按键功能码、arg=参数文本）
                               ; v1（tap/usleep 脚本）不做迁移：旧文件按损坏处理备份为 .bak

    ; 初始化文件路径（与 Settings.ini 同目录）
    static InitPath() {
        configDir := A_AppData "\ArknightsFrameAssistant\PC"
        if !DirExist(configDir)
            DirCreate(configDir)
        this.File := configDir "\CustomHotkeys.json"
    }

    ; 读取全部条目。文件不存在 → 空数组；解析失败 → 备份 .bak + Warn + 空数组。
    ; 返回 Array<{Key, Name, Func, Arg, Type}>（type/func 为原始字符串，非法值由 Config 层宽容回退）。
    static Load() {
        if this.File = ""
            this.InitPath()
        if !FileExist(this.File)
            return []
        text := ""
        try {
            handle := FileOpen(this.File, "r", "UTF-8")
            text := handle.Read()
            handle.Close()
        } catch Error as e {
            Logger.Error("CustomHotkeyStore", "读取失败：" e.Message)
            this._BackupCorrupt()
            return []
        }
        entries := this._Parse(text)
        if !IsObject(entries) {
            Logger.Warn("CustomHotkeyStore", "CustomHotkeys.json 解析失败，已备份损坏文件并回退空列表")
            this._BackupCorrupt()
            return []
        }
        return entries
    }

    ; 原子替换写入。返回 {success, message}（message 为技术错误原文，弹窗文案由调用方经 I18n 包装）
    static Save(entries) {
        if this.File = ""
            this.InitPath()
        text := this._Serialize(entries)
        target := this.File
        temp := target ".tmp-" A_TickCount "-" Random(1000, 9999)
        Critical "On"
        try {
            if FileExist(target)
                FileCopy(target, temp, true)
            handle := FileOpen(temp, "w", "UTF-8")
            handle.Write(text)
            handle.Close()
            if FileExist(target) {
                if !DllCall("Kernel32\ReplaceFileW"
                    , "Str", target
                    , "Str", temp
                    , "Ptr", 0
                    , "UInt", 0x1 ; REPLACEFILE_WRITE_THROUGH
                    , "Ptr", 0
                    , "Ptr", 0
                    , "Int") {
                    errorCode := A_LastError
                    throw Error("配置文件替换失败，错误码：" errorCode)
                }
            } else {
                FileMove(temp, target, true)
            }
            return {success: true, message: ""}
        } catch Error as e {
            Logger.Error("CustomHotkeyStore", "写入失败：" e.Message)
            return {success: false, message: e.Message}
        } finally {
            if temp != "" && FileExist(temp)
                try FileDelete(temp)
            Critical "Off"
        }
    }

    ; ── 内部：序列化（写定式） ──
    static _Serialize(entries) {
        body := ""
        for i, entry in entries {
            if i > 1
                body .= ","
            body .= '{"key":' this._Quote(entry.Key)
                  . ',"name":' this._Quote(entry.Name)
                  . ',"func":"' entry.Func '"'
                  . ',"arg":' this._Quote(entry.Arg)
                  . ',"type":"' entry.Type '"}'
        }
        return '{"version":' this.FORMAT_VERSION ',"keys":[' body "]}"
    }

    ; JSON 字符串转义：\ " 与 \r \n \t（其余控制字符由上游校验排除，坐标/名称语法天然不含）
    static _Quote(s) {
        s := StrReplace(s, "\", "\\")
        s := StrReplace(s, '"', '\"')
        s := StrReplace(s, "`r", "\r")
        s := StrReplace(s, "`n", "\n")
        s := StrReplace(s, "`t", "\t")
        return '"' s '"'
    }

    ; ── 内部：严格解析（写定式自锁：固定键序 + 字符集白名单保证正则无歧义） ──
    ; 成功返回 Array；失败返回 ""（未设置值）
    static _Parse(text) {
        text := Trim(text)
        skeleton := '^\{"version":' this.FORMAT_VERSION ',"keys":\[(.*)\]}$'
        if !RegExMatch(text, skeleton, &m)
            return ""
        inner := m[1]
        entries := []
        if inner != "" {
            parts := StrSplit(inner, "},{")
            for i, part in parts {
                ; 恢复被分隔符吞掉的花括号：首个缺 "{"、末个缺 "}"、中间缺两侧
                candidate := (i > 1 ? "{" : "") part (i < parts.Length ? "}" : "")
                if !RegExMatch(candidate, '^\{"key":"([^"]*)","name":"([^"]*)","func":"([^"]*)","arg":"([^"]*)","type":"([^"]*)"\}$', &em)
                    return ""
                entries.Push({
                    Key: this._Unescape(em[1]),
                    Name: this._Unescape(em[2]),
                    Func: em[3],
                    Arg: this._Unescape(em[4]),
                    Type: em[5]
                })
            }
        }
        return entries
    }

    ; JSON 反转义（与 _Quote 对称）
    static _Unescape(s) {
        s := StrReplace(s, "\\", "\")
        s := StrReplace(s, '\"', '"')
        s := StrReplace(s, "\n", "`n")
        s := StrReplace(s, "\r", "`r")
        s := StrReplace(s, "\t", "`t")
        return s
    }

    ; ── 内部：损坏文件备份（同名覆盖旧备份） ──
    static _BackupCorrupt() {
        bak := this.File this.BAK_SUFFIX
        if FileExist(bak)
            try FileDelete(bak)
        try FileMove(this.File, bak, true)
        catch Error as e
            Logger.Warn("CustomHotkeyStore", "损坏文件备份失败：" e.Message)
    }
}
