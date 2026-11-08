; == Unity PlayerPrefs 注册表读取 ==
; 游戏把 PlayerPrefs 以 REG_BINARY 存入 HKCU\Software\{Company}\{Product}，
; 这里提供通用的 hex 解码与值名查找，供 GameKeys 与游戏帧率识别复用。

class UnityPlayerPrefs {
    ; REG_BINARY 的 hex 字符串 → UTF-8 文本；空值、非法长度或非 hex 内容返回 ""
    static DecodeHexUtf8(hexStr) {
        if (StrLen(hexStr) = 0 || Mod(StrLen(hexStr), 2) != 0)
            return ""
        if !RegExMatch(hexStr, "^[0-9A-Fa-f]+$")
            return ""
        bufSize := StrLen(hexStr) // 2
        buf := Buffer(bufSize)
        Loop bufSize {
            byteHex := SubStr(hexStr, (A_Index - 1) * 2 + 1, 2)
            NumPut("UChar", Integer("0x" byteHex), buf, A_Index - 1)
        }
        return StrGet(buf, bufSize, "UTF-8")
    }

    ; 查找值名：优先返回所有前缀匹配项（按注册表枚举顺序）；
    ; 一个匹配都没有时退回 knownNames 中实际可读取的名字
    static FindValueNames(root, prefix, knownNames := []) {
        names := []
        if (root = "")
            return names

        try {
            Loop Reg, root, "V" {
                if (InStr(A_LoopRegName, prefix) = 1)
                    names.Push(A_LoopRegName)
            }
        } catch Error as e {
            Logger.Warn("UnityPlayerPrefs", "注册表枚举失败：" root " - " e.Message)
        }

        if (names.Length = 0) {
            for name in knownNames {
                try {
                    if (RegRead(root, name, "") != "")
                        names.Push(name)
                }
            }
        }
        return names
    }
}
