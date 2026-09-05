; 自定义主题编辑器：固定内置配色，预览不写盘；完成后交回主窗口保存。
class ThemeEditor {
    static GuiObj := ""
    static Original := ""
    static Draft := ""
    static Inputs := Map()
    static Swatches := Map()
    static Status := ""
    static ImageLabel := ""
    static Fit := ""
    static Opacity := ""
    static OpacityLabel := ""
    static AcceptButton := ""
    static Owner := ""
    static Updating := false
    static PreviewCallback := ""

    static Open() {
        if this.GuiObj != "" {
            this.GuiObj.Show()
            return
        }
        if this.PreviewCallback = ""
            this.PreviewCallback := ObjBindMethod(this, "RenderPreview")
        this.Owner := GuiManager.MainGui
        this.Original := Appearance.Snapshot()
        this.Draft := this.Original.Clone()
        this.Inputs := Map(), this.Swatches := Map()
        this.GuiObj := Gui("+Owner" this.Owner.Hwnd, I18n.T("编辑自定义主题"))
        windowGui := this.GuiObj
        Theme.Attach(windowGui, true)
        Theme.SetFont(windowGui, "s9", Metrics.FontFor(I18n.GetCurrent()))
        windowGui.MarginX := 18, windowGui.MarginY := 16
        windowGui.OnEvent("Close", (*) => this.Cancel())
        windowGui.OnEvent("Escape", (*) => this.Cancel())
        labels := Map("ThemeWindow", "窗口背景", "ThemeSurface", "控件背景", "ThemeText", "主要文字", "ThemeAccent", "强调色")
        for index, key in Appearance.ColorKeys {
            y := 18 + (index - 1) * 36
            Theme.Add(windowGui, "Text", "x18 y" y " w160 h22", I18n.T(labels[key]))
            input := Theme.Add(windowGui, "Edit", "x190 y" (y - 3) " w110 h24", "#" this.Draft[key])
            input.OnEvent("Change", (*) => this.Update())
            this.Inputs[key] := input
            ; 色块展示实际用户颜色，不套用主题语义色。
            this.Swatches[key] := windowGui.Add("Progress", "x312 y" (y - 3) " w28 h24 c" this.Draft[key] " Background" this.Draft[key], 100)
            pick := Theme.Add(windowGui, "Button", "x352 y" (y - 4) " w170 h26", I18n.T("选择颜色"))
            pick.OnEvent("Click", ObjBindMethod(this, "PickColor", key))
        }
        light := Theme.Add(windowGui, "Button", "x18 y166 w246 h28", I18n.T("恢复浅色配色"))
        dark := Theme.Add(windowGui, "Button", "x276 yp w246 h28", I18n.T("恢复深色配色"))
        light.OnEvent("Click", (*) => this.ResetColors(false))
        dark.OnEvent("Click", (*) => this.ResetColors(true))
        Theme.Add(windowGui, "Text", "x18 y212 w504", I18n.T("背景图片仅用于主设置窗口"))
        select := Theme.Add(windowGui, "Button", "x18 y+10 w246 h28", I18n.T("选择背景图片"))
        remove := Theme.Add(windowGui, "Button", "x276 yp w246 h28", I18n.T("移除背景图片"))
        select.OnEvent("Click", (*) => this.PickImage())
        remove.OnEvent("Click", (*) => this.RemoveImage())
        this.ImageLabel := Theme.Add(windowGui, "Text", "x18 y+8 w504 h36", "")
        Theme.Add(windowGui, "Text", "x18 y+8 w160 h24", I18n.T("图片显示方式"))
        this.Fit := Theme.Add(windowGui, "DropDownList", "x190 yp-3 w332", [I18n.T("填满裁切"), I18n.T("完整显示")])
        this.Fit.Value := this.Draft["ThemeImageFit"] = "contain" ? 2 : 1
        this.Fit.OnEvent("Change", (*) => this.Update())
        this.OpacityLabel := Theme.Add(windowGui, "Text", "x18 y+14 w504 h22", "")
        ; 原生滑杆使用系统样式，固定编辑器背景，不受用户选色影响。
        this.Opacity := windowGui.Add("Slider", "x18 y+3 w504 h28 Range0-100 ToolTip AltSubmit", this.Draft["ThemeImageOpacity"])
        this.Opacity.OnEvent("Change", (*) => this.Update())
        this.Status := Theme.Add(windowGui, "Text", "x18 y+12 w504 h55", "")
        this.AcceptButton := Theme.Add(windowGui, "Button", "x18 y+10 w246 h30", I18n.T("完成编辑"))
        cancel := Theme.Add(windowGui, "Button", "x276 yp w246 h30", I18n.T("取消"))
        this.AcceptButton.OnEvent("Click", (*) => this.Accept())
        cancel.OnEvent("Click", (*) => this.Cancel())
        this.Owner.Opt("+Disabled")
        this.Update()
        windowGui.Show("AutoSize")
    }

