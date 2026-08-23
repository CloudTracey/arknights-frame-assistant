; == 自定义按键编辑窗口（含坐标拾取与帮助窗口） ==
; 独立顶层 Gui（非 MainGui）——KeyBinder.WM_LBUTTONDOWN 的父窗口检查据此自动豁免按键录制。
; 设计见 docs/plan/custom_hotkeys_design.md 第 8 节：
;   - 单编辑窗口：再次打开直接切换目标行（未保存修改丢弃，D10）；
;   - 打开期间游戏前台时 50ms 轮询显示光标处比例坐标，左键拾取插入 "(x, y)" 并激活编辑窗口（点击被吞，D12）；
;   - 保存时校验命名（50 字符 + 字符集白名单）与指令语法，非法拒绝并弹窗；
;   - 帮助按钮打开只读说明窗口（D16）。

class CustomKeyEditor {
    static GuiObj := ""      ; 编辑窗口
    static RowIndex := 0     ; 目标行号（1-based）
    static NameEdit := ""
    static TypeDDL := ""
    static ScriptEdit := ""
    static PickContext := (*) => CustomKeyEditor.IsPicking()  ; 拾取 HotIf 条件对象（唯一实例，与 KeyBinder 同款箭头模式）：
                                                              ; AHK 按条件对象区分热键变体，注册/注销必须用同一对象
    static PollFn := ""        ; _PickPoll 定时器函数对象（唯一实例）：
                               ; AHK v2 的 SetTimer 按函数对象身份匹配，取消定时器必须用启动时的同一对象，
                               ; 每次新建对象会导致取消失效、50ms 定时器永不停歇地刷日志
    static PickingActive := false  ; 拾取会话是否激活（用于日志：无会话时 Close 不记"结束"）
    static BtnHelp := ""           ; 「帮助」按钮（默认焦点，误按 Enter 只打开无害的帮助窗口）

