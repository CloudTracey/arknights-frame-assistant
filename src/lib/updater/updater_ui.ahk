; == 更新UI模块 ==

class UpdateUI {
    ; 更新对话框实例和参数
    static UpdateDialog := ""
    static UpdateDialogParams := ""
    
    ; 下载对话框实例
    static DownloadingDialog := ""
    
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
        MsgBox("当前版本 " version " 已是最新版本。", "无需更新", "Iconi")
    }
    
    ; 显示更新检查失败的提示
    static ShowCheckFailedDialog(message := "", suggestToken := false) {
        if (message = "") {
            message := "检查更新失败，请检查网络连接后重试。"
        }
        
        if (suggestToken) {
            ; 显示带有Token配置引导的对话框
            result := MsgBox(message "`n`n是否现在配置GitHub Token？", "检查失败", "YesNo Icon!")
            if (result = "Yes") {
                ; 打开设置界面
                GuiManager.Show()
            }
        } else {
            MsgBox(message, "检查失败", "Icon!")
        }
    }
    
    ; 显示正在下载的提示
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
        
        ; 根据重试次数显示不同消息
        if (retryCount = 0) {
            message := "正在下载更新，请稍候..."
        } else {
            message := "正在下载更新，请稍候...`n（第 " retryCount " 次重试）"
        }
        
        ; 添加文本
        this.DownloadingDialog.Add("Text", "x20 y20 w300 Center", message)
        
        ; 显示对话框（非模态，不阻塞）
        this.DownloadingDialog.Show("w340 h80 Center")
    }
    
    ; 关闭下载对话框
    static CloseDownloadingDialog() {
        if (this.DownloadingDialog != "") {
            this.DownloadingDialog.Destroy()
            this.DownloadingDialog := ""
        }
    }
    
    ; 显示下载完成的提示
    static ShowDownloadCompleteDialog() {
        MsgBox("下载完成！程序将在重启后应用更新。", "下载完成", "Iconi")
    }
    
    ; 显示下载失败的提示
    static ShowDownloadFailedDialog(message := "") {
        if (message = "") {
            message := "下载更新失败，请检查网络连接后重试。"
        }
        MsgBox(message, "下载失败", "Icon!")
    }
    
    ; 显示自动更新已禁用的提示
    static ShowAutoUpdateDisabledDialog() {
        MsgBox("自动检查更新已禁用。`n如需开启，请在配置文件中设置 AutoUpdate=1", "提示", "Iconi")
    }
}
