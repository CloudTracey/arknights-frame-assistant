; == 更新源仓库 ==
; 承载版本检查的 GitHub/国内源实现与 changelog 缓存，供 VersionChecker 门面调用。

class ReleaseRepository {
    ; GitHub API地址（完整列表，含预发布）
    static ApiUrl := "https://api.github.com/repos/CloudTracey/arknights-frame-assistant/releases"

    ; GitHub API地址（仅正式版）
    static StableApiUrl := "https://api.github.com/repos/CloudTracey/arknights-frame-assistant/releases/latest"

    ; 国内源 CDN 基地址（正式版和测试版分别拼接 /stable/version.json 和 /beta/version.json）
    static CdnBaseUrl := "https://release.arknightsframeassistant.com"

    ; 缓存文件路径
    static CacheFile := ""

    ; 超时设置（毫秒）
    static TimeoutMs := 5000

    static CheckGithub(localVersion) {
        useGitHubToken := Config.GetImportant("UseGitHubToken")
        updateChannel := Config.GetImportant("UpdateChannel")
        isStable := (updateChannel == "1")

        ; 选择API URL
        if (isStable) {
            apiUrl := this.StableApiUrl
            VersionChecker._Log("更新渠道: 正式版")
        } else {
            apiUrl := this.ApiUrl
            VersionChecker._Log("更新渠道: 测试版")
        }

        VersionChecker._Log("========== 开始版本检查 ==========")
        VersionChecker._Log("Timestamp: " VersionChecker._Timestamp())
        VersionChecker._Log("本地版本: [" localVersion "] 长度: " StrLen(localVersion))
        VersionChecker._Log("API URL: " apiUrl)
        VersionChecker._Log("超时设置: " this.TimeoutMs "ms")
        gitHubToken := ""

        ; 检查本地版本是否有效
        if (localVersion = "") {
            VersionChecker._Log("错误: 本地版本为空!")
            return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "无法获取本地版本号"}
        }

        ; 是否使用GitHub Token进行更新检查
        if (useGitHubToken == 1) {
            ; 获取Token
            gitHubToken := Config.GetImportant("GitHubToken")
            VersionChecker._Log("GitHub Token长度: " StrLen(gitHubToken))
        }

        ; 构建请求头Map（用于日志）
        headersMap := Map(
            "Accept", "application/vnd.github.v3+json",
            "User-Agent", "ArknightsFrameAssistant/" localVersion
        )
        if (gitHubToken != "")
            headersMap["Authorization"] := "token " gitHubToken

        VersionChecker._LogRequest("VERSION_CHECK_REQUEST", apiUrl, "GET", headersMap)

        try {
            req := VersionChecker._CreateHttpRequest(apiUrl, gitHubToken)
            if (req.error != "") {
                VersionChecker._Log("创建HTTP请求失败: " req.error)
                return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "网络错误: " req.error}
            }

