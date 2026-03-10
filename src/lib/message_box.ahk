; == 统一消息框 ==
; 替代 MsgBox，提供统一的样式和大小

class MessageBox {
    ; 窗口尺寸常量
    static DefaultWidth := 340
    static MinHeight := 120
    static MaxHeight := 400
    
    ; 图标类型
    static ICON_INFO := "info"
    static ICON_WARNING := "warning"
    static ICON_ERROR := "error"
    static ICON_QUESTION := "question"
    
    ; 按钮类型
    static BTN_OK := "OK"
    static BTN_OK_CANCEL := "OKCancel"
    static BTN_YES_NO := "YesNo"
    static BTN_YES_NO_CANCEL := "YesNoCancel"
    
    ; 存储当前对话框实例
    static CurrentDialog := ""
    
    ; 显示消息框（同步模式，阻塞等待结果）
    ; 返回: "OK", "Cancel", "Yes", "No", "Close"
    static Show(message, title := "", options := "") {
        ; 创建结果变量
        result := ""
        
        ; 显示对话框
        this._CreateDialog(message, title, options, (r) => result := r)
        
        ; 等待用户响应
        while (result = "") {
            Sleep(10)
        }
        
        return result
    }
    
    ; 显示消息框（异步模式，带回调）
    ; callback: 回调函数，接收结果参数
    static ShowAsync(message, title := "", options := "", callback := "") {
        return this._CreateDialog(message, title, options, callback)
    }
    
    ; 显示信息框
    static Info(message, title := "提示") {
        return this.Show(message, title, "Iconi")
    }
    
    ; 显示警告框
    static Warning(message, title := "警告") {
        return this.Show(message, title, "Icon!")
    }
    
    ; 显示错误框
    static Error(message, title := "错误") {
        return this.Show(message, title, "Iconx")
    }
    
    ; 显示确认框（Yes/No）
    static Confirm(message, title := "确认") {
        return this.Show(message, title, "YesNo Icon?")
    }
    
    ; 显示确认框（OK/Cancel）
    static ConfirmCancel(message, title := "确认") {
        return this.Show(message, title, "OKCancel Icon?")
    }
    
    ; 关闭当前对话框
    static Close() {
        if (this.CurrentDialog != "") {
            try this.CurrentDialog.Destroy()
            this.CurrentDialog := ""
        }
    }
    
    ; 内部：创建对话框
    static _CreateDialog(message, title, options, callback) {
        ; 如果已有对话框存在，先关闭
        if (this.CurrentDialog != "") {
            try this.CurrentDialog.Destroy()
        }
        
        ; 解析选项
        parsedOptions := this._ParseOptions(options)
        
        ; 创建GUI
        dialog := Gui(, title != "" ? title : "提示")
        dialog.Opt("+AlwaysOnTop -MinimizeBox +Owner")
        dialog.BackColor := "FFFFFF"
        dialog.SetFont("s10", "Microsoft YaHei UI")
        hWnd := dialog.Hwnd
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hWnd, "int", 38, "int*", true, "int", 4)
        
        ; 添加图标
        ; iconX := 25
        ; iconY := 25
        ; iconSize := 32
        ; hasIcon := false
        
        ; if (parsedOptions.icon != "") {
        ;     iconChar := this._GetIconCharacter(parsedOptions.icon)
        ;     if (iconChar != "") {
        ;         dialog.SetFont("s28", "Segoe UI Symbol")
        ;         iconCtrl := dialog.Add("Text", "x" iconX " y" iconY " w" iconSize " h" iconSize " Center", iconChar)
        ;         hasIcon := true
        ;         dialog.SetFont("s10", "Microsoft YaHei UI")
        ;     }
        ; }
        
        ; 计算文本区域
        ; textX := hasIcon ? iconX + iconSize + 20 : 30
        textX := 30
        textY := 30
        textW := this.DefaultWidth - textX - 30
        
        ; 添加消息文本
        dialog.SetFont("s9", "Microsoft YaHei UI")
        textCtrl := dialog.Add("Text", "x" textX " y" textY " w" textW, message)
        textCtrl.Opt("Center")
        textCtrl.GetPos(, , , &textH)
        
        ; 计算实际窗口高度
        contentHeight := textY + textH + 70
        contentHeight := Max(contentHeight, this.MinHeight)
        contentHeight := Min(contentHeight, this.MaxHeight)
        
        ; 计算按钮位置
        btnW := 90
        btnH := 30
        btnY := contentHeight - 50
        
        ; 根据按钮类型创建按钮
        buttons := this._CreateButtons(dialog, parsedOptions.buttons, btnW, btnH, btnY)
        
        ; 存储回调引用
        dialog.Callback := callback
        
        ; 绑定按钮事件
        this._BindButtonEvents(dialog, buttons)
        
        ; 保存引用
        this.CurrentDialog := dialog
        
        ; 显示窗口（居中）
        dialog.Show("w" this.DefaultWidth " h" contentHeight " Center")
        
        ; 设置焦点到默认按钮
        if (buttons.HasProp("DefaultBtn") && buttons.DefaultBtn != "") {
            buttons.DefaultBtn.Focus()
        }
        
