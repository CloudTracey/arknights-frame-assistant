; == GitHub Token 验证服务 ==
; 从 VersionChecker.ValidateToken 迁出，供 SettingsService/VersionChecker 复用。

class GitHubTokenService {
    ; Token验证API地址
    static TokenValidateUrl := "https://api.github.com/user"

    ; 超时设置（毫秒）
    static TimeoutMs := 5000

    ; Token验证状态缓存
    static TokenValidated := false

    static Validate(token := "") {
        if (token = "")
            token := Config.GetImportant("GitHubToken")

        VersionChecker._Log("========== 验证Token ==========")
        VersionChecker._Log("Token长度: " StrLen(token))

        ; 构建请求头Map（用于日志）
        headersMap := Map(
            "Accept", "application/vnd.github.v3+json",
            "User-Agent", "ArknightsFrameAssistant/" Version.Get()
        )
        if (token != "")
            headersMap["Authorization"] := "token ***" StrLen(token) "chars"

        VersionChecker._LogRequest("TOKEN_VALIDATION_REQUEST", this.TokenValidateUrl, "GET", headersMap)

        try {
            req := VersionChecker._CreateHttpRequest(this.TokenValidateUrl, token)
            if (req.error != "") {
                VersionChecker._Log("创建HTTP请求失败: " req.error)
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
                    VersionChecker._Log("Token验证超时")
                    return {valid: false, message: "请求超时，请检查网络连接", username: "", rateLimit: ""}
                }
            }
            resp := VersionChecker._GetResponseInfo(req.http)
            rateInfo := VersionChecker._GetRateLimitInfo(req.http)

            VersionChecker._LogResponse("TOKEN_VALIDATION_RESPONSE", resp.statusCode, resp.statusText, resp.headers, resp.body)

            ; 解析结果
            if (resp.statusCode = 200) {
                username := VersionUtils.ExtractJsonValue(resp.body, "login")
                this.TokenValidated := true
                VersionChecker._Log("Token验证成功")
                return {valid: true, message: "Token有效", username: username, rateLimit: rateInfo.remaining "/" rateInfo.limit}
            } else if (resp.statusCode = 401) {
                this.TokenValidated := false
                VersionChecker._Log("Token无效（401未授权）")
                return {valid: false, message: "Token无效，请检查是否正确", username: "", rateLimit: ""}
            } else if (resp.statusCode = 403) {
                this.TokenValidated := false
                VersionChecker._Log("Token可能已超限（403禁止访问）")
                return {valid: false, message: "API请求频率已超限", username: "", rateLimit: "0/" rateInfo.limit}
            } else {
                this.TokenValidated := false
                VersionChecker._Log("Token验证失败，状态码: " resp.statusCode)
                return {valid: false, message: "验证失败，HTTP " resp.statusCode, username: "", rateLimit: ""}
            }
        } catch as err {
            this.TokenValidated := false
            errorInfo := VersionChecker._ParseErrorInfo(err)
            VersionChecker._Log("Token验证异常: " errorInfo.desc)
            return {valid: false, message: "网络错误: " errorInfo.desc, username: "", rateLimit: ""}
        }
    }
}
