; == 游戏帧率自动识别 ==
; 读取游戏 Unity PlayerPrefs 的 common_setting（fpsStrategy/enableVSync），
; 垂直同步开启时结合游戏窗口所在显示器的刷新率，算出游戏实际帧率并发布 GameFrameRateChanged；
; 检测失败时发布 ok=false，由 TimingService 回退到 60fps。

class GameFrameRate {
    static _Initialized := false
    static _Refreshing := false
    static _LastSignature := ""
    static _LastServerId := ""
    static _CommonValueName := "common_setting_h2012961537"  ; 值名后缀可能随游戏版本变化，仅作首选与兜底
    static _CommonValuePrefix := "common_setting_"

    ; 初始化：首次识别 + 订阅客户端事件 + 10 秒轮询（与 GameKeys 一致）
    static Init() {
        if (this._Initialized)
            return
        this._Initialized := true

        EventBus.Subscribe("ForegroundClientChanged", (*) => this.Refresh())
        EventBus.Subscribe("GameClientsChanged", (*) => this.Refresh())
        this.Refresh()
        SetTimer ObjBindMethod(GameFrameRate, "_OnPoll"), 10000
    }

    static _OnPoll() {
        this.Refresh()
    }

    ; 重新识别并发布变化；payload：{ok, fps, vsync, strategy, refreshRate, serverId, reason}
    static Refresh() {
        if (this._Refreshing)
            return
        this._Refreshing := true
        try {
            try {
                snapshot := this._Detect()
            } catch Error as e {
                Logger.Error("GameFrameRate", "帧率识别异常：" e.Message)
                snapshot := this._Failed("识别异常：" e.Message)
            }
        } finally {
            this._Refreshing := false
        }

        signature := (snapshot.ok ? "ok" : "fail")
            . "|" snapshot.fps "|" snapshot.vsync "|" snapshot.strategy
            . "|" snapshot.refreshRate "|" snapshot.serverId "|" snapshot.reason
        if (signature = this._LastSignature)
            return
        this._LastSignature := signature
        this._LogSnapshot(snapshot)
        EventBus.Publish("GameFrameRateChanged", snapshot)
    }

    ; 识别一次：区服 → 注册表 common_setting → 按垂直同步决定是否取屏幕刷新率
    static _Detect() {
        serverId := this._ResolveServerId()
        if (!ServerProfile.RegistryRootExists(serverId))
            return this._Failed("区服注册表根不存在（游戏未安装或尚未运行）", serverId, true)

        setting := this._ReadCommonSetting(ServerProfile.RegistryRoot(serverId))
        if (!setting.success)
            return this._Failed(setting.reason, serverId)

        if (setting.enableVSync = 1) {
            hwnd := this._GetGameHwnd()
            if (!hwnd)
                return this._Failed("游戏窗口不存在，暂无法读取屏幕刷新率", serverId, true)
            refreshRate := Round(DisplayInfo.GetRefreshRate(hwnd))
            if (refreshRate < 20)
                return this._Failed("屏幕刷新率读取失败", serverId)
            return {ok: true, fps: refreshRate, vsync: 1, strategy: setting.strategy,
                refreshRate: refreshRate, serverId: serverId, reason: ""}
        }

        if (!setting.strategyFps)
            return this._Failed("fpsStrategy 异常：" setting.strategy, serverId)
        return {ok: true, fps: setting.strategyFps, vsync: 0, strategy: setting.strategy,
            refreshRate: 0, serverId: serverId, reason: ""}
    }

    ; 当前应读取哪个区服：前台客户端 → 运行中的客户端 → 上次区服 → 首选/上次识别区服 → CN
    static _ResolveServerId() {
        serverId := GameClientRegistry.GetForegroundServerId()
        if (serverId != "") {
            this._LastServerId := serverId
            return serverId
        }

        clients := GameClientRegistry.GetClients()
        if (clients.Length > 0) {
            for client in clients {
                if (client.serverId = this._LastServerId)
                    return this._LastServerId
            }
            for client in clients {
                if (client.serverId != "" && client.serverId != "Unknown") {
                    this._LastServerId := client.serverId
                    return this._LastServerId
                }
            }
        }

        if (this._LastServerId != "")
            return this._LastServerId

        serverId := Config.GetImportant("PreferredServer")
        if (serverId = "")
            serverId := Config.GetImportant("LastActiveServer")
        if (serverId = "") {
            for id in ServerProfile.Ids() {
                if (ServerProfile.RegistryRootExists(id)) {
                    serverId := id
                    break
                }
            }
        }
        if (serverId = "")
            serverId := "CN"
        this._LastServerId := serverId
        return serverId
    }

