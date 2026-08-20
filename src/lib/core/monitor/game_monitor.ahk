; == 游戏状态监控 ==

class GameMonitor {
    ; SetTimer 需要缓存同一 bound 回调对象，才能正确启停/调速
    static _CheckTimer := ""
    static _TimeoutTimer := ""

    ; 私有状态
    static _GameHasStarted := false
    static _BlackScreenDetected := false
    static _ReadyForPause := false

    ; 启动监控定时器（由 Bootstrap 调用，避免顶层副作用）
    static Start() {
        if (this._CheckTimer = "")
            this._CheckTimer := GameMonitor.CheckGameStatus.Bind(GameMonitor)
        SetTimer this._CheckTimer, 400
    }

    ; 调整主轮询定时器间隔（供内部与 hotkey_actions 复用）
    static SetPollInterval(interval) {
        if (this._CheckTimer = "")
            this._CheckTimer := GameMonitor.CheckGameStatus.Bind(GameMonitor)
        SetTimer this._CheckTimer, interval
    }

    ; 安排/取消黑屏识别超时（同一 bound 回调，避免无法取消）
    static _ScheduleTimeout(ms) {
        if (this._TimeoutTimer = "")
            this._TimeoutTimer := GameMonitor.StopSearchLoadingTimeout.Bind(GameMonitor)
        SetTimer this._TimeoutTimer, ms
    }

    ; 重置游戏运行记录（由 SettingsService/Saver 在需要时调用）
    static ResetRunRecord() {
        this._GameHasStarted := false
    }

    ; 游戏是否曾运行过（供自动退出判断；目前仅内部使用，保留 getter 便于测试/日志）
    static IsGameHasStarted() {
        return this._GameHasStarted
    }

