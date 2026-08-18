; == 窗口工具 ==
; 从 hotkey_actions.ahk 抽出的 base 层窗口判定函数，供 core 层与 UI 层复用。

; 安全获取明日方舟窗口 Client 区域尺寸，窗口不存在时返回 false 而非抛出 TargetError
SafeWinGetClientPos(&ww, &wh) {
    try {
        WinGetClientPos ,, &ww, &wh, "ahk_exe Arknights.exe"
        return true
    } catch TargetError {
        return false
    }
}

; 判断鼠标是否在 Client 区域内
IsMouseInClient() {
    MouseGetPos , &ypos, &hwnd
    gameHwnd := WinExist("ahk_exe Arknights.exe")
    if !(hwnd == gameHwnd)
        return false
    ; 简单判断会不会点到最小化或者关闭窗口
    if ypos < 0
        return false
    return true
}
