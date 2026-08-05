; == 更新协调器 ==
; 协调更新流程的各个模块

class Updater {
    ; 每源下载重试次数（降级前）
    static DownloadRetries := 3
    ; 重试间隔（毫秒）
    static DownloadRetryDelay := 1000
    ; 启动延迟检查时间（毫秒）
    static StartupDelay := 100

    ; 初始化：订阅事件
    static Init() {
        ; 订阅应用启动事件（自动检查）
        EventBus.Subscribe("AppStarted", (*) => this.CheckOnStartup())
        ; 订阅手动检查更新事件
        EventBus.Subscribe("CheckUpdateClick", (*) => this.CheckManual())
        ; 订阅更新可用事件
        EventBus.Subscribe("UpdateAvailable", (data) => this.ShowUpdateDialog(data))
        ; 订阅更新确认事件
        EventBus.Subscribe("UpdateConfirmed", (data) => this.DownloadWithAltSource(data))
        ; 订阅更新忽略事件
        EventBus.Subscribe("UpdateIgnored", (data) => this.HandleUpdateIgnored(data))
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
        Logger.Info("Updater", "开始检查更新 manual=" isManual)
        ; 自动检查时，检查是否开启了自动更新
        if (!isManual && Config.GetImportant("AutoUpdate") != "1") {
            return
        }

        ; 执行版本检查
        EventBus.Publish("CheckUpdateStart")
        checkResult := VersionChecker.Check()
        Logger.Info("Updater", "版本检查结果 status=" checkResult.status)

        ; 处理检查结果
        switch checkResult.status {
            case "up_to_date":
                if (isManual) {
                    UpdateUI.ShowUpToDateDialog(checkResult.localVersion)
                }
                ; 清除已忽略版本记录（当前已是最新）
                dismissedVersion := Config.GetImportant("LastDismissedVersion")
                if (dismissedVersion != "") {
                    Config.SetImportant("LastDismissedVersion", "")
                    saveResult := Config.SaveAllToIni()
                    if (!saveResult.success) {
                        ; 保存失败时恢复内存值，避免配置文件与当前状态不一致。
                        Config.SetImportant("LastDismissedVersion", dismissedVersion)
                        Logger.Warn("Updater", "清除已忽略版本记录失败：" saveResult.message)
                        MessageBox.Warning("当前版本已是最新，但忽略版本记录未能清除：`n" saveResult.message, "配置未保存")
                    }
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
                    expectedHash: checkResult.HasProp("expectedHash") ? checkResult.expectedHash : "",
                    isManual: isManual,
                    changelogBody: checkResult.HasProp("changelogBody") ? checkResult.changelogBody : ""
                })

            case "rate_limited":
                ; 自动检查时静默降级到国内源
                if (!isManual) {
                    fallbackResult := VersionChecker._CheckFromDomestic(checkResult.localVersion)
                    if (fallbackResult.status = "update_available") {
                        EventBus.Publish("UpdateAvailable", {
                            localVersion: fallbackResult.localVersion,
                            remoteVersion: fallbackResult.remoteVersion,
                            downloadUrl: fallbackResult.downloadUrl,
                            expectedHash: fallbackResult.HasProp("expectedHash") ? fallbackResult.expectedHash : "",
                            isManual: isManual,
                            changelogBody: fallbackResult.HasProp("changelogBody") ? fallbackResult.changelogBody : ""
                        })
                        EventBus.Publish("CheckUpdateComplete")
                        return
                    }
                }
                if (isManual) {
                    suggestToken := checkResult.HasProp("suggestToken") ? checkResult.suggestToken : false
                    UpdateUI.ShowCheckFailedDialog(checkResult.message, suggestToken)
                }

            case "token_invalid":
                ; 自动检查时静默降级到国内源
                if (!isManual) {
                    fallbackResult := VersionChecker._CheckFromDomestic(checkResult.localVersion)
                    if (fallbackResult.status = "update_available") {
                        EventBus.Publish("UpdateAvailable", {
                            localVersion: fallbackResult.localVersion,
                            remoteVersion: fallbackResult.remoteVersion,
                            downloadUrl: fallbackResult.downloadUrl,
                            expectedHash: fallbackResult.HasProp("expectedHash") ? fallbackResult.expectedHash : "",
                            isManual: isManual,
                            changelogBody: fallbackResult.HasProp("changelogBody") ? fallbackResult.changelogBody : ""
                        })
                        EventBus.Publish("CheckUpdateComplete")
                        return
                    }
                }
                ; 手动检查或降级也失败，显示错误
                if (isManual) {
                    result := MessageBox.Info(checkResult.message)
                    VersionChecker.TokenValidated := false
                    GuiManager.Show()
                }

            case "check_failed":
                if (isManual) {
                    UpdateUI.ShowCheckFailedDialog(checkResult.message)
                }
        }
        EventBus.Publish("CheckUpdateComplete")
    }

    ; 下载入口（含同源重试 + 降级备选源）
    static DownloadWithAltSource(params, triedFallback := false) {
        this._TryDownload(params, triedFallback)
    }

    ; 内部：执行单次下载（在新线程中）
    static _ExecuteDownloadAttempt(downloadParams) {
        UpdateDownloader.Download(downloadParams)
    }

    ; 内部：带重试的单源下载
    ; reason: 上次失败的简要原因（透传给 UI 展示）
    static _TryDownload(params, triedFallback, retryCount := 0, reason := "") {
        UpdateUI.ShowDownloadingDialog(retryCount, reason)

        ; downloadParams 结构约定：{downloadUrl, expectedHash, localVersion, remoteVersion, ...}
        ; expectedHash：下载文件的期望 SHA-256（hex，小写；为空时跳过校验）
        downloadParams := {
            downloadUrl: params.downloadUrl,
            localVersion: params.localVersion,
            remoteVersion: params.remoteVersion,
            expectedHash: params.HasProp("expectedHash") ? params.expectedHash : "",
            onProgress: (data) => UpdateUI.UpdateDownloadProgress(data),
            onComplete: (result) => this.HandleDownloadSuccess(result),
            onError: (error) => this.HandleDownloadRetryOrFallback(error, params, triedFallback, retryCount),
            onCancel: (info) => this.HandleDownloadCancelComplete()
        }

        SetTimer(() => this._ExecuteDownloadAttempt(downloadParams), -10)
    }

    ; 下载错误处理——重试或降级
    static HandleDownloadRetryOrFallback(error, params, triedFallback, retryCount) {
        Logger.Warn("Updater", "下载失败 retry=" retryCount " fallback=" triedFallback " message=" error.message)
        if (error.HasProp("cancelled") && error.cancelled) {
            return
        }

        ; 同源重试（把失败原因传给 UI 展示，让用户知道为什么重试）
        if (retryCount < this.DownloadRetries - 1) {
            Sleep(this.DownloadRetryDelay)
            ; 优先用不含"下载失败:"前缀的原始原因，避免 UI 重复显示
            reason := error.HasProp("reason") ? error.reason : error.message
            this._TryDownload(params, triedFallback, retryCount + 1, reason)
            return
        }

        ; 同源重试耗尽，尝试降级备选源
        if (!triedFallback) {
            ; 降级检查期间更新下载窗口提示，避免用户误以为更新静默失败
            UpdateUI.ShowFallbackNotice()
            fallbackInfo := this._GetFallbackDownloadInfo(params)
            if (fallbackInfo.downloadUrl != "") {
                UpdateUI.CloseDownloadingDialog()
                fallbackParams := {
                    downloadUrl: fallbackInfo.downloadUrl,
                    localVersion: params.localVersion,
                    remoteVersion: params.remoteVersion,
                    expectedHash: fallbackInfo.expectedHash
                }
                this._TryDownload(fallbackParams, true, 0)
                return
            }
        }

        ; 降级也失败，显示错误
        UpdateUI.CloseDownloadingDialog()
        ; 用不含"下载失败:"前缀的原始原因，避免与弹窗标题/前缀重复
        reason := error.HasProp("reason") ? error.reason : error.message
        UpdateUI.ShowDownloadFailedDialog("下载失败：`n" reason "`n`n两个更新源均不可用，请稍后重试或手动下载")
    }

    ; 内部：获取备选源的下载信息（重新用备选源检查版本）
    ; 返回 {downloadUrl, expectedHash}：备选源下载地址 + 期望 SHA-256（为空时跳过校验）
    static _GetFallbackDownloadInfo(params) {
        updateSource := Config.GetImportant("UpdateSource")
        isGitHubPreferred := (updateSource == "2")

        localVersion := params.localVersion
        fallbackResult := isGitHubPreferred
            ? VersionChecker._CheckFromDomestic(localVersion)
            : VersionChecker._CheckFromGithub(localVersion)

        if (fallbackResult.status = "update_available" || fallbackResult.status = "up_to_date") {
            return {
                downloadUrl: fallbackResult.HasProp("downloadUrl") ? fallbackResult.downloadUrl : "",
                expectedHash: fallbackResult.HasProp("expectedHash") ? fallbackResult.expectedHash : ""
            }
        }
        return {downloadUrl: "", expectedHash: ""}
    }

    ; 下载成功处理
    static HandleDownloadSuccess(result) {
        Logger.Info("Updater", "更新下载完成，准备执行自替换")
        ; 关闭下载对话框
        UpdateUI.CloseDownloadingDialog()
        UpdateUI.ShowDownloadCompleteDialog()
        ; 执行自替换
        this.ExecuteSelfReplacement(result)
    }

    ; 处理下载取消
    static HandleDownloadCancelled() {
        ; 取消下载器
        UpdateDownloader.Cancel()
    }

    ; 处理下载取消完成
    static HandleDownloadCancelComplete() {
        Logger.Info("Updater", "用户取消更新下载")
        ; 关闭下载对话框
        UpdateUI.CloseDownloadingDialog()
        ; 显示取消提示
        UpdateUI.ShowDownloadCancelledDialog()
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
        saveResult := Config.SaveAllToIni()

        ; 显示提示
        if (saveResult.success)
            MessageBox.Info("已忽略版本 " data.remoteVersion " 的更新提示。`n`n下次自动检查更新时将不再提示此版本。", "已忽略")
        else
            MessageBox.Warning("已关闭本次更新提示，但忽略状态未能写入配置：`n" saveResult.message, "配置未保存")
    }

    ; 显示更新对话框
    static ShowUpdateDialog(data) {
        UpdateUI.ShowUpdateDialog(data)
    }
}

; 初始化协调器
Updater.Init()
