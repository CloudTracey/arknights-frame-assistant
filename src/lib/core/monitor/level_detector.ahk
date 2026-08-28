; == 关卡检测投票状态机 ==
; 通过 3 个关卡内专属对象的颜色检测投票，维护私有 InLevel（守卫消费）
; 每秒轮询：命中 ≥2 个对象 → 置位 InLevel=true；命中 <2 个 → 复位 InLevel=false
; PixelSearch 颜色检测：区域用相对比例定位（LX/RX/UY/DY = ww/wh 比例，同项目其他位置函数），检测区域内目标颜色，不依赖模板尺寸
; 3 个对象：关卡内文本 / 退出按钮 / 暂停按钮

class LevelDetector {
    ; 投票阈值（3 个对象命中 ≥2 置位）
    static VoteThreshold := 2

    static _PollTimer := ""  ; 轮询定时器回调引用（SetTimer 启停需用同一对象匹配，故缓存）
    static _PollCount := 0   ; 轮询计数（节流 debug 明细用，每 20 次或状态变化记一条）
    static _GuardActive := false  ; 守卫轮询当前是否开启（守卫开关切换日志去重用）
    static _InLevel := false        ; 关卡状态私有字段

    ; 对象配置（PixelSearch 颜色检测：区域用相对比例定位，LX/RX = ww 比例，UY/DY = wh 比例）
    ; Colors: [{C: 0xRRGGBB 目标颜色, V: 容差 0-255}]，多个颜色 OR；任一命中即算对象命中
    static Objects := [
        ; 关卡内文本（右下角；白色 V1，低分辨率 <1600×900 时容差放宽到 20）
        {Name: "TextInLevel",
         Colors: [{C: 0xFFFFFF, V: 2}, {C: 0x9B9B9B, V: 2}],
         LX: 0.9300, RX: 0.9420, UY: 0.7833, DY: 0.8465},
        ; 退出按钮（左上角；灰色两色 + 其他模式深红/黄绿，OR；识别线加长至 65px 并左移到 x=136）
        {Name: "ExitButton",
         Colors: [{C: 0x868686, V: 5}, {C: 0x8C8C8C, V: 5}, {C: 0xB72518, V: 5}, {C: 0xBF2719, V: 5},
            {C: 0xD0CF67, V: 5}, {C: 0xD9D86B, V: 5}, {C: 0x555555, V: 5}, {C: 0x515151, V: 5},
            {C: 0x74180F, V: 5}, {C: 0x6F160F, V: 5}, {C: 0x848341, V: 5}, {C: 0x7E7E3F, V: 5}],
         LX: 0.0531, RX: 0.0535, UY: 0.0299, DY: 0.0750},
        ; 暂停按钮（右上角；白/浅灰两色 OR）
        {Name: "PauseButton",
         Colors: [{C: 0xFFFFFF, V: 2}, {C: 0xF5F5F5, V: 2}],
         LX: 0.9297, RX: 0.9453, UY: 0.0590, DY: 0.0590}
    ]

    ; 关卡状态 getter
    static IsInLevel() {
        return this._InLevel
    }

    ; 设置关卡状态并发布事实事件（守卫消费走 getter，观察者可订阅 InLevelChanged）
    static _SetInLevel(newVal) {
        if (this._InLevel = newVal)
            return
        this._InLevel := newVal
        EventBus.Publish("InLevelChanged", {inLevel: newVal})
    }

    ; 守卫开关：开启→启动每秒轮询；关闭→停止轮询（不消耗像素检测）
    static SetGuardEnabled(enabled) {
        ; 状态未变化则跳过（Init 与 SyncGuardSetting 会在启动时重复调用同一状态）
        if (this._GuardActive = enabled)
            return
        this._GuardActive := enabled
        Logger.Info("LevelDetector", "关卡守卫 " (enabled ? "开启" : "关闭"))
        if enabled {
            if (this._PollTimer = "")
                this._PollTimer := LevelDetector.Poll.Bind(LevelDetector)
            SetTimer this._PollTimer, 333
        } else if (this._PollTimer != "") {
            SetTimer this._PollTimer, 0
        }
    }

