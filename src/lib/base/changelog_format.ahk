; == 更新公告多语言裁剪 ==
; Release body 使用 HTML 注释分段：<!-- afa:lang zh-Hans --> ... <!-- afa:lang ja-JP --> ...
; 渲染时按当前语言裁剪；无标记时回退整篇原文。
; GitHub 页面可用 <details>/<summary> 折叠非默认语言，客户端裁剪前先剥离这些仅对浏览器渲染生效的标签。

class ChangelogFormat {
    ; 按当前语言（或指定 locale）裁剪 release body
    static LocalizeBody(body, locale := "") {
        if (locale = "")
            locale := I18n.GetCurrent()
        body := this._StripCollapseTags(body)
        section := this._ExtractSection(body, locale)
        if (section != "")
            return section
        section := this._ExtractSection(body, "zh-Hans")
        if (section != "")
            return section
        return body
    }

    ; 剥离 GitHub 折叠容器标签（仅影响浏览器渲染），保留内部内容，避免裁剪结果残留标签原文。
    ; 注意：不用 (?s)/.*? 等组合（部分 AHK 环境对惰性匹配+点修饰组合不友好），用字符类匹配单行 summary。
    static _StripCollapseTags(body) {
        body := RegExReplace(body, "<summary>[^<>]*</summary>", "")
        body := RegExReplace(body, "<details[^>]*>", "")
        body := RegExReplace(body, "</details>", "")
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
        section := (nextMatch > 0) ? SubStr(body, start, m.Pos[0] - start) : SubStr(body, start)
        ; 标记与正文之间有一个换行，去掉开头的空行，避免公告首行空白
        return this._TrimLeadingNewlines(section)
    }

    ; 去掉字符串开头的空行（\r\n / \r / \n 连续出现均移除）
    static _TrimLeadingNewlines(s) {
        Loop {
            if (SubStr(s, 1, 2) = "`r`n") {
                s := SubStr(s, 3)
            } else if (SubStr(s, 1, 1) = "`r" || SubStr(s, 1, 1) = "`n") {
                s := SubStr(s, 2)
            } else {
                break
            }
        }
        return s
    }
}
