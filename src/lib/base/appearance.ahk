; 自定义外观的纯数据与配色运算；文件写入仍由 SettingsService 编排。
class Appearance {
    static Defaults := Map("ThemeMode", "auto", "ThemeWindow", "202020", "ThemeSurface", "2B2B2B",
        "ThemeText", "E6E6E6", "ThemeAccent", "4DB6EA", "ThemeImage", "", "ThemeImageFit", "cover", "ThemeImageOpacity", "20")
    static ColorKeys := ["ThemeWindow", "ThemeSurface", "ThemeText", "ThemeAccent"]

    static NormalizeColor(value, fallback := "") {
        value := LTrim(Trim(value), "#")
        return RegExMatch(value, "i)^[0-9a-f]{6}$") ? StrUpper(value) : fallback
    }

    static Normalize(values) {
        result := this.Defaults.Clone()
        for key, fallback in result {
            if !values.Has(key)
                continue
            value := values[key]
            switch key {
                case "ThemeMode": result[key] := Theme.Normalize(value)
                case "ThemeImage": result[key] := Trim(value)
                case "ThemeImageFit": result[key] := value = "contain" ? "contain" : "cover"
                case "ThemeImageOpacity": result[key] := IsNumber(value) ? String(Max(0, Min(100, Round(value)))) : fallback
                default: result[key] := this.NormalizeColor(value, fallback)
            }
        }
        return result
    }

    static Snapshot(persisted := false) {
        values := Map()
        for key in this.Defaults
            values[key] := persisted ? Config.ReadImportantFromIni(key) : Config.GetImportant(key)
        return this.Normalize(values)
    }

    static SetWorking(values) {
        for key, value in this.Normalize(values)
            Config.SetImportant(key, value)
    }

    static Signature(values) {
        result := ""
        for key in this.Defaults {
            value := values[key]
            result .= key ":" StrLen(value) ":" value "|"
        }
        return result
    }

    static Equal(left, right) => this.Signature(left) == this.Signature(right)

    static Mix(foreground, background, amount) {
        a := Integer("0x" foreground), b := Integer("0x" background)
        result := 0
        for shift in [16, 8, 0]
            result |= Round(((a >> shift) & 255) * amount + ((b >> shift) & 255) * (1 - amount)) << shift
        return Format("{:06X}", result)
    }

    static Luminance(color) {
        rgb := Integer("0x" color), result := 0
        for pair in [[16, 0.2126], [8, 0.7152], [0, 0.0722]] {
            v := ((rgb >> pair[1]) & 255) / 255
            result += (v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) ** 2.4) * pair[2]
        }
        return result
    }

    static Contrast(a, b) {
        x := this.Luminance(a), y := this.Luminance(b)
        return (Max(x, y) + 0.05) / (Min(x, y) + 0.05)
    }

    static Palette(values) {
        bg := values["ThemeWindow"], field := values["ThemeSurface"]
        fg := values["ThemeText"], accent := values["ThemeAccent"]
        palette := (this.Luminance(bg) < 0.179 ? Theme.Dark : Theme.Light).Clone()
        for key in ["Window"]
            palette[key] := bg
        for key in ["Field", "Button", "Row"]
            palette[key] := field
        for key in ["Text", "Heading"]
            palette[key] := fg
        for key in ["Accent", "Link"]
            palette[key] := accent
        for key in ["Hint", "Secondary", "Caption"]
            palette[key] := this.Mix(fg, bg, 0.70)
        for key in ["Muted", "Grip"]
            palette[key] := this.Mix(fg, bg, 0.45)
        palette["Border"] := this.Mix(fg, field, 0.30)
        palette["Hover"] := this.Mix(fg, field, 0.12)
        palette["Selected"] := this.Mix(accent, field, 0.30)
        return palette
    }

    ; 居中等比缩放：cover 可超出目标，由目标位图裁切；contain 留白。
    static ImageRect(iw, ih, width, height, fit) {
        scale := fit = "contain" ? Min(width / iw, height / ih) : Max(width / iw, height / ih)
        w := iw * scale, h := ih * scale
        return {X: (width - w) / 2, Y: (height - h) / 2, W: w, H: h}
    }
}
