; == 游戏状态监控 ==
; 自动退出计时器
SetTimer CheckGameStatus, 1000

; 检查游戏状态
CheckGameStatus() {
    if (Config.GetImportant("AutoClose") != "1")
        return
    if WinExist("ahk_exe Arknights.exe") {
        State.GameHasStarted := true
    }
    else {
        if (State.GameHasStarted == true) {
            ExitApp
        }
    }
}
