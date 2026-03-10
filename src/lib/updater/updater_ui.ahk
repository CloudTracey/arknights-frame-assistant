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
    
    ; 显示正在下载的提示（带取消按钮）
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
        this.DownloadingDialog.Add("Text", "x20 y20 w300 Center vDownloadText", message)

        ; 添加手动下载渠道
        manualBtnW := 80
        manualBtnH := 26
        padding := 70
        manualBtnY := 60
        ; 手动下载按钮 - 左下角
        manualBtn := this.DownloadingDialog.Add("Button", "x" padding " y" manualBtnY " w" manualBtnW " h" manualBtnH, "手动下载(&M)")
        manualBtn.OnEvent("Click", (*) => EventBus.Publish("OnManualDownload"))
        ; 取消下载按钮 - 右下角
        cancelBtnX := 340 - padding - manualBtnW
        this.DownloadingCancelBtn := this.DownloadingDialog.Add("Button", "x" cancelBtnX " y" manualBtnY " w" manualBtnW " h" manualBtnH, "取消下载(&C)")
        this.DownloadingCancelBtn.OnEvent("Click", (*) => this.OnDownloadCancel())

        ; 显示对话框（非模态，不阻塞）
        this.DownloadingDialog.Show("w340 h110 Center")
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