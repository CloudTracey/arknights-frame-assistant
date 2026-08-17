; == 系统代理读取工具 ==
; 从注册表读取 IE/WinINET 系统代理设置（Clash Verge / v2rayN 等代理软件均通过此配置），
; 返回 ServerXMLHTTP.SetProxy(2, ...) 兼容的代理字符串。
GetSystemProxyServer() {
    try {
        proxyEnable := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings", "ProxyEnable")
        if (proxyEnable != 1)
            return ""
        proxyServer := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings", "ProxyServer")
        if (proxyServer = "")
            return ""
        ; 含协议前缀时（如 "http=...;https=..."），将分号转空格以符合 ServerXMLHTTP 格式
        if (InStr(proxyServer, "="))
            proxyServer := StrReplace(proxyServer, ";", " ")
        return proxyServer
    } catch {
        return ""
    }
}

; 为 HTTP 请求对象应用系统代理：系统代理已启用 → SetProxy(2, ...)；未启用 → SetProxy(0) 回退到 WinHTTP 默认
ApplySystemProxy(http) {
    proxyServer := GetSystemProxyServer()
    if (proxyServer != "") {
        bypassList := ""
        try {
            bypassList := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Internet Settings", "ProxyOverride")
            if (bypassList != "")
                bypassList := StrReplace(bypassList, ";", " ")
        }
        http.SetProxy(2, proxyServer, bypassList)
    } else {
        http.SetProxy(0)
    }
}

; == 版本检查器 ==

class VersionChecker {
    ; GitHub API地址（完整列表，含预发布）
    static ApiUrl := "https://api.github.com/repos/CloudTracey/arknights-frame-assistant/releases"

    ; GitHub API地址（仅正式版）
    static StableApiUrl := "https://api.github.com/repos/CloudTracey/arknights-frame-assistant/releases/latest"

    ; 国内源 CDN 基地址（正式版和测试版分别拼接 /stable/version.json 和 /beta/version.json）
    static CdnBaseUrl := "https://release.arknightsframeassistant.com"

    ; Token验证API地址
    static TokenValidateUrl := "https://api.github.com/user"

    ; 缓存文件路径
    static CacheFile := ""

    ; 超时设置（毫秒）
    static TimeoutMs := 5000

    ; 是否启用调试日志（根据版本号判断，alpha版本启用）
    static DebugMode := false

    ; Token验证状态缓存
    static TokenValidated := false

    ; 初始化
    static Init() {
        configDir := A_AppData "\ArknightsFrameAssistant\PC"
        this.CacheFile := configDir "\version_cache.json"

        ; alpha版本启用调试模式
        this.DebugMode := InStr(Version.Get(), "alpha") > 0
    }

    ; 调试日志解锁：alpha 构建恒开，正式版随用户「调试模式」开关
    ; 直接读 SettingsService 已同步的运行时开关，避免每次 INI 重读、并与 Logger.DebugEnabled 保持一致（无双源）
    static IsDebugLogging() {
        if (this.DebugMode)
            return true
        return Logger.DebugEnabled
    }

    ; 内部：输出调试日志
    static _Log(message) {
        if (this.IsDebugLogging()) {
            Logger.Debug("VersionChecker", message)
        }
    }

    ; 内部：输出请求报文日志
    static _LogRequest(type, url, method, headers) {
        if (!this.IsDebugLogging())
            return

        this._Log("========== " type " ==========")
        this._Log("Timestamp: " this._Timestamp())
        this._Log("Method: " method)
        this._Log("URL: " url)
        this._Log("Headers:")
        for key, value in headers {
            ; 隐藏敏感信息
            if (key = "Authorization") {
                ; 显示token前缀和长度，不显示完整token
                tokenLen := StrLen(value) - 6  ; 减去 "token " 前缀长度
                if (tokenLen > 0) {
                    this._Log("  " key ": token ***" tokenLen "chars")
                } else {
                    this._Log("  " key ": " value)
                }
            } else {
                this._Log("  " key ": " value)
            }
        }
    }

    ; 内部：输出响应报文日志
    static _LogResponse(type, statusCode, statusText, headers, body) {
        if (!this.IsDebugLogging())
            return

        this._Log("========== " type " ==========")
        this._Log("Timestamp: " this._Timestamp())
        this._Log("Status: " statusCode " " statusText)
        this._Log("Response headers omitted from persistent diagnostics")
        this._Log("Response body length=" StrLen(body))
    }

