; == 更新下载器 ==

class UpdateDownloader {
    ; 下载文件
    ; params: 包含以下字段的对象
    ;   - downloadUrl: 下载链接
    ;   - localVersion: 当前版本
    ;   - remoteVersion: 远程版本
    ;   - onProgress: 进度回调函数(可选)
    ;   - onComplete: 完成回调函数
    ;   - onError: 错误回调函数
    static Download(params) {
        downloadUrl := params.downloadUrl
        remoteVersion := params.remoteVersion
        
        ; 生成临时文件路径
        tempDir := A_Temp "\ArknightsFrameAssistant"
        if !DirExist(tempDir)
            DirCreate(tempDir)
        
        tempFile := tempDir "\AFA_" remoteVersion "_update.exe"
        
        try {
            ; 使用 WinHttpRequest 进行下载
            http := ComObject("WinHttp.WinHttpRequest.5.1")
            http.Open("GET", downloadUrl, true)
            http.Send()
            http.WaitForResponse()
            
            ; 检查HTTP状态
            if (http.Status != 200) {
                throw Error("HTTP错误: " http.Status " - " http.StatusText)
            }
            
            ; 获取响应体并保存到文件
            responseBody := http.ResponseBody
            adodb := ComObject("ADODB.Stream")
            adodb.Type := 1  ; 二进制模式
            adodb.Open()
            adodb.Write(responseBody)
            adodb.SaveToFile(tempFile, 2)  ; 2 = 覆盖模式
            adodb.Close()
            
            ; 验证文件是否成功创建
            if !FileExist(tempFile) {
                throw Error("文件保存失败")
            }
            
            ; 发布下载完成事件
            EventBus.Publish("UpdateDownloadComplete", {
                tempFile: tempFile,
                remoteVersion: remoteVersion
            })
            
            ; 调用完成回调（如果提供且是函数）
            if (params.HasProp("onComplete") && (Type(params.onComplete) = "Func" || Type(params.onComplete) = "Closure")) {
                callback := params.onComplete
                callback.Call({
                    tempFile: tempFile,
                    remoteVersion: remoteVersion
                })
            }
            
            return {
                success: true,
                tempFile: tempFile,
                remoteVersion: remoteVersion
            }
            
        } catch Error as e {
            errorInfo := {
                message: "下载失败: " e.Message,
                url: downloadUrl,
                version: remoteVersion
            }
            
            ; 发布下载错误事件
            EventBus.Publish("UpdateDownloadError", errorInfo)
            
            ; 调用错误回调（如果提供且是函数）
            if (params.HasProp("onError") && (Type(params.onError) = "Func" || Type(params.onError) = "Closure")) {
                callback := params.onError
                callback.Call(errorInfo)
            }
            
            return {
                success: false,
                error: errorInfo.message
            }
        }
    }
    
    ; 获取临时文件路径（用于检查之前的下载）
    static GetTempFilePath(version) {
        tempDir := A_Temp "\ArknightsFrameAssistant"
        return tempDir "\AFA_" version "_update.exe"
    }
    
    ; 验证下载的文件是否完整（简单的存在性检查）
    static VerifyDownload(filePath) {
        if !FileExist(filePath) {
            return false
        }
        
        ; 获取文件大小
        try {
            fileSize := FileGetSize(filePath)
            return fileSize > 0
        } catch {
            return false
        }
    }
}
