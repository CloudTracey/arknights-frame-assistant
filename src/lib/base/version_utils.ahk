; == 版本/JSON 纯工具 ==
; base 层版本/JSON 纯工具，供 updater/changelog 复用。

class VersionUtils {
    ; 反转义 JSON 字符串
    static UnescapeJsonString(str) {
        placeholder := Chr(1)
        result := StrReplace(str, "\\", placeholder)
        result := StrReplace(result, '\"', Chr(34))
        result := StrReplace(result, "\/", "/")
        result := StrReplace(result, "\n", "`n")
        result := StrReplace(result, "\r", "`r")
        result := StrReplace(result, "\t", "`t")
        result := StrReplace(result, placeholder, "\")
        return result
    }

    ; 转义字符串为 JSON 字符串值
    static EscapeJsonString(str) {
        result := StrReplace(str, "\", "\\")
        result := StrReplace(result, Chr(34), '\"')
        result := StrReplace(result, "`r`n", "\r\n")
        result := StrReplace(result, "`n", "\n")
        result := StrReplace(result, "`r", "\r")
        result := StrReplace(result, "`t", "\t")
        return result
    }

    ; 从 JSON 源码提取字符串值（valueStartPos 为值起始引号的位置，返回原始转义内容，未反转义）。
    ; 替代 ((?:[^"\\]|\\.)*) 类正则：长 body 会触发 PCRE2 match limit（PCRE execution error，-8），
    ; 线性扫描逐字符处理 \" 转义，无回溯、不依赖正则，任意长度稳定。
    static ExtractJsonStringValue(json, valueStartPos) {
        value := ""
        pos := valueStartPos + 1
        q := Chr(34)
        total := StrLen(json)
        Loop {
            if (pos > total)
                return ""  ; JSON 损坏：未找到结束引号
            ch := SubStr(json, pos, 1)
            if (ch = q)
                return value
            if (ch = "\") {
                if (pos + 1 > total)
                    return ""  ; JSON 损坏：转义符后无字符
                value .= ch SubStr(json, pos + 1, 1)
                pos += 2
            } else {
                value .= ch
                pos += 1
            }
        }
    }

    ; 解析 GitHub Releases JSON 数组，提取所有发布版本
    static ParseReleasesArray(json) {
        releases := []
        pos := 1

        Loop {
            pos := RegExMatch(json, '"tag_name"\s*:\s*"([^"]*)"', &tagMatch, pos)
            if (pos == 0)
                break

            tagName := tagMatch[1]
            tagEnd := pos + StrLen(tagMatch[0])

            ; 确定当前release对象的结束位置（下一个tag_name之前或JSON结尾）
            nextTagPos := RegExMatch(json, '"tag_name"', , tagEnd)
            if (nextTagPos == 0)
                nextTagPos := StrLen(json) + 1

            searchEnd := nextTagPos - 1
            searchStr := SubStr(json, tagEnd, searchEnd - tagEnd + 1)

            ; 提取prerelease状态
            prerelease := false
            if (RegExMatch(searchStr, '"prerelease"\s*:\s*(true|false)', &preMatch)) {
                prerelease := (preMatch[1] == "true")
            }

            ; 提取下载地址
            downloadUrl := ""
            if (RegExMatch(searchStr, '"browser_download_url"\s*:\s*"([^"]*)"', &urlMatch)) {
                downloadUrl := urlMatch[1]
            }

            ; 提取 AFA.exe asset 的 SHA-256 摘要（GitHub 格式 sha256:<hex>，剥离前缀；限定 AFA.exe asset）
            expectedHash := ""
            if (RegExMatch(searchStr, '"name"\s*:\s*"AFA\.exe".*?"digest"\s*:\s*"sha256:([0-9a-fA-F]{64})"', &digestMatch))
                expectedHash := digestMatch[1]

            ; 提取 body（Release 正文，Markdown 格式；长正文用线性扫描，避免 PCRE match limit）
            body := ""
            q := Chr(34)
            bodyHeadPattern := q "body" q "\s*:\s*" q
            if (RegExMatch(searchStr, bodyHeadPattern, &bodyHeadMatch)) {
                bodyStartQuote := bodyHeadMatch.Pos[0] + StrLen(bodyHeadMatch[0]) - 1
                body := this.UnescapeJsonString(this.ExtractJsonStringValue(searchStr, bodyStartQuote))
            }

            ; 提取发布日期（优先 published_at，回退 date）
            date := ""
            if (RegExMatch(searchStr, '"published_at"\s*:\s*"([^"]*)"', &dateMatch)) {
                date := SubStr(dateMatch[1], 1, 10)  ; 提取 YYYY-MM-DD
            } else if (RegExMatch(searchStr, '"date"\s*:\s*"([^"]*)"', &dateMatch)) {
                date := dateMatch[1]  ; 国内源 version.json 兼容
            }

            releases.Push({tag_name: tagName, prerelease: prerelease, downloadUrl: downloadUrl, body: body, date: date, expectedHash: expectedHash})
            pos := tagEnd
        }

        return releases
    }

    ; 比较版本号（支持语义化版本规范 SemVer 2.0.0）
    ; 返回: -1(本地<远程), 0(相等), 1(本地>远程)
    static CompareVersions(localVersion, remoteVersion) {
        localParsed := this.ParseVersion(localVersion)
        remoteParsed := this.ParseVersion(remoteVersion)

        ; 比较主版本、次版本、修订号
        Loop 3 {
            localNum := localParsed.numbers[A_Index]
            remoteNum := remoteParsed.numbers[A_Index]

            if (localNum < remoteNum)
                return -1
            if (localNum > remoteNum)
                return 1
        }

        ; 主版本号相同时，比较预发布标识符
        ; 规则：正式版本 > 预发布版本（如 v1.0.0 > v1.0.0-alpha）
        localHasPre := localParsed.prerelease.Length > 0
        remoteHasPre := remoteParsed.prerelease.Length > 0

        if (!localHasPre && !remoteHasPre) {
            return 0  ; 都是正式版本且主版本号相同
        }
        if (!localHasPre && remoteHasPre) {
            return 1  ; 本地是正式版本，远程是预发布版本
        }
        if (localHasPre && !remoteHasPre) {
            return -1  ; 本地是预发布版本，远程是正式版本
        }

        ; 都是预发布版本，逐个比较标识符
        return this.ComparePrerelease(localParsed.prerelease, remoteParsed.prerelease)
    }

    ; 解析版本号 vX.Y.Z[-prerelease][+metadata]
    ; 返回: {numbers: [X, Y, Z], prerelease: [ident1, ident2, ...], metadata: ""}
    static ParseVersion(versionStr) {
        ; 移除前缀 'v' 或 'V'
        cleanVersion := RegExReplace(versionStr, "^[vV]", "")

        ; 分离构建元数据（+号后的内容，不参与版本比较）
        metadata := ""
        plusPos := InStr(cleanVersion, "+")
        if (plusPos > 0) {
            metadata := SubStr(cleanVersion, plusPos + 1)
            cleanVersion := SubStr(cleanVersion, 1, plusPos - 1)
        }

        ; 分离预发布标识符（-号后的内容）
        prerelease := []
        hyphenPos := InStr(cleanVersion, "-")
        versionCore := cleanVersion
        if (hyphenPos > 0) {
            versionCore := SubStr(cleanVersion, 1, hyphenPos - 1)
            prereleaseStr := SubStr(cleanVersion, hyphenPos + 1)
            prerelease := StrSplit(prereleaseStr, ".")
        }

        ; 解析主版本号、次版本号、修订号
        parts := StrSplit(versionCore, ".")
        numbers := []
        Loop 3 {
            if (A_Index <= parts.Length) {
                ; 尝试转换为整数，如果失败则使用 0
                try {
                    numbers.Push(Integer(parts[A_Index]))
                } catch {
                    numbers.Push(0)
                }
            } else {
                numbers.Push(0)
            }
        }

        return {numbers: numbers, prerelease: prerelease, metadata: metadata}
    }

    ; 比较预发布标识符
    ; 按照 SemVer 规范：数字标识符按数值比较，字母标识符按 ASCII 比较
    ; 数字标识符优先级低于字母标识符
    static ComparePrerelease(localPre, remotePre) {
        maxLen := Max(localPre.Length, remotePre.Length)

        Loop maxLen {
            ; 获取当前位置的标识符（避免使用三元表达式，确保类型正确）
            localIdent := ""
            remoteIdent := ""

            if (A_Index <= localPre.Length)
                localIdent := localPre[A_Index]
            if (A_Index <= remotePre.Length)
                remoteIdent := remotePre[A_Index]

            ; 如果一个版本有更多标识符，则另一个版本缺少标识符意味着优先级更低
            if (localIdent == "")
                return -1
            if (remoteIdent == "")
                return 1

            ; 判断标识符类型
            localIsNum := this.IsNumeric(localIdent)
            remoteIsNum := this.IsNumeric(remoteIdent)

            ; 数字标识符优先级低于字母标识符
            if (localIsNum && !remoteIsNum)
                return -1
            if (!localIsNum && remoteIsNum)
                return 1

            ; 同类型比较
            if (localIsNum && remoteIsNum) {
                ; 都是数字，按数值比较
                localVal := Integer(localIdent)
                remoteVal := Integer(remoteIdent)
                if (localVal < remoteVal)
                    return -1
                if (localVal > remoteVal)
                    return 1
            } else {
                ; 都是字母（或混合），按 ASCII 顺序比较
                cmpResult := StrCompare(localIdent, remoteIdent)
                if (cmpResult < 0)
                    return -1
                if (cmpResult > 0)
                    return 1
            }
        }

        return 0  ; 所有标识符相同
    }

    ; 检查字符串是否为纯数字
    static IsNumeric(str) {
        if (str == "")
            return false

        Loop Parse str {
            charCode := Ord(A_LoopField)
            if (charCode < 48 || charCode > 57)  ; ASCII '0'=48, '9'=57
                return false
        }
        return true
    }

    ; 转义正则表达式中的特殊字符
    static EscapeRegex(str) {
        ; 需要转义的正则元字符: \ . ^ $ | ? * + ( ) { } [ ]
        result := str
        result := StrReplace(result, "\", "\\")
        result := StrReplace(result, ".", "\.")
        result := StrReplace(result, "^", "\^")
        result := StrReplace(result, "$", "\$")
        result := StrReplace(result, "|", "\|")
        result := StrReplace(result, "?", "\?")
        result := StrReplace(result, "*", "\*")
        result := StrReplace(result, "+", "\+")
        result := StrReplace(result, "(", "\(")
        result := StrReplace(result, ")", "\)")
        result := StrReplace(result, "{", "\{")
        result := StrReplace(result, "}", "\}")
        result := StrReplace(result, "[", "\[")
        result := StrReplace(result, "]", "\]")
        return result
    }

    ; 从 JSON 字符串中提取字段值
    static ExtractJsonValue(json, key) {
        ; 匹配 "key":"value" 格式
        ; 使用Chr构建正则表达式避免引号问题
        q := Chr(34)  ; 双引号
        notQ := Chr(94) Chr(34)  ; [^"]
        ; 对key中的正则元字符进行转义
        escapedKey := this.EscapeRegex(key)
        pattern := q escapedKey q ":\s*" q "([" notQ "]*)" q
        if (RegExMatch(json, pattern, &match)) {
            return match[1]
        }

        ; 尝试匹配数字
        pattern := q escapedKey q ":\s*(\d+)"
        if (RegExMatch(json, pattern, &match)) {
            return match[1]
        }

        return ""
    }
}
