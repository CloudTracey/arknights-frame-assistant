; == 应用主题 ==
; 只负责显示状态和 Win32 绘制，不写配置、不引用 core/ui、不启动游戏逻辑。
class Theme {
    static SavedAppearance := ""
    static PreviewAppearance := ""
    static CustomActive := false
    static SystemDark := false
    static CustomPalette := Map()
    static _DrawingWindow := 0
    static _DrawingControl := 0
    static SavedMode := "auto"
    static PreviewMode := ""
    static IsDark := false
    static HighContrast := false
    static _Ready := false
    static _Windows := Map()
    static _Controls := Map()
    static _Brushes := Map()
    static _SubclassPtr := 0
    static _RefreshCallback := ""
    static _PaintErrorLogged := false
    static _PaletteSignature := ""

    ; 语义色保留浅色界面的原色，避免升级后浅色样式漂移。
    static Light := Map("Window", "FFFFFF", "Field", "FFFFFF", "Text", "000000",
        "Accent", "1994D2", "Link", "0645AD", "Heading", "333333", "Muted", "A0A0A0",
        "Hint", "9C9C9C", "Secondary", "6B6B6B", "Caption", "8A8A8A", "Grip", "A8ADB5",
        "Border", "D0D0D0", "Row", "F5F7FA", "Selected", "EAF2FB",
        "Error", "D93025", "Unsaved", "FF0000", "Button", "F0F0F0", "Hover", "E5F1FB")
    static Dark := Map("Window", "202020", "Field", "2B2B2B", "Text", "E6E6E6",
        "Accent", "4DB6EA", "Link", "6CBFFF", "Heading", "E6E6E6", "Muted", "999999",
        "Hint", "B0B0B0", "Secondary", "B0B0B0", "Caption", "B0B0B0", "Grip", "999999",
        "Border", "555555", "Row", "2B2B2B", "Selected", "26485E",
        "Error", "FF6B6B", "Unsaved", "FF6B6B", "Button", "333333", "Hover", "414141")

    static Normalize(mode) {
        switch mode {
            case "auto", "light", "dark", "custom": return StrLower(mode)
            default: return "auto"
        }
    }

    ; 纯解析入口，便于验证预览优先级；高对比度由系统绘制接管。
    static Resolve(saved, preview, appsUseLightTheme, highContrast := false) {
        if highContrast
            return "contrast"
        mode := this.Normalize(preview != "" ? preview : saved)
        return mode = "auto" ? (appsUseLightTheme = 0 ? "dark" : "light") : mode
    }

    static Init() {
        if this._Ready
            return
        this._Ready := true
        try this.SavedMode := this.Normalize(Config.ReadImportantFromIni("ThemeMode"))
        this.SavedAppearance := Appearance.Snapshot(true)
        this._RefreshCallback := ObjBindMethod(this, "Refresh")
        this._SubclassPtr := CallbackCreate(ObjBindMethod(this, "_Subclass"), , 6)
        for msg in [0x001A, 0x031A, 0x0015] ; setting/theme/system color changes
            OnMessage(msg, ObjBindMethod(this, "_SystemChanged"))
        for msg in [0x0133, 0x0134, 0x0135, 0x0136, 0x0138]
            OnMessage(msg, ObjBindMethod(this, "_ControlColor"))
        OnMessage(0x0014, ObjBindMethod(this, "_EraseBackground"))
        OnMessage(0x0005, ObjBindMethod(this, "_BackgroundSized"))
        OnMessage(0x0082, ObjBindMethod(this, "_WindowDestroyed"))
        OnExit(ObjBindMethod(this, "Stop"))
        this.Refresh()
    }

    static Preview(mode, values?) {
        this.Init()
        this.PreviewAppearance := IsSet(values) ? Appearance.Normalize(values) : Appearance.Snapshot()
        this.PreviewMode := this.Normalize(mode)
        this.PreviewAppearance["ThemeMode"] := this.PreviewMode
        this.Refresh()
    }

    ; 仅在初始化、成功持久化或取消时调用；按键重置不结束主题预览。
    static Confirm(mode, values?) {
        this.Init()
        this.SavedAppearance := IsSet(values) ? Appearance.Normalize(values) : Appearance.Snapshot(true)
        this.SavedMode := this.Normalize(mode)
        this.SavedAppearance["ThemeMode"] := this.SavedMode
        this.PreviewAppearance := ""
        this.PreviewMode := ""
        this.Refresh()
    }

