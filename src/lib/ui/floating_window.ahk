class FloatingWindow {
    static GuiObj := ""
    static IsVisible := false
    static WantVisible := false
    static Changing := false
    static _EventsSubscribed := false
    static ActiveToggleHotkey := ""
    static TrayItemText := ""
    static MouseContext := ""
    static RightMouseCallback := ""
    static MouseEditTimer := ""
    static MouseEdit := ""
    static Rows := []
    static MinWindowWidth := 0
    static KeyColumnWidth := 0
    static MinWindowHeight := 0
    static Width := 0
    static Height := 0
    static ActiveGroup := ""
    static FitHeightOnNextCreate := false
    static MARGIN_X := 14
    static MARGIN_Y := 10
    static COLUMN_GAP := 20
    static ROW_GAP := 6
    static MIN_ROW_HEIGHT := 22
    static FONT_SIZE := 10
    static RESIZE_BORDER := 10
    static DRAG_INTERVAL_MS := 16
    static BASE_DPI := 96

    static Init() {
        if this._EventsSubscribed {
            this._SyncTrayCheck()
            return
        }
        this._EventsSubscribed := true
        EventBus.Subscribe("FloatingWindowToggleRequested", (*) => this.Toggle())
        for eventName in ["SettingsSaved", "SettingsApplied", "SettingsCancelled", "SettingsReset"]
            EventBus.Subscribe(eventName, (*) => this._OnSettingsCommitted())
        EventBus.Subscribe("LocaleChanged", (*) => this._OnLocaleChanged())
        this.ActiveGroup := HotkeyService.GetActiveGroup()
        EventBus.Subscribe("HotkeyGroupChanged", (data) => this._OnGroupChanged(data))
        EventBus.Subscribe("HotkeyStateChanged", (*) => this.RefreshIfVisible())
        this.MouseContext := ObjBindMethod(this, "MouseOverWindow")
        this.RightMouseCallback := ObjBindMethod(this, "BeginMouseEdit")
        this.MouseEditTimer := ObjBindMethod(this, "_UpdateMouseEdit")
        HotIf(this.MouseContext)
        Hotkey("*RButton", this.RightMouseCallback, "On")
        HotIf
        OnExit(ObjBindMethod(this, "_OnExit"))
        this._SetToggleHotkey()
        this.WantVisible := Config.ReadImportantFromIni("OverlayVisible") = "1"
        if this.WantVisible
            this._SyncVisibility()
    }

    static Show() {
        this.WantVisible := true
        this._SyncVisibility()
    }

    static AddTrayItem() {
        this.TrayItemText := I18n.T("显示/隐藏悬浮窗")
        A_TrayMenu.Add(this.TrayItemText, (*) => this.Toggle())
        this._SyncTrayCheck()
    }

    static _OnLocaleChanged() {
        nextText := I18n.T("显示/隐藏悬浮窗")
        if StrLen(this.TrayItemText) > 0 && this.TrayItemText != nextText {
            A_TrayMenu.Rename(this.TrayItemText, nextText)
            this.TrayItemText := nextText
        }
        this.RefreshIfVisible()
        this._SyncTrayCheck()
    }

    static Hide() {
        this.WantVisible := false
        this._SyncVisibility()
    }

    static Toggle() {
        this.WantVisible := !this.WantVisible
        this._SyncVisibility()
    }

    static _SyncVisibility() {
        if this.Changing
            return
        this.Changing := true
        try {
            if this.WantVisible && !IsObject(this.GuiObj)
                this._AdoptWindow(this._Create())
            if this.WantVisible {
                this._EnsureOnScreen()
                this.GuiObj.Show("NoActivate")
                this.IsVisible := true
                this._SaveGeometry()
                Logger.Info("FloatingWindow", "显示悬浮窗，逻辑尺寸=" this.Width "x" this.Height)
            } else {
                if IsObject(this.GuiObj)
                    this.GuiObj.Hide()
                this.IsVisible := false
                this._EndMouseEdit()
                this._SaveGeometry()
                Logger.Info("FloatingWindow", "隐藏悬浮窗")
            }
            this._SaveVisibility()
        } finally {
            this._SyncTrayCheck()
            this.Changing := false
        }
        if this.WantVisible != this.IsVisible
            this._SyncVisibility()
    }

    static RefreshIfVisible() {
        if this.Changing || !IsObject(this.GuiObj)
            return
        this.Changing := true
        oldGui := this.GuiObj
        replacement := ""
        try {
            oldGui.Hide()
            this.IsVisible := false
            this._EndMouseEdit()
            this._SaveGeometry()
            oldGui.GetPos(&x, &y)
            replacement := this._Create()
            WinMove(x, y, , , replacement.GuiObj)
            this._AdoptWindow(replacement)
            replacement := ""
            try oldGui.Destroy()
        } catch Error as e {
            if IsObject(replacement)
                try replacement.GuiObj.Destroy()
            Logger.Warn("FloatingWindow", "重建悬浮窗失败，保留原窗口以供继续使用和重试：" e.Message)
        } finally {
            this.Changing := false
        }
        this._SyncVisibility()
    }

    static _OnSettingsCommitted() {
        this._SetToggleHotkey()
        this.RefreshIfVisible()
    }

    static _OnGroupChanged(data) {
        if data.group = this.ActiveGroup
            return
        this.ActiveGroup := data.group
        this.FitHeightOnNextCreate := true
        this.RefreshIfVisible()
    }

    static _SetToggleHotkey() {
        HotIf
        if StrLen(this.ActiveToggleHotkey) > 0
            try Hotkey(this.ActiveToggleHotkey, , "Off")
        this.ActiveToggleHotkey := ""
        key := Config.ReadHotkeyFromIni("FloatingWindowToggle")
        if StrLen(key) > 0 {
            try {
                pureKey := RegExReplace(key, "^[~*$!^+#&<>()]+")
                registration := IsMouseKey(pureKey) || InStr(key, "$") ? key : "$" key
                Hotkey(registration, FloatingHotkeyToggle, "On")
                this.ActiveToggleHotkey := registration
                Logger.Info("FloatingWindow", "注册悬浮窗快捷键：" key)
            } catch Error as e {
                Logger.Error("FloatingWindow", "悬浮窗快捷键注册失败：" e.Message)
            }
        }
    }

    static _Create() {
        guiObj := Gui("+AlwaysOnTop +ToolWindow -Caption -Resize")
        rows := []
        try {
            guiObj.MarginX := this.MARGIN_X
            guiObj.MarginY := this.MARGIN_Y
            background := Config.ReadImportantFromIni("OverlayBackground")
            guiObj.BackColor := background
            guiObj.SetFont("s" this.FONT_SIZE " c" this._TextColor(background), Metrics.FontFor(I18n.GetCurrent()))
            guiObj.OnEvent("Close", (*) => this._HandleClose())
            enabledIds := HotkeyService.GetEnabledBindingIds()
            for item in HotkeySchema.Items {
                if !Constants.OverlayHotkeys.Has(item.id) && !enabledIds.Has(item.id)
                    continue
                key := Config.ReadHotkeyFromIni(item.id)
                if StrLen(key) > 0
                    this._AddRow(guiObj, rows, I18n.T(item.nameKey), KeyFormat.VirtualNewkeyFormat(key))
            }
            key := Config.ReadCustomFromIni("SwitchHotkey")
            if StrLen(key) > 0
                this._AddRow(guiObj, rows, I18n.T("启用/禁用热键"), KeyFormat.VirtualNewkeyFormat(key))
            for entry in Config.ReadCustomHotkeys() {
                if enabledIds.Has("CustomHotkey" entry.Index) && StrLen(entry.Name) > 0 && StrLen(entry.Key) > 0
                    this._AddRow(guiObj, rows, entry.Name, KeyFormat.VirtualNewkeyFormat(entry.Key))
            }
            if rows.Length = 0
                this._AddRow(guiObj, rows, I18n.T("当前没有已启用的按键"), "")

            minHeight := this.MARGIN_Y * 2 + (rows.Length - 1) * this.ROW_GAP
            nameWidth := 0
            keyWidth := 0
            for row in rows {
                nameWidth := Max(nameWidth, row.NameWidth)
                keyWidth := Max(keyWidth, row.KeyWidth)
                minHeight += row.Height
            }
            minWidth := this.MARGIN_X * 2 + this.COLUMN_GAP + nameWidth + keyWidth
            width := Max(minWidth, Integer(Config.ReadImportantFromIni("OverlayWidth")))
            height := this.FitHeightOnNextCreate
                ? minHeight
                : Max(minHeight, Integer(Config.ReadImportantFromIni("OverlayHeight")))
            this._LayoutRows(rows, width, keyWidth)
            guiObj.Show("Hide w" width " h" height)
            opacity := Integer(Config.ReadImportantFromIni("OverlayOpacity"))
            WinSetTransparent(Round(opacity * 255 / 100), guiObj)
            WinSetExStyle("+0x20", guiObj)
            x := Config.ReadImportantFromIni("OverlayX")
            y := Config.ReadImportantFromIni("OverlayY")
            if StrLen(x) > 0 && StrLen(y) > 0
                WinMove(Integer(x), Integer(y), , , guiObj)

            Logger.Info("FloatingWindow", "创建悬浮窗，行数=" rows.Length "，逻辑尺寸=" width "x" height "，最小宽度=" minWidth)
            return {
                GuiObj: guiObj, Rows: rows, MinWindowWidth: minWidth, KeyColumnWidth: keyWidth,
                MinWindowHeight: minHeight, Width: width, Height: height
            }
        } catch Error as e {
            guiObj.Destroy()
            Logger.Error("FloatingWindow", "创建悬浮窗失败：" e.Message)
            throw e
        }
    }

    static _AdoptWindow(window) {
        this.GuiObj := window.GuiObj
        this.Rows := window.Rows
        this.MinWindowWidth := window.MinWindowWidth
        this.KeyColumnWidth := window.KeyColumnWidth
        this.MinWindowHeight := window.MinWindowHeight
        this.Width := window.Width
        this.Height := window.Height
        this.FitHeightOnNextCreate := false
    }

    static _AddRow(guiObj, rows, name, key) {
        nameCtrl := guiObj.Add("Text", "x0 y0 +0x200", name)
        keyCtrl := guiObj.Add("Text", "x0 y0 Right +0x200", key)
        nameCtrl.GetPos(, , &nameWidth, &nameHeight)
        keyCtrl.GetPos(, , &keyWidth, &keyHeight)
        rowHeight := Max(this.MIN_ROW_HEIGHT, nameHeight, keyHeight)
        rows.Push({Name: nameCtrl, Key: keyCtrl, Height: rowHeight, NameWidth: nameWidth, KeyWidth: keyWidth})
    }

    static _LayoutRows(rows, width, keyWidth) {
        keyX := width - this.MARGIN_X - keyWidth
        y := this.MARGIN_Y
        for row in rows {
            row.Name.Move(this.MARGIN_X, y, keyX - this.MARGIN_X - this.COLUMN_GAP, row.Height)
            row.Key.Move(keyX, y, keyWidth, row.Height)
            y += row.Height + this.ROW_GAP
        }
    }

    static _TextColor(background) {
        luminance := 0.0
        for index, weight in [0.2126, 0.7152, 0.0722] {
            channel := Integer("0x" SubStr(background, (index - 1) * 2 + 1, 2)) / 255
            linear := channel <= 0.04045 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4
            luminance += weight * linear
        }
        whiteContrast := 1.05 / (luminance + 0.05)
        blackContrast := (luminance + 0.05) / 0.05
        return whiteContrast >= blackContrast ? "FFFFFF" : "000000"
    }

    static MouseOverWindow(*) {
        if !this.IsVisible || !IsObject(this.GuiObj) || KeyBinder.ModifyHook.InProgress
            return false
        if WinExist("ahk_class #32768")
            return false
        try {
            this._MouseGetScreenPos(&mouseX, &mouseY)
            MouseGetPos(, , &hoverWindow)
            if hoverWindow {
                className := WinGetClass(hoverWindow)
                if className = "Shell_TrayWnd" || className = "Shell_SecondaryTrayWnd"
                    return false
            }
            WinGetPos(&x, &y, &width, &height, this.GuiObj)
            return mouseX >= x && mouseX < x + width && mouseY >= y && mouseY < y + height
        }
        return false
    }

    static BeginMouseEdit(*) {
        if IsObject(this.MouseEdit) || !this.MouseOverWindow()
            return
        this.GuiObj.GetPos(&x, &y)
        this.GuiObj.GetClientPos(, , &width, &height)
        this._MouseGetScreenPos(&mouseX, &mouseY)
        scale := A_ScreenDPI / this.BASE_DPI
        offsetX := (mouseX - x) / scale
        offsetY := (mouseY - y) / scale
        this.MouseEdit := {
            X: x, Y: y, Width: width, Height: height, MouseX: mouseX, MouseY: mouseY,
            LastX: x, LastY: y,
            Left: offsetX <= this.RESIZE_BORDER, Right: offsetX >= width - this.RESIZE_BORDER,
            Top: offsetY <= this.RESIZE_BORDER, Bottom: offsetY >= height - this.RESIZE_BORDER
        }
        SetTimer(this.MouseEditTimer, this.DRAG_INTERVAL_MS)
    }

    static _UpdateMouseEdit(*) {
        if !IsObject(this.MouseEdit)
            return
        if !GetKeyState("RButton", "P") || !this.IsVisible {
            this._EndMouseEdit()
            return
        }
        edit := this.MouseEdit
        this._MouseGetScreenPos(&mouseX, &mouseY)
        scale := A_ScreenDPI / this.BASE_DPI
        dx := (mouseX - edit.MouseX) / scale
        dy := (mouseY - edit.MouseY) / scale
        width := edit.Width
        height := edit.Height
        x := edit.X
        y := edit.Y
        if edit.Left || edit.Right || edit.Top || edit.Bottom {
            if edit.Left || edit.Right
                width := Max(this.MinWindowWidth, Min(Constants.OVERLAY_MAX_WIDTH, edit.Width + (edit.Left ? -dx : dx)))
            if edit.Top || edit.Bottom
                height := Max(this.MinWindowHeight, Min(Constants.OVERLAY_MAX_HEIGHT, edit.Height + (edit.Top ? -dy : dy)))
            if edit.Left
                x += Round((edit.Width - width) * scale)
            if edit.Top
                y += Round((edit.Height - height) * scale)
        } else {
            x += mouseX - edit.MouseX
            y += mouseY - edit.MouseY
        }
        width := Round(width)
        height := Round(height)
        if x = edit.LastX && y = edit.LastY && width = this.Width && height = this.Height
            return
        if width != this.Width {
            this._LayoutRows(this.Rows, width, this.KeyColumnWidth)
        }
        WinMove(x, y, Round(width * scale), Round(height * scale), this.GuiObj)
        edit.LastX := x
        edit.LastY := y
        this.Width := width
        this.Height := height
    }

    static _EndMouseEdit() {
        SetTimer(this.MouseEditTimer, 0)
        if !IsObject(this.MouseEdit)
            return
        this.MouseEdit := ""
        this._SaveGeometry()
    }

    static _SyncTrayCheck() {
        if StrLen(this.TrayItemText) = 0
            return
        try {
            if this.IsVisible
                A_TrayMenu.Check(this.TrayItemText)
            else
                A_TrayMenu.Uncheck(this.TrayItemText)
        } catch Error as e {
            Logger.Warn("FloatingWindow", "同步托盘勾选失败：" e.Message)
        }
    }

    static _EnsureOnScreen() {
        WinGetPos(&x, &y, &width, &height, this.GuiObj)
        monitor := MonitorGetPrimary()
        Loop MonitorGetCount() {
            MonitorGetWorkArea(A_Index, &left, &top, &right, &bottom)
            if x + width / 2 >= left && x + width / 2 < right
                && y + height / 2 >= top && y + height / 2 < bottom {
                monitor := A_Index
                break
            }
        }
        MonitorGetWorkArea(monitor, &left, &top, &right, &bottom)
        newX := Max(left, Min(x, right - Min(width, right - left)))
        newY := Max(top, Min(y, bottom - Min(height, bottom - top)))
        if newX != x || newY != y {
            WinMove(newX, newY, , , this.GuiObj)
            Logger.Info("FloatingWindow", "恢复可见位置：" x "," y " → " newX "," newY)
        }
    }

    static _SaveGeometry() {
        if !IsObject(this.GuiObj)
            return
        this.GuiObj.GetPos(&x, &y)
        this.GuiObj.GetClientPos(, , &width, &height)
        for entry in [{Key: "OverlayX", Value: x}, {Key: "OverlayY", Value: y},
            {Key: "OverlayWidth", Value: width}, {Key: "OverlayHeight", Value: height}]
            this._PersistImportantValue(entry.Key, entry.Value)
        Logger.Info("FloatingWindow", "保存悬浮窗位置=" x "," y "，逻辑尺寸=" width "x" height)
    }

    static _SaveVisibility() {
        this._PersistImportantValue("OverlayVisible", this.WantVisible ? "1" : "0")
    }

    static _PersistImportantValue(key, value) {
        if Config.ReadImportantFromIni(key) == String(value)
            return
        result := SettingsService.UpdatePersistedValue(key, value)
        if !result.success
            Logger.Error("FloatingWindow", "保存悬浮窗配置失败，键=" key "：" result.message)
    }

    static _OnExit(*) {
        this._EndMouseEdit()
        this._SaveGeometry()
        this._SaveVisibility()
    }

    static _MouseGetScreenPos(&x, &y) {
        previousMode := CoordMode("Mouse", "Screen")
        try MouseGetPos(&x, &y)
        finally CoordMode("Mouse", previousMode)
    }

    static _HandleClose() {
        this.Hide()
        return true
    }
}

FloatingHotkeyToggle(*) {
    if KeyBinder.ModifyHook.InProgress {
        Logger.Info("FloatingWindow", "快捷键处于按键录制中，本次不切换窗口")
        return
    }
    Logger.Info("FloatingWindow", "悬浮窗快捷键触发")
    EventBus.Publish("FloatingWindowToggleRequested")
}
