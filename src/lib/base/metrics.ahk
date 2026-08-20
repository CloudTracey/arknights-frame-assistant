; == UI 度量与字体 ==
; 根据当前语言返回推荐字体；宽度覆盖值可后续按语言补充。

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
}