    static _SystemChanged(*) {
        ; 广播会到达多个窗口；一次性计时器合并通知，不在消息回调内批量重绘。
        SetTimer(this._RefreshCallback, -50)
    }

    static CurrentAppearance() => IsObject(this.PreviewAppearance) ? this.PreviewAppearance : this.SavedAppearance

    static _BackgroundSized(wParam, lParam, msg, hwnd) {
        if hwnd = BackgroundImage.MainHwnd
            this._SystemChanged()
    }

    static _EraseBackground(dc, lParam, msg, hwnd) {
        if (hwnd = BackgroundImage.MainHwnd && this.CustomActive && !this.HighContrast && BackgroundImage.Brush) {
            rect := Buffer(16)
            DllCall("user32\GetClientRect", "Ptr", hwnd, "Ptr", rect)
            DllCall("user32\FillRect", "Ptr", dc, "Ptr", rect, "Ptr", BackgroundImage.AlignedBrush(dc, hwnd))
            return 1
        }
    }

    static Refresh(*) {
        ; 图片解码/缩放不在 Critical 或绘制回调中执行。
        this._ReadState()
        oldKey := BackgroundImage.CacheKey
        if IsObject(this.CurrentAppearance())
            BackgroundImage.Prepare(this.CurrentAppearance(), this.CustomActive && !this.HighContrast)
        if !(oldKey == BackgroundImage.CacheKey)
            this._PaletteSignature := ""
        wasCritical := A_IsCritical
        Critical("On")
        try this._Refresh()
        finally Critical(wasCritical)
    }

    static _ReadState() {
        appsLight := 1
        try appsLight := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme", 1)
        hc := Buffer(8 + A_PtrSize, 0)
        NumPut("UInt", hc.Size, hc)
        this.HighContrast := DllCall("user32\SystemParametersInfoW", "UInt", 0x42,
            "UInt", hc.Size, "Ptr", hc, "UInt", 0) && (NumGet(hc, 4, "UInt") & 1)
        resolved := this.Resolve(this.SavedMode, this.PreviewMode, appsLight, this.HighContrast)
        this.SystemDark := appsLight = 0
        this.CustomActive := resolved = "custom"
        if this.CustomActive
            this.CustomPalette := Appearance.Palette(this.CurrentAppearance())
        this.IsDark := this.CustomActive ? Appearance.Luminance(this.CustomPalette["Window"]) < 0.179 : resolved = "dark"
    }

    static _Refresh() {
        signature := this.IsDark ":" this.HighContrast ":" this.SystemDark
        if this.CustomActive
            signature .= ":" Appearance.Signature(this.CurrentAppearance())
        if this.HighContrast {
            for index in [5, 8, 13, 15, 17, 18, 26]
                signature .= ":" DllCall("user32\GetSysColor", "Int", index, "UInt")
        }
        if (signature = this._PaletteSignature)
            return
        this._PaletteSignature := signature
        ; 高对比度色可在模式不变时变化，旧画刷在本轮应用前统一释放。
        this._DeleteBrushes()
        for hwnd, window in this._Windows {
            window.Gui.BackColor := this.Color("Window", hwnd)
            this._TitleBar(hwnd)
        }
        for hwnd, data in this._Controls {
            if !data.Alias
                this._ApplyControl(data)
        }
        for hwnd, window in this._Windows
            DllCall("user32\RedrawWindow", "Ptr", hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0485) ; include non-client borders
    }

    static Color(role, hwnd := 0) {
        if (role = "Default")
            role := "Text"
        if this.HighContrast {
            index := 8 ; COLOR_WINDOWTEXT
            switch role {
                case "Window", "Field", "Row": index := 5
                case "Button", "Hover": index := 15
                case "Border", "Grip": index := 18
                case "Selected": index := 13
                case "Accent", "Link", "Error", "Unsaved": index := 26
                case "Muted", "Hint", "Caption", "Secondary": index := 17
            }
            return this._RgbHex(DllCall("user32\GetSysColor", "Int", index, "UInt"))
        }
        hwnd := hwnd ? hwnd : this._DrawingWindow
        fixed := this._Windows.Has(hwnd) && this._Windows[hwnd].Fixed
        palette := fixed ? (this.SystemDark ? this.Dark : this.Light) : this.CustomActive ? this.CustomPalette : this.IsDark ? this.Dark : this.Light
        return palette.Has(role) ? palette[role] : palette["Text"]
    }

