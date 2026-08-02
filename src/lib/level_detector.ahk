; == 关卡检测投票状态机 ==
; 通过 6 个关卡内专属对象的 ImageSearch 投票，维护 State.InLevel（守卫/自动暂停二次确认消费）
; 每秒轮询：命中 ≥2 个对象 → 置位 InLevel=true；命中 <2 个 → 复位 InLevel=false
; 参考分辨率 2560×1440，单套模板先跑通（搜索区域用相对坐标 ww/wh 比例，多分辨率下自动换算）
; 6 个对象：费用图标 2 变体 / 退出按钮 7 变体 / 关卡内文本 2 变体 / 蓝堡 2 变体 / 敌人数 2 变体 / 暂停按钮 5 变体

class LevelDetector {
    ; 投票阈值（6 个对象命中 ≥2 置位）
    static VoteThreshold := 2

    ; ImageSearch 选项：40 色差容差 + 黑色透明（对半透明 UI 友好），实测后调整
    static ImageOptions := "*40 *TransBlack"

    ; 调试模式：测试时在屏幕中央显示投票 ToolTip + 记录详细日志（测试已完成，关闭）
    static DebugMode := false
    static _ToolTipActive := false

    ; 对象配置（搜索区域为相对坐标比例，LX/RX = ww 比例，UY/DY = wh 比例）
    ; 区域基于 2560×1440 参考分辨率下的实际对象位置换算
    static Objects := [
        ; 费用图标（右下角，暂停/非暂停 2 变体）
        {Name: "FeeIcon",
         Paths: [FileExtractor.FeeIcon1Path, FileExtractor.FeeIcon2Path],
         LX: 0.859, RX: 0.957, UY: 0.646, DY: 0.833},
        ; 退出按钮（左上角，7 变体：6 模式 + _1 非暂停态，全部 OR）
        {Name: "ExitButton",
         Paths: [FileExtractor.ExitButton1Path, FileExtractor.ExitButton2Path, FileExtractor.ExitButton3Path, FileExtractor.ExitButton4Path, FileExtractor.ExitButton5Path, FileExtractor.ExitButton6Path, FileExtractor.ExitButton7Path],
         LX: 0.000, RX: 0.086, UY: 0.000, DY: 0.118},
        ; 关卡内文本（右下角，费用图标附近，暂停/非暂停 2 变体）
        {Name: "TextInLevel",
         Paths: [FileExtractor.TextInLevel1Path, FileExtractor.TextInLevel2Path],
         LX: 0.926, RX: 1.000, UY: 0.757, DY: 0.854},
        ; 蓝堡小图标（正上方偏右，暂停/非暂停 2 变体；RX 已向右扩展至 1600px）
        {Name: "BlueCastle",
         Paths: [FileExtractor.BlueCastle1Path, FileExtractor.BlueCastle2Path],
         LX: 0.500, RX: 0.625, UY: 0.000, DY: 0.063},
        ; 敌人数（正上方偏左，暂停/非暂停 2 变体）
        {Name: "EnemyCount",
         Paths: [FileExtractor.EnemyCount1Path, FileExtractor.EnemyCount2Path],
         LX: 0.391, RX: 0.500, UY: 0.000, DY: 0.063},
        ; 暂停按钮（右上角，5 变体 OR）
        {Name: "PauseButton",
         Paths: [FileExtractor.PauseButton1Path, FileExtractor.PauseButton2Path, FileExtractor.PauseButton3Path, FileExtractor.PauseButton4Path, FileExtractor.PauseButton5Path],
         LX: 0.898, RX: 1.000, UY: 0.000, DY: 0.160}
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
            ; ToolTip 放屏幕中央，避开四角/顶部的 6 个检测区域（否则 ImageSearch 会读到 ToolTip 像素干扰识别）
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

    ; 匹配单个对象（多变体任一命中即算命中）
    ; try 保护：模板文件缺失/损坏时 ImageSearch 抛异常，返回 false 不崩溃（未编译运行时模板未自动提取）
    static _MatchObject(obj, ww, wh) {
        LX := ww * obj.LX, RX := ww * obj.RX, UY := wh * obj.UY, DY := wh * obj.DY
        for path in obj.Paths {
            try {
                if ImageSearch(&FoundX, &FoundY, LX, UY, RX, DY, this.ImageOptions " " path)
                    return true
            }
        }
        return false
    }
}

; 初始化关卡检测投票定时器
LevelDetector.Init()
