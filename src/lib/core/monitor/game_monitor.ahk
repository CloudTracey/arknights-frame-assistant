; == 游戏状态监控 ==

class GameMonitor {
    ; SetTimer 需要缓存同一 bound 回调对象，才能正确启停/调速
    static _CheckTimer := ""
    static _TimeoutTimer := ""
    static _PauseWaitTimer := ""
    static _PauseWaitTickTimer := ""

    ; 自动暂停「等待倍速按钮」阶段参数（#340）：
    ; 该阶段原为 while(true) 忙等——无 Sleep、无超时，只有找到按钮或游戏进程消失才退出。
    ; 实测单次可占用主线程 86 秒、单场会话累计 206 秒，期间 HotIf 求值全部排队，
    ; 系统据此累计低级钩子超时并最终静默摘除钩子（表现为所有热键失效）。
    ; 改为定时器状态机：每拍只做一次小区域 PixelSearch，其余时间让出主线程。
    static PauseWaitIntervalMs := 30    ; 轮询间隔，兼顾暂停延迟与主线程占用（原忙等≈100% 占用）
    static PauseWaitTimeoutMs := 8000   ; 硬超时，与黑屏识别超时同量级，超时放弃本次自动暂停
    static _PauseWaitDeadline := 0

    ; 私有状态
    static _GameHasStarted := false
    static _BlackScreenDetected := false
    static _ReadyForPause := false

    ; 启动监控定时器（由 Bootstrap 调用，避免顶层副作用）
    static Start() {
        if (this._CheckTimer = "")
            this._CheckTimer := GameMonitor.CheckGameStatus.Bind(GameMonitor)
        SetTimer this._CheckTimer, 400
        EventBus.Subscribe("ForegroundClientChanged", (data) => this._HandleForegroundClientChanged(data))
    }

