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
    static PickContext := "" ; 拾取 HotIf 条件函数对象（唯一实例）：
                             ; AHK 按条件对象区分热键变体，注册与注销必须用同一对象，
                             ; 每次 ObjBindMethod 都是新对象会导致注销打不中、热键残留全局生效

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
        btnHelp := this.GuiObj.Add("Button", "x55 y+14 w80 h28", I18n.T("帮助"))
        btnHelp.OnEvent("Click", (*) => this._OnHelp())
        btnDelete := this.GuiObj.Add("Button", "x145 yp w80 h28", I18n.T("删除"))
        btnDelete.OnEvent("Click", (*) => this._OnDelete())
        btnSave := this.GuiObj.Add("Button", "x255 yp w80 h28 Default", I18n.T("保存"))
        btnSave.OnEvent("Click", (*) => this._OnSave())
        btnCancel := this.GuiObj.Add("Button", "x345 yp w80 h28", I18n.T("取消"))
        btnCancel.OnEvent("Click", (*) => this._OnCancel())
        this.GuiObj.OnEvent("Close", (*) => this._OnCancel())

        this._StartPicking()
        this.GuiObj.Show()
        this.ScriptEdit.Focus()
    }

    ; 关闭（取消语义，不写回）；被 GuiManager 在增删行/重置/Rebuild 前调用（D11）
    static Close() {
        this._StopPicking()
        if this.GuiObj != "" {
            try this.GuiObj.Destroy()
            this.GuiObj := ""
        }
        this.RowIndex := 0
        this.NameEdit := ""
        this.TypeDDL := ""
        this.ScriptEdit := ""
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
        this.Close()
    }

    static _OnHelp() {
        CustomKeyHelp.Show()
    }

    ; ── 坐标拾取会话（编辑窗口打开期间有效） ──
    static _StartPicking() {
        if this.PickContext = ""
            this.PickContext := ObjBindMethod(CustomKeyEditor, "IsPicking")
        SetTimer ObjBindMethod(CustomKeyEditor, "_PickPoll"), 50
        HotIf(this.PickContext)
        Hotkey("LButton", ObjBindMethod(CustomKeyEditor, "_OnPickLButton"), "On")  ; 无 ~：条件命中时吞掉该次点击（D12）
        HotIf
    }

    static _StopPicking() {
        SetTimer ObjBindMethod(CustomKeyEditor, "_PickPoll"), 0
        ToolTip  ; 清除拾取提示
        if this.PickContext = ""
            this.PickContext := ObjBindMethod(CustomKeyEditor, "IsPicking")
        HotIf(this.PickContext)
        try Hotkey("LButton", "Off")
        HotIf
    }

    ; HotIf 条件：编辑窗口存在 且 游戏窗口为前台 且 光标在游戏客户区内——
    ; 拾取只对游戏 client 区域生效，游戏外的左键一律正常透传（不吞）。
    ; 短路求值：编辑器未开时零 Win32 调用；该条件只对 LButton 按压求值，
    ; 不属于"游戏热键判定热路径预算"约束对象（那是 HotkeyContext 的专属约束）。
    static IsPicking() {
        if this.GuiObj = "" || !WinExist("ahk_id " this.GuiObj.Hwnd)
            return false
        return WinActive(GameTarget.WinTitle()) && IsMouseInClient()
    }

    ; 50ms 慢路径定时器：游戏前台时在光标旁显示"即将插入的比例坐标"
    static _PickPoll() {
        if this.GuiObj = "" || !WinExist("ahk_id " this.GuiObj.Hwnd) {
            this._StopPicking()
            return
        }
        if !WinActive(GameTarget.WinTitle()) {
            ToolTip
            return
        }
        MouseGetPos(&mx, &my)   ; 启动默认 CoordMode Mouse=Client；活动窗口=游戏 → 客户端物理像素
        if !SafeWinGetClientPos(&ww, &wh) {
            ToolTip
            return
        }
        fx := Round(mx / ww, 4)
        fy := Round(my / wh, 4)
        ToolTip("(" fx ", " fy ")  " I18n.T("左键点击拾取坐标"), mx + 20, my + 20)
        ; ToolTip X/Y 默认相对活动窗口客户区（=游戏），直接落在光标旁
    }

    ; 游戏前台且光标在客户区内时按下左键：把比例坐标插入指令 Edit 光标处，激活编辑窗口（拾取自终止）
    static _OnPickLButton(*) {
        ; 双重守卫：即使热键被异常触发，条件不满足时立即返回（不执行任何拾取逻辑）
        if !this.IsPicking()
            return
        ToolTip
        MouseGetPos(&mx, &my)
        if !SafeWinGetClientPos(&ww, &wh)
            return
        fx := Round(mx / ww, 4)
        fy := Round(my / wh, 4)
        EditPaste("(" fx ", " fy ")", this.ScriptEdit)   ; 光标处插入 (x, y)（D3：纯坐标文本，用户自行补全 tap）
        WinActivate("ahk_id " this.GuiObj.Hwnd)
        this.ScriptEdit.Focus()
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