    ; 检查游戏状态
    static CheckGameStatus() {
        ; AutoExit 运行时读 INI 实际保存值（GUI 未应用修改不影响）；检测到 AutoExit 刚被应用开启时重置游戏运行记录，
        ; 避免应用设置后立即因"游戏曾运行过"的历史记录触发自动退出
        static PrevAutoExit := ""
        autoExit := Config.ReadImportantFromIni("AutoExit")
        if (autoExit == "1" && PrevAutoExit != "1" && PrevAutoExit != "") {
            this._GameHasStarted := false
            Logger.Info("GameMonitor", "AutoExit 开启，重置游戏运行记录")
        }
        PrevAutoExit := autoExit

        ; 自动退出
        if (autoExit == "1") {
            if ProcessExist("Arknights.exe") {
                this._GameHasStarted := true
            }
            else {
                if (this._GameHasStarted == true) {
                    Logger.Info("GameMonitor", "检测到游戏进程已退出，自动退出 AFA")
                    ExitApp
                }
            }
        }

        ; 自动开局暂停（运行时读 INI，同 AutoExit 理由）
        if (Config.ReadImportantFromIni("AutoBeginPause") == "1" && WinActive("ahk_exe Arknights.exe")) {
            ; 寻找黑屏：遍历 17 个全屏采样点，允许 1 个点被游戏鼠标遮挡
            if (this._BlackScreenDetected == false) {
                points := GameMonitor.BlackScreenPoints()
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
                    this._BlackScreenDetected := true
                    Logger.Info("GameMonitor", "检测到黑屏，可能是进入关卡前的加载，开始识别 Loading")
                    this._ScheduleTimeout(-8000)
                    this.SetPollInterval(200)
                }
                try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            }
            ; 识别 Loading：通过 Loading... 文字区域颜色判断场景类型
            if (this._BlackScreenDetected == true && this._ReadyForPause == false) {
                try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
                scanLines := GameMonitor.LoadingPosition()
                if !scanLines {
                    try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
                    return
                }
                line1 := scanLines[1]
                if PixelSearch(&FoundX, &FoundY, line1.lx, line1.y, line1.rx, line1.y, 0xA60000, 50) {
                    Logger.Info("GameMonitor", "识别到红色按钮，停止 Loading 搜索")
                    this._ScheduleTimeout(0)
                    this._BlackScreenDetected := false
                } else if PixelSearch(&FoundX, &FoundY, line1.lx, line1.y, line1.rx, line1.y, 0x0070a3, 50) {
                    Logger.Info("GameMonitor", "识别到蓝色按钮，停止 Loading 搜索")
                    this._ScheduleTimeout(0)
                    this._BlackScreenDetected := false
                } else {
                    allWhite := true
                    for line in scanLines {
                        if !PixelSearch(&FoundX, &FoundY, line.lx, line.y, line.rx, line.y, 0xFFFFFF, 0) {
                            allWhite := false
                            break
                        }
                    }
                    if (allWhite) {
                        Logger.Info("GameMonitor", "识别到白色 Loading，准备自动暂停")
                        this._ReadyForPause := true
                        this._ScheduleTimeout(0)
                        SetTimer GameMonitor.ActionBeginPause.Bind(GameMonitor), -2000
                    }
                }
                try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            }
        }
    }

    ; 自动开局暂停（从 hotkey_actions 迁入；内部写私有状态）
    static ActionBeginPause() {
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        PosC := SpeedButtonPositionColor()
        if !PosC {
            Logger.Warn("GameMonitor", "自动暂停：游戏窗口不存在")
            try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
            return
        }
        Logger.Info("GameMonitor", "自动暂停：等待倍速按钮")
        while(true) {
            if PixelSearch(&FoundX, &FoundY, PosC.PBCRX, PosC.PBCUY, PosC.PBCLX, PosC.PBCDY, 0xffffff, 10)
            {
                GameKeys.SendDown("pauseBattle")
                USleep(50)
                GameKeys.SendUp("pauseBattle")
                Logger.Info("GameMonitor", "自动暂停：已暂停")
                ; 为了降低暂停延迟，后置代理指挥识别，识别到是代理指挥时取消暂停
                isProxy := false
                TobC := TakeOverButtonPositions()
                if !TobC {
                    Logger.Warn("GameMonitor", "自动暂停：游戏窗口不存在（代理指挥识别）")
                    this._BlackScreenDetected := false
                    this._ReadyForPause := false
                    this.SetPollInterval(400)
                    break
                }
                ; 接管代理按钮右侧边缘
                if ImageSearch(&OutputVarX, &OutputVarY, TobC.ImageRegion.RLX, TobC.ImageRegion.RUY, TobC.ImageRegion.RRX, TobC.ImageRegion.RDY, "*90 " FileExtractor.TakeOver1Path) or ImageSearch(&OutputVarX, &OutputVarY, TobC.ImageRegion.RLX, TobC.ImageRegion.RUY, TobC.ImageRegion.RRX, TobC.ImageRegion.RDY, "*90 " FileExtractor.TakeOver2Path) {
                    isProxy := true
                }
                ; 接管代理按钮“手”图标拇指
                if !ImageSearch(&OutputVarX, &OutputVarY, TobC.ImageRegion.HLX, TobC.ImageRegion.HUY, TobC.ImageRegion.HRX, TobC.ImageRegion.HDY, "*90 " FileExtractor.TakeOver3Path) {
                    Logger.Debug("GameMonitor", "代理指挥判定：手图标识别失败")
                    isProxy := false
                }
                if isProxy {
                    GameKeys.SendDown("pauseBattle")
                    USleep(50)
                    GameKeys.SendUp("pauseBattle")
                    Logger.Info("GameMonitor", "代理指挥，取消暂停")
                } else {
                    Logger.Info("GameMonitor", "非代理指挥，保持暂停")
                }

                this._BlackScreenDetected := false
                this._ReadyForPause := false
                this.SetPollInterval(400)
                break
            }
        }
        try DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
    }

    ; 获取 Loading... 颜色识别位置（三条水平扫描线）
    static LoadingPosition() {
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
    static BlackScreenPoints() {
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

    ; 停止搜索 Loading
    static StopSearchLoading() {
        this.SetPollInterval(400)
        this._BlackScreenDetected := false
    }

    ; 黑屏识别超时（8秒未确认 Loading 状态），停止搜索并记录提示
    static StopSearchLoadingTimeout() {
        Logger.Info("GameMonitor", "黑屏识别超时（8秒未确认 Loading），并非进关卡，停止搜索")
        GameMonitor.StopSearchLoading()
    }
}
