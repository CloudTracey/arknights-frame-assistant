; == 更新协调器 ==
; 协调更新流程的各个模块；与 UpdateUI 之间只通过更新事件通信。

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
        EventBus.Subscribe("AppStartCompleted", (*) => this.CheckOnStartup())
        ; 订阅手动检查更新事件
        EventBus.Subscribe("UpdateCheckRequested", (*) => this.CheckManual())
        ; 订阅更新确认事件
        EventBus.Subscribe("UpdateConfirmRequested", (data) => this.DownloadWithAltSource(data))
        ; 订阅更新忽略事件
        EventBus.Subscribe("UpdateIgnoreRequested", (data) => this.HandleUpdateIgnored(data))
        ; 订阅下载取消事件
        EventBus.Subscribe("UpdateDownloadCancelRequested", (*) => this.HandleDownloadCancelled())
        ; 订阅手动下载事件
        EventBus.Subscribe("UpdateManualDownloadRequested", (data) => this.HandleManualDownload(data))
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
        EventBus.Publish("UpdateCheckStarted", {isManual: isManual})
        checkResult := VersionChecker.Check()
        Logger.Info("Updater", "版本检查结果 status=" checkResult.status)

        ; 处理检查结果
        switch checkResult.status {
            case "up_to_date":
                ; 清除已忽略版本记录（当前已是最新）
                dismissedVersion := Config.GetImportant("LastDismissedVersion")
                if (dismissedVersion != "") {
                    saveResult := SettingsService.UpdatePersistedValue("LastDismissedVersion", "")
                    if (!saveResult.success) {
                        ; 保存失败时恢复内存值，避免配置文件与当前状态不一致。
                        Config.SetImportant("LastDismissedVersion", dismissedVersion)
                        Logger.Warn("Updater", "清除已忽略版本记录失败：" saveResult.message)
                        MessageBox.Warning(I18n.T("msg.upToDateDismissFailed", saveResult.message), I18n.T("msg.configNotSavedTitle"))
                    }
                }

            case "update_available":
                ; 检查是否是已忽略的版本
                lastDismissed := Config.GetImportant("LastDismissedVersion")
                if (!isManual && lastDismissed == checkResult.remoteVersion) {
                    ; 自动检查时，如果该版本已被忽略，则跳过
                    EventBus.Publish("UpdateCheckCompleted", {isManual: isManual, status: "update_available", localVersion: checkResult.localVersion})
                    return
                }

                ; 发布更新可用事件
                Logger.Info("Updater", "发布更新可用：新版本 " checkResult.remoteVersion "，manual=" isManual)
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
                    fallbackResult := ReleaseRepository.CheckDomestic(checkResult.localVersion)
                    if (fallbackResult.status = "update_available") {
                        Logger.Info("Updater", "自动降级到国内源成功，发现新版本 " fallbackResult.remoteVersion)
                        EventBus.Publish("UpdateAvailable", {
                            localVersion: fallbackResult.localVersion,
                            remoteVersion: fallbackResult.remoteVersion,
                            downloadUrl: fallbackResult.downloadUrl,
                            expectedHash: fallbackResult.HasProp("expectedHash") ? fallbackResult.expectedHash : "",
                            isManual: isManual,
                            changelogBody: fallbackResult.HasProp("changelogBody") ? fallbackResult.changelogBody : ""
                        })
                        EventBus.Publish("UpdateCheckCompleted", {isManual: isManual, status: "update_available", localVersion: fallbackResult.localVersion})
                        return
                    }
                }

            case "token_invalid":
                ; 自动检查时静默降级到国内源
                if (!isManual) {
                    fallbackResult := ReleaseRepository.CheckDomestic(checkResult.localVersion)
                    if (fallbackResult.status = "update_available") {
                        Logger.Info("Updater", "自动降级到国内源成功，发现新版本 " fallbackResult.remoteVersion)
                        EventBus.Publish("UpdateAvailable", {
                            localVersion: fallbackResult.localVersion,
                            remoteVersion: fallbackResult.remoteVersion,
                            downloadUrl: fallbackResult.downloadUrl,
                            expectedHash: fallbackResult.HasProp("expectedHash") ? fallbackResult.expectedHash : "",
                            isManual: isManual,
                            changelogBody: fallbackResult.HasProp("changelogBody") ? fallbackResult.changelogBody : ""
                        })
                        EventBus.Publish("UpdateCheckCompleted", {isManual: isManual, status: "update_available", localVersion: fallbackResult.localVersion})
                        return
                    }
                }
        }
        EventBus.Publish("UpdateCheckCompleted", {
            isManual: isManual,
            status: checkResult.status,
            localVersion: checkResult.HasProp("localVersion") ? checkResult.localVersion : "",
            message: checkResult.HasProp("message") ? checkResult.message : "",
            suggestToken: checkResult.HasProp("suggestToken") ? checkResult.suggestToken : false
        })
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
        EventBus.Publish("UpdateDownloadStarted", {retryCount: retryCount, reason: reason})

        ; downloadParams 结构约定：{downloadUrl, expectedHash, localVersion, remoteVersion, ...}
        ; expectedHash：下载文件的期望 SHA-256（hex，小写；为空时跳过校验）
        downloadParams := {
            downloadUrl: params.downloadUrl,
            localVersion: params.localVersion,
            remoteVersion: params.remoteVersion,
            expectedHash: params.HasProp("expectedHash") ? params.expectedHash : "",
            onProgress: (data) => EventBus.Publish("UpdateDownloadProgress", {
                downloadedBytes: data.loaded,
                totalBytes: data.total,
                speedBytesPerSec: data.speed
            }),
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
            EventBus.Publish("UpdateDownloadRetryScheduled", {retryCount: retryCount + 1, reason: reason})
            this._TryDownload(params, triedFallback, retryCount + 1, reason)
            return
        }

        ; 同源重试耗尽，尝试降级备选源
        if (!triedFallback) {
            ; 降级检查期间更新下载窗口提示，避免用户误以为更新静默失败
            EventBus.Publish("UpdateFallbackNotice")
            fallbackInfo := this._GetFallbackDownloadInfo(params)
            if (fallbackInfo.downloadUrl != "") {
                Logger.Info("Updater", "同源重试耗尽，降级备选源下载")
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
        ; 用不含"下载失败:"前缀的原始原因，避免与弹窗标题/前缀重复
        reason := error.HasProp("reason") ? error.reason : error.message
        EventBus.Publish("UpdateDownloadFailed", {reason: reason})
    }

    ; 内部：获取备选源的下载信息（重新用备选源检查版本）
    ; 返回 {downloadUrl, expectedHash}：备选源下载地址 + 期望 SHA-256（为空时跳过校验）
    static _GetFallbackDownloadInfo(params) {
        updateSource := Config.GetImportant("UpdateSource")
        isGitHubPreferred := (updateSource == "2")

        localVersion := params.localVersion
        fallbackResult := isGitHubPreferred
            ? ReleaseRepository.CheckDomestic(localVersion)
            : ReleaseRepository.CheckGithub(localVersion)

        if (fallbackResult.status = "update_available" || fallbackResult.status = "up_to_date") {
            fallbackUrl := fallbackResult.HasProp("downloadUrl") ? fallbackResult.downloadUrl : ""
            Logger.Info("Updater", "备选源检查成功 status=" fallbackResult.status "，downloadUrl=" fallbackUrl)
            return {
                downloadUrl: fallbackUrl,
                expectedHash: fallbackResult.HasProp("expectedHash") ? fallbackResult.expectedHash : ""
            }
        }
        Logger.Warn("Updater", "备选源检查失败 status=" fallbackResult.status)
        return {downloadUrl: "", expectedHash: ""}
    }

    ; 下载成功处理
    static HandleDownloadSuccess(result) {
        Logger.Info("Updater", "更新下载完成，准备执行自替换")
        EventBus.Publish("UpdateDownloadCompleted", {tempFile: result.tempFile})
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
        EventBus.Publish("UpdateDownloadCancelled")
    }

    ; 执行自替换
    static ExecuteSelfReplacement(downloadResult) {
        replaceResult := SelfReplacer.ExecuteReplacement({
            newFilePath: downloadResult.tempFile,
            backupOldVersion: true
        })

        if (!replaceResult.success) {
            Logger.Error("Updater", "自替换启动失败：" replaceResult.error)
            MessageBox.Error(I18n.T("msg.updateStartFailed", replaceResult.error), I18n.T("msg.updateFailedTitle"))
        } else {
            Logger.Info("Updater", "自替换已启动，即将退出程序")
        }
    }

    ; 处理忽略此版本
    static HandleUpdateIgnored(data) {
        Logger.Info("Updater", "用户忽略版本 " data.remoteVersion " 的更新提示")
        ; 记录忽略的版本号（单键写入，不触碰其他未保存设置）
        saveResult := SettingsService.UpdatePersistedValue("LastDismissedVersion", data.remoteVersion)

        ; 显示提示
        if (saveResult.success)
            MessageBox.Info(I18n.T("msg.updateIgnored", data.remoteVersion), I18n.T("msg.updateIgnoredTitle"))
        else
            MessageBox.Warning(I18n.T("msg.updateIgnoreSaveFailed", saveResult.message), I18n.T("msg.configNotSavedTitle"))
    }

    ; 处理手动下载
    static HandleManualDownload(data) {
        url := (data != "" && data.HasProp("url") && data.url != "") ? data.url : "https://www.bilibili.com/opus/1178139405104185363"
        Run(url)
    }
}
