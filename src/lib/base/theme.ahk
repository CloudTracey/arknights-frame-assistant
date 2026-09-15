; == 应用主题 ==
; 只负责显示状态和 Win32 绘制，不写配置、不引用 core/ui、不启动游戏逻辑。
; 数据流：已保存模式 + 临时预览 -> 系统/高对比度解析 -> 语义配色 -> 窗口/控件刷新。
; Win32 支持版本、HRESULT/BOOL 区别与资源所有权见 docs/win_docs/theme_api_compatibility.md。
class Theme {
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
    static _Warned := Map()           ; 按失败操作去重，而非 HWND，避免重复建窗刷日志
    static _PendingWarnings := []     ; 绘制回调只排队，日志 IO 延后到一次性定时器
    static _WarningCallback := ""

    static DWMWA_USE_IMMERSIVE_DARK_MODE := 20
    static DWMWA_CAPTION_COLOR := 35
    static DWMWA_SYSTEMBACKDROP_TYPE := 38
    static DWMSBT_NONE := 1

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

    ; 规范化规则唯一实现在 Constants.NormalizeThemeMode；此处仅保留对外薄封装。
    static Normalize(mode) => Constants.NormalizeThemeMode(mode)

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
        this._WarningCallback := ObjBindMethod(this, "_FlushWarnings")
        try this.SavedMode := this.Normalize(Config.ReadImportantFromIni("ThemeMode"))
        catch as err
            this._WarnOnce("ReadThemeMode", "读取主题设置失败，使用 auto：" err.Message)
        this._RefreshCallback := ObjBindMethod(this, "Refresh")
        this._SubclassPtr := CallbackCreate(ObjBindMethod(this, "_Subclass"), , 6)
        ; WM_SETTINGCHANGE / WM_THEMECHANGED / WM_SYSCOLORCHANGE。
        for msg in [0x001A, 0x031A, 0x0015]
            OnMessage(msg, ObjBindMethod(this, "_SystemChanged"))
        for msg in [0x0133, 0x0134, 0x0135, 0x0136, 0x0138]
            OnMessage(msg, ObjBindMethod(this, "_ControlColor"))
        OnMessage(0x0082, ObjBindMethod(this, "_WindowDestroyed"))
        ; -1：早于 main.ahk 的 HandleAfaExit 执行，保证停止日志写在 [Shutdown] 标记之前
        OnExit(ObjBindMethod(this, "Stop"), -1)
        Logger.Info("Theme", "初始化：Windows=" A_OSVersion ", AHK=" A_AhkVersion ", ptr=" A_PtrSize ", saved=" this.SavedMode)
        this.Refresh()
    }

    static Preview(mode) {
        this.Init()
        normalized := this.Normalize(mode)
        if (this.PreviewMode != normalized)
            Logger.Info("Theme", "预览：" (this.PreviewMode != "" ? this.PreviewMode : this.SavedMode) " -> " normalized)
        this.PreviewMode := normalized
        this.Refresh()
    }

    ; 仅在初始化、成功持久化或取消时调用；按键重置不结束主题预览。
    static Confirm(mode) {
        this.Init()
        normalized := this.Normalize(mode)
        if (this.SavedMode != normalized || this.PreviewMode != "")
            Logger.Info("Theme", "确认/恢复：saved=" this.SavedMode ", preview=" this.PreviewMode " -> " normalized)
        this.SavedMode := normalized
        this.PreviewMode := ""
        this.Refresh()
    }

    static _SystemChanged(*) {
        ; 广播会到达多个窗口；一次性计时器合并通知，不在消息回调内批量重绘。
        SetTimer(this._RefreshCallback, -50)
    }

    static Refresh(*) {
        wasCritical := A_IsCritical
        Critical("On")
        try this._Refresh()
        finally Critical(wasCritical)
    }

    static _Refresh() {
        appsLight := 1
        try appsLight := RegRead("HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize", "AppsUseLightTheme", 1)
        catch as err
            this._WarnOnce("AppsUseLightTheme", "读取系统应用主题失败，使用浅色默认值：" err.Message)
        ; HIGHCONTRASTW：cbSize(4) + dwFlags(4) + LPWSTR(指针宽度)；只读取 HCF_HIGHCONTRASTON。
        hc := Buffer(8 + A_PtrSize, 0)
        NumPut("UInt", hc.Size, hc)
        if DllCall("user32\SystemParametersInfoW", "UInt", 0x42, "UInt", hc.Size, "Ptr", hc, "UInt", 0)
            this.HighContrast := !!(NumGet(hc, 4, "UInt") & 1)
        else
            this._WarnOnce("SPI_GET HIGHCONTRAST", "高对比度查询失败，保留上次状态，win32=" A_LastError)
        this.IsDark := this.Resolve(this.SavedMode, this.PreviewMode, appsLight, this.HighContrast) = "dark"
        signature := this.IsDark ":" this.HighContrast
        if this.HighContrast {
            for index in [5, 8, 13, 15, 17, 18, 26]
                signature .= ":" DllCall("user32\GetSysColor", "Int", index, "UInt")
        }
        if (signature = this._PaletteSignature)
            return
        this._PaletteSignature := signature
        Logger.Info("Theme", "应用配色：saved=" this.SavedMode ", preview=" this.PreviewMode
            ", systemLight=" appsLight ", dark=" this.IsDark ", highContrast=" this.HighContrast ", windows=" this._Windows.Count)
        ; 高对比度色可在模式不变时变化，旧画刷在本轮应用前统一释放。
        this._DeleteBrushes()
        for hwnd, window in this._Windows {
            window.Gui.BackColor := this.Color("Window")
            this._TitleBar(hwnd)
        }
        for hwnd, data in this._Controls {
            if !data.Alias
                this._ApplyControl(data)
        }
        for hwnd, window in this._Windows
            DllCall("user32\RedrawWindow", "Ptr", hwnd, "Ptr", 0, "Ptr", 0, "UInt", 0x0485) ; include non-client borders
    }

    static Color(role) {
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
        palette := this.IsDark ? this.Dark : this.Light
        return palette.Has(role) ? palette[role] : palette["Text"]
    }

    static _RgbHex(bgr) => Format("{:06X}", ((bgr & 255) << 16) | (bgr & 0xFF00) | ((bgr >> 16) & 255))
    static _Bgr(role) {
        ; 文案/配置采用 RRGGBB；Win32 COLORREF 为 0x00BBGGRR，不能直接混用。
        rgb := Integer("0x" this.Color(role))
        return ((rgb & 255) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 255)
    }

    static _Brush(role) {
        color := this._Bgr(role)
        if !this._Brushes.Has(color) {
            brush := DllCall("gdi32\CreateSolidBrush", "UInt", color, "Ptr")
            if !brush {
                this._WarnOnce("CreateSolidBrush", "创建主题画刷失败，使用系统黑/白画刷，role=" role)
                ; Stock object 属于系统，不能纳入 _Brushes 的 DeleteObject 所有权。
                return DllCall("gdi32\GetStockObject", "Int", this.IsDark ? 4 : 0, "Ptr")
            }
            this._Brushes[color] := brush
        }
        return this._Brushes[color]
    }

    static _DeleteBrushes() {
        for color, brush in this._Brushes {
            if !DllCall("gdi32\DeleteObject", "Ptr", brush)
                this._WarnOnce("DeleteObject", "释放主题画刷失败；检查画刷是否仍选入 DC")
        }
        this._Brushes.Clear()
    }

    static Attach(gui) {
        this.Init()
        if this._Windows.Has(gui.Hwnd)
            return
        this._Windows[gui.Hwnd] := {Gui: gui, FontRole: "Text"}
        gui.BackColor := this.Color("Window")
        gui.SetFont("c" this.Color("Text"))
        this._TitleBar(gui.Hwnd)
        Logger.Debug("Theme", "登记窗口：hwnd=" gui.Hwnd ", windows=" this._Windows.Count)
    }

    static _TitleBar(hwnd) {
        ; 属性 20 在 Windows 10 上按能力尝试，失败不影响客户区；35 仅在 Win11 使用。
        this.SetWindowAttribute(hwnd, this.DWMWA_USE_IMMERSIVE_DARK_MODE, this.IsDark && !this.HighContrast)
        ; 清除旧主窗口硬编码的白色标题栏；高对比度交还系统。
        caption := this.HighContrast ? 0xFFFFFFFF : this._Bgr("Window")
        this.SetWindowAttribute(hwnd, this.DWMWA_CAPTION_COLOR, caption)
    }

    ; 仅供窗口初始化/主题切换使用；BOOL、COLORREF、枚举在这些属性中均占 4 字节。
    ; DwmSetWindowAttribute 返回 HRESULT（负数失败），不是 BOOL；try 本身不会捕获失败 HRESULT。
    static SetWindowAttribute(hwnd, attribute, value) {
        if !this._SupportsDwmAttribute(attribute, A_OSVersion) {
            this._WarnOnce("DwmVersion:" attribute, "当前 Windows 不支持可选 DWM 属性 " attribute "，保留原生外观，os=" A_OSVersion)
            return false
        }
        try {
            hr := DllCall("dwmapi\DwmSetWindowAttribute", "Ptr", hwnd, "UInt", attribute, "UInt*", value, "UInt", 4, "Int")
            if (hr < 0) {
                this._WarnOnce("DwmSet:" attribute, "DWM 属性设置失败，保留原生外观，attribute=" attribute ", HRESULT=" Format("0x{:08X}", hr & 0xFFFFFFFF))
                return false
            }
            Logger.Debug("Theme", "DWM属性：hwnd=" hwnd ", attribute=" attribute ", value=" value)
            return true
        } catch as err {
            this._WarnOnce("DwmCall:" attribute, "DWM 调用失败，attribute=" attribute ": " err.Message)
            return false
        }
    }

    static _SupportsDwmAttribute(attribute, osVersion) {
        if (attribute = this.DWMWA_CAPTION_COLOR)
            return VerCompare(osVersion, "10.0.22000") >= 0
        if (attribute = this.DWMWA_SYSTEMBACKDROP_TYPE)
            return VerCompare(osVersion, "10.0.22621") >= 0
        ; 深色标题栏属性在 Win10 仅作能力尝试，最终以 HRESULT 为准。
        return true
    }

    ; 每种故障每进程最多记录一次；回调中不直接写盘、不弹窗、不携带控件文本。
    static _WarnOnce(key, message) {
        if this._Warned.Has(key)
            return
        this._Warned[key] := true
        this._PendingWarnings.Push(message)
        if this._WarningCallback != ""
            SetTimer(this._WarningCallback, -1)
    }

    static _FlushWarnings(*) {
        pending := this._PendingWarnings
        this._PendingWarnings := []
        for message in pending
            Logger.Warn("Theme", message)
    }

    ; 与 Gui.Add 保持参数/返回值语义，只把主题色角色解析为当前颜色并登记控件。
    static Add(gui, kind, options := "", args*) {
        this.Attach(gui)
        fg := this._Windows[gui.Hwnd].FontRole
        bg := (kind = "Edit" || kind = "DropDownList") ? "Field" : "Window"
        options := this._FontOptions(options, &fg)
        if RegExMatch(options, "i)(?<!\S)Background(\w+)(?=\s|$)", &m) {
            bg := m[1]
            if bg != "Trans"
                options := StrReplace(options, m[0], "Background" this.Color(bg))
        }
        ; WS_EX_COMPOSITED 按兄弟窗口顺序合成；透明文字需延后到下层背景之后绘制。
        ; BackgroundTrans 仅提供透明画刷，不等同于 WS_EX_TRANSPARENT 的绘制顺序语义。
        if (kind = "Text" && bg = "Trans")
            options .= " +E0x20"
        ctrl := gui.Add(kind, options, args*)
        data := {Ctrl: ctrl, Parent: gui.Hwnd, Fg: fg, Bg: bg, Hot: false, Pressed: false,
            Alias: false, Subclassed: false, CheckTheme: 0}
        this._Controls[ctrl.Hwnd] := data
        if (kind = "Edit" || kind = "Button" || kind = "Checkbox" || kind = "DropDownList" || kind = "GroupBox" || kind = "UpDown") {
            data.Subclassed := !!DllCall("comctl32\SetWindowSubclass", "Ptr", ctrl.Hwnd,
                "Ptr", this._SubclassPtr, "UPtr", 1, "UPtr", 0)
            if !data.Subclassed
                this._WarnOnce("Subclass:" kind, "安装主题子类失败，保留原生控件，type=" kind ", hwnd=" ctrl.Hwnd)
        }
        if (kind = "DropDownList") {
            ; COMBOBOXINFO：x64 大小64/hwndList偏移56；x86 大小52/偏移48（指针对齐不同）。
            info := Buffer(A_PtrSize = 8 ? 64 : 52, 0)
            NumPut("UInt", info.Size, info)
            if DllCall("user32\GetComboBoxInfo", "Ptr", ctrl.Hwnd, "Ptr", info) {
                list := NumGet(info, A_PtrSize = 8 ? 56 : 48, "Ptr")
                this._Controls[list] := {Ctrl: ctrl, Parent: gui.Hwnd, Fg: fg, Bg: "Field", Alias: true, Subclassed: false}
            } else
                this._WarnOnce("GetComboBoxInfo", "获取下拉列表句柄失败，列表保留原生样式，win32=" A_LastError)
        }
        this._ApplyControl(data)
        return ctrl
    }

    static _FontOptions(options, &role) {
        if RegExMatch(options, "i)(?<!\S)c(Default|Text|Accent|Link|Heading|Muted|Hint|Secondary|Caption|Grip|Error|Unsaved)(?=\s|$)", &m) {
            role := m[1] = "Default" ? "Text" : m[1]
            options := StrReplace(options, m[0], "c" this.Color(role))
        }
        return options
    }

    static SetFont(target, options := "", fontName?) {
        if (Type(target) = "Gui") {
            this.Attach(target)
            data := this._Windows[target.Hwnd]
            role := data.FontRole
            options := this._FontOptions(options, &role)
            data.FontRole := role
        } else {
            data := this._Controls[target.Hwnd]
            role := data.Fg
            options := this._FontOptions(options, &role)
            data.Fg := role
            if IsSet(fontName)
                data.IconFont := fontName = "Segoe MDL2 Assets"
        }
        target.SetFont(options, fontName?)
        if (Type(target) != "Gui" && target.Type = "CheckBox")
            this._ApplyControl(data)
    }

    static _ApplyControl(data) {
        ctrl := data.Ctrl
        kind := ctrl.Type
        ; 文本颜色由 WM_CTLCOLOR/绘制回调实时解析；切换时不批量重建数百个字体。
        if (kind = "Progress") {
            ctrl.Opt("c" this.Color("Accent") " Background" this.Color("Row"))
        }
        ; 使用公开按名 API（不依赖 uxtheme 序号函数）。绘制消息负责内容区颜色。
        if (kind = "CheckBox") {
            this._CloseCheckTheme(data)
            ; AHK 自定义文字颜色会关闭复选框视觉主题，恢复默认关联以保留浅色现代样式。
            hr := DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Ptr", 0, "Ptr", 0, "Int")
        } else if (kind = "Edit") {
            ; 深色边框由本模块绘制，关闭原生主题悬停动画，避免两套边框反复覆盖。
            ; 带滚动条的多行 Edit 保留系统视觉主题，避免滚动条退回经典箭头/轨道。
            ; 非客户区外边框仍由 _PaintEditBorder 处理，不接管滚动区域或输入行为。
            style := DllCall("user32\GetWindowLongW", "Ptr", ctrl.Hwnd, "Int", -16, "UInt")
            if (this.IsDark && !this.HighContrast && !(style & 0x00300000))
                hr := DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Str", "", "Str", "", "Int")
            else
                hr := DllCall("uxtheme\SetWindowTheme", "Ptr", ctrl.Hwnd, "Ptr", 0, "Ptr", 0, "Int")
        }
        if (IsSet(hr) && hr < 0)
            this._WarnOnce("SetWindowTheme:" kind, "控件视觉主题设置失败，type=" kind ", HRESULT=" Format("0x{:08X}", hr & 0xFFFFFFFF))
    }

    static _ControlColor(dc, hwnd, msg, parent) {
        if !this._Controls.Has(hwnd)
            return
        data := this._Controls[hwnd]
        fg := data.Ctrl.Enabled ? data.Fg : "Muted"
        DllCall("gdi32\SetTextColor", "Ptr", dc, "UInt", this._Bgr(fg))
        if (data.Bg = "Trans") {
            DllCall("gdi32\SetBkMode", "Ptr", dc, "Int", 1)
            return DllCall("gdi32\GetStockObject", "Int", 5, "Ptr") ; NULL_BRUSH
        }
        DllCall("gdi32\SetBkMode", "Ptr", dc, "Int", 2)
        DllCall("gdi32\SetBkColor", "Ptr", dc, "UInt", this._Bgr(data.Bg))
        return this._Brush(data.Bg)
    }

    ; 保留原生控件的输入/焦点/勾选/可访问性；只在深色下接管绘制。
    static _Subclass(hwnd, msg, wParam, lParam, id, refData) {
        Critical("On")
        try {
            if (msg = 0x0082) {
                DllCall("comctl32\RemoveWindowSubclass", "Ptr", hwnd, "Ptr", this._SubclassPtr, "UPtr", id)
                if this._Controls.Has(hwnd) {
                    this._CloseCheckTheme(this._Controls[hwnd])
                    this._Controls.Delete(hwnd)
                }
            } else if this._Controls.Has(hwnd) {
                data := this._Controls[hwnd]
                if (msg = 0x031A)
                    this._CloseCheckTheme(data)
                if (data.Ctrl.Type = "Edit")
                    return this._EditMessage(data, hwnd, msg, wParam, lParam)
                if (this.IsDark && !this.HighContrast) {
                    if (msg = 0x000F || msg = 0x0318) { ; WM_PAINT / WM_PRINTCLIENT
                        ; PAINTSTRUCT x64=72/x86=64。WM_PRINTCLIENT 借用调用者 HDC，不执行 EndPaint。
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
                    ; TRACKMOUSEEVENT：cbSize/flags 各4字节，HWND 后跟 hoverTime；x64 尾部对齐至24。
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
                this._WarnOnce("PaintException", "主题绘制失败：type=" (IsSet(data) ? data.Ctrl.Type : "unknown")
                    ", hwnd=" hwnd ", msg=" Format("0x{:04X}", msg) ": " err.Message)
            }
        }
        return DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "UPtr", wParam, "Ptr", lParam, "Ptr")
    }

    static _EditMessage(data, hwnd, msg, wParam, lParam) {
        ; 先保留原生文本、光标、选区及滚动条绘制；仅覆盖非客户区的亮色边缘。
        result := DllCall("comctl32\DefSubclassProc", "Ptr", hwnd, "UInt", msg, "UPtr", wParam, "Ptr", lParam, "Ptr")
        if (this.IsDark && !this.HighContrast) {
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

    static _CloseCheckTheme(data) {
        if (data.HasOwnProp("CheckTheme") && data.CheckTheme) {
            hr := DllCall("uxtheme\CloseThemeData", "Ptr", data.CheckTheme, "Int")
            if (hr < 0)
                this._WarnOnce("CloseThemeData", "关闭复选框主题句柄失败，HRESULT=" Format("0x{:08X}", hr & 0xFFFFFFFF))
            data.CheckTheme := 0
        }
    }

    static _DrawCheck(data, dc, rect, state) {
        if !data.CheckTheme {
            data.CheckTheme := DllCall("uxtheme\OpenThemeData", "Ptr", data.Ctrl.Hwnd, "Str", "Button", "Ptr")
            if !data.CheckTheme
                this._WarnOnce("OpenThemeData:Button", "系统未提供 Button 视觉主题，复选框使用原生经典绘制")
        }
        pressed := data.Pressed || (DllCall("user32\SendMessageW", "Ptr", data.Ctrl.Hwnd, "UInt", 0x00F2, "UPtr", 0, "Ptr", 0) & 4)
        ; BP_CHECKBOX=3；未选/已选/混合各有 normal/hot/pressed/disabled 四种状态。
        visualState := (state = 1 ? 4 : state = 2 ? 8 : 0)
            + (!data.Ctrl.Enabled ? 4 : pressed ? 3 : data.Hot ? 2 : 1)
        if data.CheckTheme {
            hr := DllCall("uxtheme\DrawThemeBackground", "Ptr", data.CheckTheme, "Ptr", dc,
                "Int", 3, "Int", visualState, "Ptr", rect, "Ptr", 0, "Int")
            if (hr >= 0)
                return
            this._WarnOnce("DrawThemeBackground:Button", "复选框主题绘制失败，使用经典绘制，HRESULT=" Format("0x{:08X}", hr & 0xFFFFFFFF))
        }
        ; 系统关闭视觉样式时仍保留可辨认的原生勾选状态。
        flags := (state = 2 ? 8 : 0) | (state ? 0x400 : 0)
            | (!data.Ctrl.Enabled ? 0x100 : 0) | (pressed ? 0x200 : 0)
        DllCall("user32\DrawFrameControl", "Ptr", dc, "Ptr", rect, "UInt", 4, "UInt", flags)
    }

    static _Rect(left, top, right, bottom) {
        ; RECT 的四个 LONG 始终为32位，x86/x64 均16字节；坐标已是设备像素。
        rect := Buffer(16)
        NumPut("Int", left, "Int", top, "Int", right, "Int", bottom, rect)
        return rect
    }

    static _Fill(dc, rect, role) => DllCall("user32\FillRect", "Ptr", dc, "Ptr", rect, "Ptr", this._Brush(role))
    static _Frame(dc, rect, role) => DllCall("user32\FrameRect", "Ptr", dc, "Ptr", rect, "Ptr", this._Brush(role))

    static _Text(dc, value, rect, flags, role) {
        DllCall("gdi32\SetTextColor", "Ptr", dc, "UInt", this._Bgr(role))
        DllCall("user32\DrawTextW", "Ptr", dc, "Str", value, "Int", -1, "Ptr", rect, "UInt", flags)
    }

    static _Triangle(dc, x, y, up, role) {
        ; 3 个 POINT（每个两个32位 LONG）；画刷/画笔由外层 SaveDC/RestoreDC 恢复。
        points := Buffer(24)
        dy := up ? -3 : 3
        NumPut("Int", x - 4, "Int", y - dy, "Int", x + 4, "Int", y - dy, "Int", x, "Int", y + dy, points)
        DllCall("gdi32\SelectObject", "Ptr", dc, "Ptr", DllCall("gdi32\GetStockObject", "Int", 8, "Ptr")) ; NULL_PEN
        DllCall("gdi32\SelectObject", "Ptr", dc, "Ptr", this._Brush(role))
        DllCall("gdi32\Polygon", "Ptr", dc, "Ptr", points, "Int", 3)
    }

    static _Paint(data, dc) {
        ; 这里只借用绘制 HDC。SaveDC/RestoreDC 成对恢复字体、画刷及背景模式；不做日志 IO。
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
            kind := ctrl.Type
            if (kind = "CheckBox" || kind = "GroupBox") {
                if (kind = "CheckBox") {
                    this._Fill(dc, rect, "Window")
                    size := Round(13 * scale), y := (height - size) // 2
                    checkRect := this._Rect(0, y, size, y + size)
                    state := DllCall("user32\SendMessageW", "Ptr", ctrl.Hwnd, "UInt", 0x00F0, "UPtr", 0, "Ptr", 0)
                    this._DrawCheck(data, dc, checkRect, state)
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
                ; GuiControl.Type 返回 DDL，而非创建控件时使用的 DropDownList。
                bg := !ctrl.Enabled ? "Button" : pressed ? "Selected" : data.Hot ? "Hover" : kind = "DDL" ? "Field" : "Button"
                this._Fill(dc, rect, bg)
                isDefault := kind = "Button" && (DllCall("user32\GetWindowLongW", "Ptr", ctrl.Hwnd, "Int", -16, "UInt") & 0xF) = 1
                this._Frame(dc, rect, (focused || isDefault) && ctrl.Enabled ? "Accent" : "Border")
                if (kind = "UpDown") {
                    this._Frame(dc, this._Rect(0, 0, width, height // 2 + 1), "Border")
                    this._Triangle(dc, width // 2, height // 4, true, fg)
                    this._Triangle(dc, width // 2, height * 3 // 4, false, fg)
                } else if (kind = "DDL") {
                    this._Text(dc, ctrl.Text, this._Rect(pad, 0, width - pad * 4, height), flags | 0x8800, fg)
                    this._Triangle(dc, width - pad * 2, height // 2, false, fg)
                } else {
                    ; 20px 图标按钮不使用普通文字按钮的 6px 边距，避免裁切齿轮。
                    textPad := data.HasOwnProp("IconFont") && data.IconFont ? Max(1, Round(scale)) : pad
                    this._Text(dc, ctrl.Text, this._Rect(textPad, 0, width - textPad, height), flags | 1, fg)
                }
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
        removed := []
        for controlHwnd, data in this._Controls {
            if (data.Parent = hwnd) {
                this._CloseCheckTheme(data)
                if data.Subclassed
                    DllCall("comctl32\RemoveWindowSubclass", "Ptr", controlHwnd, "Ptr", this._SubclassPtr, "UPtr", 1)
                removed.Push(controlHwnd)
            }
        }
        for controlHwnd in removed
            this._Controls.Delete(controlHwnd)
        if this._Windows.Has(hwnd) {
            this._Windows.Delete(hwnd)
            Logger.Debug("Theme", "注销窗口：hwnd=" hwnd ", controls=" removed.Length ", windows=" this._Windows.Count)
        }
    }

    static Stop(*) {
        Logger.Info("Theme", "停止：windows=" this._Windows.Count ", controls=" this._Controls.Count ", brushes=" this._Brushes.Count)
        SetTimer(this._RefreshCallback, 0)
        windows := []
        for hwnd in this._Windows
            windows.Push(hwnd)
        for hwnd in windows
            this.Detach(hwnd)
        this._DeleteBrushes()
        if this._SubclassPtr {
            CallbackFree(this._SubclassPtr)
            this._SubclassPtr := 0
        }
        SetTimer(this._WarningCallback, 0)
        this._FlushWarnings()
    }
}
