; == 更新UI模块 ==

class UpdateUI {
    ; 初始化：订阅更新事件
    static Init() {
        EventBus.Subscribe("UpdateAvailable", (data) => this.ShowUpdateDialog(data))
        EventBus.Subscribe("UpdateCheckCompleted", (data) => this._OnUpdateCheckCompleted(data))
        EventBus.Subscribe("UpdateDownloadStarted", (data) => this.ShowDownloadingDialog(
            data.HasProp("retryCount") ? data.retryCount : 0,
            data.HasProp("reason") ? data.reason : ""))
        EventBus.Subscribe("UpdateDownloadRetryScheduled", (data) => this.ShowDownloadingDialog(data.retryCount, data.reason))
        EventBus.Subscribe("UpdateDownloadProgress", (data) => this.UpdateDownloadProgress({
            total: data.totalBytes,
            loaded: data.downloadedBytes,
            speed: data.speedBytesPerSec
        }))
        EventBus.Subscribe("UpdateFallbackNotice", (*) => this.ShowFallbackNotice())
        EventBus.Subscribe("UpdateDownloadCompleted", (data) => this._OnDownloadCompleted(data))
        EventBus.Subscribe("UpdateDownloadFailed", (data) => this._OnDownloadFailed(data))
        EventBus.Subscribe("UpdateDownloadCancelled", (*) => this._OnDownloadCancelled())
    }

    ; 更新对话框实例和参数
    static UpdateDialog := ""
    static UpdateDialogParams := ""

    ; 下载对话框实例
    static DownloadingDialog := ""
    static DownloadingCancelBtn := ""
    static DownloadingProgressBar := ""
    static DownloadingSpeedText := ""
    static DownloadingRemainingText := ""
    static DownloadingSizeText := ""

    ; 显示更新提示对话框（支持忽略此版本）
    ; params: 包含以下字段的对象
    ;   - localVersion: 当前版本
    ;   - remoteVersion: 远程版本
    ;   - downloadUrl: 下载链接
    ;   - isManual: 是否是手动检查（影响提示内容）
    static ShowUpdateDialog(params) {
        if (this.UpdateDialog != "") {
            this.UpdateDialog.Destroy()
            this.UpdateDialog := ""
            this.UpdateDialogParams := ""
        }

        localVersion := params.localVersion
        remoteVersion := params.remoteVersion
        isManual := params.HasProp("isManual") ? params.isManual : false
        changelogBody := params.HasProp("changelogBody") ? params.changelogBody : ""

        this.UpdateDialogParams := params

        title := I18n.T("ui.updateFoundTitle")
        this.UpdateDialog := Gui(, title)
        this.UpdateDialog.Opt("+Owner")
        this.UpdateDialog.BackColor := "FFFFFF"
        this.UpdateDialog.SetFont("s9", Metrics.FontFor(I18n.GetCurrent()))
        hWnd := this.UpdateDialog.Hwnd
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hWnd, "int", 38, "int*", true, "int", 4)

        if (isManual) {
            message := I18n.T("ui.updateDialogManual", localVersion, remoteVersion)
        } else {
            message := I18n.T("ui.updateDialogAuto", localVersion, remoteVersion)
        }

        ; 按钮宽度按当前语言最长按钮文本估算，对话框宽度随之调整（避免长文案截断）
        btnW := Max(100, Metrics.TextWidth(I18n.T("msg.btnYes")),
            Metrics.TextWidth(I18n.T("msg.btnNo")),
            Metrics.TextWidth(I18n.T("ui.btnIgnoreVersion"))) + 18
        btnH := 28
        btnGap := 14
        startX := 20
        dialogW := startX * 2 + btnW * 3 + btnGap * 2

        ; 先加文本（有公告时加只读 Edit），用实际位置计算按钮行 Y 与窗口高度
        lastCtrl := this.UpdateDialog.Add("Text", "x" startX " y15 w" (dialogW - startX * 2), message)
        if (changelogBody != "") {
            ; 有更新内容时显示 Edit 控件
            lastCtrl := this.UpdateDialog.Add("Edit", "x" startX " y+10 w" (dialogW - startX * 2) " h200 ReadOnly +VScroll", changelogBody)
        }
        lastCtrl.GetPos(, &lastY, , &lastH)
        btnY := lastY + lastH + 12
        dialogH := btnY + btnH + 14

