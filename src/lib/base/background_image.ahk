; 仅主窗口使用的静态背景。解码/合成在慢路径，绘制回调只取缓存画刷。
class BackgroundImage {
    static MAX_BYTES := 20 * 1024 * 1024
    static MAX_PIXELS := 16000000
    static MainHwnd := 0
    static Brush := 0
    static Bitmap := 0
    static CacheKey := ""
    static ErrorText := ""
    static _Token := 0
    static _Module := 0

    static Start() {
        if this._Token
            return
        ; GDI+ token 跨调用存在，必须持有 DLL 引用直到 Shutdown 完成。
        if !this._Module
            this._Module := DllCall("kernel32\LoadLibraryW", "Str", "gdiplus.dll", "Ptr")
        if !this._Module
            throw Error(I18n.T("图片处理初始化失败"))
        input := Buffer(A_PtrSize = 8 ? 24 : 16, 0)
        NumPut("UInt", 1, input)
        token := 0
        if DllCall("gdiplus\GdiplusStartup", "Ptr*", &token, "Ptr", input, "Ptr", 0)
            throw Error(I18n.T("图片处理初始化失败"))
        this._Token := token
    }

    static Directory() => A_AppData "\ArknightsFrameAssistant\PC\backgrounds"
    static IsManaged(name) => !!RegExMatch(name, "i)^background-[0-9-]+\.(png|jpe?g|bmp)$")
    static Path(name) => this.IsManaged(name) ? this.Directory() "\" name : name

    static Load(name) {
        this.Start()
        path := this.Path(name)
        if !RegExMatch(path, "i)^[a-z]:[\\/].*\.(png|jpe?g|bmp)$")
            throw Error(I18n.T("请选择 PNG、JPG 或 BMP 图片"))
        if (!FileExist(path) || InStr(FileExist(path), "D"))
            throw Error(I18n.T("背景图片不存在，请重新选择"))
        if FileGetSize(path) > this.MAX_BYTES
            throw Error(I18n.T("图片不得超过 20 MiB 或 1600 万像素"))
        bitmap := 0
        if DllCall("gdiplus\GdipLoadImageFromFile", "Str", path, "Ptr*", &bitmap)
            throw Error(I18n.T("图片损坏或格式不受支持"))
        try {
            w := 0, h := 0
            DllCall("gdiplus\GdipGetImageWidth", "Ptr", bitmap, "UInt*", &w)
            DllCall("gdiplus\GdipGetImageHeight", "Ptr", bitmap, "UInt*", &h)
            if (!w || !h || w * h > this.MAX_PIXELS)
                throw Error(I18n.T("图片不得超过 20 MiB 或 1600 万像素"))
            return {Image: bitmap, W: w, H: h}
        } catch as err {
            DllCall("gdiplus\GdipDisposeImage", "Ptr", bitmap)
            throw err
        }
    }

    static Validate(name) {
        image := this.Load(name)
        DllCall("gdiplus\GdipDisposeImage", "Ptr", image.Image)
    }

    ; 由 SettingsService 调用。已有托管资源不重写；新选图片复制成功才返回新标识。
    static Stage(values) {
        result := values.Clone(), created := ""
        name := result["ThemeImage"]
        if (name = "" || this.IsManaged(name))
            return {Values: result, Created: created}
        this.Validate(name)
        SplitPath(name, , , &ext)
        DirCreate(this.Directory())
        id := "background-" A_NowUTC "-" A_TickCount "-" Random(100000, 999999) "." StrLower(ext)
        created := this.Directory() "\" id
        if FileExist(created)
            throw Error(I18n.T("背景图片处理失败"))
        try {
            FileCopy(name, created, false)
            this.Validate(created)
            result["ThemeImage"] := id
            return {Values: result, Created: created}
        } catch as err {
            this.Discard(created)
            throw err
        }
    }

    static Discard(path) {
        SplitPath(path, &name, &directory)
        if (directory = this.Directory() && this.IsManaged(name) && FileExist(path))
            try FileDelete(path)
    }

