; == 托盘提示工具 ==
; base 层托盘提示封装，供 core 与 UI 统一使用。

; 隐藏 TrayTip
HideTrayTip() {
    TrayTip
}

; 显示 TrayTip（包装 AHK 内建 TrayTip，避免 core 层直接散落内建调用）
ShowTrayTip(message, title := "", options := "") {
    TrayTip(message, title, options)
}
