; == 更新公告多语言裁剪 ==
; Release body 使用 HTML 注释分段：<!-- afa:lang zh-CN --> ... <!-- afa:lang ja-JP --> ...
; 渲染时按当前语言裁剪；无标记时回退整篇原文。

class ChangelogFormat {
    ; 按当前语言（或指定 locale）裁剪 release body
    static LocalizeBody(body, locale := "") {
        if (locale = "")
            locale := I18n.GetCurrent()
        section := this._ExtractSection(body, locale)
        if (section != "")
            return section
        section := this._ExtractSection(body, "zh-CN")
        if (section != "")
            return section
        return body
    }

    static _ExtractSection(body, locale) {
        marker := "<!-- afa:lang " locale " -->"
        start := InStr(body, marker, false)
        if (start = 0)
            return ""
        start += StrLen(marker)
        ; 找下一个语言标记或结束
        nextMatch := RegExMatch(body, "<!-- afa:lang [A-Za-z0-9-]+ -->", &m, start)
        if (nextMatch > 0)
            return SubStr(body, start, m.Pos[0] - start)
        return SubStr(body, start)
    }
}
