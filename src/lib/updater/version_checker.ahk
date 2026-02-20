; == 版本检查器 ==

class VersionChecker {
    ; GitHub API地址
    static ApiUrl := "https://api.github.com/repos/CloudTracey/arknights-frame-assistant/releases"
    
    ; Token验证API地址
    static TokenValidateUrl := "https://api.github.com/user"
    
    ; 缓存文件路径
    static CacheFile := ""
    
    ; 超时设置（毫秒）
    static TimeoutMs := 10000
    
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
    
    ; 内部：输出调试日志
    static _Log(message) {
        if (this.DebugMode) {
            OutputDebug("[VersionChecker] " message)
        }
    }
    
    ; 内部：输出请求报文日志
    static _LogRequest(type, url, method, headers) {
        if (!this.DebugMode)
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
        if (!this.DebugMode)
            return
            
        this._Log("========== " type " ==========")
        this._Log("Timestamp: " this._Timestamp())
        this._Log("Status: " statusCode " " statusText)
        this._Log("Headers:")
        if (headers != "") {
            Loop Parse headers, "`n" {
                this._Log("  " A_LoopField)
            }
        }
        this._Log("Body (first 500 chars):")
        this._Log(SubStr(body, 1, 500))
    }
    
    ; 内部：格式化时间戳
    static _Timestamp() {
        return FormatTime(, "yyyy-MM-dd HH:mm:ss.") A_MSec
    }
    
