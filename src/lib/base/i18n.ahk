; == 国际化（i18n） ==
; 轻量本地化核心：资源为编译内置 AHK Map，回退链为 请求语言 → zh-CN → key 本身。
; 语言 id 使用 BCP-47：zh-CN / ja-JP / ko-KR / en-US。

class I18n {
    static Current := "zh-CN"
    static _Locales := Map()
    static _WarnedKeys := Map()

    ; 初始化语言。localeId 为空或 "auto" 时使用系统 UI 语言。
    static Init(localeId := "") {
        if (this._Locales.Count = 0) {
            this._Locales := Map(
                "zh-CN", LocaleZhCN,
                "ja-JP", LocaleJaJP,
                "ko-KR", LocaleKoKR,
                "en-US", LocaleEnUS
            )
        }

        if (localeId = "" || localeId = "auto")
            localeId := this.DetectAutoLocale()

        if !this._Locales.Has(localeId)
            localeId := "zh-CN"

        this.Current := localeId
        return localeId
    }

    ; 切换语言并发布事实事件
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

    ; 翻译：key → 当前语言 → zh-CN → key 本身
    static T(key, args*) {
        value := this._Lookup(this.Current, key)
        if (value = "")
            value := this._Lookup("zh-CN", key)
        if (value = "") {
            if !this._WarnedKeys.Has(key) {
                this._WarnedKeys[key] := true
                Logger.Warn("I18n", "缺失翻译键：" key)
            }
            return key
        }
        if (args.Length > 0)
            return Format(value, args*)
        return value
    }

    static _Lookup(localeId, key) {
        if !this._Locales.Has(localeId)
            return ""
        cls := this._Locales[localeId]
        if !cls.HasOwnProp("Data") || !cls.Data.Has(key)
            return ""
        return cls.Data[key]
    }

    ; 系统 UI 语言 → BCP-47；仅映射四语，其余回退 zh-CN
    static DetectAutoLocale() {
        langId := DllCall("GetUserDefaultUILanguage", "UInt")
        switch langId {
            case 0x0411: return "ja-JP"
            case 0x0412: return "ko-KR"
            case 0x0409: return "en-US"
            default: return "zh-CN"
        }
    }
}