    ; 内部：格式化时间戳
    static _Timestamp() {
        return FormatTime(, "yyyy-MM-dd HH:mm:ss.") A_MSec
    }

    ; 内部：构建HTTP请求对象
    ; 返回: {http, error} - error非空表示创建失败
    static _CreateHttpRequest(url, token := "", acceptHeader := "application/vnd.github.v3+json") {
        try {
            http := ComObject("MSXML2.ServerXMLHTTP.6.0")
            ApplySystemProxy(http)
            http.Open("GET", url, true)
            http.SetRequestHeader("Accept", acceptHeader)
            http.SetRequestHeader("User-Agent", "ArknightsFrameAssistant/" Version.Get())
            if (token != "")
                http.SetRequestHeader("Authorization", "token " token)
            return {http: http, error: ""}
        } catch as err {
            return {http: "", error: err.Message}
        }
    }

    ; 内部：获取HTTP响应信息
    static _GetResponseInfo(http) {
        info := {statusCode: 0, statusText: "", headers: "", body: ""}
        try
            info.statusCode := http.Status
        catch
            {}
        try
            info.statusText := http.StatusText
        catch
            {}
        try
            info.headers := http.GetAllResponseHeaders()
        catch
            {}
        try
            info.body := http.ResponseText
        catch
            {}
        return info
    }

    ; 内部：获取Rate Limit信息
    static _GetRateLimitInfo(http) {
        remaining := "", limit := ""
        try
            remaining := http.GetResponseHeader("X-RateLimit-Remaining")
        catch
            {}
        try
            limit := http.GetResponseHeader("X-RateLimit-Limit")
        catch
            {}
        return {remaining: remaining, limit: limit}
    }

    ; 验证GitHub Token有效性
    ; 返回: {valid, message, username, rateLimit}
    static ValidateToken(token := "") {
        if (token = "")
            token := Config.GetImportant("GitHubToken")

        this._Log("========== 验证Token ==========")
        this._Log("Token长度: " StrLen(token))

        ; 构建请求头Map（用于日志）
        headersMap := Map(
            "Accept", "application/vnd.github.v3+json",
            "User-Agent", "ArknightsFrameAssistant/" Version.Get()
        )
        if (token != "")
            headersMap["Authorization"] := "token ***" StrLen(token) "chars"

        this._LogRequest("TOKEN_VALIDATION_REQUEST", this.TokenValidateUrl, "GET", headersMap)

        try {
            req := this._CreateHttpRequest(this.TokenValidateUrl, token)
            if (req.error != "") {
                this._Log("创建HTTP请求失败: " req.error)
                return {valid: false, message: "网络错误: " req.error, username: "", rateLimit: ""}
            }

            req.http.Send()
            tokenStart := A_TickCount
            Loop {
                Sleep(50)
                if (req.http.readyState >= 4)
                    break
                if (A_TickCount - tokenStart > this.TimeoutMs) {
                    try req.http.Abort()
                    this._Log("Token验证超时")
                    return {valid: false, message: "请求超时，请检查网络连接", username: "", rateLimit: ""}
                }
            }
            resp := this._GetResponseInfo(req.http)
            rateInfo := this._GetRateLimitInfo(req.http)

            this._LogResponse("TOKEN_VALIDATION_RESPONSE", resp.statusCode, resp.statusText, resp.headers, resp.body)

            ; 解析结果
            if (resp.statusCode = 200) {
                username := VersionUtils.ExtractJsonValue(resp.body, "login")
                this.TokenValidated := true
                this._Log("Token验证成功")
                return {valid: true, message: "Token有效", username: username, rateLimit: rateInfo.remaining "/" rateInfo.limit}
            } else if (resp.statusCode = 401) {
                this.TokenValidated := false
                this._Log("Token无效（401未授权）")
                return {valid: false, message: "Token无效，请检查是否正确", username: "", rateLimit: ""}
            } else if (resp.statusCode = 403) {
                this.TokenValidated := false
                this._Log("Token可能已超限（403禁止访问）")
                return {valid: false, message: "API请求频率已超限", username: "", rateLimit: "0/" rateInfo.limit}
            } else {
                this.TokenValidated := false
                this._Log("Token验证失败，状态码: " resp.statusCode)
                return {valid: false, message: "验证失败，HTTP " resp.statusCode, username: "", rateLimit: ""}
            }
        } catch as err {
            this.TokenValidated := false
            errorInfo := this._ParseErrorInfo(err)
            this._Log("Token验证异常: " errorInfo.desc)
            return {valid: false, message: "网络错误: " errorInfo.desc, username: "", rateLimit: ""}
        }
    }

