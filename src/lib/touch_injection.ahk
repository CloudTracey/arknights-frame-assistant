PT_TOUCH := 2

POINTER_FLAG_INRANGE    := 0x00000002
POINTER_FLAG_INCONTACT  := 0x00000004
POINTER_FLAG_DOWN       := 0x00010000
POINTER_FLAG_UPDATE     := 0x00020000
POINTER_FLAG_UP         := 0x00040000

class TouchInjector {
    static _Initialized := false
    static _Down := false
    static _LastX := 0
    static _LastY := 0
    static LastError := 0

    static Init(maxCount := 3, feedbackMode := 1) {
        result := DllCall("User32.dll\InitializeTouchInjection", "UInt", maxCount, "UInt", feedbackMode, "Int")
        if (!result) {
            this.LastError := A_LastError
            return false
        }
        this._Initialized := true
        this.LastError := 0
        return true
    }

    static _WriteFields(buf, x, y, flags) {
        NumPut("UInt", PT_TOUCH, buf, 0)
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
        hwnd := WinExist("ahk_exe Arknights.exe")
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
        if (!this._Inject(POINTER_FLAG_INRANGE | POINTER_FLAG_INCONTACT | POINTER_FLAG_DOWN))
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
        if (!this._Inject(POINTER_FLAG_INRANGE | POINTER_FLAG_INCONTACT | POINTER_FLAG_UPDATE))
            return false
        if (!this._Inject(POINTER_FLAG_UP))
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
        if (!this._Inject(POINTER_FLAG_INRANGE | POINTER_FLAG_UPDATE))
            return false
        if (!this._Inject(POINTER_FLAG_UP))
            return false
        this._Down := false
        return true
    }
}

; == 初始化 ==
if !TouchInjector.Init(3, 1)
    ; Logger.Error("TouchInjector", "触控注入初始化失败，错误码=" TouchInjector.LastError)
MouseGetPos &xpos, &ypos
TouchInjector.Move(xpos, ypos)
MouseMove xpos, ypos