    static Prepare(values, enabled) {
        if !this.MainHwnd
            return
        rc := Buffer(16)
        if !DllCall("user32\GetClientRect", "Ptr", this.MainHwnd, "Ptr", rc)
            return
        w := NumGet(rc, 8, "Int"), h := NumGet(rc, 12, "Int")
        key := enabled ":" w ":" h ":" Appearance.Signature(values)
        if (key == this.CacheKey)
            return
        this.Clear()
        this.CacheKey := key
        this.ErrorText := ""
        if (!enabled || values["ThemeImage"] = "" || values["ThemeImageOpacity"] = "0" || w <= 0 || h <= 0)
            return
        image := "", canvas := 0, graphics := 0, attrs := 0, hbitmap := 0
        try {
            image := this.Load(values["ThemeImage"])
            if DllCall("gdiplus\GdipCreateBitmapFromScan0", "Int", w, "Int", h, "Int", 0, "Int", 0x26200A, "Ptr", 0, "Ptr*", &canvas)
                throw Error(I18n.T("背景图片处理失败"))
            if DllCall("gdiplus\GdipGetImageGraphicsContext", "Ptr", canvas, "Ptr*", &graphics)
                throw Error(I18n.T("背景图片处理失败"))
            DllCall("gdiplus\GdipGraphicsClear", "Ptr", graphics, "UInt", 0xFF000000 | Integer("0x" values["ThemeWindow"]))
            DllCall("gdiplus\GdipSetInterpolationMode", "Ptr", graphics, "Int", 7)
            if DllCall("gdiplus\GdipCreateImageAttributes", "Ptr*", &attrs)
                throw Error(I18n.T("背景图片处理失败"))
            matrix := Buffer(100, 0)
            for offset in [0, 24, 48, 96]
                NumPut("Float", 1, matrix, offset)
            NumPut("Float", Number(values["ThemeImageOpacity"]) / 100, matrix, 72)
            DllCall("gdiplus\GdipSetImageAttributesColorMatrix", "Ptr", attrs, "Int", 1, "Int", true, "Ptr", matrix, "Ptr", 0, "Int", 0)
            r := Appearance.ImageRect(image.W, image.H, w, h, values["ThemeImageFit"])
            if DllCall("gdiplus\GdipDrawImageRectRect", "Ptr", graphics, "Ptr", image.Image,
                "Float", r.X, "Float", r.Y, "Float", r.W, "Float", r.H,
                "Float", 0, "Float", 0, "Float", image.W, "Float", image.H, "Int", 2, "Ptr", attrs, "Ptr", 0, "Ptr", 0)
                throw Error(I18n.T("背景图片处理失败"))
            if DllCall("gdiplus\GdipCreateHBITMAPFromBitmap", "Ptr", canvas, "Ptr*", &hbitmap, "UInt", 0xFF000000)
                throw Error(I18n.T("背景图片处理失败"))
            brush := DllCall("gdi32\CreatePatternBrush", "Ptr", hbitmap, "Ptr")
            if !brush
                throw Error(I18n.T("背景图片处理失败"))
            this.Bitmap := hbitmap, hbitmap := 0
            this.Brush := brush
        } catch as err {
            this.ErrorText := err.Message
        } finally {
            if attrs
                DllCall("gdiplus\GdipDisposeImageAttributes", "Ptr", attrs)
            if graphics
                DllCall("gdiplus\GdipDeleteGraphics", "Ptr", graphics)
            if canvas
                DllCall("gdiplus\GdipDisposeImage", "Ptr", canvas)
            if IsObject(image)
                DllCall("gdiplus\GdipDisposeImage", "Ptr", image.Image)
            if hbitmap
                DllCall("gdi32\DeleteObject", "Ptr", hbitmap)
        }
    }

    static AlignedBrush(dc, hwnd) {
        if !this.Brush
            return 0
        point := Buffer(8, 0)
        if hwnd != this.MainHwnd
            DllCall("user32\MapWindowPoints", "Ptr", hwnd, "Ptr", this.MainHwnd, "Ptr", point, "UInt", 1)
        DllCall("gdi32\SetBrushOrgEx", "Ptr", dc, "Int", -NumGet(point, 0, "Int"), "Int", -NumGet(point, 4, "Int"), "Ptr", 0)
        return this.Brush
    }

    static Clear() {
        if this.Brush
            DllCall("gdi32\DeleteObject", "Ptr", this.Brush)
        if this.Bitmap
            DllCall("gdi32\DeleteObject", "Ptr", this.Bitmap)
        this.Brush := 0, this.Bitmap := 0, this.CacheKey := ""
    }

    static Stop() {
        this.Clear()
        this.MainHwnd := 0
        if this._Token
            DllCall("gdiplus\GdiplusShutdown", "Ptr", this._Token)
        this._Token := 0
        if this._Module
            DllCall("kernel32\FreeLibrary", "Ptr", this._Module)
        this._Module := 0
    }
}
