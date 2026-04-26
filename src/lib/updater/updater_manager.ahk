; == 更新协调器 ==
; 协调更新流程的各个模块

class Updater {
    ; 最大重试次数
    static MaxRetries := 3
    ; 重试间隔（毫秒）
    static RetryDelay := 2000
    ; 启动延迟检查时间（毫秒）
    static StartupDelay := 100
    
    ; 下载参数存储（用于重试）
    static CurrentDownloadParams := ""
    static CurrentRetryCount := 0
    
    ; 初始化：订阅事件
    static Init() {
        ; 订阅应用启动事件（自动检查）
        EventBus.Subscribe("AppStarted", (*) => this.CheckOnStartup())
        ; 订阅手动检查更新事件
        EventBus.Subscribe("CheckUpdateClick", (*) => this.CheckManual())
        ; 订阅更新可用事件
        EventBus.Subscribe("UpdateAvailable", (data) => this.ShowUpdateDialog(data))
        ; 订阅更新确认事件
        EventBus.Subscribe("UpdateConfirmed", (data) => this.DownloadWithRetry(data))
        ; 订阅更新忽略事件
        EventBus.Subscribe("UpdateIgnored", (data) => this.HandleUpdateIgnored(data))
        ; 订阅下载完成事件
        EventBus.Subscribe("UpdateDownloadComplete", (data) => this.HandleDownloadComplete(data))
        ; 订阅下载错误事件
        EventBus.Subscribe("UpdateDownloadError", (data) => this.HandleDownloadError(data))
        ; 订阅下载取消事件
        EventBus.Subscribe("UpdateDownloadCancelled", (*) => this.HandleDownloadCancelled())
    }
    
    ; 启动时检查（异步）
    static CheckOnStartup() {
        ; 延迟执行，避免阻塞GUI初始化
        SetTimer(() => this._DoCheck(false), -this.StartupDelay)
    }
    
    ; 手动检查
    static CheckManual() {
        ; 立即执行检查
        this._DoCheck(true)
    }
    
    ; 内部：执行版本检查
    static _DoCheck(isManual) {
        ; 自动检查时，检查是否开启了自动更新
        if (!isManual && Config.GetImportant("AutoUpdate") != "1") {
            return
        }
        
        ; 执行版本检查
        EventBus.Publish("CheckUpdateStart")
        checkResult := VersionChecker.Check()
        
        ; 处理检查结果
        switch checkResult.status {
            case "up_to_date":
                if (isManual) {
                    UpdateUI.ShowUpToDateDialog(checkResult.localVersion)
                }
                ; 清除已忽略版本记录（当前已是最新）
                if (Config.GetImportant("LastDismissedVersion") != "") {
                    Config.SetImportant("LastDismissedVersion", "")
                    Config.SaveAllToIni()
                }
            
            case "update_available":
                ; 检查是否是已忽略的版本
                lastDismissed := Config.GetImportant("LastDismissedVersion")
                if (!isManual && lastDismissed == checkResult.remoteVersion) {
                    ; 自动检查时，如果该版本已被忽略，则跳过
                    EventBus.Publish("CheckUpdateComplete")
                    return
                }
                
                ; 发布更新可用事件
                EventBus.Publish("UpdateAvailable", {
                    localVersion: checkResult.localVersion,
                    remoteVersion: checkResult.remoteVersion,
                    downloadUrl: checkResult.downloadUrl,
                    isManual: isManual
                })
            
            case "rate_limited":
                if (isManual) {
                    suggestToken := checkResult.HasProp("suggestToken") ? checkResult.suggestToken : false
                    UpdateUI.ShowCheckFailedDialog(checkResult.message, suggestToken)
                }
            
            case "token_invalid":
                if (isManual) {
                    ; Token无效，引导用户重新配置
                    result := MessageBox.Confirm(checkResult.message "`n`n是否现在修改Token设置？", "Token无效")
                    if (result = "Yes") {
                        ; 重置Token验证状态
                        VersionChecker.TokenValidated := false
                        GuiManager.Show()
                    }
                }
            
            case "check_failed":
                if (isManual) {
                    UpdateUI.ShowCheckFailedDialog(checkResult.message)
                }
        }
        EventBus.Publish("CheckUpdateComplete")
    }
    