        btnYes := this.UpdateDialog.Add("Button", "x" startX " y" btnY " w" btnW " h" btnH " Default", I18n.T("msg.btnYes"))
        btnNo := this.UpdateDialog.Add("Button", "x" (startX + btnW + btnGap) " y" btnY " w" btnW " h" btnH, I18n.T("msg.btnNo"))
        btnIgnore := this.UpdateDialog.Add("Button", "x" (startX + (btnW + btnGap) * 2) " y" btnY " w" btnW " h" btnH, I18n.T("ui.btnIgnoreVersion"))

        btnYes.OnEvent("Click", (*) => this.OnUpdateYes())
        btnNo.OnEvent("Click", (*) => this.OnUpdateNo())
        btnIgnore.OnEvent("Click", (*) => this.OnUpdateIgnore())

        this.UpdateDialog.Show("w" dialogW " h" dialogH " Center")

        btnYes.Focus

        DllCall("RedrawWindow", "ptr", hWnd, "ptr", 0, "ptr", 0, "uint", 0x0103)
    }

    ; 点击"是"按钮
    static OnUpdateYes() {
        params := this.UpdateDialogParams
        Logger.Info("UpdateUI", "用户确认更新：" params.remoteVersion)
        this.UpdateDialog.Destroy()
        this.UpdateDialog := ""
        this.UpdateDialogParams := ""
        EventBus.Publish("UpdateConfirmRequested", params)
    }

    ; 点击"否"按钮
    static OnUpdateNo() {
        params := this.UpdateDialogParams
        Logger.Info("UpdateUI", "用户拒绝更新：" params.remoteVersion)
        this.UpdateDialog.Destroy()
        this.UpdateDialog := ""
        this.UpdateDialogParams := ""
        ; UpdateDismissed 为孤儿事件，已删除；拒绝更新无需额外处理
    }

    ; 点击"忽略此版本"按钮
    static OnUpdateIgnore() {
        params := this.UpdateDialogParams
        Logger.Info("UpdateUI", "用户忽略版本 " params.remoteVersion " 的更新提示")
        this.UpdateDialog.Destroy()
        this.UpdateDialog := ""
        this.UpdateDialogParams := ""
        EventBus.Publish("UpdateIgnoreRequested", params)
    }

    ; 处理检查完成事件：仅手动检查时展示结果弹窗
    static _OnUpdateCheckCompleted(data) {
        if (!data.isManual)
            return
        switch data.status {
            case "up_to_date":
                this.ShowUpToDateDialog(data.HasProp("localVersion") ? data.localVersion : "")
            case "check_failed":
            case "rate_limited":
            case "token_invalid":
                this.ShowCheckFailedDialog(
                    data.HasProp("message") ? data.message : "",
                    data.HasProp("suggestToken") ? data.suggestToken : false)
        }
    }

    ; 处理下载完成事件
    static _OnDownloadCompleted(data) {
        this.CloseDownloadingDialog()
        this.ShowDownloadCompleteDialog()
    }

    ; 处理下载失败事件
    static _OnDownloadFailed(data) {
        this.CloseDownloadingDialog()
        this.ShowDownloadFailedDialog(data.HasProp("reason") ? data.reason : "")
    }

    ; 处理下载取消完成事件
    static _OnDownloadCancelled() {
        this.CloseDownloadingDialog()
        this.ShowDownloadCancelledDialog()
    }

    ; 显示已是最新版本的提示
    static ShowUpToDateDialog(version) {
        MessageBox.Info(I18n.T("msg.upToDate", version), I18n.T("msg.noUpdateTitle"))
    }

    ; 显示更新检查失败的提示
    static ShowCheckFailedDialog(message := "", suggestToken := false) {
        if (message = "") {
            message := I18n.T("msg.checkUpdateFailedDefault")
        }

        if (suggestToken) {
            ; 显示带有Token配置引导的对话框
            result := MessageBox.Confirm(message "`n`n" I18n.T("msg.configureTokenConfirm"), I18n.T("msg.checkFailedTitle"))
            if (result = "Yes") {
                ; 打开设置界面
                EventBus.Publish("SettingsShowRequested")
            }
        } else {
            MessageBox.Error(message, I18n.T("msg.checkFailedTitle"))
        }
    }

    ; 显示正在下载的提示（带取消按钮和进度条）
    ; retryCount: 重试次数（0表示首次下载，1+表示重试）
    ; reason: 上次失败的简要原因（重试时展示给用户，非空才显示）
    static ShowDownloadingDialog(retryCount := 0, reason := "") {
        ; 关闭已存在的下载对话框
        this.CloseDownloadingDialog()

        ; 创建非模态GUI窗口
        title := I18n.T("ui.downloadingTitle")
        this.DownloadingDialog := Gui(, title)
        this.DownloadingDialog.Opt("+AlwaysOnTop +Owner")
        this.DownloadingDialog.BackColor := "FFFFFF"
        this.DownloadingDialog.SetFont("s9", Metrics.FontFor(I18n.GetCurrent()))
        hWnd := this.DownloadingDialog.Hwnd
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hWnd, "int", 38, "int*", true, "int", 4)

        ; 根据重试次数显示不同消息（reason 存在时拼入提示；窗口高度按控件实际位置动态计算）
        if (retryCount = 0) {
            message := I18n.T("ui.downloadingMessage")
        } else {
            message := I18n.T("ui.downloadingRetryMessage", retryCount)
            if (reason != "")
                message .= "`n" I18n.T("ui.lastFailReason", reason)
        }

        ; 按钮宽度按当前语言最长按钮文本估算；对话框宽度随之调整（避免长文案截断）
        btnW := Max(110, Metrics.TextWidth(I18n.T("ui.btnManualDownload")),
            Metrics.TextWidth(I18n.T("ui.btnCancelDownload"))) + 18
        btnH := 26
        padding := 20
        btnGap := 12
        dialogW := padding * 2 + btnW * 2 + btnGap
        textW := dialogW - padding * 2

        ; 添加文本（指定宽度但无高度时自动换行增高，后续控件跟随实际位置）
        this.DownloadingDialog.Add("Text", "x" padding " y15 w" textW " Center vDownloadText", message)
        ; 进度条
        this.DownloadingProgressBar := this.DownloadingDialog.Add("Progress", "x" padding " y+8 w" textW " h20 Range0-1000 vProgressBar")
        ; 速度文本
        this.DownloadingSpeedText := this.DownloadingDialog.Add("Text", "x" padding " y+5 w" textW " Center c6b6b6b vSpeedText", "")
        ; 剩余时间文本
        this.DownloadingRemainingText := this.DownloadingDialog.Add("Text", "x" padding " y+0 w" textW " Center c6b6b6b vRemainingText", "")
        ; 已下载文本
        this.DownloadingSizeText := this.DownloadingDialog.Add("Text", "x" padding " y+0 w" textW " Center c6b6b6b vSizeText", "")

        ; 用最后一个文本控件的实际底部计算按钮 Y 与窗口高度，适配任意语言的换行
        this.DownloadingSizeText.GetPos(, &lastY, , &lastH)
        btnY := lastY + lastH + 10

        ; 添加手动下载和取消按钮
        manualBtnX := padding
        cancelBtnX := padding + btnW + btnGap

        manualBtn := this.DownloadingDialog.Add("Button", "x" manualBtnX " y" btnY " w" btnW " h" btnH, I18n.T("ui.btnManualDownload"))
        manualBtn.OnEvent("Click", (*) => this.RequestManualDownload())
        this.DownloadingCancelBtn := this.DownloadingDialog.Add("Button", "x" cancelBtnX " y" btnY " w" btnW " h" btnH, I18n.T("ui.btnCancelDownload"))
        this.DownloadingCancelBtn.OnEvent("Click", (*) => this.OnDownloadCancel())
        this.DownloadingDialog.OnEvent("Close", (*) => this.OnDownloadCancel())

        ; 显示对话框（非模态，不阻塞；高度按实际布局动态计算）
        dialogHeight := btnY + btnH + 14
        this.DownloadingDialog.Show("w" dialogW " h" dialogHeight " Center")
    }

    ; 手动下载唯一发布点：GuiManager 与下载对话框按钮都经由这里请求 Updater 打开下载地址页面
    static RequestManualDownload(url := "") {
        EventBus.Publish("UpdateManualDownloadRequested", {url: url})
    }

    ; 下载取消按钮点击事件
    static OnDownloadCancel() {
        ; 更新UI显示取消状态
        if (this.DownloadingDialog != "") {
            try {
                ; 禁用取消按钮，防止重复点击
                this.DownloadingCancelBtn.Opt("+Disabled")
                ; 更新文本为取消中
                this.DownloadingDialog["DownloadText"].Value := I18n.T("ui.cancellingDownload")
            }
        }
        ; 发布取消命令
        EventBus.Publish("UpdateDownloadCancelRequested")
    }

    ; 显示正在切换更新源的提示（复用下载窗口，非模态，不阻塞降级检查）
    static ShowFallbackNotice() {
        if (this.DownloadingDialog != "") {
            try this.DownloadingDialog["DownloadText"].Value := I18n.T("ui.switchingSource")
        }
    }

    ; 关闭下载对话框
    static CloseDownloadingDialog() {
        if (this.DownloadingDialog != "") {
            try this.DownloadingDialog.Destroy()
            this.DownloadingDialog := ""
            this.DownloadingCancelBtn := ""
            this.DownloadingProgressBar := ""
            this.DownloadingSpeedText := ""
            this.DownloadingRemainingText := ""
            this.DownloadingSizeText := ""
        }
    }

    ; 更新下载进度显示
    ; data: {total, loaded, speed} — total为0时表示未知大小
    static UpdateDownloadProgress(data) {
        if (this.DownloadingDialog = "")
            return

        total := data.total
        loaded := data.loaded
        speedBytes := data.speed

        ; 更新进度条 (Range0-1000，支持0.1%精度)
        try {
            if (total > 0) {
                percentage := loaded * 1000 / total
                this.DownloadingProgressBar.Value := Max(1, Min(percentage, 1000))
            }
        }

        ; 更新速度文本
        try {
            speedText := I18n.T("ui.downloadSpeed", FormatSpeed(speedBytes))
            this.DownloadingSpeedText.Value := speedText
        }

        ; 更新剩余时间
        try {
            if (total > 0 && loaded < total && speedBytes > 0) {
                remainingSeconds := (total - loaded) / speedBytes
                remainingText := I18n.T("ui.estimatedRemaining", FormatDuration(remainingSeconds))
            } else if (loaded > 0) {
                remainingText := I18n.T("ui.estimatedRemainingCalc")
            } else {
                remainingText := ""
            }
            this.DownloadingRemainingText.Value := remainingText
        }

        ; 更新大小文本
        try {
            if (total > 0) {
                sizeText := I18n.T("ui.downloadedSizeTotal", FormatSize(loaded), FormatSize(total))
            } else {
                sizeText := I18n.T("ui.downloadedSize", FormatSize(loaded))
            }
            this.DownloadingSizeText.Value := sizeText
        }
    }

    ; 显示下载完成的提示
    static ShowDownloadCompleteDialog() {
        MessageBox.Info(I18n.T("msg.downloadComplete"), I18n.T("msg.downloadCompleteTitle"))
    }

    ; 显示下载失败的提示
    static ShowDownloadFailedDialog(message := "") {
        if (message = "") {
            message := I18n.T("msg.downloadUpdateFailedDefault")
        }
        MessageBox.Error(message, I18n.T("msg.downloadFailedTitle"))
    }

    ; 显示下载取消的提示
    static ShowDownloadCancelledDialog() {
        MessageBox.Info(I18n.T("msg.downloadCancelled"), I18n.T("msg.downloadCancelledTitle"))
    }

    ; 显示自动更新已禁用的提示
    static ShowAutoUpdateDisabledDialog() {
        MessageBox.Info(I18n.T("msg.autoUpdateDisabled"), I18n.T("msg.hintTitle"))
    }
}


