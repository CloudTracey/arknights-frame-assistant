; == 窗口工具 ==
; base 层窗口/屏幕工具，供 core 层与 UI 层复用。

; 安全获取明日方舟窗口 Client 区域尺寸，窗口不存在时返回 false 而非抛出 TargetError
SafeWinGetClientPos(&ww, &wh) {
    try {
        WinGetClientPos ,, &ww, &wh, GameTarget.WinTitle()
        return true
    } catch TargetError {
        return false
    }
}

; 安全像素搜索：PixelSearch 内部 GDI 调用（GetDC/BitBlt/GetDIBits 等）失败时会抛 OSError——
; 典型触发场景是搜索区域整体落在可见桌面之外（副屏拔掉/关闭、窗口被移出屏幕、RDP 断开等），
; 以及桌面/会话不可访问（锁屏、安全桌面、远程会话中断）。
; 此处统一把 OSError 按"未命中"处理并节流记录日志，避免未处理异常打断轮询/监控定时器线程。
; 返回语义与 PixelSearch 相同：命中返回 1，未命中或内部失败返回 0（输出变量置空）。
SafePixelSearch(&FoundX, &FoundY, LX, UY, RX, DY, ColorID, Variation := 0) {
    if _SearchRectOffScreen(LX, UY, RX, DY) {
        FoundX := "", FoundY := ""
        _LogSearchError("PixelSearch", "搜索区域完全在可见桌面之外")
        return false
    }
    try {
        return PixelSearch(&FoundX, &FoundY, LX, UY, RX, DY, ColorID, Variation)
    } catch OSError as e {
        FoundX := "", FoundY := ""
        _LogSearchError("PixelSearch", e.Message, e.Number)
        return false
    }
}

; 安全图像搜索：与 SafePixelSearch 同理包裹 ImageSearch（同一抓屏 GDI 路径，失败同样抛 OSError）。
; AHK v2 的 ImageSearch 无独立 Options 参数：容差/缩放等选项前缀拼在 ImageFile 字符串内（如 "*90 " path）。
; ValueError（图库加载失败/参数无效）同样按未命中处理——资源缺失时不应弹错误框打断监控。
SafeImageSearch(&FoundX, &FoundY, LX, UY, RX, DY, ImageFile) {
    if _SearchRectOffScreen(LX, UY, RX, DY) {
        FoundX := "", FoundY := ""
        _LogSearchError("ImageSearch", "搜索区域完全在可见桌面之外")
        return false
    }
    try {
        return ImageSearch(&FoundX, &FoundY, LX, UY, RX, DY, ImageFile)
    } catch OSError as e {
        FoundX := "", FoundY := ""
        _LogSearchError("ImageSearch", e.Message, e.Number)
        return false
    } catch ValueError as e {
        FoundX := "", FoundY := ""
        _LogSearchError("ImageSearch", e.Message)
        return false
    }
}

; 单次捕获目标窗口客户区位图（BGRA，每像素 4 字节，自顶向下），供内存颜色扫描。
; 用途：替代"每拍多次独立 PixelSearch"——一次 GetDC/BitBlt/GetDIBits 完成 N 次 GDI 往返的活
; （关卡检测每拍 16 次像素搜索 → 1 次捕获 + 内存扫描），把 333ms 轮询的"忙碌段"压缩一个数量级，
; 降低与高频输入流同时段的线程争用与输入延迟。
; 注意：必须从**屏幕 DC**（GetDC(NULL)）按客户区屏幕坐标抓取——DX/Unity 游戏画面不经过
; 窗口 GDI DC（GetDC(hwnd) 会得到黑屏/旧帧），PixelSearch 的实现同样是屏幕合成路径
; （参见 _SearchRectOffScreen 的"换算为屏幕坐标"逻辑），本函数与其语义保持一致。
; 语义约束（调用方保证）：
;   - 调用前已切 per-monitor DPI aware（与 SafeWinGetClientPos 同坐标系）；
;   - 目标窗口即 GameTarget（ahk_id / ahk_exe 宽松回退），客户区坐标 (0,0) 即位图 (0,0)；
;   - 屏幕 DC 捕获不含光标（与 Window DC 捕获一致，区域极小无影响）。
; 失败返回 false（不抛异常）；调用方按"未命中"处理。
SafeCaptureClientRect(&bits, &width, &height) {
    hwnd := 0, hdc := 0, memdc := 0, bmp := 0, old := 0
    try {
        hwnd := WinExist(GameTarget.WinTitle())
        if !hwnd
            return false
        rect := Buffer(16)
        if !DllCall("user32\GetClientRect", "Ptr", hwnd, "Ptr", rect)
            return false
        w := NumGet(rect, 8, "Int")
        h := NumGet(rect, 12, "Int")
        if (w <= 0 || h <= 0)
            return false
        ; 客户区原点的屏幕坐标（POINT(0,0) → ClientToScreen）
        pt := Buffer(8)
        NumPut("Int", 0, pt, 0)
        NumPut("Int", 0, pt, 4)
        if !DllCall("user32\ClientToScreen", "Ptr", hwnd, "Ptr", pt)
            return false
        ox := NumGet(pt, 0, "Int")
        oy := NumGet(pt, 4, "Int")
        hdc := DllCall("user32\GetDC", "Ptr", 0, "Ptr")  ; 屏幕 DC（含 DX 合成画面）
        if !hdc
            return false
        memdc := DllCall("gdi32\CreateCompatibleDC", "Ptr", hdc, "Ptr")
        if !memdc
            return false
        bmp := DllCall("gdi32\CreateCompatibleBitmap", "Ptr", hdc, "Int", w, "Int", h, "Ptr")
        if !bmp
            return false
        old := DllCall("gdi32\SelectObject", "Ptr", memdc, "Ptr", bmp, "Ptr")
        if !DllCall("gdi32\BitBlt", "Ptr", memdc, "Int", 0, "Int", 0, "Int", w, "Int", h, "Ptr", hdc, "Int", ox, "Int", oy, "UInt", 0x00CC0020)  ; SRCCOPY
            return false
        ; BITMAPINFOHEADER（40 字节）：biSize/biWidth/biHeight(负=自顶向下)/biPlanes/biBitCount/biCompression
        bmi := Buffer(40)
        NumPut("UInt", 40, bmi, 0)
        NumPut("UInt", w, bmi, 4)
        NumPut("UInt", -h, bmi, 8)
        NumPut("UShort", 1, bmi, 12)
        NumPut("UShort", 32, bmi, 14)
        NumPut("UInt", 0, bmi, 16)  ; BI_RGB
        bits := Buffer(w * h * 4)
        scan := DllCall("gdi32\GetDIBits", "Ptr", memdc, "Ptr", bmp, "UInt", 0, "UInt", h, "Ptr", bits, "Ptr", bmi, "UInt", 0)
        if (scan != h)
            return false
        width := w, height := h
        return true
    } catch {
        return false
    } finally {
        if bmp {
            if old
                DllCall("gdi32\SelectObject", "Ptr", memdc, "Ptr", old)
            DllCall("gdi32\DeleteObject", "Ptr", bmp)
        }
        if memdc
            DllCall("gdi32\DeleteDC", "Ptr", memdc)
        if hdc
            DllCall("user32\ReleaseDC", "Ptr", 0, "Ptr", hdc)
    }
}