    ; 带重试的下载
    static DownloadWithRetry(params, retryCount := 0) {
        ; 保存当前参数（用于重试和取消）
        this.CurrentDownloadParams := params
        this.CurrentRetryCount := retryCount
        
        ; 显示下载中提示（传递重试次数）
        UpdateUI.ShowDownloadingDialog(retryCount)
        
        ; 执行下载
        downloadParams := {
            downloadUrl: params.downloadUrl,
            localVersion: params.localVersion,
            remoteVersion: params.remoteVersion,
            onComplete: (result) => this.HandleDownloadSuccess(result),
            onError: (error) => this.HandleDownloadFailure(error, params, retryCount),
            onCancel: (info) => this.HandleDownloadCancelComplete()
        }
        
        ; 在新线程中执行下载，避免阻塞UI
        SetTimer(() => this._ExecuteDownload(downloadParams), -10)
    }
    
    ; 执行下载（在新线程中）
    static _ExecuteDownload(downloadParams) {
        UpdateDownloader.Download(downloadParams)
    }
    
    ; 下载成功处理
    static HandleDownloadSuccess(result) {
        ; 关闭下载对话框
        UpdateUI.CloseDownloadingDialog()
        UpdateUI.ShowDownloadCompleteDialog()
        ; 执行自替换
        this.ExecuteSelfReplacement(result)
    }
    
    ; 下载失败处理（带重试）
    static HandleDownloadFailure(error, originalParams, retryCount) {
        ; 检查是否是取消导致的失败
        if (error.HasProp("cancelled") && error.cancelled) {
            ; 取消导致的失败，不显示错误，也不重试
            return
        }
        
        if (retryCount < this.MaxRetries) {
            ; 延迟后重试
            Sleep(this.RetryDelay)
            this.DownloadWithRetry(originalParams, retryCount + 1)
        } else {
            ; 关闭下载对话框
            UpdateUI.CloseDownloadingDialog()
            ; 重试次数用尽，显示失败
            UpdateUI.ShowDownloadFailedDialog("重试" this.MaxRetries "次后仍失败：`n" error.message)
        }
    }
    
    ; 处理下载取消
    static HandleDownloadCancelled() {
        ; 取消下载器
        UpdateDownloader.Cancel()
    }
    
    ; 处理下载取消完成
    static HandleDownloadCancelComplete() {
        ; 关闭下载对话框
        UpdateUI.CloseDownloadingDialog()
        ; 显示取消提示
        UpdateUI.ShowDownloadCancelledDialog()
        ; 清理参数
        this.CurrentDownloadParams := ""
        this.CurrentRetryCount := 0
    }
    
    ; 处理下载完成事件
    static HandleDownloadComplete(data) {
        ; 由 onComplete 回调处理，这里不需要额外操作
    }
    
    ; 处理下载错误事件
    static HandleDownloadError(data) {
        ; 由 onError 回调处理，这里不需要额外操作
    }
    
    ; 执行自替换
    static ExecuteSelfReplacement(downloadResult) {
        replaceResult := SelfReplacer.ExecuteReplacement({
            newFilePath: downloadResult.tempFile,
            backupOldVersion: true
        })
        
        if (!replaceResult.success) {
            MessageBox.Error("启动更新失败：`n" replaceResult.error, "更新失败")
        }
        ; 成功时会自动退出程序
    }
    
    ; 处理忽略此版本
    static HandleUpdateIgnored(data) {
        ; 记录忽略的版本号
        Config.SetImportant("LastDismissedVersion", data.remoteVersion)
        Config.SaveAllToIni()
        
        ; 显示提示
        MessageBox.Info("已忽略版本 " data.remoteVersion " 的更新提示。`n`n下次检查更新时将不再提示此版本。", "已忽略")
    }
    
    ; 显示更新对话框
    static ShowUpdateDialog(data) {
        UpdateUI.ShowUpdateDialog(data)
    }
}

; 初始化协调器
Updater.Init()