        return dialog
    }
    
    ; 内部：解析选项字符串
    static _ParseOptions(options) {
        result := {icon: "", buttons: "OK"}
        
        if (options = "")
            return result
            
        ; 解析图标
        if (InStr(options, "Iconi"))
            result.icon := this.ICON_INFO
        else if (InStr(options, "Icon!"))
            result.icon := this.ICON_WARNING
        else if (InStr(options, "Iconx"))
            result.icon := this.ICON_ERROR
        else if (InStr(options, "Icon?"))
            result.icon := this.ICON_QUESTION
            
        ; 解析按钮类型
        if (InStr(options, "YesNoCancel"))
            result.buttons := this.BTN_YES_NO_CANCEL
        else if (InStr(options, "YesNo"))
            result.buttons := this.BTN_YES_NO
        else if (InStr(options, "OKCancel"))
            result.buttons := this.BTN_OK_CANCEL
        else
            result.buttons := this.BTN_OK
            
        return result
    }
    
    ; 内部：获取图标字符（使用 Unicode 表情符号）
    static _GetIconCharacter(iconType) {
        switch iconType {
            case this.ICON_INFO: return "ℹ"  ; 信息图标
            case this.ICON_WARNING: return "⚠"  ; 警告图标
            case this.ICON_ERROR: return "✕"  ; 错误图标
            case this.ICON_QUESTION: return "?"  ; 问号
            default: return ""
        }
    }
    
    ; 内部：创建按钮
    static _CreateButtons(dialog, btnType, btnW, btnH, btnY) {
        buttons := {}
        
        switch btnType {
            case this.BTN_OK:
                btnX := (this.DefaultWidth - btnW) / 2
                buttons.OK := dialog.Add("Button", "x" btnX " y" btnY " w" btnW " h" btnH " Default", "确定")
                buttons.DefaultBtn := buttons.OK
                
            case this.BTN_OK_CANCEL:
                spacing := 20
                totalW := btnW * 2 + spacing
                startX := (this.DefaultWidth - totalW) / 2
                buttons.OK := dialog.Add("Button", "x" startX " y" btnY " w" btnW " h" btnH " Default", "确定")
                buttons.Cancel := dialog.Add("Button", "x" (startX + btnW + spacing) " y" btnY " w" btnW " h" btnH, "取消")
                buttons.DefaultBtn := buttons.OK
                
            case this.BTN_YES_NO:
                spacing := 20
                totalW := btnW * 2 + spacing
                startX := (this.DefaultWidth - totalW) / 2
                buttons.Yes := dialog.Add("Button", "x" startX " y" btnY " w" btnW " h" btnH " Default", "是(&Y)")
                buttons.No := dialog.Add("Button", "x" (startX + btnW + spacing) " y" btnY " w" btnW " h" btnH, "否(&N)")
                buttons.DefaultBtn := buttons.Yes
                
            case this.BTN_YES_NO_CANCEL:
                spacing := 15
                totalW := btnW * 3 + spacing * 2
                startX := (this.DefaultWidth - totalW) / 2
                buttons.Yes := dialog.Add("Button", "x" startX " y" btnY " w" btnW " h" btnH " Default", "是(&Y)")
                buttons.No := dialog.Add("Button", "x" (startX + btnW + spacing) " y" btnY " w" btnW " h" btnH, "否(&N)")
                buttons.Cancel := dialog.Add("Button", "x" (startX + (btnW + spacing) * 2) " y" btnY " w" btnW " h" btnH, "取消(&C)")
                buttons.DefaultBtn := buttons.Yes
        }
        
        return buttons
    }
    
    ; 内部：绑定按钮事件
    static _BindButtonEvents(dialog, buttons) {
        ; 绑定OK按钮
        if (buttons.HasProp("OK")) {
            buttons.OK.OnEvent("Click", (ctrl, *) => this._CloseWithResult(dialog, "OK"))
        }
        
        ; 绑定Cancel按钮
        if (buttons.HasProp("Cancel")) {
            buttons.Cancel.OnEvent("Click", (ctrl, *) => this._CloseWithResult(dialog, "Cancel"))
        }
        
        ; 绑定Yes按钮
        if (buttons.HasProp("Yes")) {
            buttons.Yes.OnEvent("Click", (ctrl, *) => this._CloseWithResult(dialog, "Yes"))
        }
        
        ; 绑定No按钮
        if (buttons.HasProp("No")) {
            buttons.No.OnEvent("Click", (ctrl, *) => this._CloseWithResult(dialog, "No"))
        }
        
        ; 绑定窗口关闭事件
        dialog.OnEvent("Close", (*) => this._CloseWithResult(dialog, "Close"))
    }
    
    ; 内部：关闭对话框并返回结果
    static _CloseWithResult(dialog, result) {
        ; 获取回调
        callback := dialog.Callback
        
        ; 销毁对话框
        try dialog.Destroy()
        if (this.CurrentDialog = dialog) {
            this.CurrentDialog := ""
        }
        
        ; 调用回调
        if (callback != "") {
            callback(result)
        }
    }
}

; 便捷的替代 MsgBox 的函数
MsgBoxEx(message, title := "", options := "") {
    return MessageBox.Show(message, title, options)
}
