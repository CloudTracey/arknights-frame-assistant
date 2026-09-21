; == 高精度延迟工具 ==
; base 层高精度延迟工具，供 core 层过帧动作使用。

; 高精度计时读点（QueryPerformanceCounter 原始值，单位=计数不=毫秒）。
; 频率在首次调用时缓存为 static：这是"每次调用都读一次频率"与"只读一次"的差别，
; 热键判定路径（HotkeyContext）每按一次键都要取两次读点，**不允许**多出第三次 DllCall。
; 用途：先把两次 Qpc() 相减，再用 QpcMs() 换算（配对使用，勿把原始计数当毫秒用）。
Qpc() {
    static freq := 0
    if (freq = 0)
        DllCall("QueryPerformanceFrequency", "Int64*", &freq)
    counter := 0
    DllCall("QueryPerformanceCounter", "Int64*", &counter)
    return counter
}

; QPC 计数差 → 毫秒（浮点）。freq 为 0（QueryPerformanceFrequency 异常失败）时返回 -1，调用方按"无观测"处理。
QpcMs(delta) {
    static freq := 0
    if (freq = 0)
        DllCall("QueryPerformanceFrequency", "Int64*", &freq)
    if (freq = 0)
        return -1
    return delta * 1000.0 / freq
}

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
    ; overshoot := (current - target) * 1000.0 / freq
    ; if (overshoot >= 1.0) {
        ; 记录调用栈，便于定位是哪个 USleep 调用点出现超时（过帧/点击延迟等）
        ; err := Error("USleep timeout")
        ; Logger.Debug("USleep", Format("USleep 超时 {:.1f}ms，delay={}ms`n调用栈:`n{}", overshoot, delay_ms, err.Stack))
    ; }
}
