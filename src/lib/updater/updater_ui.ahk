; == 更新UI模块 ==

class UpdateUI {
    ; 初始化：订阅事件
    static Init() {
        ; 订阅手动下载
        EventBus.Subscribe("OnManualDownload", (*) => this.OnManualDownload())
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
        ; 如果对话框已存在，先销毁旧的
        if (this.UpdateDialog != "") {
            this.UpdateDialog.Destroy()
            this.UpdateDialog := ""
            this.UpdateDialogParams := ""
        }
        
        localVersion := params.localVersion
        remoteVersion := params.remoteVersion
        isManual := params.HasProp("isManual") ? params.isManual : false
        
        ; 保存参数供按钮事件使用
        this.UpdateDialogParams := params
        
        ; 创建自定义GUI对话框
        title := "发现新版本"
        this.UpdateDialog := Gui(, title)
        this.UpdateDialog.Opt("+Owner")
        this.UpdateDialog.BackColor := "FFFFFF"
        this.UpdateDialog.SetFont("s9", "Microsoft YaHei UI")
        hWnd := this.UpdateDialog.Hwnd
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hWnd, "int", 38, "int*", true, "int", 4)
        
        
        ; 添加图标和消息文本
        if (isManual) {
            message := "当前版本: " localVersion "`n最新版本: " remoteVersion "`n`n是否立即更新？"
        } else {
            message := "检测到新版本可用！`n当前版本: " localVersion "`n最新版本: " remoteVersion "`n`n是否立即更新？"
        }
        this.UpdateDialog.Add("Text", "x60 y20 w320", message)
        
        ; 计算按钮位置
        btnW := 100
        btnH := 28
        dialogW := 400
        startX := (dialogW - (btnW * 3 + 20)) // 2
        btnY := 120
        
        ; 添加三个按钮
        btnYes := this.UpdateDialog.Add("Button", "x" startX " y" btnY " w" btnW " h" btnH " Default", "是(&Y)")
        btnNo := this.UpdateDialog.Add("Button", "x" (startX + btnW + 10) " y" btnY " w" btnW " h" btnH, "否(&N)")
        btnIgnore := this.UpdateDialog.Add("Button", "x" (startX + (btnW + 10) * 2) " y" btnY " w" btnW " h" btnH, "忽略此版本(&I)")
        
        ; 绑定按钮事件
        btnYes.OnEvent("Click", (*) => this.OnUpdateYes())
        btnNo.OnEvent("Click", (*) => this.OnUpdateNo())
        btnIgnore.OnEvent("Click", (*) => this.OnUpdateIgnore())
        
