; == 国际化（i18n） ==
; 轻量本地化核心：资源为编译内置 AHK Map，回退链为 请求语言 → zh-Hans → key 本身。
; 语言 id 使用 BCP-47：zh-Hans / zh-Hant / ja-JP / ko-KR / en-US。
; 现行键约定：键即中文原文（source-as-key），zh-Hans 资源表为空，回退链天然命中原文；
; zh-Hant / ja-JP / ko-KR / en-US 四张表以中文原文为键、各语言为值。

class I18n {
    static Current := "zh-Hans"
    static _Locales := Map()
    static _WarnedKeys := Map()

    ; 初始化语言。localeId 为空或 "auto" 时使用系统 UI 语言。
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

    ; 翻译：key → 当前语言 → zh-Hans（空表）→ key 本身（key 即中文原文）。
    ; 缺键时仅对非 zh-Hans 语言 Warn（zh-Hans 命中原文属预期）；回退路径同样执行 Format，
    ; 保证带 {1} 占位符的中文键在 zh-Hans 下也能正确插值。
    static T(key, args*) {
        if (this._Locales.Count = 0)
            this.Init(this.Current)  ; 防御：I18n.Init 之前的调用惰性加载，避免返回 key 本身
        value := this._Lookup(this.Current, key)
        if (value = "")
            value := this._Lookup("zh-Hans", key)
        if (value = "") {
            if (this.Current != "zh-Hans") {
                if !this._WarnedKeys.Has(key) {
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
        ; 资源表按 Data → Data2 顺序查找（Data2 存放超出 AHK 单条静态声明上限的键）
        if cls.HasOwnProp("Data") && cls.Data.Has(key)
            return cls.Data[key]
        if cls.HasOwnProp("Data2") && cls.Data2.Has(key)
            return cls.Data2[key]
        return ""
    }

    ; 系统 UI 语言 → BCP-47。
    ; 支持简繁日韩英；繁体中文（台/港/澳）映射 zh-Hant；简体中文/新加坡映射 zh-Hans；其余不支持语言回退英文。
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
