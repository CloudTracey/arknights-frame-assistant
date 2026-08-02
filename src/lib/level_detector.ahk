; == 关卡检测投票状态机 ==
; 通过 3 个关卡内专属对象的颜色检测投票，维护 State.InLevel（守卫消费）
; 每秒轮询：命中 ≥2 个对象 → 置位 InLevel=true；命中 <2 个 → 复位 InLevel=false
; PixelSearch 颜色检测：区域用相对比例定位（LX/RX/UY/DY = ww/wh 比例，同项目其他位置函数），检测区域内目标颜色，不依赖模板尺寸
; 3 个对象：关卡内文本 / 退出按钮 / 暂停按钮

class LevelDetector {
    ; 投票阈值（3 个对象命中 ≥2 置位）
    static VoteThreshold := 2

    ; 调试模式：测试时在屏幕中央显示投票 ToolTip + 记录详细日志（测试完成，关闭）
    static DebugMode := false
    static _ToolTipActive := false

    ; 对象配置（PixelSearch 颜色检测：区域用相对比例定位，LX/RX = ww 比例，UY/DY = wh 比例）
    ; Colors: [{C: 0xRRGGBB 目标颜色, V: 容差 0-255}]，多个颜色 OR；任一命中即算对象命中
    static Objects := [
        ; 关卡内文本（右下角；白色 V1，低分辨率 <1600×900 时容差放宽到 20）
        {Name: "TextInLevel",
         Colors: [{C: 0xFFFFFF, V: 1}],
         LX: 0.9355, RX: 0.9375, UY: 0.7833, DY: 0.8465},
        ; 退出按钮（左上角；灰色两色 + 其他模式深红/黄绿，OR；识别线加长至 65px 并左移到 x=136）
        {Name: "ExitButton",
         Colors: [{C: 0x868686, V: 3}, {C: 0x8C8C8C, V: 3}, {C: 0xB72518, V: 3}, {C: 0xBF2719, V: 3}, {C: 0xD0CF67, V: 3}, {C: 0xD9D86B, V: 3}],
         LX: 0.0531, RX: 0.0535, UY: 0.0299, DY: 0.0750},
        ; 暂停按钮（右上角；白/浅灰两色 OR）
        {Name: "PauseButton",
         Colors: [{C: 0xFFFFFF, V: 3}, {C: 0xF5F5F5, V: 3}],
         LX: 0.9297, RX: 0.9453, UY: 0.0590, DY: 0.0590}
    ]

    ; 启动投票定时器（每秒轮询）
    ; 类静态方法引用作回调需 Bind(LevelDetector)——直接传引用回调验证失败（Invalid callback function），同 KeyForward.ActionUpForward 模式
    static Init() {
        SetTimer LevelDetector.Poll.Bind(LevelDetector), 1000
    }

    ; 轮询投票
    static Poll() {
        ; 游戏进程不存在 → 复位关卡状态
        if !ProcessExist("Arknights.exe") {
            State.InLevel := false
            return
        }
        ; 游戏窗口未激活 → 跳过（保持现有状态，回前台自愈）
        if !WinActive("ahk_exe Arknights.exe")
            return
        try oldCtx := DllCall("SetThreadDpiAwarenessContext", "ptr", -3, "ptr")
        try {
            if !SafeWinGetClientPos(&ww, &wh) {
                State.InLevel := false
                return
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
            ; 日志只在状态变化时记录（含各对象识别详情），避免每秒刷屏
            if (newVal != State.InLevel)
                Logger.Info("LevelDetector", "关卡状态切换：" (newVal ? "进入关卡" : "退出关卡") "（投票 " hitCount "/" this.Objects.Length " " detail "）")
            ; 调试模式：ToolTip 直观实时显示各对象识别情况；关闭时清除 ToolTip
            ; ToolTip 放屏幕中央，避开四角/顶部的检测区域（否则会读到 ToolTip 像素干扰识别）
            if (this.DebugMode) {
                this._ToolTipActive := true
                ToolTip("AFA 关卡检测  " (newVal ? "●关卡内" : "○关卡外") "  " hitCount "/" this.Objects.Length "`n" detail, A_ScreenWidth // 2 - 160, A_ScreenHeight // 2 - 60, 2)
            } else if (this._ToolTipActive) {
                this._ToolTipActive := false
                ToolTip(, , , 2)
            }
            State.InLevel := newVal
        } finally {
            DllCall("SetThreadDpiAwarenessContext", "ptr", oldCtx, "ptr")
        }
    }

    ; 匹配单个对象：在区域内 PixelSearch 检测任一目标颜色（任一命中即算对象命中）
    ; 区域用相对比例定位（LX/RX = ww 比例，UY/DY = wh 比例），不依赖模板尺寸
    ; 低分辨率（长或宽任一 < 1600×900）时关卡内文本容差放宽到 20（低分辨率下文本更模糊，需更大容差）
    static _MatchObject(obj, ww, wh) {
        LX := ww * obj.LX, RX := ww * obj.RX, UY := wh * obj.UY, DY := wh * obj.DY
        for color in obj.Colors {
            v := color.V
            if (obj.Name = "TextInLevel" && (ww < 1600 || wh < 900))
                v := Max(v, 20)
            if PixelSearch(&FoundX, &FoundY, LX, UY, RX, DY, color.C, v)
                return true
        }
        return false
    }
}

; 初始化关卡检测投票定时器
LevelDetector.Init()
