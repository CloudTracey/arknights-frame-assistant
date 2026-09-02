; == 状态栏悬停说明 ==
; 主窗口底部模拟状态栏（左下角主题色指示块 + 紧随其后的黑色说明文本，与界面自绘风格一致）：
; - 鼠标悬停在已登记的控件上时，实时显示该控件的功能简要说明；
; - 未悬停（或悬停在无说明的空白/GroupBox 上，或鼠标移出窗口）时，
;   每 RotateIntervalMs（默认 10 秒）随机轮播一条引导文案（_TipItems）。
; - 首次打开设置窗口时按当前系统时间显示时段问候语（ShowGreetingOnce，进程内仅一次）。
; 说明以「中文原文」为键存储（source-as-key），仅显示时才经 I18n.T 翻译，
; 因此 Register 时不固化语言、切换界面语言后当前文本也会刷新。
; 说明键可带 {1} 占位符：Register 可传 argsProvider 回调，显示时实时求值（如过帧档位的配置值）。
; 控件对象引用在 AHK 中与窗口同生命周期（不可运行时销毁重建，
; 自定义按键 12 行为显隐复用），以控件 HWND 为表键安全且稳定。
; 行为约定：仅悬停到「有说明的控件」才刷新状态栏；悬停在无说明控件/空白/窗口外时
; 不刷新、不重置轮播计时器，轮播按自身节奏继续。

class StatusBarHints {
    static MainGui := ""
    static SepLine := ""        ; 主题色指示块（状态栏左侧，28×13）
    static TextCtrl := ""       ; 说明文本控件
    static Started := false
    static RotateIntervalMs := 10000
    ; 控件 HWND → {Key: 说明键（中文原文）, Args: 参数提供回调（可空）}
    static _Hints := Map()
    ; 当前悬停控件 HWND（去重缓存；0 = 未处理或不在主窗口）
    static _HoverHwnd := 0
    ; 当前悬停控件的说明键（"" = 未悬停在有说明的控件上；决定轮播是否暂停）
    static _HoverKey := ""
    ; 状态栏当前显示的键（中文原文）与文本（SetText 去重）
    static _CurrentKey := ""
    static _CurrentArgs := []
    static _CurrentText := ""
    ; 轮播文案（中文原文，显示时经 I18n.T）
    static _TipItems := [
        "悬停到任意控件即可查看功能说明",
        "修改设置后记得保存或应用哦",
        "遇到问题可在「日志」页导出日志压缩包，然后到GitHub Issues或者加入QQ群反馈",
        "使用满意的话欢迎上GitHub给AFA点个Star，非常感谢~"
    ]
    static _LastTip := ""
    ; 定时器回调必须是单一函数对象（SetTimer 启停按对象身份匹配）
    static _RotateCallback := ObjBindMethod(this, "_OnRotate")
    ; OnMessage 全局回调只注册一次（窗口重建后在 Init 中重复注册会叠加调用）
    static _MsgRegistered := false
    ; 首次打开窗口时段的问候语是否已显示（进程内仅一次；语言切换重建不重置）
    static _GreetingShown := false

    ; 创建状态栏并启动轮播；由 GuiManager._CreateControls 末尾调用。
    ; 注意：调用时序为 _CreateControls 内「先 Register 后 Init」，因此 Init 绝不清空 _Hints；
    ; 窗口重建（语言切换等场景的 GuiManager.Rebuild）由 Reset() 负责清理，Init 只处理重建后的初建。
    static Init(mainGui) {
        if (this.Started && this.MainGui = mainGui)
            return
        SetTimer(this._RotateCallback, 0)
        this.Started := true
        this.MainGui := mainGui
        this._HoverHwnd := 0
        this._HoverKey := ""
        this._CurrentKey := ""
        this._CurrentArgs := []
        this._CurrentText := ""
        this._LastTip := ""
        ; 主题色指示块（左下角）+ 说明文本（紧随其右，黑色）
        this.SepLine := mainGui.Add("Text", "x0 y+-6 w28 h13 Background1994d2")
        this.TextCtrl := mainGui.Add("Text", "x+4 yp-2 w660 cDefault", "")
        if !this._MsgRegistered {
            this._MsgRegistered := true
            OnMessage(0x0200, ObjBindMethod(this, "OnMouseMove"))
        }
        ; 立即显示第一条引导文案，不等首个轮播周期
        this._Rotate()
        SetTimer(this._RotateCallback, this.RotateIntervalMs)
    }

    ; 主窗口重建前调用（GuiManager.Rebuild 销毁旧窗口后）：清理全部运行时状态。
    ; OnMessage 全局回调保留注册（_MsgRegistered 不清），随新窗口的 Init 复用。
    static Reset() {
        SetTimer(this._RotateCallback, 0)
        this.Started := false
        this.MainGui := ""
        this.SepLine := ""
        this.TextCtrl := ""
        this._Hints := Map()
        this._HoverHwnd := 0
        this._HoverKey := ""
        this._CurrentKey := ""
        this._CurrentArgs := []
        this._CurrentText := ""
        this._LastTip := ""
    }

