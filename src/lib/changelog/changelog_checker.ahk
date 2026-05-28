; == 更新公告检查器 ==

class ChangelogChecker {
    static ChangelogFile := ""

    static CheckAndShow() {
        configDir := A_AppData "\ArknightsFrameAssistant\PC"
        this.ChangelogFile := configDir "\changelog.json"

        currentVersion := Version.Get()
        dismissedVersion := Config.GetImportant("DismissedChangelogVersion")

        if (dismissedVersion = currentVersion)
            return

        if (!FileExist(this.ChangelogFile))
            return

        ; 从 changelog.json 读取所有版本 body 并拼接
        body := this._ReadAndBuildBody()
        if (body = "")
            return

        ChangelogUI.Show(currentVersion, body)
    }

    ; 内部：读取 changelog.json，按版本降序拼接所有 body
    static _ReadAndBuildBody() {
        try {
            content := FileRead(this.ChangelogFile, "UTF-8")

            ; 解析 JSON 数组中的 versions
            bodies := []
            pos := 1
            Loop {
                ; 找到下一个 tag_name
                pos := RegExMatch(content, '"tag_name"\s*:\s*"([^"]*)"', &tagMatch, pos)
                if (pos = 0)
                    break

                tagName := tagMatch[1]
                bodyStart := pos + StrLen(tagMatch[0])

                ; 在 tag_name 之后找到 body
                q := Chr(34)
                bodyPattern := q "body" q "\s*:\s*" q "((?:[^" q "\\]|\\.)*)" q
                if (RegExMatch(content, bodyPattern, &bodyMatch, bodyStart)) {
                    bodies.Push({tag_name: tagName, body: bodyMatch[1]})
                }

                pos := bodyStart
            }

            if (bodies.Length = 0)
                return ""

            ; 降序排列
            Loop bodies.Length - 1 {
                Loop bodies.Length - A_Index {
                    if (VersionChecker._CompareVersions(bodies[A_Index].tag_name, bodies[A_Index + 1].tag_name) < 0) {
                        temp := bodies[A_Index]
                        bodies[A_Index] := bodies[A_Index + 1]
                        bodies[A_Index + 1] := temp
                    }
                }
            }

            ; 拼接 body，反转义 JSON 转义
            result := ""
            for i, entry in bodies {
                if (i > 1)
                    result .= "`r`n`r`n---`r`n`r`n"
                result .= "## " entry.tag_name "`r`n`r`n" VersionChecker._UnescapeJsonString(entry.body)
            }
            return result
        } catch {
            return ""
        }
    }
}