    ; 打开（或切换目标到）指定行；index 越界时忽略
    static Open(index) {
        ; 单实例：已打开则先以取消语义关闭（未保存修改丢弃，D10）
        this.Close()
        entries := Config.AllCustomHotkeys
        if index < 1 || index > entries.Length {
            Logger.Warn("CustomKeyEditor", "打开失败：行号越界 " index)
            return
        }
        this.RowIndex := index
        entry := entries[index]

        this.GuiObj := Gui(, I18n.T("编辑按键"))
        this.GuiObj.MarginX := 20
        this.GuiObj.MarginY := 20
        ; 样式对齐主设置窗口：白底 + 亮色标题栏（DWM 属性与 GuiManager.Init 一致）
        this.GuiObj.BackColor := "FFFFFF"
        hWnd := this.GuiObj.Hwnd
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hWnd, "int", 20, "int*", false, "int", 4)
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hWnd, "int", 35, "uint*", 0x00FFFFFF, "int", 4)
        this.GuiObj.SetFont("s9", Metrics.FontFor(I18n.GetCurrent()))

        ; 按键命名
        this.GuiObj.Add("Text", "xm y10 Section", I18n.T("按键命名"))
        this.NameEdit := this.GuiObj.Add("Edit", "x+10 yp-4 w330 vCustomKeyName", entry.Name)

        ; 按键类型
        this.GuiObj.Add("Text", "xs y+12", I18n.T("按键类型"))
        typeLabels := []
        for opt in Constants.CustomHotkeyTypeOptions
            typeLabels.Push(I18n.T(opt.nameKey))
        this.TypeDDL := this.GuiObj.Add("DropDownList", "x+10 yp-4 w160 vCustomKeyType", typeLabels)
        this.TypeDDL.Value := this._TypeToIndex(entry.Type)
        this.GuiObj.Add("Text", "xs y+8 c9c9c9c", I18n.T("此设置影响按键生效的范围"))

        ; 指令
        this.GuiObj.Add("Text", "xs y+12", I18n.T("指令"))
        this.ScriptEdit := this.GuiObj.Add("Edit", "xs y+6 w420 r10 +VScroll vCustomKeyScript", entry.Script)

        ; 底部按钮：帮助 / 删除 / 保存 / 取消（删除功能内置于编辑窗口，行上不放 ✕）
        ; 对齐：帮助左缘对齐上方 Edit 左缘(x20)，取消右缘对齐 Edit 右缘(x440)，删除/保存按 10px 间距分列两侧
        btnHelp := this.GuiObj.Add("Button", "x20 y+14 w80 h28", I18n.T("帮助"))
        btnHelp.OnEvent("Click", (*) => this._OnHelp())
        this.BtnHelp := btnHelp
        btnDelete := this.GuiObj.Add("Button", "x110 yp w80 h28", I18n.T("删除"))
        btnDelete.OnEvent("Click", (*) => this._OnDelete())
        btnSave := this.GuiObj.Add("Button", "x270 yp w80 h28 Default", I18n.T("保存"))
        btnSave.OnEvent("Click", (*) => this._OnSave())
        btnCancel := this.GuiObj.Add("Button", "x360 yp w80 h28", I18n.T("取消"))
        btnCancel.OnEvent("Click", (*) => this._OnCancel())
        this.GuiObj.OnEvent("Close", (*) => this._OnCancel())

        this._StartPicking()
        this.GuiObj.Show()
        this._ActivateAndFocus()
        Logger.Info("CustomKeyEditor", "打开编辑窗口：行=" index)
    }

    ; 激活编辑窗口并把默认焦点放在「帮助」按钮——误按 Enter 只会打开无害的帮助窗口；
    ; 不再聚焦指令框（聚焦会导致内容被全选，下一次拾取插入会覆盖整段脚本）。
    static _ActivateAndFocus() {
        try {
            WinActivate("ahk_id " this.GuiObj.Hwnd)
            WinWaitActive("ahk_id " this.GuiObj.Hwnd, , 0.5)
        } catch {
        }
        try this.BtnHelp.Focus()
    }

    ; 关闭（取消语义，不写回）；被 GuiManager 在增删行/重置/Rebuild 前调用（D11）
    static Close() {
        this._StopPicking()
        if this.GuiObj != "" {
            gui := this.GuiObj
            this.GuiObj := ""   ; 先置空再销毁：防止 50ms 拾取轮询/条件回调在销毁瞬间访问已销毁 Gui 的 Hwnd（"Gui has no window"）
            try gui.Destroy()
        }
        this.RowIndex := 0
        this.NameEdit := ""
        this.TypeDDL := ""
        this.ScriptEdit := ""
        this.BtnHelp := ""
    }

    ; ── 类型码 ↔ 下拉框索引 ──
    static _TypeToIndex(type) {
        for i, opt in Constants.CustomHotkeyTypeOptions {
            if opt.code = type
                return i
        }
        return 1
    }

    static _IndexToType(index) {
        if index >= 1 && index <= Constants.CustomHotkeyTypeOptions.Length
            return Constants.CustomHotkeyTypeOptions[index].code
        return "global"
    }

    ; ── 保存/取消/帮助 ──
    static _OnSave() {
        ; ① 命名校验：长度 + 字符集白名单（D14，保证存储文件严格读取无歧义）
        name := Trim(this.NameEdit.Value)
        if StrLen(name) > 50 {
            MessageBox.Error(I18n.T("按键名称不能超过 50 个字符"), I18n.T("提示"))
            return
        }
        if InStr(name, '"') || InStr(name, "\") || RegExMatch(name, "[\x00-\x1F]") {
            MessageBox.Error(I18n.T("按键名称不能包含引号或反斜杠"), I18n.T("提示"))
            return
        }
        ; ② 指令语法校验：不合法拒绝保存并弹窗（窗口保持打开）
        script := this.ScriptEdit.Value
        result := CustomScriptEngine.Validate(script)
        if (!result.success) {
            MessageBox.Error(result.message, I18n.T("自定义指令语法错误"))
            return
        }
        ; ③ 写工作副本 → 刷新行标签 → 脏值 → 冲突刷新（类型变化影响冲突组）→ 关闭
        typeCode := this._IndexToType(this.TypeDDL.Value)
        Config.SetCustomHotkeyField(this.RowIndex, "Name", name)
        Config.SetCustomHotkeyField(this.RowIndex, "Type", typeCode)
        Config.SetCustomHotkeyField(this.RowIndex, "Script", script)
        GuiManager.RefreshCustomRow(this.RowIndex)
        GuiManager.TrackCustomHotkeysChange()
        GuiManager.RefreshHotkeyConflicts()
        Logger.Info("CustomKeyEditor", "保存编辑窗口：行=" this.RowIndex ", 类型=" typeCode)
        this.Close()
    }

    static _OnCancel() {
        this.Close()
    }

    ; 删除当前行：确认 → 移除工作副本条目（整体前移）→ 刷新行/脏值/冲突 → 关闭编辑窗口
    static _OnDelete() {
        result := MessageBox.Confirm(I18n.T("确定删除该自定义按键吗？"), I18n.T("删除自定义按键"))
        if result != "Yes"
            return
        Config.RemoveCustomHotkeyAt(this.RowIndex)
        GuiManager.RefreshCustomHotkeyRows()
        GuiManager.TrackCustomHotkeysChange()
        GuiManager.RefreshHotkeyConflicts()
        Logger.Info("CustomKeyEditor", "删除自定义按键：行=" this.RowIndex)
        this.Close()
    }

    static _OnHelp() {
        CustomKeyHelp.Show()
    }

    ; ── 坐标拾取会话（编辑窗口打开期间有效） ──
    ; 触发键为 LButton（无 ~：条件命中时吞掉该次点击，D12）；条件未命中（游戏外/编辑窗口内）时点击正常透传。
    ; 条件对象必须为唯一实例（箭头函数静态属性），注册/注销按同一对象匹配变体。
    static _StartPicking() {
        if this.PollFn = ""
            this.PollFn := ObjBindMethod(CustomKeyEditor, "_PickPoll")
        SetTimer this.PollFn, 8   ; 约 120 次/秒：轮询仅做轻量 Win32 读取且只在光标位于游戏客户区时刷新 ToolTip，CPU 开销可忽略
        HotIf(this.PickContext)
        Hotkey("LButton", ObjBindMethod(CustomKeyEditor, "_OnPickKey"), "On")
        HotIf
        this.PickingActive := true
        Logger.Debug("CustomKeyEditor", "坐标拾取会话开始")
    }

    static _StopPicking() {
        if this.PollFn = ""
            this.PollFn := ObjBindMethod(CustomKeyEditor, "_PickPoll")
        SetTimer this.PollFn, 0
        ToolTip  ; 清除拾取提示
        HotIf(this.PickContext)
        try Hotkey("LButton", "Off")
        HotIf
        if this.PickingActive {
            this.PickingActive := false
            Logger.Debug("CustomKeyEditor", "坐标拾取会话结束")
        }
    }

    ; HotIf 条件：编辑窗口存在 且 光标在游戏**客户区内**（不要求游戏前台——游戏未聚焦时第一次点击即可拾取）。
    ; 拾取只对游戏 client 区域生效：游戏外、编辑窗口内、游戏标题栏（客户区 y<0）的左键一律正常透传（不吞）。
    ; 该条件只对 LButton 按压求值，不属于"游戏热键判定热路径预算"约束对象（那是 HotkeyContext 的专属约束）。
    static IsPicking() {
        try {
            if this.GuiObj = "" || !WinExist("ahk_id " this.GuiObj.Hwnd)
                return false
            return this._CursorOverGame()
        } catch {
            return false
        }
    }

    ; 光标是否位于游戏窗口客户区内：Screen 取点 → ScreenToClient 换算（游戏非前台时 Client 模式坐标会相对错误窗口，
    ; #289 同款思路），并排除标题栏/边框（客户区坐标 <0）。
    static _CursorOverGame() {
        gameHwnd := WinExist(GameTarget.WinTitle())
        if !gameHwnd
            return false
        prevCoord := CoordMode("Mouse", "Screen")
        MouseGetPos(&sx, &sy, &hwndUnder)
        CoordMode("Mouse", prevCoord)
        if hwndUnder != gameHwnd
            return false
        if !this._ScreenToClient(gameHwnd, sx, sy, &mx, &my)
            return false
        return mx >= 0 && my >= 0
    }

    ; 屏幕坐标 → 游戏客户区坐标
    static _ScreenToClient(gameHwnd, sx, sy, &mx, &my) {
        pt := Buffer(8, 0)
        NumPut("Int", sx, pt, 0)
        NumPut("Int", sy, pt, 4)
        if !DllCall("User32.dll\ScreenToClient", "Ptr", gameHwnd, "Ptr", pt)
            return false
        mx := NumGet(pt, 0, "Int")
        my := NumGet(pt, 4, "Int")
        return true
    }

    ; 8ms 轮询：光标位于游戏客户区时在光标旁显示"即将插入的比例坐标"（ToolTip 用屏幕坐标定位，游戏可非前台）
    static _PickPoll() {
        try {
            if this.GuiObj = "" || !WinExist("ahk_id " this.GuiObj.Hwnd) {
                this._StopPicking()
                return
            }
            if !this._CursorOverGame() {
                ToolTip
                return
            }
            prevCoord := CoordMode("Mouse", "Screen")
            MouseGetPos(&sx, &sy)
            CoordMode("Mouse", prevCoord)
            gameHwnd := WinExist(GameTarget.WinTitle())
            if !gameHwnd || !this._ScreenToClient(gameHwnd, sx, sy, &mx, &my) {
                ToolTip
                return
            }
            if !SafeWinGetClientPos(&ww, &wh) {
                ToolTip
                return
            }
            fx := Round(mx / ww, 4)
            fy := Round(my / wh, 4)
            prevTip := CoordMode("ToolTip", "Screen")
            ToolTip("(" fx ", " fy ")  " I18n.T("左键点击拾取坐标"), sx + 20, sy + 20)
            CoordMode("ToolTip", prevTip)
        } catch Error as e {
            Logger.Warn("CustomKeyEditor", "拾取轮询异常：" e.Message)
        }
    }

    ; 游戏前台且光标在客户区内时按下拾取键：把比例坐标插入指令 Edit 光标处，激活编辑窗口（拾取自终止）
    static _OnPickKey(*) {
        ; 双重守卫：即使热键被异常触发，条件不满足时立即返回（不执行任何拾取逻辑）
        if !this.IsPicking()
            return
        try {
            ToolTip
            ; 屏幕取点 → ScreenToClient（游戏可能非前台，Client 模式坐标会相对错误窗口）
            prevCoord := CoordMode("Mouse", "Screen")
            MouseGetPos(&sx, &sy)
            CoordMode("Mouse", prevCoord)
            gameHwnd := WinExist(GameTarget.WinTitle())
            if !gameHwnd || !this._ScreenToClient(gameHwnd, sx, sy, &mx, &my)
                return
            if !SafeWinGetClientPos(&ww, &wh)
                return
            fx := Round(mx / ww, 4)
            fy := Round(my / wh, 4)
            EditPaste("(" fx ", " fy ")", this.ScriptEdit)   ; 光标处插入 (x, y)（D3：纯坐标文本，用户自行补全 tap）
            Logger.Info("CustomKeyEditor", "拾取坐标：(" fx ", " fy ")")
            WinActivate("ahk_id " this.GuiObj.Hwnd)
            ; 不调用 ScriptEdit.Focus()：聚焦会全选内容，后续拾取插入将覆盖整段脚本
        } catch Error as e {
            Logger.Error("CustomKeyEditor", "坐标拾取失败：" e.Message)
        }
    }
}