    ; 内部：解析网络错误码
    static _ParseNetworkError(errorCode) {
        ; WinHttp错误码解析
        static ErrorMessages := Map(
            0x80070057, "参数错误：请求参数无效",
            0x80072EE7, "DNS解析失败：无法解析服务器域名",
            0x80072EFD, "连接失败：无法连接到服务器",
            0x80072EE2, "连接超时：服务器响应超时",
            0x80072F06, "SSL证书错误：无法验证服务器身份",
            0x80072F0D, "SSL证书无效：服务器证书不受信任",
            0x80072F76, "SSL握手失败：无法建立安全连接",
            0x80004005, "未知错误：请求失败"
        )

        hexCode := Format("0x{:08X}", errorCode)

        ; 尝试匹配已知错误
        if (ErrorMessages.Has(errorCode)) {
            return {code: hexCode, desc: ErrorMessages[errorCode]}
        }

        ; 检查是否为超时错误（0x80072EE2 是常见的超时错误）
        if ((errorCode & 0xFFFF) = 0x2EE2) {
            return {code: hexCode, desc: "请求超时：服务器未在规定时间内响应"}
        }

        ; 通用网络错误
        if ((errorCode & 0xFFFF0000) = 0x80070000) {
            return {code: hexCode, desc: "网络错误：请求过程中发生错误"}
        }

        return {code: hexCode, desc: "网络错误：未知错误类型"}
    }

    ; 内部：解析错误对象信息（AHK v2 兼容）
    static _ParseErrorInfo(err) {
        ; 尝试从错误消息中解析HRESULT错误码
        errMsg := err.Message
        errorCode := 0

        ; 尝试匹配 0x开头的十六进制错误码
        if (RegExMatch(errMsg, "i)0x[0-9A-Fa-f]{8}", &match)) {
            try {
                errorCode := Integer(match[0])
            } catch {
                errorCode := 0
            }
        }

        ; 如果没有从消息中解析到错误码，尝试使用 A_LastError
        if (errorCode = 0 && A_LastError != 0) {
            ; A_LastError 是 Win32 错误码，需要转换为 HRESULT
            errorCode := 0x80070000 | A_LastError
        }

        ; 如果解析到了错误码，使用网络错误解析
        if (errorCode != 0) {
            return this._ParseNetworkError(errorCode)
        }

        ; 无法获取具体错误码，根据消息内容判断
        desc := "网络错误："
        if (InStr(errMsg, "timeout") || InStr(errMsg, "超时")) {
            desc .= "请求超时"
        } else if (InStr(errMsg, "DNS") || InStr(errMsg, "resolve")) {
            desc .= "DNS解析失败"
        } else if (InStr(errMsg, "SSL") || InStr(errMsg, "certificate")) {
            desc .= "SSL证书错误"
        } else if (InStr(errMsg, "connect") || InStr(errMsg, "连接")) {
            desc .= "连接失败"
        } else {
            desc .= errMsg
        }

        return {code: "N/A", desc: desc}
    }



    ; 检查更新（主入口）
    ; 返回: {status, localVersion, remoteVersion, downloadUrl, message}
    static Check() {
        localVersion := Version.Get()

        ; Token 验证（仅 GitHub 源需要，国内源不依赖 Token）
        updateSource := Config.GetImportant("UpdateSource")
        if (updateSource == "2") {
            useGitHubToken := Config.GetImportant("UseGitHubToken")
            if (useGitHubToken == 1) {
                gitHubToken := Config.GetImportant("GitHubToken")
                if (gitHubToken != "") {
                    if (!this.TokenValidated) {
                        tokenResult := this.ValidateToken(gitHubToken)
                        if (!tokenResult.valid) {
                            this._Log("Token验证失败，阻止更新检查")
                            return {status: "token_invalid", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: tokenResult.message "。请检查GitHub Token设置。"}
                        }
                    }
                }
            }
        }

        return this._TryCheckWithFallback(localVersion)
    }

