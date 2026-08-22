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
    ; 是否启用调试日志（根据版本号判断，alpha版本启用）
    static DebugMode := false

    ; 初始化
    static Init() {
        configDir := A_AppData "\ArknightsFrameAssistant\PC"
        ReleaseRepository.CacheFile := configDir "\version_cache.json"

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
    static _ParseNetworkError(errorCode) {
        ; WinHttp错误码解析（每次调用按当前语言构建，避免函数静态缓存过期文案）
        ErrorMessages := Map(
            0x80070057, I18n.T("参数错误：请求参数无效"),
            0x80072EE7, I18n.T("DNS解析失败：无法解析服务器域名"),
            0x80072EFD, I18n.T("连接失败：无法连接到服务器"),
            0x80072EE2, I18n.T("连接超时：服务器响应超时"),
            0x80072F06, I18n.T("SSL证书错误：无法验证服务器身份"),
            0x80072F0D, I18n.T("SSL证书无效：服务器证书不受信任"),
            0x80072F76, I18n.T("SSL握手失败：无法建立安全连接"),
            0x80004005, I18n.T("未知错误：请求失败")
        )

        hexCode := Format("0x{:08X}", errorCode)

        ; 尝试匹配已知错误
        if (ErrorMessages.Has(errorCode)) {
            return {code: hexCode, desc: ErrorMessages[errorCode]}
        }

        ; 检查是否为超时错误（0x80072EE2 是常见的超时错误）
        if ((errorCode & 0xFFFF) = 0x2EE2) {
            return {code: hexCode, desc: I18n.T("请求超时：服务器未在规定时间内响应")}
        }

        ; 通用网络错误
        if ((errorCode & 0xFFFF0000) = 0x80070000) {
            return {code: hexCode, desc: I18n.T("网络错误：请求过程中发生错误")}
        }

        return {code: hexCode, desc: I18n.T("网络错误：未知错误类型")}
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
        desc := I18n.T("网络错误：")
        if (InStr(errMsg, "timeout") || InStr(errMsg, "超时")) {
            desc .= I18n.T("请求超时")
        } else if (InStr(errMsg, "DNS") || InStr(errMsg, "resolve")) {
            desc .= I18n.T("DNS解析失败")
        } else if (InStr(errMsg, "SSL") || InStr(errMsg, "certificate")) {
            desc .= I18n.T("SSL证书错误")
        } else if (InStr(errMsg, "connect") || InStr(errMsg, "连接")) {
            desc .= I18n.T("连接失败")
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
                    if (!GitHubTokenService.TokenValidated) {
                        tokenResult := GitHubTokenService.Validate(gitHubToken)
                        if (!tokenResult.valid) {
                            this._Log("Token验证失败，阻止更新检查")
                            return {status: "token_invalid", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: tokenResult.message "`n`n" I18n.T("请检查GitHub Token设置。")}
                        }
                    }
                }
            }
        }

        return this._TryCheckWithFallback(localVersion)
    }

    ; 内部：对单个源执行带重试的检查
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
        lastResult.message .= "`n" I18n.T("（已重试 {1} 次）", maxRetries)
        return lastResult
    }

    ; 内部：尝试用首选源检查更新，每源重试 3 次，均失败后降级到备选源
    static _TryCheckWithFallback(localVersion) {
        updateSource := Config.GetImportant("UpdateSource")
        isGitHubPreferred := (updateSource == "2")
        preferredName := isGitHubPreferred ? "GitHub" : "国内源"
        fallbackName := isGitHubPreferred ? "国内源" : "GitHub"
        preferredFn := isGitHubPreferred ? ReleaseRepository.CheckGithub.Bind(ReleaseRepository) : ReleaseRepository.CheckDomestic.Bind(ReleaseRepository)
        fallbackFn := isGitHubPreferred ? ReleaseRepository.CheckDomestic.Bind(ReleaseRepository) : ReleaseRepository.CheckGithub.Bind(ReleaseRepository)

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
            fallbackResult.message := I18n.T("两个更新源均不可用，请检查网络连接")
        }

        return fallbackResult
    }
}