    static _HandleForegroundClientChanged(data) {
        Logger.Debug("GameMonitor", "前台客户端变化：serverId=" data.serverId ", pid=" data.pid)
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
        ; 慢路径：刷新客户端实例与前台缓存（热键路径不调用本方法）
        GameClientRegistry.Refresh()

        ; AutoExit 运行时读 INI 实际保存值（GUI 未应用修改不影响）；检测到 AutoExit 刚被应用开启时重置游戏运行记录，
        ; 避免应用设置后立即因"游戏曾运行过"的历史记录触发自动退出
        static PrevAutoExit := ""
        autoExit := Config.ReadImportantFromIni("AutoExit")
        if (autoExit == "1" && PrevAutoExit != "1" && PrevAutoExit != "") {
            this._GameHasStarted := false
            Logger.Info("GameMonitor", "AutoExit 开启，重置游戏运行记录")
        }
        PrevAutoExit := autoExit

        ; 自动退出：所有受管客户端都退出才退出 AFA
        if (autoExit == "1") {
            hasClients := GameClientRegistry.HasClients()
            ; 枚举失败时兜底旧判断，避免误退出
            if (!hasClients && GameTarget.ProcessExists())
                hasClients := true
            if (hasClients) {
                this._GameHasStarted := true
            } else {
                if (this._GameHasStarted == true) {
                    Logger.Info("GameMonitor", "检测到所有游戏客户端已退出，自动退出 AFA")
                    ExitApp
                }
            }
        }

        ; 自动开局暂停（运行时读 INI，同 AutoExit 理由）
        if (Config.ReadImportantFromIni("AutoBeginPause") == "1" && GameTarget.IsActive()) {
            ; 寻找黑屏：遍历 17 个全屏采样点，允许 1 个点被游戏鼠标遮挡
            if (this._BlackScreenDetected == false) {
                points := GameMonitor.BlackScreenPoints()
                if !points
                    return
                try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
                try {
                    missCount := 0
                    for point in points {
                        if !SafePixelSearch(&FoundX, &FoundY, point.x, point.y, point.x, point.y, 0x000000, 10) {
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
                } finally {
                    if (oldCtx)
                        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
                }
            }
            ; 识别 Loading：通过 Loading... 文字区域颜色判断场景类型
            if (this._BlackScreenDetected == true && this._ReadyForPause == false) {
                try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
                try {
                    scanLines := GameMonitor.LoadingPosition()
                    if !scanLines
                        return
                    line1 := scanLines[1]
                    if SafePixelSearch(&FoundX, &FoundY, line1.lx, line1.y, line1.rx, line1.y, 0xA60000, 50) {
                        Logger.Info("GameMonitor", "识别到红色按钮，停止 Loading 搜索")
                        this._ScheduleTimeout(0)
                        this._BlackScreenDetected := false
                    } else if SafePixelSearch(&FoundX, &FoundY, line1.lx, line1.y, line1.rx, line1.y, 0x0070a3, 50) {
                        Logger.Info("GameMonitor", "识别到蓝色按钮，停止 Loading 搜索")
                        this._ScheduleTimeout(0)
                        this._BlackScreenDetected := false
                    } else {
                        allWhite := true
                        for line in scanLines {
                            if !SafePixelSearch(&FoundX, &FoundY, line.lx, line.y, line.rx, line.y, 0xFFFFFF, 0) {
                                allWhite := false
                                break
                            }
                        }
                        if (allWhite) {
                            Logger.Info("GameMonitor", "识别到白色 Loading，准备自动暂停")
                            this._ReadyForPause := true
                            this._ScheduleTimeout(0)
                            ; 缓存同一 bound 对象（本文件既定约定），否则每次新建对象会让 SetTimer 无法取消
                            if (this._PauseWaitTimer = "")
                                this._PauseWaitTimer := GameMonitor.ActionBeginPause.Bind(GameMonitor)
                            SetTimer this._PauseWaitTimer, -2000
                        }
                    }
                } finally {
                    if (oldCtx)
                        DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
                }
            }
        }
    }

    ; 自动开局暂停：进入「等待倍速按钮」阶段（由 Loading 识别命中后延迟 2 秒调度）
    ; 像素/图像搜索全部走 Safe* 包装：窗口/桌面不可用时按未命中处理，不抛 OSError
    static ActionBeginPause() {
        Logger.Info("GameMonitor", "自动暂停：等待倍速按钮")
        this._PauseWaitDeadline := A_TickCount + this.PauseWaitTimeoutMs
        this._PauseWaitTick()
    }

    ; 「等待倍速按钮」单拍：命中则暂停并收尾，未命中则重新排程下一拍。
    ; 每拍只做一次小区域 PixelSearch 后立即返回，主线程在拍间完全空闲——
    ; 这正是替换掉原 while(true) 忙等的关键（忙等期间 HotIf 求值排队会导致系统摘除键盘钩子）。
    static _PauseWaitTick() {
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        try {
            ; 游戏窗口消失 → 结束等待，避免 Safe 包装按未命中处理造成无限轮询
            if !GameTarget.Exists() {
                Logger.Warn("GameMonitor", "自动暂停：等待倍速按钮期间游戏窗口已不存在")
                this._ResetPauseWait()
                return
            }
            ; 游戏已不在前台：与 CheckGameStatus 的自动暂停前置条件保持一致。
            ; 继续等下去只会对着遮挡窗口做像素判断，既可能误命中（凭空注入一次暂停），也白占主线程。
            if !GameTarget.IsActive() {
                Logger.Info("GameMonitor", "自动暂停：游戏已切出前台，放弃本次自动暂停")
                this._ResetPauseWait()
                return
            }
            if (A_TickCount > this._PauseWaitDeadline) {
                Logger.Info("GameMonitor", "自动暂停：" (this.PauseWaitTimeoutMs // 1000) " 秒内未识别到倍速按钮，放弃本次自动暂停")
                this._ResetPauseWait()
                return
            }
            PosC := SpeedButtonPositionColor()
            if !PosC {
                Logger.Warn("GameMonitor", "自动暂停：游戏窗口不存在")
                this._ResetPauseWait()
                return
            }
            if !SafePixelSearch(&FoundX, &FoundY, PosC.PBCRX, PosC.PBCUY, PosC.PBCLX, PosC.PBCDY, 0xffffff, 10) {
                SetTimer this._PauseWaitTimerTick(), -this.PauseWaitIntervalMs
                return
            }
            GameKeys.SendDown("pauseBattle")
            USleep(50)
            GameKeys.SendUp("pauseBattle")
            Logger.Info("GameMonitor", "自动暂停：已暂停")
            ; 为了降低暂停延迟，后置代理指挥识别，识别到是代理指挥时取消暂停
            isProxy := false
            TobC := TakeOverButtonPositions()
            if !TobC {
                Logger.Warn("GameMonitor", "自动暂停：游戏窗口不存在（代理指挥识别）")
                this._ResetPauseWait()
                return
            }
            ; 接管代理按钮右侧边缘
            if SafeImageSearch(&OutputVarX, &OutputVarY, TobC.ImageRegion.RLX, TobC.ImageRegion.RUY, TobC.ImageRegion.RRX, TobC.ImageRegion.RDY, "*90 " FileExtractor.TakeOver1Path) or SafeImageSearch(&OutputVarX, &OutputVarY, TobC.ImageRegion.RLX, TobC.ImageRegion.RUY, TobC.ImageRegion.RRX, TobC.ImageRegion.RDY, "*90 " FileExtractor.TakeOver2Path) {
                isProxy := true
            }
            ; 接管代理按钮“手”图标拇指
            if !SafeImageSearch(&OutputVarX, &OutputVarY, TobC.ImageRegion.HLX, TobC.ImageRegion.HUY, TobC.ImageRegion.HRX, TobC.ImageRegion.HDY, "*90 " FileExtractor.TakeOver3Path) {
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
            this._ResetPauseWait()
        } finally {
            if (oldCtx)
                DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        }
    }

    ; 「等待倍速按钮」轮询回调（缓存同一 bound 对象，保证可被 SetTimer 取消/重排）
    static _PauseWaitTimerTick() {
        if (this._PauseWaitTickTimer = "")
            this._PauseWaitTickTimer := GameMonitor._PauseWaitTick.Bind(GameMonitor)
        return this._PauseWaitTickTimer
    }

    ; 结束等待并回到常规轮询节奏
    static _ResetPauseWait() {
        ; 连同尚未触发的 2 秒启动定时器一并取消，避免复位后又被一次陈旧调度重新拉起等待
        if (this._PauseWaitTimer != "")
            SetTimer this._PauseWaitTimer, 0
        SetTimer this._PauseWaitTimerTick(), 0
        this._BlackScreenDetected := false
        this._ReadyForPause := false
        this.SetPollInterval(400)
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
