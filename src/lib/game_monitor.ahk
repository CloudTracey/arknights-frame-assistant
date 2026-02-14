; == 游戏状态监控 ==
; 自动退出计时器
SetTimer CheckGameStatus, 1000

; 检查游戏状态
CheckGameStatus() {
    global GameHasStarted
    if (ImportantSettings["AutoClose"] != "1")
        return
    if WinExist("ahk_exe Arknights.exe") {
        GameHasStarted := true
    }
    else {
        if (GameHasStarted == true) {
            ExitApp
        }
    }
}
