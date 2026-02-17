; == 版本检查器 ==

class VersionChecker {
    ; GitHub API地址
    static ApiUrl := "https://api.github.com/repos/CloudTracey/arknights-frame-assistant/releases/latest"
    
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
    
    ; 内部：比较版本号
    ; 返回: -1(本地<远程), 0(相等), 1(本地>远程)
    static _CompareVersions(localVersion, remoteVersion) {
        localParts := this._ParseVersion(localVersion)
        remoteParts := this._ParseVersion(remoteVersion)
        
        Loop 3 {
            localNum := localParts[A_Index]
            remoteNum := remoteParts[A_Index]
            
            if (localNum < remoteNum)
                return -1
            if (localNum > remoteNum)
                return 1
        }
        
        return 0
    }
    
    ; 内部：解析版本号 vX.Y.Z -> [X, Y, Z]
    static _ParseVersion(versionStr) {
        ; 移除前缀 'v' 或 'V'
        cleanVersion := RegExReplace(versionStr, "^[vV]", "")
        
        parts := StrSplit(cleanVersion, ".")
        result := []
        
        Loop 3 {
            if (A_Index <= parts.Length) {
                result.Push(Integer(parts[A_Index]))
            } else {
                result.Push(0)
            }
        }
        
        return result
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
