; == 托盘提示工具 ==
; base 层托盘提示封装，供 core 与 UI 统一使用。

; 隐藏 TrayTip
HideTrayTip() {
    TrayTip
}

; 显示 TrayTip（包装 AHK 内建 TrayTip，避免 core 层直接散落内建调用）
; Debug 记录（标题+消息前缀截断）：用户反馈"没看到提示"时可核对通知是否真的发出。
ShowTrayTip(message, title := "", options := "") {
    Logger.Debug("Tray", "弹出托盘提示 title=" title " message=" SubStr(message, 1, 120))
    TrayTip(message, title, options)
}