    ; 登记控件说明：ctrl 为 GuiControl 对象，descKey 为中文原文（可含 {1} 占位符）；
    ; argsProvider 为可选的参数提供回调（返回数组，悬停显示时实时求值），用于动态文案（如过帧档位数值）
    static Register(ctrl, descKey, argsProvider := "") {
        if (IsObject(ctrl))
            this._Hints[ctrl.Hwnd] := {Key: descKey, Args: argsProvider}
    }

    ; 进程级 WM_MOUSEMOVE（0x0200）：定位鼠标下的控件并更新状态栏。
    ; 与 TabManager 的 0x0200 回调共存（OnMessage 多回调按注册顺序执行），互不干扰。
    ; 仅悬停到「有说明的控件」才刷新；无说明控件/空白/窗口外一律忽略（不刷新、不重置计时器）。
    ; 窗口重建期间（Rebuild 销毁/重建窗口）可能收到消息，此时主窗口无效：防御性跳过。
    static OnMouseMove(wParam, lParam, msg, hwnd) {
        if !IsObject(this.MainGui)
            return
        try {
            MouseGetPos(, , &winHwnd, &ctrlHwnd, 2)
            ; 同一控件内的移动不重复处理（含空白/窗口区域，避免高频查找）
            if (ctrlHwnd = this._HoverHwnd)
                return
            this._HoverHwnd := ctrlHwnd
            if (winHwnd != this.MainGui.Hwnd || !this._Hints.Has(ctrlHwnd)) {
                ; 无说明/窗口外：保持现状，轮播按自身节奏继续
                this._HoverKey := ""
                return
            }
            entry := this._Hints[ctrlHwnd]
            this._HoverKey := entry.Key
            args := IsObject(entry.Args) ? entry.Args() : []
            this._SetText(entry.Key, args*)
        } catch Error as e {
            ; 窗口销毁/重建的竞态窗口内静默跳过（状态栏文本随后由重建 Init 重置）
            Logger.Debug("StatusBarHints", "OnMouseMove 跳过: " e.Message)
        }
    }

    ; 首次打开设置窗口时显示时段问候（GuiManager.Show 调用）。
    ; 问候语完整展示一个轮播周期后再进入随机轮播（重置计时器）。
    static ShowGreetingOnce() {
        if (this._GreetingShown || !IsObject(this.TextCtrl))
            return
        this._GreetingShown := true
        this._SetText(this._GreetingFor(A_Hour))
        SetTimer(this._RotateCallback, this.RotateIntervalMs)
    }

    ; 按当前小时返回问候语键（键=中文原文，显示时经 I18n.T；文案定稿见 docs/status_bar_texts_review.md）。
    ; 分段：6:00-11:00 早 / 11:00-13:00 中午 / 13:00-18:00 下午 / 18:00-23:00 晚上 /
    ; 23:00-4:00 夜猫子 / 4:00-6:00 刚醒或没睡。
    static _GreetingFor(hour) {
        if (hour >= 6 && hour < 11)
            return "早上好！博士！新的一天也要活力满满哦！"
        if (hour >= 11 && hour < 13)
            return "中午好！博士！"
        if (hour >= 13 && hour < 18)
            return "下午好！博士！需要慵懒的时候就要保持慵懒……"
        if (hour >= 18 && hour < 23)
            return "晚上好！博士！要记得好好放松哦"
        if (hour >= 23 || hour < 4)
            return "夜猫子出没中——"
        return "博士……你是刚醒还是没睡？要注意身体哦"
    }

    ; 界面语言切换后刷新当前文本（GuiManager._OnLocaleChanged 调用）
    static OnLocaleChanged() {
        if (this._CurrentKey = "" || !IsObject(this.TextCtrl))
            return
        this._SetText(this._CurrentKey, this._CurrentArgs*)
    }

    ; 内部：显示指定键的说明（翻译在当前语言下进行；文本未变化时跳过重绘）
    static _SetText(key, args*) {
        text := I18n.T(key, args*)
        if (text = this._CurrentText)
            return
        this._CurrentText := text
        this._CurrentKey := key
        this._CurrentArgs := []
        this._CurrentArgs.Push(args*)
        try this.TextCtrl.Text := text
    }

    ; 定时器回调：仅在悬停到「有说明的控件」时暂停切换；其余时间按 RotateIntervalMs 节奏轮播
    static _OnRotate() {
        if (this._HoverKey != "")
            return
        this._Rotate()
    }

    ; 内部：从 _TipItems 随机取一条（确定性排除上一条，列表单条时直接使用）
    static _Rotate() {
        if (this._TipItems.Length = 0)
            return
        candidates := []
        for item in this._TipItems {
            if (item != this._LastTip)
                candidates.Push(item)
        }
        if (candidates.Length = 0)
            return
        this._LastTip := candidates[Random(1, candidates.Length)]
        this._SetText(this._LastTip)
    }
}