    ; 内部：构建HTTP请求对象
    ; 返回: {http, error} - error非空表示创建失败
    static _CreateHttpRequest(url, token := "") {
        try {
            http := ComObject("WinHttp.WinHttpRequest.5.1")
            http.SetTimeouts(this.TimeoutMs, this.TimeoutMs, this.TimeoutMs, this.TimeoutMs)
            http.Open("GET", url, false)
            http.SetRequestHeader("Accept", "application/vnd.github.v3+json")
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
            resp := this._GetResponseInfo(req.http)
            rateInfo := this._GetRateLimitInfo(req.http)
            
            this._LogResponse("TOKEN_VALIDATION_RESPONSE", resp.statusCode, resp.statusText, resp.headers, resp.body)
            
            ; 解析结果
            if (resp.statusCode = 200) {
                username := this._ExtractJsonValue(resp.body, "login")
                this.TokenValidated := true
                this._Log("Token验证成功，用户: " username)
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
        
        ; 检查是否配置了Token
        gitHubToken := Config.GetImportant("GitHubToken")
        if (gitHubToken != "") {
            ; 如果配置了Token，先验证Token有效性
            if (!this.TokenValidated) {
                tokenResult := this.ValidateToken(gitHubToken)
                if (!tokenResult.valid) {
                    this._Log("Token验证失败，阻止更新检查")
                    return {status: "token_invalid", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: tokenResult.message "。请检查GitHub Token设置。"}
                }
            }
        }
        
        ; 直接从API获取最新版本
        return this._FetchFromApi(localVersion)
    }
    
    ; 内部：从API获取最新版本
    static _FetchFromApi(localVersion) {
        this._Log("========== 开始版本检查 ==========")
        this._Log("Timestamp: " this._Timestamp())
        this._Log("本地版本: [" localVersion "] 长度: " StrLen(localVersion))
        this._Log("API URL: " this.ApiUrl)
        this._Log("超时设置: " this.TimeoutMs "ms")
        
        ; 检查本地版本是否有效
        if (localVersion = "") {
            this._Log("错误: 本地版本为空!")
            return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "无法获取本地版本号"}
        }
        
        ; 获取Token
        gitHubToken := Config.GetImportant("GitHubToken")
        this._Log("GitHub Token长度: " StrLen(gitHubToken))
        
        ; 构建请求头Map（用于日志）
        headersMap := Map(
            "Accept", "application/vnd.github.v3+json",
            "User-Agent", "ArknightsFrameAssistant/" localVersion
        )
        if (gitHubToken != "")
            headersMap["Authorization"] := "token " gitHubToken
        
        this._LogRequest("VERSION_CHECK_REQUEST", this.ApiUrl, "GET", headersMap)
        
        try {
            req := this._CreateHttpRequest(this.ApiUrl, gitHubToken)
            if (req.error != "") {
                this._Log("创建HTTP请求失败: " req.error)
                return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "网络错误: " req.error}
            }
            
            this._Log("发送请求...")
            req.http.Send()
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
            
            ; 解析JSON响应
            remoteVersion := this._ExtractJsonValue(resp.body, "tag_name")
            downloadUrl := this._ExtractJsonValue(resp.body, "browser_download_url")
            this._Log("解析结果 - 远程版本: " remoteVersion)
            this._Log("解析结果 - 下载地址: " downloadUrl)
            
            if (remoteVersion = "" || downloadUrl = "") {
                this._Log("无法解析版本信息")
                return {status: "check_failed", localVersion: localVersion, remoteVersion: "", downloadUrl: "", message: "无法解析版本信息"}
            }
            
            ; 保存到缓存
            this._SaveToCache(remoteVersion, downloadUrl)
            
            ; 比较版本
            compareResult := this._CompareVersions(localVersion, remoteVersion)
            this._Log("版本比较结果: " compareResult " (-1=需更新, 0=相同, 1=本地更新)")
            
            if (compareResult < 0) {
                this._Log("发现新版本: " remoteVersion)
                return {status: "update_available", localVersion: localVersion, remoteVersion: remoteVersion, downloadUrl: downloadUrl}
            } else {
                this._Log("已是最新版本")
                return {status: "up_to_date", localVersion: localVersion, remoteVersion: remoteVersion, downloadUrl: ""}
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
    
    ; 内部：从缓存加载
    ; 返回: {version, url} 或 false（缓存无效或过期）
    static _LoadFromCache() {
        if (!FileExist(this.CacheFile))
            return false
        
        try {
            content := FileRead(this.CacheFile)
            
            ; 解析缓存JSON
            version := this._ExtractJsonValue(content, "latestVersion")
            url := this._ExtractJsonValue(content, "downloadUrl")
            
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
            ; 缓存失败不影响主流程，但输出调试信息
            OutputDebug("保存缓存失败: " err.Message)
        }
    }
    
    ; 内部：比较版本号（支持语义化版本规范 SemVer 2.0.0）
    ; 返回: -1(本地<远程), 0(相等), 1(本地>远程)
    static _CompareVersions(localVersion, remoteVersion) {
        localParsed := this._ParseVersion(localVersion)
        remoteParsed := this._ParseVersion(remoteVersion)
        
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
        return this._ComparePrerelease(localParsed.prerelease, remoteParsed.prerelease)
    }
    
    ; 内部：解析版本号 vX.Y.Z[-prerelease][+metadata]
    ; 返回: {numbers: [X, Y, Z], prerelease: [ident1, ident2, ...], metadata: ""}
    static _ParseVersion(versionStr) {
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
    
    ; 内部：比较预发布标识符
    ; 按照 SemVer 规范：数字标识符按数值比较，字母标识符按 ASCII 比较
    ; 数字标识符优先级低于字母标识符
    static _ComparePrerelease(localPre, remotePre) {
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
            localIsNum := this._IsNumeric(localIdent)
            remoteIsNum := this._IsNumeric(remoteIdent)

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
    
    ; 内部：检查字符串是否为纯数字
    static _IsNumeric(str) {
        if (str == "")
            return false

        Loop Parse str {
            charCode := Ord(A_LoopField)
            if (charCode < 48 || charCode > 57)  ; ASCII '0'=48, '9'=57
                return false
        }
        return true
    }
    
    ; 内部：从JSON字符串中提取字段值
    static _ExtractJsonValue(json, key) {
        ; 匹配 "key":"value" 格式
        ; 使用Chr构建正则表达式避免引号问题
        q := Chr(34)  ; 双引号
        notQ := Chr(94) Chr(34)  ; [^"]
        pattern := q key q ":\s*" q "([" notQ "]*)" q
        if (RegExMatch(json, pattern, &match)) {
            return match[1]
        }
        
        ; 尝试匹配数字
        pattern := q key q ":\s*(\d+)"
        if (RegExMatch(json, pattern, &match)) {
            return match[1]
        }
        
        return ""
    }
}

; 初始化
VersionChecker.Init()
