; == 显示信息工具 ==
; 读取显示器当前刷新率，供游戏帧率识别按游戏窗口所在显示器取实际帧率。

class DisplayInfo {
    ; 窗口所在显示器的当前刷新率（Hz）；窗口/显示器查询失败时回退主屏，仍失败返回 0
    static GetRefreshRate(hwnd) {
        if (hwnd) {
            device := this._MonitorDeviceName(hwnd)
            if (device != "") {
                refreshRate := this._ModeRefreshRate(device)
                if (refreshRate > 0)
                    return refreshRate
            }
        }
        return this._PrimaryRefreshRate()
    }

    ; 窗口所在显示器的设备名（如 \\.\DISPLAY1）
    static _MonitorDeviceName(hwnd) {
        hMonitor := DllCall("MonitorFromWindow", "Ptr", hwnd, "UInt", 2, "Ptr")  ; MONITOR_DEFAULTTONEAREST
        if (!hMonitor)
            return ""
        ; MONITORINFOEXW：cbSize(4) + rcMonitor(16) + rcWork(16) + dwFlags(4) + szDevice(64)
        info := Buffer(104)
        NumPut("UInt", 104, info, 0)
        if !DllCall("GetMonitorInfoW", "Ptr", hMonitor, "Ptr", info)
            return ""
        return StrGet(info.Ptr + 40, 32, "UTF-16")
    }

    ; 指定显示设备当前模式的刷新率
    static _ModeRefreshRate(device) {
        ; DEVMODEW 固定 220 字节；dmSize 偏移 68，dmDisplayFrequency 偏移 184
        devMode := Buffer(220)
        NumPut("UShort", 220, devMode, 68)
        if !DllCall("EnumDisplaySettingsW", "Str", device, "UInt", 0xFFFFFFFF, "Ptr", devMode, "Int")
            return 0
        refreshRate := NumGet(devMode, 184, "UInt")
        return refreshRate >= 20 ? refreshRate : 0
    }

    ; 主屏（当前桌面 DC）刷新率，用于按显示器查询失败时的兜底
    static _PrimaryRefreshRate() {
        hdc := DllCall("GetDC", "Ptr", 0, "Ptr")
        if (!hdc)
            return 0
        refreshRate := 0
        try {
            refreshRate := DllCall("GetDeviceCaps", "Ptr", hdc, "Int", 116, "Int")  ; VREFRESH
        } finally {
            DllCall("ReleaseDC", "Ptr", 0, "Ptr", hdc)
        }
        return refreshRate >= 20 ? refreshRate : 0
    }
}
