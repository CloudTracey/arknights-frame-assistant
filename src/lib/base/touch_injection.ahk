class TouchInjector {
    static PT_TOUCH := 2
    static POINTER_FLAG_INRANGE := 0x00000002
    static POINTER_FLAG_INCONTACT := 0x00000004
    static POINTER_FLAG_DOWN := 0x00010000
    static POINTER_FLAG_UPDATE := 0x00020000
    static POINTER_FLAG_UP := 0x00040000
    static _Initialized := false
    static _Down := false
    static _LastX := 0
    static _LastY := 0
    static LastError := 0
    static _MouseMode := false
    static _MouseHoldMs := 10
    static _MouseGapMs := 40

    static Init(maxCount := 3, feedbackMode := 1) {
        ; Wine 的 user32.dll 没有导出 InjectTouchInput，这里探测后自动回退成鼠标注入。
        hMod := DllCall("GetModuleHandle", "Str", "user32.dll", "Ptr")
        pProc := hMod ? DllCall("GetProcAddress", "Ptr", hMod, "AStr", "InjectTouchInput", "Ptr") : 0
        if (!pProc) {
            this._MouseMode := true
            this._MouseHoldMs := this._ReadIniInt("MouseHoldMs", this._MouseHoldMs)
            this._MouseGapMs := this._ReadIniInt("MouseGapMs", this._MouseGapMs)
            this._Initialized := true
            this.LastError := 0
            return true
        }
        result := DllCall("User32.dll\InitializeTouchInjection", "UInt", maxCount, "UInt", feedbackMode, "Int")
        if (!result) {
            this.LastError := A_LastError
            return false
        }
        this._Initialized := true
        this.LastError := 0
        return true
    }

    ; 从 Settings.ini [Custom] 读取整数覆盖项（仅鼠标回退模式使用）
    static _ReadIniInt(key, def) {
        ini := A_AppData "\ArknightsFrameAssistant\PC\Settings.ini"
        if !FileExist(ini)
            return def
        v := IniRead(ini, "Custom", key, "")
        if (v = "")
            return def
        if !IsInteger(v)
            return def
        return Integer(v)
    }

    static _WriteFields(buf, x, y, flags) {
        NumPut("UInt", TouchInjector.PT_TOUCH, buf, 0)
        NumPut("UInt", 0, buf, 4)
        NumPut("UInt", flags, buf, 12)
        NumPut("Int", x, buf, 32)
        NumPut("Int", y, buf, 36)
        NumPut("UInt", 7, buf, 100)
        NumPut("UInt", 90, buf, 136)
        NumPut("UInt", 32000, buf, 140)
        NumPut("Int", x-2, buf, 104)
        NumPut("Int", y-2, buf, 108)
        NumPut("Int", x+2, buf, 112)
        NumPut("Int", y+2, buf, 116)
    }

    static _Inject(flags) {
        if (this._MouseMode) {
            hwnd := WinExist(GameTarget.WinTitle())
            pt := Buffer(8, 0)
            NumPut("Int", this._LastX, pt, 0)
            NumPut("Int", this._LastY, pt, 4)
            if (hwnd)
                DllCall("User32.dll\ClientToScreen", "Ptr", hwnd, "Ptr", pt)
            sx := NumGet(pt, 0, "Int")
            sy := NumGet(pt, 4, "Int")
            DllCall("User32.dll\SetCursorPos", "Int", sx, "Int", sy)
            if (flags & 0x00010000) {
                DllCall("User32.dll\mouse_event", "UInt", 0x0002, "UInt", 0, "UInt", 0, "UInt", 0, "UPtr", 0)
                Sleep(this._MouseHoldMs)
            } else if (flags & 0x00040000) {
                if (this._Down) {
                    DllCall("User32.dll\mouse_event", "UInt", 0x0004, "UInt", 0, "UInt", 0, "UInt", 0, "UPtr", 0)
                    Sleep(this._MouseGapMs)
                }
            }
            this.LastError := 0
            return true
        }

        hwnd := WinExist(GameTarget.WinTitle())
        pt := Buffer(8, 0)
        NumPut("Int", this._LastX, pt, 0)
        NumPut("Int", this._LastY, pt, 4)
        DllCall("User32.dll\ClientToScreen", "Ptr", hwnd, "Ptr", pt)
        buf := Buffer(144, 0)
        this._WriteFields(buf, NumGet(pt, 0, "Int"), NumGet(pt, 4, "Int"), flags)
        result := DllCall("User32.dll\InjectTouchInput", "UInt", 1, "Ptr", buf, "Int")
        if (!result) {
            this.LastError := A_LastError
            ; Logger.Warn("TouchInjector", "InjectTouchInput 失败，错误码=" this.LastError)
            return false
        }
        this.LastError := 0
        return true
    }

    ; 解析坐标，省略则用鼠标位置
    static _ResolveCoord(x?, y?) {
        if (!IsSet(x) || !IsSet(y)) {
            MouseGetPos(&mx, &my)
            if (!IsSet(x))
                x := mx
            if (!IsSet(y))
                y := my
        }
        this._LastX := x
        this._LastY := y
    }

    ; 按下
    static Down(x?, y?) {
        if (!this._Initialized) {
            this.LastError := 87
            ; Logger.Warn("TouchInjector", "Down 失败：未初始化，错误码=" this.LastError)
            return false
        }
        if (this._Down) {
            this.LastError := 87
            ; Logger.Warn("TouchInjector", "Down 失败：重复按下，错误码=" this.LastError)
            return false
        }
        this._ResolveCoord(x?, y?)
        if (!this._Inject(TouchInjector.POINTER_FLAG_INRANGE | TouchInjector.POINTER_FLAG_INCONTACT | TouchInjector.POINTER_FLAG_DOWN))
            return false
        this._Down := true
        return true
    }

    ; 抬起
    static Up(x?, y?) {
        if (!this._Initialized) {
            this.LastError := 87
            ; Logger.Warn("TouchInjector", "Up 失败：未初始化，错误码=" this.LastError)
            return false
        }

        this._ResolveCoord(x?, y?)
        if (!this._Inject(TouchInjector.POINTER_FLAG_INRANGE | TouchInjector.POINTER_FLAG_INCONTACT | TouchInjector.POINTER_FLAG_UPDATE))
            return false
        if (!this._Inject(TouchInjector.POINTER_FLAG_UP))
            return false
        this._Down := false
        return true
    }

    ; 点击
    static Tap(x?, y?) {
        if (!this.Down(x?, y?))
            return false
        return this.Up(x?, y?)
    }

    ; 无按下移动
    static Move(x?, y?) {
        if (!this._Initialized) {
            this.LastError := 87
            ; Logger.Warn("TouchInjector", "Move 失败：未初始化，错误码=" this.LastError)
            return false
        }

        this._ResolveCoord(x?, y?)
        if (!this._Inject(TouchInjector.POINTER_FLAG_INRANGE | TouchInjector.POINTER_FLAG_UPDATE))
            return false
        if (!this._Inject(TouchInjector.POINTER_FLAG_UP))
            return false
        this._Down := false
        return true
    }

    ; 将屏幕坐标换算到当前目标游戏窗口客户区，并执行无接触移动（供启动预热使用）。
    ; 与 Move 的“客户区坐标”契约分离：签名即坐标系，调用方不得混用。
    static MoveFromScreen(screenX, screenY) {
        if (!this._Initialized) {
            this.LastError := 87
            return false
        }
        hwnd := WinExist(GameTarget.WinTitle())
        if (!hwnd) {
            this.LastError := 87
            return false
        }
        pt := Buffer(8, 0)
        NumPut("Int", screenX, pt, 0)
        NumPut("Int", screenY, pt, 4)
        if (!DllCall("User32.dll\ScreenToClient", "Ptr", hwnd, "Ptr", pt)) {
            this.LastError := A_LastError
            return false
        }
        clientX := NumGet(pt, 0, "Int")
        clientY := NumGet(pt, 4, "Int")
        return this.Move(clientX, clientY)
    }
}
