; == 游戏状态监控 ==
; 自动退出计时器
SetTimer CheckGameStatus, 400

; 检查游戏状态
CheckGameStatus() {
    ; AutoExit 运行时读 INI 实际保存值（GUI 未应用修改不影响）；检测到 AutoExit 刚被应用开启时重置游戏运行记录，
    ; 避免应用设置后立即因"游戏曾运行过"的历史记录触发自动退出
    static PrevAutoExit := ""
    autoExit := Config.ReadImportantFromIni("AutoExit")
    if (autoExit == "1" && PrevAutoExit != "1" && PrevAutoExit != "") {
        State.GameHasStarted := false
        Logger.Info("GameMonitor", "AutoExit 开启，重置游戏运行记录")
    }
    PrevAutoExit := autoExit

    ; 自动退出
    if (autoExit == "1") {
        if ProcessExist("Arknights.exe") {
            State.GameHasStarted := true
        }
        else {
            if (State.GameHasStarted == true) {
                Logger.Info("GameMonitor", "检测到游戏进程已退出，自动退出 AFA")
                ExitApp
            }
        }
    }

    ; 自动开局暂停（运行时读 INI，同 AutoExit 理由）
    if (Config.ReadImportantFromIni("AutoBeginPause") == "1" && WinActive("ahk_exe Arknights.exe")) {
        ; 寻找黑屏：遍历 17 个全屏采样点，允许 1 个点被游戏鼠标遮挡
        if (State.BlackScreenDetected == false) {
            points := BlackScreenPoints()
            if !points
                return
            try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
            missCount := 0
            for point in points {
                if !PixelSearch(&FoundX, &FoundY, point.x, point.y, point.x, point.y, 0x000000, 10) {
                    missCount++
                    if (missCount > 3)
                        break
                }
            }
            if (missCount <= 1) {
                State.BlackScreenDetected := true
                Logger.Debug("GameMonitor", "检测到黑屏，可能是进入关卡前的加载，开始识别 Loading")
                SetTimer StopSearchLoadingTimeout, -8000
                SetTimer CheckGameStatus, 200
            }
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        }
        ; 识别 Loading：通过 Loading... 文字区域颜色判断场景类型
        if (State.BlackScreenDetected == true && State.ReadyForPause == false) {
            try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
            scanLines := LoadingPosition()
            if !scanLines {
                try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
                return
            }
            line1 := scanLines[1]
            if PixelSearch(&FoundX, &FoundY, line1.lx, line1.y, line1.rx, line1.y, 0xA60000, 50) {
                Logger.Debug("GameMonitor", "识别到红色按钮，停止 Loading 搜索")
                SetTimer StopSearchLoadingTimeout, 0
                State.BlackScreenDetected := false
            } else if PixelSearch(&FoundX, &FoundY, line1.lx, line1.y, line1.rx, line1.y, 0x0070a3, 50) {
                Logger.Debug("GameMonitor", "识别到蓝色按钮，停止 Loading 搜索")
                SetTimer StopSearchLoadingTimeout, 0
                State.BlackScreenDetected := false
            } else {
                allWhite := true
                for line in scanLines {
                    if !PixelSearch(&FoundX, &FoundY, line.lx, line.y, line.rx, line.y, 0xFFFFFF, 0) {
                        allWhite := false
                        break
                    }
                }
                if (allWhite) {
                    Logger.Debug("GameMonitor", "识别到白色 Loading，准备自动暂停")
                    State.ReadyForPause := true
                    SetTimer StopSearchLoadingTimeout, 0
                    SetTimer ActionBeginPause, -2000
                }
            }
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        }
    }
}

; ==工具函数==
; 获取Loading...颜色识别位置（三条水平扫描线）
LoadingPosition() {
    if !SafeWinGetClientPos(&ww, &wh)
        return false
    ; 第一条：右下 Loading... 文字
    L1LX := ww * 0.835156, L1RX := ww * 0.976953, L1Y := wh * 0.953472
    ; 第二条：底部中央
    L2LX := ww * 0.469531, L2RX := ww * 0.526562, L2Y := wh * 0.953472
    ; 第三条：屏幕中央
    L3LX := ww * 0.413671, L3RX := ww * 0.582421, L3Y := wh * 0.520833
    return [
        {lx: L1LX, rx: L1RX, y: L1Y},
        {lx: L2LX, rx: L2RX, y: L2Y},
        {lx: L3LX, rx: L3RX, y: L3Y}
    ]
}
; 获取全屏 17 点黑屏采样位置（覆盖四角、四边、内部、中心）
BlackScreenPoints() {
    if !SafeWinGetClientPos(&ww, &wh)
        return false
    x5 := ww * 0.05, x25 := ww * 0.25, x50 := ww * 0.5, x75 := ww * 0.75, x95 := ww * 0.95
    y5 := wh * 0.05, y25 := wh * 0.25, y50 := wh * 0.5, y75 := wh * 0.75, y95 := wh * 0.95
    return [
        ; 上边（左→右 5 点）
        {x: x5, y: y5}, {x: x25, y: y5}, {x: x50, y: y5}, {x: x75, y: y5}, {x: x95, y: y5},
        ; 下边（左→右 5 点）
        {x: x5, y: y95}, {x: x25, y: y95}, {x: x50, y: y95}, {x: x75, y: y95}, {x: x95, y: y95},
        ; 左边中点、右边中点
        {x: x5, y: y50}, {x: x95, y: y50},
        ; 内部四点和正中心
        {x: x25, y: y25}, {x: x75, y: y25},
        {x: x50, y: y50},
        {x: x25, y: y75}, {x: x75, y: y75}
    ]
}
; 停止搜索Loading
StopSearchLoading() {
    SetTimer CheckGameStatus, 400
    State.BlackScreenDetected := false
}
; 黑屏识别超时（8秒未确认 Loading 状态），停止搜索并记录提示
StopSearchLoadingTimeout() {
    Logger.Info("GameMonitor", "黑屏识别超时（8秒未确认 Loading），并非进关卡，停止搜索")
    StopSearchLoading()
}