    ; 内部：从 GitHub API 获取最新版本
    ; 返回格式: {status, localVersion, remoteVersion, downloadUrl, message, changelogBody?}
    static _CheckFromGithub(localVersion) {
        useGitHubToken := Config.GetImportant("UseGitHubToken")
        updateChannel := Config.GetImportant("UpdateChannel")
        isStable := (updateChannel == "1")

        ; 选择API URL
        if (isStable) {
            apiUrl := this.StableApiUrl
            this._Log("更新渠道: 正式版")
        } else {
            apiUrl := this.ApiUrl
            this._Log("更新渠道: 测试版")
        }

        this._Log("========== 开始版本检查 ==========")
        this._Log("Timestamp: " this._Timestamp())
        this._Log("本地版本: [" localVersion "] 长度: " StrLen(localVersion))
        this._Log("API URL: " apiUrl)
        this._Log("超时设置: " this.TimeoutMs "ms")
        gitHubToken := ""

        ; 检查本地版本是否有效
        if (localVersion = "") {
            this._Log("错误: 本地版本为空!")
            return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "无法获取本地版本号"}
        }

        ; 是否使用GitHub Token进行更新检查
        if (useGitHubToken == 1) {
            ; 获取Token
            gitHubToken := Config.GetImportant("GitHubToken")
            this._Log("GitHub Token长度: " StrLen(gitHubToken))
        }

        ; 构建请求头Map（用于日志）
        headersMap := Map(
            "Accept", "application/vnd.github.v3+json",
            "User-Agent", "ArknightsFrameAssistant/" localVersion
        )
        if (gitHubToken != "")
            headersMap["Authorization"] := "token " gitHubToken

        this._LogRequest("VERSION_CHECK_REQUEST", apiUrl, "GET", headersMap)

        try {
            req := this._CreateHttpRequest(apiUrl, gitHubToken)
            if (req.error != "") {
                this._Log("创建HTTP请求失败: " req.error)
                return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "网络错误: " req.error}
            }