; == 编辑按键说明窗口（只读，样式参照 ChangelogUI） ==
class CustomKeyHelp {
    static GuiObj := ""

    static Show() {
        if this.GuiObj != "" {
            try WinActivate("ahk_id " this.GuiObj.Hwnd)
            return
        }
        this.GuiObj := Gui("+AlwaysOnTop", I18n.T("编辑按键说明"))
        this.GuiObj.MarginX := 20
        this.GuiObj.MarginY := 20
        ; 样式对齐主设置窗口：白底 + 亮色标题栏
        this.GuiObj.BackColor := "FFFFFF"
        hWnd := this.GuiObj.Hwnd
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hWnd, "int", 20, "int*", false, "int", 4)
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hWnd, "int", 35, "uint*", 0x00FFFFFF, "int", 4)
        this.GuiObj.SetFont("s10", Metrics.FontFor(I18n.GetCurrent()))

        body := ""
        body .= I18n.T("每行输入一条指令，目前支持：") "`n"
        body .= "`n- " I18n.T("tap(x, y)：单击游戏窗口客户端坐标。x、y 为 0-1 之间的小数比例（0.5 即窗口中央），最多 4 位小数。") "`n"
        body .= "- " I18n.T("usleep(ms)：等待 ms 毫秒后继续执行下一条。") "`n`n"
        body .= I18n.T("示例：") "`n"
        body .= "tap(0.5, 0.5)`nusleep(600)`ntap(0.3125, 0.4567)`n`n"
        body .= I18n.T("拾取坐标：编辑窗口打开时切换到游戏窗口，按下鼠标左键即可把当前光标位置的客户端坐标（已换算为比例）插入指令光标处。") "`n`n"
        body .= I18n.T("函数名不区分大小写；tap 参数为 0-1 之间的小数，usleep 参数为非负整数；最多 500 行；空行可随意使用。") "`n`n"
        body .= I18n.T("注意：比例坐标会自动适配窗口大小变化；游戏界面改版导致按钮位置变化时，请重新拾取坐标。")

        this.GuiObj.Add("Edit", "w420 r14 ReadOnly +VScroll", body)
        btn := this.GuiObj.Add("Button", "x170 y+12 w80 Default", I18n.T("确定"))
        btn.OnEvent("Click", (*) => this._Close())
        this.GuiObj.OnEvent("Close", (*) => this._Close())
        this.GuiObj.Show()
        btn.Focus()
    }

    static _Close() {
        if this.GuiObj != ""
            try this.GuiObj.Destroy()
        this.GuiObj := ""
    }
}