    static Update() {
        if (this.Updating || this.GuiObj = "" || this.Status = "")
            return false
        valid := true
        for key, input in this.Inputs {
            color := Appearance.NormalizeColor(input.Value)
            if color = "" {
                valid := false
                continue
            }
            this.Draft[key] := color
            this.Swatches[key].Opt("c" color " Background" color)
        }
        this.AcceptButton.Enabled := valid
        if !valid {
            Theme.SetFont(this.Status, "cError")
            this.Status.Value := I18n.T("颜色格式应为 #RRGGBB")
            return false
        }
        this.Draft["ThemeImageFit"] := this.Fit.Value = 2 ? "contain" : "cover"
        this.Draft["ThemeImageOpacity"] := String(this.Opacity.Value)
        this.OpacityLabel.Value := I18n.T("图片不透明度：{1}%", this.Opacity.Value)
        SplitPath(this.Draft["ThemeImage"], &name)
        this.ImageLabel.Value := name != "" ? name : I18n.T("未选择背景图片")
        SetTimer(this.PreviewCallback, -60)
        this.UpdateStatus()
        return true
    }

    static RenderPreview() {
        if this.GuiObj = ""
            return
        Theme.Preview("custom", this.Draft)
        this.UpdateStatus()
    }

    static UpdateStatus() {
        low := Min(Appearance.Contrast(this.Draft["ThemeText"], this.Draft["ThemeWindow"]),
            Appearance.Contrast(this.Draft["ThemeText"], this.Draft["ThemeSurface"])) < 4.5
        Theme.SetFont(this.Status, BackgroundImage.ErrorText != "" ? "cError" : "cText")
        this.Status.Value := BackgroundImage.ErrorText != "" ? BackgroundImage.ErrorText
            : low ? I18n.T("文字与背景对比度较低，仍可保存；请检查预览效果")
            : I18n.T("完成编辑后，请在主窗口保存或应用；取消可恢复")
    }

    static PickColor(key, *) {
        dialog := Buffer(A_PtrSize = 8 ? 72 : 36, 0)
        custom := Buffer(64, 0)
        offsetOwner := A_PtrSize = 8 ? 8 : 4
        offsetColor := A_PtrSize = 8 ? 24 : 12
        offsetCustom := A_PtrSize = 8 ? 32 : 16
        offsetFlags := A_PtrSize = 8 ? 40 : 20
        rgb := Integer("0x" this.Draft[key])
        bgr := ((rgb & 255) << 16) | (rgb & 0xFF00) | ((rgb >> 16) & 255)
        NumPut("UInt", dialog.Size, dialog)
        NumPut("Ptr", this.GuiObj.Hwnd, dialog, offsetOwner)
        NumPut("UInt", bgr, dialog, offsetColor)
        NumPut("Ptr", custom.Ptr, dialog, offsetCustom)
        NumPut("UInt", 3, dialog, offsetFlags)
        if DllCall("comdlg32\ChooseColorW", "Ptr", dialog) {
            this.Inputs[key].Value := "#" Theme._RgbHex(NumGet(dialog, offsetColor, "UInt"))
            ; 程序赋值不触发 Edit.Change，需显式同步草稿、色块与预览。
            this.Update()
        }
    }

    static ResetColors(dark) {
        palette := dark ? Theme.Dark : Theme.Light
        this.Updating := true
        try {
            for pair in [["ThemeWindow", "Window"], ["ThemeSurface", "Field"], ["ThemeText", "Text"], ["ThemeAccent", "Accent"]]
                this.Inputs[pair[1]].Value := "#" palette[pair[2]]
        } finally this.Updating := false
        this.Update()
    }

    static PickImage() {
        path := FileSelect(1, , I18n.T("选择背景图片"), "Images (*.png; *.jpg; *.jpeg; *.bmp)")
        if path = ""
            return
        try {
            BackgroundImage.Validate(path)
            this.Draft["ThemeImage"] := path
            BackgroundImage.CacheKey := ""
            this.Update()
        } catch as err {
            Theme.SetFont(this.Status, "cError")
            this.Status.Value := err.Message
        }
    }

    static RemoveImage() {
        this.Draft["ThemeImage"] := ""
        this.Update()
    }

    static Accept() {
        if !this.Update()
            return
        Appearance.SetWorking(this.Draft)
        this.Close()
        GuiManager.TrackAppearanceChange()
    }

    static Cancel() {
        if this.GuiObj = ""
            return
        SetTimer(this.PreviewCallback, 0)
        Theme.Preview(this.Original["ThemeMode"], this.Original)
        this.Close()
    }

    static Close() {
        SetTimer(this.PreviewCallback, 0)
        windowGui := this.GuiObj
        this.GuiObj := ""
        this.Status := "", this.AcceptButton := ""
        this.Owner.Opt("-Disabled")
        Theme.Destroy(windowGui)
        this.Owner.Show()
    }
}