            this._Log("发送请求...")
            req.http.Send()
            checkStart := A_TickCount
            Loop {
                Sleep(50)
                if (req.http.readyState >= 4)
                    break
                if (A_TickCount - checkStart > this.TimeoutMs) {
                    try req.http.Abort()
                    this._Log("版本检查超时")
                    return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "请求超时，请检查网络连接"}
                }
            }
            this._Log("请求已发送，等待响应...")

            resp := this._GetResponseInfo(req.http)
            this._LogResponse("VERSION_CHECK_RESPONSE", resp.statusCode, resp.statusText, resp.headers, resp.body)

            ; 检查HTTP状态
            if (resp.statusCode = 401) {
                this._Log("Token无效（401未授权）")
                return {status: "token_invalid", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "GitHub Token无效，请检查设置"}
            }
            if (resp.statusCode = 403) {
                this._Log("检测到API频率限制")
                return {status: "rate_limited", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "API请求频率超限。请在设置中配置GitHub Token以提高配额", suggestToken: true}
            }
            if (resp.statusCode != 200) {
                this._Log("服务器返回非200状态码: " resp.statusCode)
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
                this._Log("解析结果（正式版） - 远程版本: " remoteVersion)
                this._Log("解析结果（正式版） - 下载地址: " downloadUrl)

                if (remoteVersion = "" || downloadUrl = "") {
                    this._Log("无法解析版本信息")
                    return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "无法解析版本信息"}
                }

                ; 保存到缓存
                this._SaveToCache(remoteVersion, downloadUrl)

                ; 比较版本
                compareResult := VersionUtils.CompareVersions(localVersion, remoteVersion)
                this._Log("版本比较结果: " compareResult " (-1=需更新, 0=相同, 1=本地更新)")

                if (compareResult < 0) {
                    this._Log("发现新版本: " remoteVersion)
                    Logger.Info("VersionChecker", "发现新版本：" remoteVersion)
                    return {status: "update_available", localVersion: localVersion, remoteVersion: remoteVersion, downloadUrl: downloadUrl, expectedHash: expectedHash, changelogBody: changelogBody}
                } else {
                    this._Log("已是最新版本")
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
                this._Log("解析到 " releases.Length " 个发布版本")

                if (releases.Length = 0) {
                    this._Log("无法解析版本信息")
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
                this._Log("解析结果（测试版） - 最高远程版本: " remoteVersion)
                this._Log("解析结果（测试版） - 下载地址: " downloadUrl)

                if (remoteVersion = "" || downloadUrl = "") {
                    this._Log("无法解析版本信息")
                    return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "无法解析版本信息"}
                }

                ; 保存到缓存
                this._SaveToCache(remoteVersion, downloadUrl)

                ; 比较版本
                compareResult := VersionUtils.CompareVersions(localVersion, remoteVersion)
                this._Log("版本比较结果: " compareResult " (-1=需更新, 0=相同, 1=本地更新)")

                if (compareResult < 0) {
                    this._Log("发现新版本: " remoteVersion)
                    Logger.Info("VersionChecker", "发现新版本：" remoteVersion)
                    return {status: "update_available", localVersion: localVersion, remoteVersion: remoteVersion, downloadUrl: downloadUrl, expectedHash: expectedHash, changelogBody: changelogBody}
                } else {
                    this._Log("已是最新版本")
                    Logger.Info("VersionChecker", "已是最新版本")
                    return {status: "up_to_date", localVersion: localVersion, remoteVersion: remoteVersion, downloadUrl: ""}
                }
            }
        } catch as err {
            errorInfo := this._ParseErrorInfo(err)
            this._Log("========== VERSION_CHECK_ERROR ==========")
            this._Log("Timestamp: " this._Timestamp())
            this._Log("ErrorCode: " errorInfo.code)
            this._Log("ErrorDesc: " errorInfo.desc)
            this._Log("ErrorMessage: " err.Message)

            userMessage := errorInfo.desc
            if (InStr(errorInfo.desc, "超时"))
                userMessage := "网络请求超时，请检查网络连接后重试。`n`n如果问题持续存在，请尝试配置GitHub Token。"

            return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: userMessage, errorDetail: "[" errorInfo.code "] " err.Message}
        }
    }

    ; 内部：从国内源（COS+CDN）检查更新
    ; 返回格式与 _CheckFromGithub 一致
    ; 正式版：仅查 /stable；测试版：查 /beta + /stable 取最高版本（与 GitHub 行为对齐）
    static _CheckFromDomestic(localVersion) {
        updateChannel := Config.GetImportant("UpdateChannel")
        isStable := (updateChannel == "1")

        this._Log("========== 国内源版本检查 ==========")
        this._Log("更新渠道: " (isStable ? "正式版" : "测试版"))
        this._Log("本地版本: " localVersion)

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
            this._Log("测试版渠道: beta=" betaResult.remoteVersion " >= stable=" stableResult.remoteVersion "，使用 beta")
            return betaResult
        } else {
            this._Log("测试版渠道: stable=" stableResult.remoteVersion " > beta=" betaResult.remoteVersion "，使用 stable")
            return stableResult
        }
    }

    ; 内部：从国内源指定渠道拉取 version.json 并解析
    static _CheckDomesticChannel(localVersion, channelPath) {
        jsonUrl := this.CdnBaseUrl channelPath "/version.json"

        this._Log("URL: " jsonUrl)

        headersMap := Map(
            "Accept", "application/json",
            "User-Agent", "ArknightsFrameAssistant/" localVersion
        )
        this._LogRequest("DOMESTIC_CHECK_REQUEST", jsonUrl, "GET", headersMap)

        try {
            req := this._CreateHttpRequest(jsonUrl, "", "application/json")
            if (req.error != "") {
                this._Log("国内源HTTP请求创建失败: " req.error)
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
                    this._Log("国内源版本检查超时")
                    return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "请求超时，请检查网络连接"}
                }
            }

            resp := this._GetResponseInfo(req.http)
            this._LogResponse("DOMESTIC_CHECK_RESPONSE", resp.statusCode, resp.statusText, resp.headers, resp.body)

            if (resp.statusCode != 200) {
                this._Log("国内源返回非200状态码: " resp.statusCode)
                return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "国内源返回错误: " resp.statusCode}
            }

            ; 解析 version.json
            remoteVersion := VersionUtils.ExtractJsonValue(resp.body, "version")
            downloadUrl := VersionUtils.ExtractJsonValue(resp.body, "downloadUrl")
            expectedHash := VersionUtils.ExtractJsonValue(resp.body, "sha256")

            this._Log("解析结果 - 远程版本: " remoteVersion)
            this._Log("解析结果 - 下载地址: " downloadUrl)

            if (remoteVersion = "" || downloadUrl = "") {
                this._Log("无法解析国内源 version.json")
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
            this._Log("版本比较结果: " compareResult)

            if (compareResult < 0) {
                this._Log("国内源发现新版本: " remoteVersion)
                Logger.Info("VersionChecker", "国内源发现新版本：" remoteVersion)
                return {status: "update_available", localVersion: localVersion, remoteVersion: remoteVersion, downloadUrl: downloadUrl, expectedHash: expectedHash, changelogBody: changelogBody}
            } else {
                this._Log("已是最新版本（国内源）")
                Logger.Info("VersionChecker", "已是最新版本（国内源）")
                return {status: "up_to_date", localVersion: localVersion, remoteVersion: remoteVersion, downloadUrl: ""}
            }
        } catch as err {
            errorInfo := this._ParseErrorInfo(err)
            this._Log("国内源检查异常: " errorInfo.desc)
            return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "国内源检查失败: " errorInfo.desc}
        }
    }

    ; 内部：用单个源检查更新（带重试，最多 3 次）
    ; checkFn: 一个 Func 对象，签名为 (localVersion) → result
    static _CheckSingleSource(checkFn, sourceName, localVersion) {
        maxRetries := 3
        lastResult := ""
        Loop maxRetries {
            this._Log(sourceName " 第 " A_Index "/" maxRetries " 次尝试...")
            result := checkFn(localVersion)

            if (result.status != "check_failed") {
                return result
            }

            lastResult := result

            if (A_Index < maxRetries) {
                Sleep(1000)
            }
        }
        ; 保留最后一次的真实错误信息，追加重试次数说明
        lastResult.message .= "`n（已重试 " maxRetries " 次）"
        return lastResult
    }

    ; 内部：尝试用首选源检查更新，每源重试 3 次，均失败后降级到备选源
    static _TryCheckWithFallback(localVersion) {
        updateSource := Config.GetImportant("UpdateSource")
        isGitHubPreferred := (updateSource == "2")
        preferredName := isGitHubPreferred ? "GitHub" : "国内源"
        fallbackName := isGitHubPreferred ? "国内源" : "GitHub"
        preferredFn := isGitHubPreferred ? ObjBindMethod(this, "_CheckFromGithub") : ObjBindMethod(this, "_CheckFromDomestic")
        fallbackFn := isGitHubPreferred ? ObjBindMethod(this, "_CheckFromDomestic") : ObjBindMethod(this, "_CheckFromGithub")

        this._Log("首选源: " preferredName)

        ; 首选源（最多 3 次重试）
        result := this._CheckSingleSource(preferredFn, preferredName, localVersion)

        ; 成功或非网络类错误不降级
        if (result.status != "check_failed") {
            return result
        }

        this._Log(preferredName " 3 次均失败，降级到 " fallbackName)
        Logger.Info("VersionChecker", preferredName " 3 次均失败，降级到 " fallbackName)

        ; 备选源（最多 3 次重试）
        fallbackResult := this._CheckSingleSource(fallbackFn, fallbackName, localVersion)

        if (fallbackResult.status = "check_failed") {
            fallbackResult.message := "两个更新源均不可用，请检查网络连接"
        }

        return fallbackResult
    }

    ; 内部：获取全部 releases（正式版渠道额外请求，用于构建 changelog 缓存）
    static _FetchAllReleases(token := "") {
        try {
            req := this._CreateHttpRequest(this.ApiUrl, token)
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

            resp := this._GetResponseInfo(req.http)
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

        this._Log("========== 获取 Changelog 缓存 ==========")
        releases := this._FetchAllReleases(gitHubToken)
        if (releases.Length > 0) {
            this._SaveChangelogCache(releases)
            this._Log("Changelog 缓存已保存，共 " releases.Length " 个版本")
            return true
        }
        this._Log("获取 Changelog 缓存失败（无网络或API不可用）")
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

