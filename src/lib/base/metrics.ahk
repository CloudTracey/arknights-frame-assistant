; == UI 度量与字体 ==
; 根据当前语言返回推荐字体；TextWidth 用于按语言估算控件所需宽度，避免换行/溢出。

class Metrics {
    static FontFor(locale) {
        switch locale {
            case "zh-Hant": return "Microsoft JhengHei UI"
            case "ja-JP": return "Yu Gothic UI"
            case "ko-KR": return "Malgun Gothic"
            case "en-US": return "Segoe UI"
            case "zh-Hans": return "Microsoft YaHei UI"
            default: return "Microsoft YaHei UI"
        }
    }

    static IconFont() {
        return "Segoe MDL2 Assets"
    }

    ; 估算文本渲染像素宽度（fontSize 为像素字号，s9 ≈ 12px）。
    ; 规则：CJK/全角（含假名、谚文、全角标点）≈ 1.0em；窄字母 ≈ 0.35em；其余字符 ≈ 0.55em；空格 ≈ 0.3em。
    static TextWidth(text, fontSize := 12) {
        width := 0.0
        for char in StrSplit(text) {  ; StrSplit 无分隔符时按字符拆分
            code := Ord(char)
            if (code >= 0x2E80)
                width += 1.0
            else if (char = " ")
                width += 0.3
            else if (char = "i" || char = "l" || char = "I" || char = "j"
                || char = "f" || char = "t" || char = "." || char = ","
                || char = ":" || char = ";" || char = "(" || char = ")"
                || char = "[" || char = "]" || char = "'")
                width += 0.35
            else
                width += 0.55
        }
        return Ceil(width * fontSize)
    }
}
