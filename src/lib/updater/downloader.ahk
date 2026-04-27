; == 更新下载器（支持取消和进度回调）==

class UpdateDownloader {
    ; 取消标志
    static IsCancelled := false
    ; HTTP请求对象（用于中止）
    static CurrentHttp := ""
    ; ADODB流对象（累积所有分块数据）
    static MasterStream := ""
    ; 临时文件路径
    static TempFile := ""
    ; 总字节数（来自Content-Length，0表示未知）
    static TotalBytes := 0
    ; 已下载字节数
    static LoadedBytes := 0
    ; 下载开始时间（用于速度计算）
    static StartTime := 0
    ; 远程版本号
    static RemoteVersion := ""
    ; 分块参数
    static ChunkSize := 0
    static ChunkIndex := 0
    static TotalChunks := 0
    static DownloadUrl := ""
    ; 回调函数
    static OnProgress := ""
    static OnComplete := ""
    static OnError := ""
    static OnCancel := ""
    ; 上一次报告进度的时间
    static LastProgressTime := 0
    ; 标记是否正在下载（防止重复取消）
    static IsDownloading := false
    ; 进度定时器回调（绑定为静态引用以正确停止）
    static ProgressTimer := ObjBindMethod(UpdateDownloader, "_ReportProgress")
    ; 超时常量
    static HeadTimeout := 30000
    static ChunkMaxTimeout := 120000
    static FullMaxTimeout := 120000
    static StallTimeout := 15000
    static ConnStallTimeout := 10000
    ; 分块重试
    static ChunkRetries := 0
    static MaxChunkRetries := 3
    static ChunkRetryDelay := 2000
    ; 上次分块完成时间（用于停滞检测）
    static LastChunkTime := 0
    
    ; 取消当前下载
    static Cancel() {
        this.IsCancelled := true
        if (this.CurrentHttp != "") {
            try this.CurrentHttp.Abort()
        }
    }
    
    ; 重置状态
    static ResetCancel() {
        this.IsCancelled := false
        this.CurrentHttp := ""
        this.MasterStream := ""
        this.TempFile := ""
        this.TotalBytes := 0
        this.LoadedBytes := 0
        this.StartTime := 0
        this.RemoteVersion := ""
        this.ChunkSize := 0
        this.ChunkIndex := 0
        this.TotalChunks := 0
        this.DownloadUrl := ""
        this.OnProgress := ""
        this.OnComplete := ""
        this.OnError := ""
        this.OnCancel := ""
        this.LastProgressTime := 0
        this.IsDownloading := false
        this.ChunkRetries := 0
        this.LastChunkTime := 0
    }
    
