; == 高精度延迟工具 ==
; 从 hotkey_actions.ahk 抽出的 base 层纯时序函数，供 core 层过帧动作使用。

; 高精度延迟
USleep(delay_ms) {
    if (delay_ms <= 0)
        return
    static freq := 0
    if (freq = 0)
        DllCall("QueryPerformanceFrequency", "Int64*", &freq)
    start := 0
    DllCall("QueryPerformanceCounter", "Int64*", &start)
    target := start + (delay_ms * freq / 1000)
    current := 0
    Loop {
        DllCall("QueryPerformanceCounter", "Int64*", &current)
        if (current >= target)
            break
        remaining := (target - current) * 1000 / freq
        if (remaining > 4)
            DllCall("Sleep", "UInt", 1)
    }
    ; 诊断：到期时超出 target 的时长（换算毫秒）。正常忙等退出 overshoot 应 <1ms；
    ; 若被 LevelDetector 等定时器中断，或 Sleep(1) 粒度过大（系统 tick 默认 15.6ms），会显著增大——用于定位过帧时序波动
    overshoot := (current - target) * 1000.0 / freq
    if (overshoot >= 1.0) {
        ; 记录调用栈，便于定位是哪个 USleep 调用点出现超时（过帧/点击延迟等）
        err := Error("USleep timeout")
        Logger.Debug("USleep", Format("USleep 超时 {:.1f}ms，delay={}ms`n调用栈:`n{}", overshoot, delay_ms, err.Stack))
    }
}