    ; 守卫开关同步（设置保存/应用/取消/重置后由 SettingsService/事件调用）
    ; 关闭守卫→停止轮询并强制 InLevel=true（守卫直接放行，无需维护真实关卡状态）
    ; 开启守卫→恢复轮询（下轮 Poll 依据像素检测自动校正 InLevel）
    static SyncGuardSetting() {
        if (Config.ReadImportantFromIni("InLevelGuard") != "1") {
            this.SetGuardEnabled(false)
            this._SetInLevel(true)
            return
        }
        this.SetGuardEnabled(true)
    }

    ; 启动投票定时器（每秒轮询）
    ; 类静态方法引用作回调需 Bind(LevelDetector)——直接传引用回调验证失败（Invalid callback function），同 KeyForward.ActionUpForward 模式
    static Init() {
        ; 订阅设置变更，守卫开关变化时即时同步
        EventBus.Subscribe("SettingsChanged", (data) => this._HandleSettingsChanged(data))
        EventBus.Subscribe("SettingsSaved", (*) => this.SyncGuardSetting())
        EventBus.Subscribe("SettingsApplied", (*) => this.SyncGuardSetting())
        EventBus.Subscribe("SettingsReset", (*) => this.SyncGuardSetting())
        ; 未开启关卡守卫时不轮询，强制 InLevel=true（守卫直接放行，避免无谓的像素检测）
        if (Config.ReadImportantFromIni("InLevelGuard") != "1") {
            this._SetInLevel(true)
            return
        }
        this.SetGuardEnabled(true)
    }

    ; 处理单键设置变更：InLevelGuard 变化时同步守卫开关
    static _HandleSettingsChanged(data) {
        if (data.key = "InLevelGuard")
            this.SyncGuardSetting()
    }

    ; 轮询投票
    static Poll() {
        this._PollCount += 1
        ; 游戏进程不存在 → 复位关卡状态
        if !GameTarget.Exists() {
            this._SetInLevel(false)
            return
        }
        ; 游戏窗口未激活 → 跳过（保持现有状态，回前台自愈）
        if !GameTarget.IsActive()
            return
        oldCtx := 0
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        try {
            if !SafeWinGetClientPos(&ww, &wh) {
                this._SetInLevel(false)
            }
            hitCount := 0
            detail := ""
            for obj in this.Objects {
                matched := this._MatchObject(obj, ww, wh)
                if matched
                    hitCount++
                detail .= obj.Name ": " (matched ? "✓" : "✗") "  "
            }
            newVal := hitCount >= this.VoteThreshold
            ; 状态切换：Info（含各对象识别详情）
            if (newVal != this._InLevel)
                Logger.Info("LevelDetector", "关卡状态切换：" (newVal ? "进入关卡" : "退出关卡") "（识别结果 " hitCount "/" this.Objects.Length " " detail "）")
            ; 轮询明细：节流 Debug（每 20 次轮询或状态变化时记一条）
            if (newVal != this._InLevel || Mod(this._PollCount, 20) = 0)
                Logger.Debug("LevelDetector", "识别结果 " hitCount "/" this.Objects.Length " " detail)
            this._SetInLevel(newVal)
        } finally {
            if (oldCtx)
                DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        }
    }

    ; 匹配单个对象：在区域内 PixelSearch 检测任一目标颜色（任一命中即算对象命中）
    ; 区域用相对比例定位（LX/RX = ww 比例，UY/DY = wh 比例），不依赖模板尺寸
    ; 低分辨率（长或宽任一 < 1600×900）时关卡内文本容差放宽到 20（低分辨率下文本更模糊，需更大容差）
    ; 走 SafePixelSearch：窗口/桌面不可用（区域在可见桌面外、副屏断开等）时按未命中处理，不抛 OSError
    static _MatchObject(obj, ww, wh) {
        LX := ww * obj.LX, RX := ww * obj.RX, UY := wh * obj.UY, DY := wh * obj.DY
        for color in obj.Colors {
            v := color.V
            if (obj.Name = "TextInLevel" && (ww < 1600 || wh < 900))
                v := Max(v, 20)
            if SafePixelSearch(&FoundX, &FoundY, LX, UY, RX, DY, color.C, v)
                return true
        }
        return false
    }
}