; 格式化文件大小
FormatSize(bytes) {
    if (bytes < 1024)
        return bytes " B"
    else if (bytes < 1048576)
        return Format("{:.1f}", bytes / 1024) " KB"
    else if (bytes < 1073741824)
        return Format("{:.2f}", bytes / 1048576) " MB"
    else
        return Format("{:.2f}", bytes / 1073741824) " GB"
}

; 格式化下载速度
FormatSpeed(bytesPerSec) {
    if (bytesPerSec < 1024)
        return Format("{:.0f}", bytesPerSec) " B/s"
    else if (bytesPerSec < 1048576)
        return Format("{:.1f}", bytesPerSec / 1024) " KB/s"
    else
        return Format("{:.2f}", bytesPerSec / 1048576) " MB/s"
}

; 格式化剩余时间（秒）
FormatDuration(totalSeconds) {
    totalSeconds := Integer(totalSeconds)
    if (totalSeconds < 0)
        return I18n.T("ui.calculating")
    if (totalSeconds < 60)
        return totalSeconds "s"
    if (totalSeconds < 3600) {
        minutes := totalSeconds // 60
        secs := Mod(totalSeconds, 60)
        return minutes "m " secs "s"
    }
    hours := totalSeconds // 3600
    minutes := Mod(totalSeconds, 60) // 60
    return hours "h " minutes "m"
}
