; == 国际化（i18n） ==

class I18n {
    static Current := "zh-Hans"
    static _Locales := Map()
    static _WarnedKeys := Map()
    static WARNED_KEYS_LIMIT := 256

    static Init(localeId := "") {
        if (this._Locales.Count = 0) {
            this._Locales := Map(
                "zh-Hans", LocaleZhHans,
                "zh-Hant", LocaleZhHant,
                "ja-JP", LocaleJaJP,
                "ko-KR", LocaleKoKR,
                "en-US", LocaleEnUS
            )
        }

        if (localeId = "" || localeId = "auto")
            localeId := this.DetectAutoLocale()

        if !this._Locales.Has(localeId)
            localeId := "en-US"

        this.Current := localeId
        return localeId
    }

    ; 切换语言
    static SetLocale(localeId) {
        if !this._Locales.Has(localeId)
            return false
        if (this.Current = localeId)
            return true
        previous := this.Current
        this.Current := localeId
        EventBus.Publish("LocaleChanged", {locale: localeId, previous: previous})
        return true
    }

    ; 获取当前语言
    static GetCurrent() {
        return this.Current
    }

    ; 翻译 key
    static T(key, args*) {
        if (this._Locales.Count = 0)
            this.Init(this.Current)
        value := this._Lookup(this.Current, key)
        if (value = "")
            value := this._Lookup("zh-Hans", key)
        if (value = "") {
            if (this.Current != "zh-Hans") {
                if !this._WarnedKeys.Has(key) && this._WarnedKeys.Count < this.WARNED_KEYS_LIMIT {
                    this._WarnedKeys[key] := true
                    Logger.Warn("I18n", "缺失翻译键：" key)
                }
            }
            value := key
        }
        if (args.Length > 0)
            return Format(value, args*)
        return value
    }

    static _Lookup(localeId, key) {
        if !this._Locales.Has(localeId)
            return ""
        cls := this._Locales[localeId]
        if cls.HasOwnProp("Data") && cls.Data.Has(key)
            return cls.Data[key]
        if cls.HasOwnProp("Data2") && cls.Data2.Has(key)
            return cls.Data2[key]
        if cls.HasOwnProp("Data3") && cls.Data3.Has(key)
            return cls.Data3[key]
        return ""
    }

    ; 系统 UI 语言 → BCP-47
    static DetectAutoLocale() {
        langId := DllCall("GetUserDefaultUILanguage", "UInt")
        switch langId {
            case 0x0404, 0x0C04, 0x1404: return "zh-Hant"  ; zh-TW / zh-HK / zh-MO
            case 0x0411: return "ja-JP"
            case 0x0412: return "ko-KR"
            case 0x0409: return "en-US"
            case 0x0804, 0x1004: return "zh-Hans"  ; 简体中文 / 新加坡中文
            default: return "en-US"
        }
    }
}