        ; 显示对话框
        this.UpdateDialog.Show("w" dialogW " h170 Center")
    }
    
    ; 点击"是"按钮
    static OnUpdateYes() {
        params := this.UpdateDialogParams
        this.UpdateDialog.Destroy()
        this.UpdateDialog := ""
        this.UpdateDialogParams := ""
        EventBus.Publish("UpdateConfirmed", params)
    }
    
    ; 点击"否"按钮
    static OnUpdateNo() {
        params := this.UpdateDialogParams
        this.UpdateDialog.Destroy()
        this.UpdateDialog := ""
        this.UpdateDialogParams := ""
        EventBus.Publish("UpdateDismissed", params)
    }
    
    ; 点击"忽略此版本"按钮
    static OnUpdateIgnore() {
        params := this.UpdateDialogParams
        this.UpdateDialog.Destroy()
        this.UpdateDialog := ""
        this.UpdateDialogParams := ""
        EventBus.Publish("UpdateIgnored", params)
    }
    
    ; 显示已是最新版本的提示
    static ShowUpToDateDialog(version) {
        MessageBox.Info("当前版本 " version " 已是最新版本。", "无需更新")
    }
    
    ; 显示更新检查失败的提示
    static ShowCheckFailedDialog(message := "", suggestToken := false) {
        if (message = "") {
            message := "检查更新失败，请检查网络连接后重试。"
        }
        
        if (suggestToken) {
            ; 显示带有Token配置引导的对话框
            result := MessageBox.Confirm(message "`n`n是否现在配置GitHub Token？", "检查失败")
            if (result = "Yes") {
                ; 打开设置界面
                GuiManager.Show()
            }
        } else {
            MessageBox.Error(message, "检查失败")
        }
    }
    
    ; 显示正在下载的提示（带取消按钮和进度条）
    ; retryCount: 重试次数（0表示首次下载，1+表示重试）
    static ShowDownloadingDialog(retryCount := 0) {
        ; 关闭已存在的下载对话框
        this.CloseDownloadingDialog()
        
        ; 创建非模态GUI窗口
        title := "下载中"
        this.DownloadingDialog := Gui(, title)
        this.DownloadingDialog.Opt("+AlwaysOnTop +Owner")
        this.DownloadingDialog.BackColor := "FFFFFF"
        this.DownloadingDialog.SetFont("s9", "Microsoft YaHei UI")
        hWnd := this.DownloadingDialog.Hwnd
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hWnd, "int", 38, "int*", true, "int", 4)
        
        ; 根据重试次数显示不同消息
        if (retryCount = 0) {
            message := "正在下载更新，请稍候..."
        } else {
            message := "正在下载更新，请稍候...`n（第 " retryCount " 次重试，如多次下载失败请尝试手动下载）"
        }
        
        ; 添加文本
        this.DownloadingDialog.Add("Text", "x20 y15 w300 Center vDownloadText", message)
        ; 进度条
        this.DownloadingProgressBar := this.DownloadingDialog.Add("Progress", "x20 y+8 w300 h20 Range0-1000 vProgressBar")
        ; 速度文本
        this.DownloadingSpeedText := this.DownloadingDialog.Add("Text", "x20 y+5 w300 Center c6b6b6b vSpeedText", "")
        ; 剩余时间文本
        this.DownloadingRemainingText := this.DownloadingDialog.Add("Text", "x20 y+0 w300 Center c6b6b6b vRemainingText", "")
        ; 已下载文本
        this.DownloadingSizeText := this.DownloadingDialog.Add("Text", "x20 y+0 w300 Center c6b6b6b vSizeText", "")

        ; 添加手动下载和取消按钮
        manualBtnW := 80
        manualBtnH := 26
        padding := 70
        cancelBtnX := 340 - padding - manualBtnW
        
        manualBtn := this.DownloadingDialog.Add("Button", "x" padding " y+15 w" manualBtnW " h" manualBtnH, "手动下载(&M)")
        manualBtn.OnEvent("Click", (*) => EventBus.Publish("OnManualDownload"))
        this.DownloadingCancelBtn := this.DownloadingDialog.Add("Button", "x" cancelBtnX " yp w" manualBtnW " h" manualBtnH, "取消下载(&C)")
        this.DownloadingCancelBtn.OnEvent("Click", (*) => this.OnDownloadCancel())

        ; 显示对话框（非模态，不阻塞）
        this.DownloadingDialog.Show("w340 h190 Center")
    }
    
    ; 手动下载按钮点击事件
    static OnManualDownload() {
        ; 打开浏览器访问下载地址页面
        Run("https://www.bilibili.com/opus/1178139405104185363")
        ; 关闭下载对话框
        try this.CloseDownloadingDialog()
    }

    ; 下载取消按钮点击事件
    static OnDownloadCancel() {
        ; 更新UI显示取消状态
        if (this.DownloadingDialog != "") {
            try {
                ; 禁用取消按钮，防止重复点击
                this.DownloadingCancelBtn.Opt("+Disabled")
                ; 更新文本为取消中
                this.DownloadingDialog["DownloadText"].Value := "正在取消下载..."
            }
        }
        ; 发布取消事件
        EventBus.Publish("UpdateDownloadCancelled")
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
            speedText := "下载速度: " FormatSpeed(speedBytes)
            this.DownloadingSpeedText.Value := speedText
        }
        
        ; 更新剩余时间
        try {
            if (total > 0 && loaded < total && speedBytes > 0) {
                remainingSeconds := (total - loaded) / speedBytes
                remainingText := "预计剩余: " FormatDuration(remainingSeconds)
            } else if (loaded > 0) {
                remainingText := "预计剩余: 计算中..."
            } else {
                remainingText := ""
            }
            this.DownloadingRemainingText.Value := remainingText
        }
        
        ; 更新大小文本
        try {
            if (total > 0) {
                sizeText := "已下载: " FormatSize(loaded) " / " FormatSize(total)
            } else {
                sizeText := "已下载: " FormatSize(loaded)
            }
            this.DownloadingSizeText.Value := sizeText
        }
    }
    
    ; 显示下载完成的提示
    static ShowDownloadCompleteDialog() {
        MessageBox.Info("下载完成！程序将在重启后应用更新。", "下载完成")
    }
    
    ; 显示下载失败的提示
    static ShowDownloadFailedDialog(message := "") {
        if (message = "") {
            message := "下载更新失败，请检查网络连接后重试。"
        }
        MessageBox.Error(message, "下载失败")
    }
    
    ; 显示下载取消的提示
    static ShowDownloadCancelledDialog() {
        MessageBox.Info("下载已取消。", "下载取消")
    }
    
    ; 显示自动更新已禁用的提示
    static ShowAutoUpdateDisabledDialog() {
        MessageBox.Info("自动检查更新已禁用。`n如需开启，请在配置文件中设置 AutoUpdate=1", "提示")
    }
}

; 初始化更新UI
UpdateUI.Init()

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
        return "计算中..."
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