    ; 取游戏窗口：优先前台客户端，否则任一运行中客户端；没有运行中的游戏时返回 0
    static _GetGameHwnd() {
        client := GameClientRegistry.GetForegroundClient()
        if (client != "")
            return client.hwnd
        clients := GameClientRegistry.GetClients()
        if (clients.Length > 0)
            return clients[1].hwnd
        return 0
    }

    ; 读取并解析 common_setting：已知全名优先，其余前缀候选按枚举顺序兜底，逐个校验字段
    static _ReadCommonSetting(root) {
        names := UnityPlayerPrefs.FindValueNames(root, this._CommonValuePrefix, [this._CommonValueName])
        if (names.Length = 0)
            return {success: false, reason: "注册表中未找到 common_setting 值"}

        ordered := []
        for name in names {
            if (name = this._CommonValueName)
                ordered.Push(name)
        }
        for name in names {
            if (name != this._CommonValueName)
                ordered.Push(name)
        }

        for name in ordered {
            try {
                hexStr := RegRead(root, name, "")
            } catch Error as e {
                Logger.Warn("GameFrameRate", "读取 " name " 失败：" e.Message)
                continue
            }
            if (hexStr = "")
                continue
            try {
                parsed := this._ParseCommonSetting(UnityPlayerPrefs.DecodeHexUtf8(hexStr))
            } catch Error as e {
                Logger.Warn("GameFrameRate", "解析 " name " 失败：" e.Message)
                continue
            }
            if (parsed.success)
                return parsed
        }
        return {success: false, reason: "common_setting 解析失败"}
    }

    ; fpsStrategy：0/1/2 → 30/60/120fps；垂直同步开启时忽略该字段
    static _ParseCommonSetting(json) {
        result := {success: false, strategy: -1, strategyFps: 0, enableVSync: 0, reason: ""}
        if RegExMatch(json, '"fpsStrategy"\s*:\s*(-?\d+)', &match)
            result.strategy := Integer(match[1])
        if RegExMatch(json, '"enableVSync"\s*:\s*(-?\d+)', &match) {
            vsyncValue := Integer(match[1])
            if (vsyncValue != 0 && vsyncValue != 1) {
                result.reason := "enableVSync 异常：" vsyncValue
                return result
            }
            result.enableVSync := vsyncValue
        } else if (InStr(json, '"enableVSync"')) {
            result.reason := "enableVSync 格式异常"
            return result
        } else {
            result.enableVSync := 0  ; 旧版本无该字段，按未开启处理
        }

        if (result.enableVSync = 0) {
            if (result.strategy = 0)
                result.strategyFps := 30
            else if (result.strategy = 1)
                result.strategyFps := 60
            else if (result.strategy = 2)
                result.strategyFps := 120
            else {
                result.reason := "fpsStrategy 异常：" result.strategy
                return result
            }
        }

        result.success := true
        return result
    }

    ; expected=true 表示游戏未就绪等预期内状态
    static _Failed(reason, serverId := "", expected := false) {
        return {ok: false, fps: 0, vsync: 0, strategy: -1, refreshRate: 0,
            serverId: serverId, reason: reason, expected: expected}
    }

    ; 只在识别结果变化时记录日志
    static _LogSnapshot(snapshot) {
        if (snapshot.ok) {
            if (snapshot.vsync = 1)
                Logger.Info("GameFrameRate", "帧率识别：区服=" snapshot.serverId
                    . "，垂直同步开启，屏幕刷新率=" snapshot.refreshRate "Hz，游戏帧率=" snapshot.fps "fps")
            else
                Logger.Info("GameFrameRate", "帧率识别：区服=" snapshot.serverId
                    . "，垂直同步关闭，fpsStrategy=" snapshot.strategy "，游戏帧率=" snapshot.fps "fps")
        } else if (snapshot.expected) {
            Logger.Info("GameFrameRate", "帧率识别暂不可用，回退 60fps：区服="
                . (snapshot.serverId = "" ? "未知" : snapshot.serverId) . "，原因=" snapshot.reason)
        } else {
            Logger.Warn("GameFrameRate", "帧率识别失败，回退 60fps：区服="
                . (snapshot.serverId = "" ? "未知" : snapshot.serverId) . "，原因=" snapshot.reason)
        }
    }
}
