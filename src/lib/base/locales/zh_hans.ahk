class LocaleZhHans {
    ; 简体中文不维护资源表：键即中文原文（source-as-key / gettext 风格）。
    ; I18n.T 回退链「请求语言 → zh-Hans → key 本身」使 zh-Hans 用户天然命中原文；
    ; 新增/修改用户可见文案时，只需同步 zh-Hant / ja-JP / ko-KR / en-US 四张翻译表。
    static Data := Map()
}