    ; 下载文件
    ; params: {downloadUrl, remoteVersion, onProgress, onComplete, onError, onCancel}
    static Download(params) {
        this.ResetCancel()
        this.StartTime := A_TickCount
        this.IsDownloading := true
        
        this.DownloadUrl := params.downloadUrl
        this.RemoteVersion := params.remoteVersion
        if (params.HasProp("onProgress"))
            this.OnProgress := params.onProgress
        if (params.HasProp("onComplete"))
            this.OnComplete := params.onComplete
        if (params.HasProp("onError"))
            this.OnError := params.onError
        if (params.HasProp("onCancel"))
            this.OnCancel := params.onCancel
        
        ; 启动定期进度刷新（200ms间隔，速度实时更新）
        this._StartProgressTimer()
        
        ; 生成临时文件路径
        tempDir := A_Temp "\ArknightsFrameAssistant"
        if !DirExist(tempDir)
            DirCreate(tempDir)
        this.TempFile := tempDir "\AFA_" this.RemoteVersion "_update.exe"
        
        ; 第一步：异步HEAD请求获取文件大小
        try {
            http := ComObject("MSXML2.ServerXMLHTTP.6.0")
            this.CurrentHttp := http
            http.SetProxy(0)
            http.Open("HEAD", this.DownloadUrl, true)
            http.Send()
            
            ; 轮询等待响应，基于无数据活动的停滞检测
            headStart := A_TickCount
            lastState := 0
            stallStart := A_TickCount
            Loop {
                if (this.IsCancelled) {
                    this._Cleanup()
                    this._FireCancel()
                    return
                }
                rs := http.readyState
                if (rs >= 4)
                    break
                ; readyState有变化 → 重置停滞计时
                if (rs != lastState) {
                    lastState := rs
                    stallStart := A_TickCount
                }
                ; 连接阶段停滞（readyState<3）超过 ConnStallTimeout
                if (rs < 3 && A_TickCount - stallStart > this.ConnStallTimeout) {
                    try http.Abort()
                    throw Error("HEAD请求连接超时")
                }
                ; 绝对超时安全网
                if (A_TickCount - headStart > this.HeadTimeout) {
                    try http.Abort()
                    throw Error("HEAD请求超时")
                }
                Sleep(25)
            }
            
            if (this.IsCancelled) {
                this._Cleanup()
                this._FireCancel()
                return
            }
            
            if (http.Status = 200) {
                try {
                    contentLengthStr := http.GetResponseHeader("Content-Length")
                    if (contentLengthStr != "")
                        this.TotalBytes := Integer(contentLengthStr)
                }
            }
        } catch {
            this.TotalBytes := 0
        }
        
        ; 创建累积数据的流
        this.MasterStream := ComObject("ADODB.Stream")
        this.MasterStream.Type := 1
        this.MasterStream.Open()
        
        if (this.TotalBytes > 0) {
            ; 分块下载
            ; 动态分块大小：目标约50次进度更新，最小16KB，最大512KB
            this.ChunkSize := Max(16384, Min(524288, this.TotalBytes // 100))
            this.TotalChunks := Ceil(this.TotalBytes / this.ChunkSize)
            this.ChunkIndex := 0
            this.LoadedBytes := 0
            SetTimer(() => UpdateDownloader._DownloadNextChunk(), -10)
        } else {
            ; 未知大小，异步整体下载
            try {
                http := ComObject("MSXML2.ServerXMLHTTP.6.0")
                this.CurrentHttp := http
                http.SetProxy(0)
                http.Open("GET", this.DownloadUrl, true)
                http.SetRequestHeader("User-Agent", "ArknightsFrameAssistant/" Version.Get())
                http.Send()
                
                ; 轮询等待完成，基于无数据活动的停滞检测
                fullStart := A_TickCount
                lastState := 0
                stallStart := A_TickCount
                Loop {
                    if (this.IsCancelled) {
                        this._Cleanup()
                        this._FireCancel()
                        return
                    }
                    rs := http.readyState
                    if (rs >= 4)
                        break
                    if (rs != lastState) {
                        lastState := rs
                        stallStart := A_TickCount
                    }
                    if (rs < 3 && A_TickCount - stallStart > this.ConnStallTimeout) {
                        try http.Abort()
                        throw Error("下载请求连接超时")
                    }
                    if (A_TickCount - fullStart > this.FullMaxTimeout) {
                        try http.Abort()
                        throw Error("下载请求超时")
                    }
                    Sleep(25)
                }
                
                if (this.IsCancelled) {
                    this._Cleanup()
                    this._FireCancel()
                    return
                }
                
                if (http.Status != 200) {
                    throw Error("下载失败，HTTP状态: " http.Status)
                }
                
                responseBody := http.ResponseBody
                this.MasterStream.Write(responseBody)
                this.LoadedBytes := this._GetBufferSize(responseBody)
                if (this.LoadedBytes = 0) {
                    try {
                        contentLengthStr := http.GetResponseHeader("Content-Length")
                        if (contentLengthStr != "")
                            this.LoadedBytes := Integer(contentLengthStr)
                    }
                }
                this.TotalBytes := this.LoadedBytes
                this._ReportProgress()
                this._FinishDownload()
            } catch Error as e {
                this._Cleanup()
                this._HandleErrorObj(e)
            }
        }
    }
    
    ; 内部：下载下一个分块（由SetTimer调度）
    static _DownloadNextChunk() {
        if (this.IsCancelled) {
            this._Cleanup()
            this._FireCancel()
            return
        }
        
        if (this.ChunkIndex >= this.TotalChunks) {
            this._FinishDownload()
            return
        }
        
        ; 分块间停滞检测：非首块时，若长时间无分块完成则判停滞
        if (this.ChunkIndex > 0 && this.LastChunkTime > 0 && A_TickCount - this.LastChunkTime > this.StallTimeout) {
            this._Cleanup()
            this._HandleErrorObj(Error("下载停滞：" (this.StallTimeout // 1000) "秒无新数据"))
            return
        }
        
        rangeStart := this.ChunkIndex * this.ChunkSize
        rangeEnd := Min((this.ChunkIndex + 1) * this.ChunkSize - 1, this.TotalBytes - 1)
        
        try {
            http := ComObject("MSXML2.ServerXMLHTTP.6.0")
            this.CurrentHttp := http
            http.SetProxy(0)
            http.Open("GET", this.DownloadUrl, true)
            http.SetRequestHeader("Range", "bytes=" rangeStart "-" rangeEnd)
            http.Send()
            
            ; 异步轮询等待，基于无数据活动的停滞检测
            chunkStart := A_TickCount
            lastState := 0
            stallStart := A_TickCount
            Loop {
                if (this.IsCancelled) {
                    this._Cleanup()
                    this._FireCancel()
                    return
                }
                rs := http.readyState
                if (rs >= 4)
                    break
                ; readyState有变化 → 数据传输中，重置停滞计时
                if (rs != lastState) {
                    lastState := rs
                    stallStart := A_TickCount
                }
                ; 连接阶段停滞（readyState<3）超过 ConnStallTimeout
                if (rs < 3 && A_TickCount - stallStart > this.ConnStallTimeout) {
                    try http.Abort()
                    throw Error("下载分块连接超时")
                }
                ; 接收阶段停滞（readyState>=3）超过 StallTimeout — 数据流中断
                if (rs >= 3 && A_TickCount - stallStart > this.StallTimeout) {
                    try http.Abort()
                    throw Error("下载分块数据停滞")
                }
                ; 绝对超时安全网
                if (A_TickCount - chunkStart > this.ChunkMaxTimeout) {
                    try http.Abort()
                    throw Error("下载分块超时")
                }
                Sleep(25)
            }
            
            if (this.IsCancelled) {
                this._Cleanup()
                this._FireCancel()
                return
            }
            
            if (http.Status != 206 && http.Status != 200) {
                throw Error("下载分块失败，HTTP状态: " http.Status)
            }
            
            responseBody := http.ResponseBody
            
            ; 从Content-Range响应头获取实际接收的字节数
            actualBytes := 0
            try {
                contentRange := http.GetResponseHeader("Content-Range")
                if (contentRange != "") {
                    if (RegExMatch(contentRange, "bytes\s+(\d+)-(\d+)", &match)) {
                        start := Integer(match[1])
                        end := Integer(match[2])
                        actualBytes := end - start + 1
                    }
                }
            }
            if (actualBytes = 0)
                actualBytes := rangeEnd - rangeStart + 1
            
            ; 解析完成后再写入流，避免重试时重复数据
            this.MasterStream.Write(responseBody)
            
            this.LoadedBytes := rangeStart + actualBytes
            this.ChunkIndex += 1
            this.ChunkRetries := 0
            this.LastChunkTime := A_TickCount
            this._ReportProgress()
            
            SetTimer(() => UpdateDownloader._DownloadNextChunk(), -10)
            
        } catch Error as e {
            if (this.IsCancelled) {
                this._Cleanup()
                this._FireCancel()
                return
            }
            ; 分块级重试：仅重试当前块，保留已下载数据
            if (this.ChunkRetries < this.MaxChunkRetries) {
                this.ChunkRetries += 1
                Sleep(this.ChunkRetryDelay)
                SetTimer(() => UpdateDownloader._DownloadNextChunk(), -10)
                return
            }
            ; 分块重试耗尽，触发完整重试
            this._Cleanup()
            this._HandleErrorObj(e)
        }
    }
    
    ; 内部：完成下载（保存文件）
    static _FinishDownload() {
        try {
            this.LoadedBytes := this.TotalBytes
            this._ReportProgress()
            
            this.MasterStream.SaveToFile(this.TempFile, 2)
            this.MasterStream.Close()
            this.MasterStream := ""
            
            if !FileExist(this.TempFile) {
                throw Error("文件保存失败")
            }
            
            this.IsDownloading := false
            this._StopProgressTimer()
            this._FireComplete()
        } catch Error as e {
            this._Cleanup()
            this._HandleErrorObj(e)
        }
    }
    
    ; 内部：获取Buffer或ComObj的字节大小
    static _GetBufferSize(data) {
        try {
            if (Type(data) = "Buffer")
                return data.Size
        }
        return 0
    }
    
    ; 内部：报告进度
    static _ReportProgress() {
        if (this.OnProgress = "" || !(Type(this.OnProgress) = "Func" || Type(this.OnProgress) = "Closure"))
            return
        
        elapsed := Max((A_TickCount - this.StartTime) / 1000, 0.001)
        speed := this.LoadedBytes / elapsed
        this.OnProgress.Call({
            total: this.TotalBytes,
            loaded: this.LoadedBytes,
            speed: speed
        })
    }
    
    ; 启动进度刷新计时器（200ms间隔，独立于分块完成）
    static _StartProgressTimer() {
        SetTimer(this.ProgressTimer, 200)
    }
    
    ; 停止进度刷新计时器
    static _StopProgressTimer() {
        SetTimer(this.ProgressTimer, 0)
    }
    
    ; 内部：触发完成回调
    static _FireComplete() {
        result := {
            tempFile: this.TempFile,
            remoteVersion: this.RemoteVersion
        }
        EventBus.Publish("UpdateDownloadComplete", result)
        if (this.OnComplete != "" && (Type(this.OnComplete) = "Func" || Type(this.OnComplete) = "Closure"))
            this.OnComplete.Call(result)
        this._Cleanup()
    }
    
    ; 内部：触发取消回调
    static _FireCancel() {
        this.IsDownloading := false
        cancelInfo := {message: "用户取消了下载"}
        if (this.OnCancel != "" && (Type(this.OnCancel) = "Func" || Type(this.OnCancel) = "Closure"))
            this.OnCancel.Call(cancelInfo)
        this._Cleanup()
    }
    
    ; 内部：触发错误回调
    static _HandleErrorObj(err) {
        this.IsDownloading := false
        errorInfo := {
            message: "下载失败: " err.Message,
            version: this.RemoteVersion
        }
        EventBus.Publish("UpdateDownloadError", errorInfo)
        if (this.OnError != "" && (Type(this.OnError) = "Func" || Type(this.OnError) = "Closure"))
            this.OnError.Call(errorInfo)
        this._Cleanup()
    }
    
    ; 内部：清理资源
    static _Cleanup() {
        this._StopProgressTimer()
        if (this.MasterStream != "") {
            try this.MasterStream.Close()
            this.MasterStream := ""
        }
        this.CurrentHttp := ""
        this.IsDownloading := false
        
        if (this.IsCancelled && FileExist(this.TempFile)) {
            try FileDelete(this.TempFile)
        }
    }
    
    ; 获取临时文件路径（用于检查之前的下载）
    static GetTempFilePath(version) {
        tempDir := A_Temp "\ArknightsFrameAssistant"
        return tempDir "\AFA_" version "_update.exe"
    }
    
    ; 验证下载的文件是否完整
    static VerifyDownload(filePath) {
        if !FileExist(filePath) {
            return false
        }
        try {
            fileSize := FileGetSize(filePath)
            return fileSize > 0
        } catch {
            return false
        }
    }
}