            VersionChecker._Log("发送请求...")
            req.http.Send()
            checkStart := A_TickCount
            Loop {
                Sleep(50)
                if (req.http.readyState >= 4)
                    break
                if (A_TickCount - checkStart > this.TimeoutMs) {
                    try req.http.Abort()
                    VersionChecker._Log("版本检查超时")
                    return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "请求超时，请检查网络连接"}
                }
            }
            VersionChecker._Log("请求已发送，等待响应...")

            resp := VersionChecker._GetResponseInfo(req.http)
            VersionChecker._LogResponse("VERSION_CHECK_RESPONSE", resp.statusCode, resp.statusText, resp.headers, resp.body)

            ; 检查HTTP状态
            if (resp.statusCode = 401) {
                VersionChecker._Log("Token无效（401未授权）")
                return {status: "token_invalid", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "GitHub Token无效，请检查设置"}
            }
            if (resp.statusCode = 403) {
                VersionChecker._Log("检测到API频率限制")
                return {status: "rate_limited", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "API请求频率超限。请在设置中配置GitHub Token以提高配额", suggestToken: true}
            }
            if (resp.statusCode != 200) {
                VersionChecker._Log("服务器返回非200状态码: " resp.statusCode)
                return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "服务器返回错误: " resp.statusCode " " resp.statusText}
            }

            ; 根据渠道解析响应
            if (isStable) {
                ; 正式版：/releases/latest 返回单个对象
                remoteVersion := VersionUtils.ExtractJsonValue(resp.body, "tag_name")
                downloadUrl := VersionUtils.ExtractJsonValue(resp.body, "browser_download_url")

                ; 提取 AFA.exe asset 的 SHA-256 摘要（GitHub 格式 sha256:<hex>，剥离前缀；限定 AFA.exe asset，避免多 asset 时命中其他文件）
                expectedHash := ""
                if (RegExMatch(resp.body, '"name"\s*:\s*"AFA\.exe".*?"digest"\s*:\s*"sha256:([0-9a-fA-F]{64})"', &hashMatch))
                    expectedHash := hashMatch[1]

                ; 额外请求全量 releases 用于 changelog
                allReleases := this._FetchAllReleases(gitHubToken)
                if (allReleases.Length > 0) {
                    this._SaveChangelogCache(allReleases)
                }
                changelogBody := (allReleases.Length > 0) ? this._BuildChangelogBody(localVersion, allReleases) : ""
                VersionChecker._Log("解析结果（正式版） - 远程版本: " remoteVersion)
                VersionChecker._Log("解析结果（正式版） - 下载地址: " downloadUrl)

                if (remoteVersion = "" || downloadUrl = "") {
                    VersionChecker._Log("无法解析版本信息")
                    return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "无法解析版本信息"}
                }

                ; 保存到缓存
                this._SaveToCache(remoteVersion, downloadUrl)

                ; 比较版本
                compareResult := VersionUtils.CompareVersions(localVersion, remoteVersion)
                VersionChecker._Log("版本比较结果: " compareResult " (-1=需更新, 0=相同, 1=本地更新)")

                if (compareResult < 0) {
                    VersionChecker._Log("发现新版本: " remoteVersion)
                    Logger.Info("VersionChecker", "发现新版本：" remoteVersion)
                    return {status: "update_available", localVersion: localVersion, remoteVersion: remoteVersion, downloadUrl: downloadUrl, expectedHash: expectedHash, changelogBody: changelogBody}
                } else {
                    VersionChecker._Log("已是最新版本")
                    Logger.Info("VersionChecker", "已是最新版本")
                    return {status: "up_to_date", localVersion: localVersion, remoteVersion: remoteVersion, downloadUrl: ""}
                }
            } else {
                ; 测试版：/releases 返回数组，解析所有发布并找到最高版本
                releases := VersionUtils.ParseReleasesArray(resp.body)

                ; 保存 changelog 缓存
                if (releases.Length > 0) {
                    this._SaveChangelogCache(releases)
                }
                changelogBody := (releases.Length > 0) ? this._BuildChangelogBody(localVersion, releases) : ""
                VersionChecker._Log("解析到 " releases.Length " 个发布版本")

                if (releases.Length = 0) {
                    VersionChecker._Log("无法解析版本信息")
                    return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "无法解析版本信息"}
                }

                ; 找出SemVer最高的版本（包含正式版和预发布版）
                bestIndex := 1
                Loop releases.Length - 1 {
                    idx := A_Index + 1
                    if (VersionUtils.CompareVersions(releases[bestIndex].tag_name, releases[idx].tag_name) < 0)
                        bestIndex := idx
                }
                bestRelease := releases[bestIndex]

                remoteVersion := bestRelease.tag_name
                downloadUrl := bestRelease.downloadUrl
                expectedHash := bestRelease.HasProp("expectedHash") ? bestRelease.expectedHash : ""
                VersionChecker._Log("解析结果（测试版） - 最高远程版本: " remoteVersion)
                VersionChecker._Log("解析结果（测试版） - 下载地址: " downloadUrl)

                if (remoteVersion = "" || downloadUrl = "") {
                    VersionChecker._Log("无法解析版本信息")
                    return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "无法解析版本信息"}
                }

                ; 保存到缓存
                this._SaveToCache(remoteVersion, downloadUrl)

                ; 比较版本
                compareResult := VersionUtils.CompareVersions(localVersion, remoteVersion)
                VersionChecker._Log("版本比较结果: " compareResult " (-1=需更新, 0=相同, 1=本地更新)")

                if (compareResult < 0) {
                    VersionChecker._Log("发现新版本: " remoteVersion)
                    Logger.Info("VersionChecker", "发现新版本：" remoteVersion)
                    return {status: "update_available", localVersion: localVersion, remoteVersion: remoteVersion, downloadUrl: downloadUrl, expectedHash: expectedHash, changelogBody: changelogBody}
                } else {
                    VersionChecker._Log("已是最新版本")
                    Logger.Info("VersionChecker", "已是最新版本")
                    return {status: "up_to_date", localVersion: localVersion, remoteVersion: remoteVersion, downloadUrl: ""}
                }
            }
        } catch as err {
            errorInfo := VersionChecker._ParseErrorInfo(err)
            VersionChecker._Log("========== VERSION_CHECK_ERROR ==========")
            VersionChecker._Log("Timestamp: " VersionChecker._Timestamp())
            VersionChecker._Log("ErrorCode: " errorInfo.code)
            VersionChecker._Log("ErrorDesc: " errorInfo.desc)
            VersionChecker._Log("ErrorMessage: " err.Message)

            userMessage := errorInfo.desc
            if (InStr(errorInfo.desc, "超时"))
                userMessage := "网络请求超时，请检查网络连接后重试。`n`n如果问题持续存在，请尝试配置GitHub Token。"

            return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: userMessage, errorDetail: "[" errorInfo.code "] " err.Message}
        }
    }

    ; 内部：从国内源（COS+CDN）检查更新
    ; 返回格式与 _CheckFromGithub 一致
    ; 正式版：仅查 /stable；测试版：查 /beta + /stable 取最高版本（与 GitHub 行为对齐）
    static CheckDomestic(localVersion) {
        updateChannel := Config.GetImportant("UpdateChannel")
        isStable := (updateChannel == "1")

        VersionChecker._Log("========== 国内源版本检查 ==========")
        VersionChecker._Log("更新渠道: " (isStable ? "正式版" : "测试版"))
        VersionChecker._Log("本地版本: " localVersion)

        if (localVersion = "") {
            return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "无法获取本地版本号"}
        }

        ; 正式版：只查 stable
        if (isStable) {
            return this._CheckDomesticChannel(localVersion, "/stable")
        }

        ; 测试版：查 beta 和 stable，取版本号更高者
        betaResult := this._CheckDomesticChannel(localVersion, "/beta")
        stableResult := this._CheckDomesticChannel(localVersion, "/stable")

        ; 两个都失败
        betaFailed := (betaResult.status = "check_failed")
        stableFailed := (stableResult.status = "check_failed")

        if (betaFailed && stableFailed) {
            ; 返回最后一次的错误（优先保留 beta 的错误信息）
            return betaResult
        }

        ; 仅 beta 成功
        if (stableFailed) {
            return betaResult
        }

        ; 仅 stable 成功
        if (betaFailed) {
            return stableResult
        }

        ; 两个都成功 → 取版本号更高者
        if (VersionUtils.CompareVersions(betaResult.remoteVersion, stableResult.remoteVersion) >= 0) {
            VersionChecker._Log("测试版渠道: beta=" betaResult.remoteVersion " >= stable=" stableResult.remoteVersion "，使用 beta")
            return betaResult
        } else {
            VersionChecker._Log("测试版渠道: stable=" stableResult.remoteVersion " > beta=" betaResult.remoteVersion "，使用 stable")
            return stableResult
        }
    }

    ; 内部：从国内源指定渠道拉取 version.json 并解析
    static _CheckDomesticChannel(localVersion, channelPath) {
        jsonUrl := this.CdnBaseUrl channelPath "/version.json"

        VersionChecker._Log("URL: " jsonUrl)

        headersMap := Map(
            "Accept", "application/json",
            "User-Agent", "ArknightsFrameAssistant/" localVersion
        )
        VersionChecker._LogRequest("DOMESTIC_CHECK_REQUEST", jsonUrl, "GET", headersMap)

        try {
            req := VersionChecker._CreateHttpRequest(jsonUrl, "", "application/json")
            if (req.error != "") {
                VersionChecker._Log("国内源HTTP请求创建失败: " req.error)
                return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "网络错误: " req.error}
            }

            req.http.Send()
            checkStart := A_TickCount
            Loop {
                Sleep(50)
                if (req.http.readyState >= 4)
                    break
                if (A_TickCount - checkStart > this.TimeoutMs) {
                    try req.http.Abort()
                    VersionChecker._Log("国内源版本检查超时")
                    return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "请求超时，请检查网络连接"}
                }
            }

            resp := VersionChecker._GetResponseInfo(req.http)
            VersionChecker._LogResponse("DOMESTIC_CHECK_RESPONSE", resp.statusCode, resp.statusText, resp.headers, resp.body)

            if (resp.statusCode != 200) {
                VersionChecker._Log("国内源返回非200状态码: " resp.statusCode)
                return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "国内源返回错误: " resp.statusCode}
            }

            ; 解析 version.json
            remoteVersion := VersionUtils.ExtractJsonValue(resp.body, "version")
            downloadUrl := VersionUtils.ExtractJsonValue(resp.body, "downloadUrl")
            expectedHash := VersionUtils.ExtractJsonValue(resp.body, "sha256")

            VersionChecker._Log("解析结果 - 远程版本: " remoteVersion)
            VersionChecker._Log("解析结果 - 下载地址: " downloadUrl)

            if (remoteVersion = "" || downloadUrl = "") {
                VersionChecker._Log("无法解析国内源 version.json")
                return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "无法解析版本信息"}
            }

            ; 解析 releases 数组用于 changelog 缓存
            releases := VersionUtils.ParseReleasesArray(resp.body)
            if (releases.Length > 0) {
                this._SaveChangelogCache(releases)
            }
            changelogBody := (releases.Length > 0) ? this._BuildChangelogBody(localVersion, releases) : ""

            ; 保存到缓存
            this._SaveToCache(remoteVersion, downloadUrl)

            ; 比较版本
            compareResult := VersionUtils.CompareVersions(localVersion, remoteVersion)
            VersionChecker._Log("版本比较结果: " compareResult)

            if (compareResult < 0) {
                VersionChecker._Log("国内源发现新版本: " remoteVersion)
                Logger.Info("VersionChecker", "国内源发现新版本：" remoteVersion)
                return {status: "update_available", localVersion: localVersion, remoteVersion: remoteVersion, downloadUrl: downloadUrl, expectedHash: expectedHash, changelogBody: changelogBody}
            } else {
                VersionChecker._Log("已是最新版本（国内源）")
                Logger.Info("VersionChecker", "已是最新版本（国内源）")
                return {status: "up_to_date", localVersion: localVersion, remoteVersion: remoteVersion, downloadUrl: ""}
            }
        } catch as err {
            errorInfo := VersionChecker._ParseErrorInfo(err)
            VersionChecker._Log("国内源检查异常: " errorInfo.desc)
            return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "国内源检查失败: " errorInfo.desc}
        }
    }

    ; 内部：用单个源检查更新（带重试，最多 3 次）
    ; checkFn: 一个 Func 对象，签名为 (localVersion) → result

    static _FetchAllReleases(token := "") {
        try {
            req := VersionChecker._CreateHttpRequest(this.ApiUrl, token)
            if (req.error != "")
                return []

            req.http.Send()
            start := A_TickCount
            Loop {
                Sleep(50)
                if (req.http.readyState >= 4)
                    break
                if (A_TickCount - start > this.TimeoutMs) {
                    try req.http.Abort()
                    return []
                }
            }

            resp := VersionChecker._GetResponseInfo(req.http)
            if (resp.statusCode != 200)
                return []

            return VersionUtils.ParseReleasesArray(resp.body)
        } catch {
            return []
        }
    }


    ; 内部：从缓存加载
    ; 返回: {version, url} 或 false（缓存无效或过期）
    static _LoadFromCache() {
        if (!FileExist(this.CacheFile))
            return false

        try {
            content := FileRead(this.CacheFile)

            ; 解析缓存JSON
            version := VersionUtils.ExtractJsonValue(content, "latestVersion")
            url := VersionUtils.ExtractJsonValue(content, "downloadUrl")

            if (version = "" || url = "")
                return false

            return {version: version, url: url}

        } catch {
            return false
        }
    }

    ; 内部：保存到缓存
    static _SaveToCache(version, url) {
        try {
            ; 确保目录存在
            SplitPath(this.CacheFile, , &cacheDir)
            if (!DirExist(cacheDir))
                DirCreate(cacheDir)

            ; 使用Chr(34)构建JSON字符串，避免转义问题
            q := Chr(34)  ; 双引号
            json := "{" q "latestVersion" q ":" q version q "," q "downloadUrl" q ":" q url q "}"

            if (FileExist(this.CacheFile))
                FileDelete(this.CacheFile)
            FileAppend(json, this.CacheFile, "UTF-8")
        } catch Error as err {
            ; 缓存失败不影响主流程，但记录警告
            Logger.Warn("VersionChecker", "保存缓存失败：" err.Message)
        }
    }

    ; 获取并缓存全部 changelog 数据（不进行版本比较）
    ; 用于首次启动 / 从旧版本升级时生成 changelog.json
    static FetchChangelogCache() {
        useGitHubToken := Config.GetImportant("UseGitHubToken")
        gitHubToken := ""
        if (useGitHubToken == 1)
            gitHubToken := Config.GetImportant("GitHubToken")

        VersionChecker._Log("========== 获取 Changelog 缓存 ==========")
        releases := this._FetchAllReleases(gitHubToken)
        if (releases.Length > 0) {
            this._SaveChangelogCache(releases)
            VersionChecker._Log("Changelog 缓存已保存，共 " releases.Length " 个版本")
            return true
        }
        VersionChecker._Log("获取 Changelog 缓存失败（无网络或API不可用）")
        return false
    }

    ; 内部：保存 changelog 缓存到 changelog.json
    static _SaveChangelogCache(releases) {
        try {
            configDir := A_AppData "\ArknightsFrameAssistant\PC"
            changelogFile := configDir "\changelog.json"
            if (!DirExist(configDir))
                DirCreate(configDir)

            json := '{"versions":['
            firstAdded := false
            for release in releases {
                if (release.body = "")
                    continue
                if (firstAdded)
                    json .= ","
                escapedBody := VersionUtils.EscapeJsonString(release.body)
                json .= '{"tag_name":"' release.tag_name '","body":"' escapedBody '","date":"' release.date '"}'
                firstAdded := true
            }
            json .= ']}'

            if (FileExist(changelogFile))
                FileDelete(changelogFile)
            FileAppend(json, changelogFile, "UTF-8")
        } catch Error as err {
            Logger.Warn("VersionChecker", "保存 changelog 缓存失败：" err.Message)
        }
    }

    ; 内部：构建更新提示用的 changelog 文本（筛选高于 localVersion 的版本，降序排列）
    static _BuildChangelogBody(localVersion, releases) {
        newerReleases := []
        for release in releases {
            if (release.body = "")
                continue
            if (VersionUtils.CompareVersions(localVersion, release.tag_name) < 0) {
                newerReleases.Push(release)
            }
        }

        if (newerReleases.Length = 0)
            return ""

        ; 降序排列（最高版本在前）
        Loop newerReleases.Length - 1 {
            Loop newerReleases.Length - A_Index {
                if (VersionUtils.CompareVersions(newerReleases[A_Index].tag_name, newerReleases[A_Index + 1].tag_name) < 0) {
                    temp := newerReleases[A_Index]
                    newerReleases[A_Index] := newerReleases[A_Index + 1]
                    newerReleases[A_Index + 1] := temp
                }
            }
        }

        body := ""
        for i, release in newerReleases {
            dateHeaderPattern := "m)^## (\d{4}-\d{2}-\d{2})"
            cleanBody := RegExReplace(release.body, dateHeaderPattern, "## " release.tag_name " ($1)")
            if (i > 1)
                body .= "`r`n`r`n---`r`n`r`n"
            body .= cleanBody
        }
        return body
    }






}
