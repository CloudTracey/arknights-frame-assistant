; == 版本检查器 ==

class VersionChecker {
    ; GitHub API地址
    static ApiUrl := "https://api.github.com/repos/CloudTracey/arknights-frame-assistant/releases"
    
    ; 缓存文件路径
    static CacheFile := ""
    
    ; 初始化
    static Init() {
        configDir := A_AppData "\ArknightsFrameAssistant\PC"
        this.CacheFile := configDir "\version_cache.json"
    }
    
    ; 检查更新（主入口）
    ; 返回: {status, localVersion, remoteVersion, downloadUrl, message}
    static Check() {
        localVersion := Version.Get()
        
        ; 直接从API获取最新版本（每次都检查）
        return this._FetchFromApi(localVersion)
    }
    
    ; 内部：从API获取最新版本
    static _FetchFromApi(localVersion) {
        try {
            ; 创建WinHttpRequest对象
            http := ComObject("WinHttp.WinHttpRequest.5.1")
            http.Open("GET", this.ApiUrl, false)
            http.SetRequestHeader("Accept", "application/vnd.github.v3+json")
            http.SetRequestHeader("User-Agent", "ArknightsFrameAssistant/" localVersion)
            http.Send()
            
            ; 检查HTTP状态
            statusCode := http.Status
            if (statusCode = 403) {
                return {
                    status: "rate_limited",
                    localVersion: localVersion,
                    remoteVersion: "",
                    downloadUrl: "",
                    message: "API请求过于频繁，请稍后再试"
                }
            }
            if (statusCode != 200) {
                return {
                    status: "check_failed",
                    localVersion: localVersion,
                    remoteVersion: "",
                    downloadUrl: "",
                    message: "服务器返回错误: " statusCode
                }
            }
            
            ; 解析JSON响应
            response := http.ResponseText
            
            ; 手动解析JSON
            remoteVersion := this._ExtractJsonValue(response, "tag_name")
            downloadUrl := this._ExtractJsonValue(response, "browser_download_url")
            
            if (remoteVersion = "" || downloadUrl = "") {
                return {
                    status: "check_failed",
                    localVersion: localVersion,
                    remoteVersion: "",
                    downloadUrl: "",
                    message: "无法解析版本信息"
                }
            }
            
            ; 保存到缓存
            this._SaveToCache(remoteVersion, downloadUrl)
            
            ; 比较版本
            compareResult := this._CompareVersions(localVersion, remoteVersion)
            if (compareResult < 0) {
                return {
                    status: "update_available",
                    localVersion: localVersion,
                    remoteVersion: remoteVersion,
                    downloadUrl: downloadUrl
                }
            } else {
                return {
                    status: "up_to_date",
                    localVersion: localVersion,
                    remoteVersion: remoteVersion,
                    downloadUrl: ""
                }
            }
            
        } catch as err {
            return {
                status: "check_failed",
                localVersion: localVersion,
                remoteVersion: "",
                downloadUrl: "",
                message: "网络错误: " err.Message
            }
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
            
            json := '{"latestVersion":"' version '","downloadUrl":"' url '"}'
            
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
            ; 获取当前位置的标识符
            localIdent := A_Index <= localPre.Length ? localPre[A_Index] : ""
            remoteIdent := A_Index <= remotePre.Length ? remotePre[A_Index] : ""
            
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
                if (localIdent < remoteIdent)
                    return -1
                if (localIdent > remoteIdent)
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
            if (A_LoopField < "0" || A_LoopField > "9")
                return false
        }
        return true
    }
    
    ; 内部：从JSON字符串中提取字段值
    static _ExtractJsonValue(json, key) {
        ; 匹配 "key":"value" 或 "key":value 格式
        pattern := '"' key '":\s*"([^"]*)"'
        if (RegExMatch(json, pattern, &match)) {
            return match[1]
        }
        
        ; 尝试匹配数字
        pattern := '"' key '":\s*(\d+)'
        if (RegExMatch(json, pattern, &match)) {
            return match[1]
        }
        
        return ""
    }
}

; 初始化
VersionChecker.Init()