; 判断搜索矩形是否完全在可见桌面（虚拟屏幕）之外。
; 坐标按当前 Pixel 坐标模式换算为屏幕坐标（镜像 AHK CoordToScreen：默认相对前台窗口客户区，
; 前台窗口不存在/最小化时不加偏移），再与虚拟屏幕边界求交。
; 返回 true 表示确定越界（此时 BitBlt 必将失败）；任何不确定情况返回 false，交由 PixelSearch 自身的 OSError 兜底。
_SearchRectOffScreen(FX1, FY1, FX2, FY2) {
    try {
        ; 归一化（调用方不保证 X1<=X2 / Y1<=Y2）
        x1 := Min(FX1, FX2), x2 := Max(FX1, FX2)
        y1 := Min(FY1, FY2), y2 := Max(FY1, FY2)
        ; 换算为屏幕坐标：与 AHK CoordToScreen 同一规则
        ox := 0, oy := 0
        if (A_CoordModePixel != "Screen") {
            fg := DllCall("GetForegroundWindow", "Ptr")
            if (fg && !DllCall("IsIconic", "Ptr", fg)) {
                if (A_CoordModePixel = "Window") {
                    WinGetPos &wx, &wy,,, "ahk_id " fg
                } else { ; Client（AHK 默认，AFA 全项目未改 Pixel 模式）
                    WinGetClientPos &wx, &wy,,, "ahk_id " fg
                }
                ox := wx, oy := wy
            }
        }
        x1 += ox, x2 += ox, y1 += oy, y2 += oy
        ; 虚拟桌面边界（全部显示器合并）。GetSystemMetrics 按调用线程 DPI 感知上下文返回物理像素，
        ; 调用方在 PixelSearch 前已临时切到 per-monitor aware，与 ClientToScreen 结果同坐标系
        vx := DllCall("GetSystemMetrics", "Int", 76)  ; SM_XVIRTUALSCREEN
        vy := DllCall("GetSystemMetrics", "Int", 77)  ; SM_YVIRTUALSCREEN
        vr := vx + DllCall("GetSystemMetrics", "Int", 78)  ; SM_CXVIRTUALSCREEN
        vb := vy + DllCall("GetSystemMetrics", "Int", 79)  ; SM_CYVIRTUALSCREEN
        return (x2 < vx || x1 > vr || y2 < vy || y1 > vb)
    } catch TargetError {
        ; 前台窗口在换算瞬间消失：与 AHK CoordToScreen 失败效果一致（不做偏移），不拦截
        return false
    } catch OSError {
        ; Win32 查询失败：无法确定越界，不拦截
        return false
    }
}

; 像素/图像搜索失败日志：60 秒节流记一次 Warn。
; 失败场景下单次轮询最多产生十余个搜索调用（如 ExitButton 12 色 OR），
; 若逐次落盘会在 DEBUG 恒持久化时刷屏，故统一按 60s 节流、只记 Warn。
_LogSearchError(kind, message, code := "") {
    static _NextWarnTick := 0
    if (A_TickCount < _NextWarnTick)
        return
    _NextWarnTick := A_TickCount + 60000
    detail := kind " 失败：" message (code != "" ? "（错误码 " code "）" : "")
    Logger.Warn("ScreenSearch", detail)
}

; 判断鼠标是否在 Client 区域内
IsMouseInClient() {
    MouseGetPos , &ypos, &hwnd
    gameHwnd := WinExist(GameTarget.WinTitle())
    if !(hwnd == gameHwnd)
        return false
    ; 简单判断会不会点到最小化或者关闭窗口
    if ypos < 0
        return false
    return true
}