    static _RgbHex(bgr) => Format("{:06X}", ((bgr & 255) << 16) | (bgr & 0xFF00) | ((bgr >> 16) & 255))
    static _Bgr(role, hwnd := 0) {
        rgb := Integer("0x" this.Color(role, hwnd))
        return ((rgb & 255) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 255)
    }

    static _Brush(role) {
        color := this._Bgr(role)
        if !this._Brushes.Has(color)
            this._Brushes[color] := DllCall("gdi32\CreateSolidBrush", "UInt", color, "Ptr")
        return this._Brushes[color]
    }

    static _DeleteBrushes() {
        for color, brush in this._Brushes
            DllCall("gdi32\DeleteObject", "Ptr", brush)
        this._Brushes.Clear()
    }

    static Attach(gui, fixed := false, background := false) {
        this.Init()
        if this._Windows.Has(gui.Hwnd)
            return
        this._Windows[gui.Hwnd] := {Gui: gui, FontRole: "Text", Fixed: fixed}
        if background
            BackgroundImage.MainHwnd := gui.Hwnd
        gui.BackColor := this.Color("Window", gui.Hwnd)
        gui.SetFont("c" this.Color("Text", gui.Hwnd))
        this._TitleBar(gui.Hwnd)
    }

    static _TitleBar(hwnd) {
        ; 失败仅表示当前系统不支持对应 DWM 属性，内容区主题仍可使用。
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 20,
            "Int*", (this._Windows[hwnd].Fixed ? this.SystemDark : this.IsDark) && !this.HighContrast, "UInt", 4)
        ; 清除旧主窗口硬编码的白色标题栏；高对比度交还系统。
        caption := this.HighContrast ? 0xFFFFFFFF : this._Bgr("Window", hwnd)
        try DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", 35,
            "UInt*", caption, "UInt", 4)
    }

    ; 与 Gui.Add 保持参数/返回值语义，只把主题色角色解析为当前颜色并登记控件。
    static Add(gui, kind, options := "", args*) {
        this.Attach(gui)
        fg := this._Windows[gui.Hwnd].FontRole
        bg := (kind = "Edit" || kind = "DropDownList") ? "Field" : "Window"
        options := this._FontOptions(options, &fg, gui.Hwnd)
        if RegExMatch(options, "i)(?<!\S)Background(\w+)(?=\s|$)", &m) {
            bg := m[1]
            if bg != "Trans"
                options := StrReplace(options, m[0], "Background" this.Color(bg, gui.Hwnd))
        }
        ctrl := gui.Add(kind, options, args*)
        data := {Ctrl: ctrl, Kind: kind, Parent: gui.Hwnd, Fg: fg, Bg: bg, Hot: false, Pressed: false,
            Alias: false, Subclassed: false}
        this._Controls[ctrl.Hwnd] := data
        if (kind = "Edit" || kind = "Button" || kind = "Checkbox" || kind = "DropDownList" || kind = "GroupBox" || kind = "UpDown") {
            data.Subclassed := !!DllCall("comctl32\SetWindowSubclass", "Ptr", ctrl.Hwnd,
                "Ptr", this._SubclassPtr, "UPtr", 1, "UPtr", 0)
        }
        if (kind = "DropDownList") {
            info := Buffer(A_PtrSize = 8 ? 64 : 52, 0)
            NumPut("UInt", info.Size, info)
            if DllCall("user32\GetComboBoxInfo", "Ptr", ctrl.Hwnd, "Ptr", info) {
                list := NumGet(info, A_PtrSize = 8 ? 56 : 48, "Ptr")
                this._Controls[list] := {Ctrl: ctrl, Parent: gui.Hwnd, Fg: fg, Bg: "Field", Alias: true, Subclassed: false}
            }
        }
        this._ApplyControl(data)
        return ctrl
    }

    static _FontOptions(options, &role, hwnd := 0) {
        if RegExMatch(options, "i)(?<!\S)c(Default|Text|Accent|Link|Heading|Muted|Hint|Secondary|Caption|Grip|Error|Unsaved)(?=\s|$)", &m) {
            role := m[1] = "Default" ? "Text" : m[1]
            options := StrReplace(options, m[0], "c" this.Color(role, hwnd))
        }
        return options
    }

    static SetFont(target, options := "", fontName?) {
        if (Type(target) = "Gui") {
            this.Attach(target)
            data := this._Windows[target.Hwnd]
            role := data.FontRole
            options := this._FontOptions(options, &role, Type(target) = "Gui" ? target.Hwnd : data.Parent)
            data.FontRole := role
        } else {
            data := this._Controls[target.Hwnd]
            role := data.Fg
            options := this._FontOptions(options, &role, Type(target) = "Gui" ? target.Hwnd : data.Parent)
            data.Fg := role
        }
        target.SetFont(options, fontName?)
    }

    static _ApplyControl(data) {
        ctrl := data.Ctrl
        kind := ctrl.Type
        ; 文本颜色由 WM_CTLCOLOR/绘制回调实时解析；切换时不批量重建数百个字体。
        if (kind = "Progress") {
            ctrl.Opt("c" this.Color("Accent") " Background" this.Color("Row"))
        }
        ; 使用公开按名 API（不依赖 uxtheme 序号函数）。绘制消息负责内容区颜色。
        if (kind = "Edit")
            DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", this.IsDark ? "DarkMode_Explorer" : "Explorer", "Ptr", 0)
    }

    static _ControlColor(dc, hwnd, msg, parent) {
        previous := this._DrawingWindow
        this._DrawingWindow := this._Controls.Has(hwnd) ? this._Controls[hwnd].Parent : 0
        try return this._ControlBrush(dc, hwnd)
        finally this._DrawingWindow := previous
    }

    static _ControlBrush(dc, hwnd) {
        if !this._Controls.Has(hwnd)
            return
        data := this._Controls[hwnd]
        fg := data.Ctrl.Enabled ? data.Fg : "Muted"
        DllCall("gdi32\SetTextColor", "Ptr", dc, "UInt", this._Bgr(fg))
        if (data.Bg = "Window" && data.Parent = BackgroundImage.MainHwnd && this.CustomActive && !this.HighContrast && BackgroundImage.Brush) {
            DllCall("gdi32\SetBkMode", "Ptr", dc, "Int", 1)
            return BackgroundImage.AlignedBrush(dc, hwnd)
        }
        if (data.Bg = "Trans") {
            DllCall("gdi32\SetBkMode", "Ptr", dc, "Int", 1)
            return DllCall("gdi32\GetStockObject", "Int", 5, "Ptr") ; NULL_BRUSH
        }
        DllCall("gdi32\SetBkMode", "Ptr", dc, "Int", 2)
        DllCall("gdi32\SetBkColor", "Ptr", dc, "UInt", this._Bgr(data.Bg))
        return this._Brush(data.Bg)
    }

    ; 保留原生控件的输入/焦点/勾选/可访问性；深色及自定义模式接管绘制，高对比度使用原生绘制。
    static _Subclass(hwnd, msg, wParam, lParam, id, refData) {
        Critical("On")
        previousWindow := this._DrawingWindow, previousControl := this._DrawingControl
        this._DrawingWindow := this._Controls.Has(hwnd) ? this._Controls[hwnd].Parent : 0
        this._DrawingControl := hwnd
        try {
            if (msg = 0x0082) {
                DllCall("comctl32\RemoveWindowSubclass", "Ptr", hwnd, "Ptr", this._SubclassPtr, "UPtr", id)
                if this._Controls.Has(hwnd)
                    this._Controls.Delete(hwnd)
            } else if this._Controls.Has(hwnd) {
                data := this._Controls[hwnd]
                if (data.Ctrl.Type = "Edit")
                    return this._EditMessage(data, hwnd, msg, wParam, lParam)
                if ((this.IsDark || this.CustomActive) && !this.HighContrast) {
                    if (msg = 0x000F || msg = 0x0318) { ; WM_PAINT / WM_PRINTCLIENT
                        ps := Buffer(A_PtrSize = 8 ? 72 : 64, 0)
                        dc := msg = 0x000F ? DllCall("user32\BeginPaint", "Ptr", hwnd, "Ptr", ps, "Ptr") : wParam
                        try this._Paint(data, dc)
                        finally {
                            if (msg = 0x000F)
                                DllCall("user32\EndPaint", "Ptr", hwnd, "Ptr", ps)
                        }
                        return 0
                    }
                    if (msg = 0x0014) ; WM_ERASEBKGND
                        return 1
                }
                if (msg = 0x0200 && !data.Hot) {
                    data.Hot := true
                    track := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
                    NumPut("UInt", track.Size, "UInt", 2, "Ptr", hwnd, track)
                    DllCall("user32\TrackMouseEvent", "Ptr", track)
                    DllCall("user32\InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", false)
                } else if (msg = 0x02A3 || msg = 0x0215) {
                    data.Hot := false
                    data.Pressed := false
                    DllCall("user32\InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", false)
                }
                if (msg = 0x0201 || msg = 0x0202)
                    data.Pressed := msg = 0x0201
                switch msg {
                    case 0x0007, 0x0008, 0x000A, 0x000C, 0x00F1, 0x00F3, 0x014E, 0x0201, 0x0202, 0x0128:
                        result := DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "UPtr", wParam, "Ptr", lParam, "Ptr")
                        DllCall("user32\InvalidateRect", "Ptr", hwnd, "Ptr", 0, "Int", false)
                        return result
                }
            }
        } catch as err {
            ; 不允许 AHK 异常穿过原生回调边界。
            if !this._PaintErrorLogged {
                this._PaintErrorLogged := true
                Logger.Warn("Theme", "主题绘制失败：" err.Message)
            }
        } finally {
            this._DrawingWindow := previousWindow
            this._DrawingControl := previousControl
        }
        return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "UPtr", wParam, "Ptr", lParam, "Ptr")
    }

    static _EditMessage(data, hwnd, msg, wParam, lParam) {
        ; 先保留原生文本、光标、选区及滚动条绘制；仅覆盖非客户区的亮色边缘。
        result := DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "UPtr", wParam, "Ptr", lParam, "Ptr")
        if ((this.IsDark || this.CustomActive) && !this.HighContrast) {
            if (msg = 0x0085) { ; WM_NCPAINT
                this._PaintEditBorder(data)
            } else {
                switch msg {
                    case 0x0007, 0x0008, 0x000A: ; focus gain/loss, enabled state
                        DllCall("user32\RedrawWindow", "Ptr", hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0401)
                }
            }
        }
        return result
    }

    static _PaintEditBorder(data) {
        hwnd := data.Ctrl.Hwnd
        exStyle := DllCall("user32\GetWindowLongW", "Ptr", hwnd, "Int", -20, "UInt")
        style := DllCall("user32\GetWindowLongW", "Ptr", hwnd, "Int", -16, "UInt")
        hasClientEdge := !!(exStyle & 0x0200)
        if (!hasClientEdge && !(style & 0x00800000))
            return
        rect := Buffer(16)
        if !DllCall("user32\GetWindowRect", "Ptr", hwnd, "Ptr", rect)
            return
        width := NumGet(rect, 8, "Int") - NumGet(rect, 0, "Int")
        height := NumGet(rect, 12, "Int") - NumGet(rect, 4, "Int")
        ; 使用原生边缘尺寸，不改控件样式或客户区，避免文字与布局跳动。
        edgeX := DllCall("user32\GetSystemMetrics", "Int", hasClientEdge ? 45 : 5)
        edgeY := DllCall("user32\GetSystemMetrics", "Int", hasClientEdge ? 46 : 6)
        dc := DllCall("user32\GetWindowDC", "Ptr", hwnd, "Ptr")
        if !dc
            return
        try {
            this._Fill(dc, this._Rect(0, 0, width, edgeY), "Field")
            this._Fill(dc, this._Rect(0, height - edgeY, width, height), "Field")
            this._Fill(dc, this._Rect(0, edgeY, edgeX, height - edgeY), "Field")
            this._Fill(dc, this._Rect(width - edgeX, edgeY, width, height - edgeY), "Field")
            focused := data.Ctrl.Enabled && DllCall("user32\GetFocus", "Ptr") = hwnd
            this._Frame(dc, this._Rect(0, 0, width, height), focused ? "Accent" : "Border")
        } finally
            DllCall("user32\ReleaseDC", "Ptr", hwnd, "Ptr", dc)
    }

    static _Rect(left, top, right, bottom) {
        rect := Buffer(16)
        NumPut("Int", left, "Int", top, "Int", right, "Int", bottom, rect)
        return rect
    }

    static _Fill(dc, rect, role) {
        brush := this._Brush(role)
        if (role = "Window" && this._DrawingWindow = BackgroundImage.MainHwnd && this.CustomActive && !this.HighContrast && BackgroundImage.Brush)
            brush := BackgroundImage.AlignedBrush(dc, this._DrawingControl)
        return DllCall("user32\FillRect", "Ptr", dc, "Ptr", rect, "Ptr", brush)
    }
    static _Frame(dc, rect, role) => DllCall("user32\FrameRect", "Ptr", dc, "Ptr", rect, "Ptr", this._Brush(role))

    static _Text(dc, value, rect, flags, role) {
        DllCall("gdi32\SetTextColor", "Ptr", dc, "UInt", this._Bgr(role))
        DllCall("user32\DrawTextW", "Ptr", dc, "Str", value, "Int", -1, "Ptr", rect, "UInt", flags)
    }

    static _Triangle(dc, x, y, up, role) {
        points := Buffer(24)
        dy := up ? -3 : 3
        NumPut("Int", x - 4, "Int", y - dy, "Int", x + 4, "Int", y - dy, "Int", x, "Int", y + dy, points)
        DllCall("gdi32\SelectObject", "Ptr", dc, "Ptr", DllCall("gdi32\GetStockObject", "Int", 8, "Ptr")) ; NULL_PEN
        DllCall("gdi32\SelectObject", "Ptr", dc, "Ptr", this._Brush(role))
        DllCall("gdi32\Polygon", "Ptr", dc, "Ptr", points, "Int", 3)
    }

    static _Paint(data, dc) {
        ctrl := data.Ctrl
        rect := Buffer(16)
        DllCall("user32\GetClientRect", "Ptr", ctrl.Hwnd, "Ptr", rect)
        width := NumGet(rect, 8, "Int"), height := NumGet(rect, 12, "Int")
        scale := A_ScreenDPI / 96
        pad := Round(6 * scale)
        savedDC := DllCall("gdi32\SaveDC", "Ptr", dc)
        try {
            font := DllCall("user32\SendMessageW", "Ptr", ctrl.Hwnd, "UInt", 0x0031, "UPtr", 0, "Ptr", 0, "Ptr")
            if font
                DllCall("gdi32\SelectObject", "Ptr", dc, "Ptr", font)
            DllCall("gdi32\SetBkMode", "Ptr", dc, "Int", 1)
            fg := ctrl.Enabled ? data.Fg : "Muted"
            focused := DllCall("user32\GetFocus", "Ptr") = ctrl.Hwnd
            uiState := DllCall("user32\SendMessageW", "Ptr", ctrl.Hwnd, "UInt", 0x0129, "UPtr", 0, "Ptr", 0)
            flags := 0x24 | ((uiState & 2) ? 0x100000 : 0) ; single line, vertical center, keyboard cues
            kind := data.Kind
            if (kind = "CheckBox" || kind = "GroupBox") {
                if (kind = "CheckBox") {
                    this._Fill(dc, rect, "Window")
                    size := Round(13 * scale), y := (height - size) // 2
                    checkRect := this._Rect(0, y, size, y + size)
                    this._Fill(dc, checkRect, data.Hot ? "Hover" : "Field")
                    this._Frame(dc, checkRect, focused ? "Accent" : "Border")
                    state := DllCall("user32\SendMessageW", "Ptr", ctrl.Hwnd, "UInt", 0x00F0, "UPtr", 0, "Ptr", 0)
                    if state {
                        pen := DllCall("gdi32\CreatePen", "Int", 0, "Int", Max(1, Round(2 * scale)), "UInt", this._Bgr(fg), "Ptr")
                        oldPen := DllCall("gdi32\SelectObject", "Ptr", dc, "Ptr", pen, "Ptr")
                        try {
                            DllCall("gdi32\MoveToEx", "Ptr", dc, "Int", Round(size * 0.2), "Int", y + size // 2, "Ptr", 0)
                            if state = 1 {
                                DllCall("gdi32\LineTo", "Ptr", dc, "Int", size // 2, "Int", y + Round(size * 0.8))
                                DllCall("gdi32\LineTo", "Ptr", dc, "Int", Round(size * 0.85), "Int", y + Round(size * 0.2))
                            } else
                                DllCall("gdi32\LineTo", "Ptr", dc, "Int", Round(size * 0.8), "Int", y + size // 2)
                        } finally {
                            DllCall("gdi32\SelectObject", "Ptr", dc, "Ptr", oldPen)
                            DllCall("gdi32\DeleteObject", "Ptr", pen)
                        }
                    }
                    textRect := this._Rect(size + pad, 0, width, height)
                    this._Text(dc, ctrl.Text, textRect, flags, fg)
                } else {
                    measure := this._Rect(0, 0, width, height)
                    DllCall("user32\DrawTextW", "Ptr", dc, "Str", ctrl.Text, "Int", -1, "Ptr", measure, "UInt", 0x420)
                    textHeight := NumGet(measure, 12, "Int")
                    this._Frame(dc, this._Rect(0, textHeight // 2, width, height), "Border")
                    labelRect := this._Rect(pad, 0, Min(width - pad, NumGet(measure, 8, "Int") + pad * 2), textHeight)
                    this._Fill(dc, labelRect, "Window")
                    this._Text(dc, ctrl.Text, labelRect, flags, fg)
                }
            } else {
                pressed := kind = "Button" ? (DllCall("user32\SendMessageW", "Ptr", ctrl.Hwnd, "UInt", 0x00F2, "UPtr", 0, "Ptr", 0) & 4) : data.Pressed
                bg := !ctrl.Enabled ? "Button" : pressed ? "Selected" : data.Hot ? "Hover" : kind = "DropDownList" ? "Field" : "Button"
                this._Fill(dc, rect, bg)
                isDefault := kind = "Button" && (DllCall("user32\GetWindowLongW", "Ptr", ctrl.Hwnd, "Int", -16, "UInt") & 0xF) = 1
                this._Frame(dc, rect, (focused || isDefault) && ctrl.Enabled ? "Accent" : "Border")
                if (kind = "UpDown") {
                    this._Frame(dc, this._Rect(0, 0, width, height // 2 + 1), "Border")
                    this._Triangle(dc, width // 2, height // 4, true, fg)
                    this._Triangle(dc, width // 2, height * 3 // 4, false, fg)
                } else if (kind = "DropDownList") {
                    this._Text(dc, ctrl.Text, this._Rect(pad, 0, width - pad * 4, height), flags | 0x8800, fg)
                    this._Triangle(dc, width - pad * 2, height // 2, false, fg)
                } else
                    this._Text(dc, ctrl.Text, this._Rect(pad, 0, width - pad, height), flags | 1, fg)
            }
            if (focused && !(uiState & 1))
                DllCall("user32\DrawFocusRect", "Ptr", dc, "Ptr", this._Rect(3, 3, width - 3, height - 3))
        } finally
            DllCall("gdi32\RestoreDC", "Ptr", dc, "Int", savedDC)
    }

    static _WindowDestroyed(wParam, lParam, msg, hwnd) {
        if this._Windows.Has(hwnd)
            this.Detach(hwnd)
    }

    ; 显式销毁（包括测量字体的临时 Gui）先注销，避免强引用/句柄复用残留。
    static Destroy(gui) {
        this.Detach(gui.Hwnd)
        gui.Destroy()
    }

    static Detach(hwnd) {
        if hwnd = BackgroundImage.MainHwnd {
            BackgroundImage.Clear()
            BackgroundImage.MainHwnd := 0
        }
        removed := []
        for controlHwnd, data in this._Controls {
            if (data.Parent = hwnd) {
                if data.Subclassed
                    DllCall("comctl32\RemoveWindowSubclass", "Ptr", controlHwnd, "Ptr", this._SubclassPtr, "UPtr", 1)
                removed.Push(controlHwnd)
            }
        }
        for controlHwnd in removed
            this._Controls.Delete(controlHwnd)
        if this._Windows.Has(hwnd)
            this._Windows.Delete(hwnd)
    }

    static Stop(*) {
        Critical("On")
        SetTimer(this._RefreshCallback, 0)
        windows := []
        for hwnd in this._Windows
            windows.Push(hwnd)
        for hwnd in windows
            this.Detach(hwnd)
        BackgroundImage.Stop()
        this._DeleteBrushes()
        if this._SubclassPtr {
            CallbackFree(this._SubclassPtr)
            this._SubclassPtr := 0
        }
    }
}
