; == 自定义按键功能引擎 ==
; 每条自定义按键 = 一个「按键功能」+ 一个参数文本。目前仅 "click"（单击）：
;   arg 为 "(x, y)" 格式的 0-1 比例坐标（最多 4 位小数），执行时按当前游戏窗口尺寸换算像素后
;   以 HotkeyActions._ClickButton 同款方式（MouseMove + Send LButton Down/Up + 光标还原）单击。
; 设计见 docs/plan/custom_hotkeys_design.md：
;   - 功能注册表（Builtins）供未来扩展：新增功能 = 注册表加一行 + 语法节加一条；
;   - 校验只在保存/Reload 慢路径发生，触发时零解析、零 IO（O(1) 缓存查表）；
;   - 执行整体 Thread "NoTimers"，每次点击后立即还原光标 + finally 无条件归位（操作完成后鼠标回归原位）。

class CustomScriptEngine {
    ; 运行时编译缓存：Map(id -> {valid, steps, type, message})
    static _Runtime := Map()

    ; 内置功能注册表（功能码小写键；ctx 为每次 Execute 创建的上下文对象，避免静态共享状态被线程中断污染）
    static _Builtins := ""

    static _InitBuiltins() {
        if IsObject(this._Builtins)
            return
        this._Builtins := Map(
            "click", ObjBindMethod(this, "_BuiltinClick")
        )
    }

    ; 校验+编译「功能 + 参数」。纯函数：无 IO、无副作用。
    ; func: 功能码（当前仅 "click"）；arg: 参数文本（click 为 "(x, y)" 比例坐标；空 = 空操作）。
    ; 返回 {success: bool, steps: Array<{F, A: Array}>, message: String}
    ; message 已本地化、可直接弹窗。
    static Validate(func, arg) {
        if func != "click"
            return {success: false, steps: [], message: I18n.T("无法识别的功能：{1}", func)}
        arg := Trim(arg)
        if arg = ""
            return {success: true, steps: [], message: ""}
        ; 全角符号先行提示：全角空格（U+3000）与全角 ASCII 区段（，（）等，U+FF01-FF5E）
        ; 部分用户分不清全角/半角，给专用提示而非笼统的格式错误。
        if RegExMatch(arg, "[\x{3000}\x{FF01}-\x{FF5E}]")
            return {success: false, steps: [], message: I18n.T("包含全角字符，请使用半角符号：{1}", arg)}
        if !RegExMatch(arg, "i)^\(\s*(\d+(?:\.\d+)?)\s*,\s*(\d+(?:\.\d+)?)\s*\)$", &m)
            return {success: false, steps: [], message: I18n.T("click 需要两个 0-1 之间的小数参数：click(x, y)")}
        x := this._ParseRatio(m[1])
        y := this._ParseRatio(m[2])
        ; 注意：不能用 x = "" 判错——AHK 数值比较会把空字符串当 0，(0, 0) 会被误判
        if !IsNumber(x) || !IsNumber(y)
            return {success: false, steps: [], message: I18n.T("click 坐标需为 0-1 之间、最多 4 位小数")}
        return {success: true, steps: [{F: "click", A: [x, y]}], message: ""}
    }

    ; 内部：解析 0-1 比例小数（最多 4 位）。非法返回 ""。
    static _ParseRatio(text) {
        value := Float(text)
        if value < 0 || value > 1
            return ""
        if RegExMatch(text, "\.(\d+)", &dm) && StrLen(dm[1]) > 4
            return ""
        return value
    }

    ; 从存储文件直读全部条目并刷新编译缓存（慢路径，由 HotkeyService 重建热键前调用）
    static Reload() {
        this._InitBuiltins()
        this._Runtime := Map()
        for entry in Config.ReadCustomHotkeys() {
            id := "CustomHotkey" entry.Index
            record := {valid: true, steps: [], type: entry.Type, message: ""}
            result := this.Validate(entry.Func, entry.Arg)
            if (!result.success) {
                record.valid := false
                record.message := result.message
                Logger.Warn("CustomScript", "功能校验失败：id=" id ", " result.message)
            } else {
                record.steps := result.steps
            }
            this._Runtime[id] := record
        }
        Logger.Info("CustomScript", "已加载自定义功能缓存，数量=" this._Runtime.Count)
    }

    ; 该 id 缓存存在且参数合法（供 HotkeyService 注册时判断）
    static IsRegistered(id) {
        if !this._Runtime.Has(id)
            return false
        return this._Runtime[id].valid
    }

    ; 热键触发入口（HotkeyService 以 Bind 绑定 id 作为 profile.Fn；由 _WrapAction 激活游戏后调用）
    ; O(1) 内存查表；combat 类型先走关卡守卫（GuardInLevel 同时记录 DownHandled 并透传原键）。
    static RunById(id, ThisHotkey) {
        if !this._Runtime.Has(id) {
            Logger.Warn("CustomScript", "未缓存的按键触发：" id)
            return
        }
        entry := this._Runtime[id]
        if !entry.valid || entry.steps.Length = 0
            return
        ; 触发/执行日志：Debug 级（仅调试模式持久化，避免热路径常态写文件）；
        ; 关卡外拦截与透传由 GuardInLevel 以 Info 输出（actionName=CustomScript:{id}）。
        Logger.Debug("CustomScript", "触发自定义功能：" id "，步骤数=" entry.steps.Length)
        if entry.type = "combat" && !GuardInLevel("CustomScript:" id, ThisHotkey)
            return
        this.Execute(entry.steps)
        ; 与标准动作一致：等待物理键松开，按住不重复触发（执行期间同键重入已被 MaxThreadsPerHotkey=1 屏蔽；
        ; 守卫拦截路径提前 return，与常规作战动作同语义——透传后无需等待）
        if !InStr(ThisHotkey, "Wheel")
            PureKeyWait(ThisHotkey)
    }

    ; 执行预编译步骤。Thread "NoTimers" 挡定时器轮询抖动、放行其他热键；
    ; finally 无条件还原光标（操作完成后鼠标回归原位，覆盖 break/异常路径）。
    static Execute(steps) {
        if steps.Length = 0
            return
        Thread "NoTimers"
        if !SafeWinGetClientPos(&ww, &wh) {
            Thread "NoTimers", false
            return
        }
        MouseGetPos(&origX, &origY)   ; Client 模式；游戏窗口已被 _WrapAction 激活
        ctx := {ww: ww, wh: wh, origX: origX, origY: origY}
        try {
            for step in steps {
                if !GameTarget.Exists()
                    break
                this._Builtins[step.F].Call(ctx, step.A*)
            }
        } finally {
            MouseMove ctx.origX, ctx.origY
            Thread "NoTimers", false
        }
    }

    ; ── 内置功能（注册表条目；签名统一为 (ctx, args*)） ──

    ; click：比例 → 客户端像素 → Send 左键点击（对齐 HotkeyActions._ClickButton），点击后立即还原光标
    static _BuiltinClick(ctx, fx, fy) {
        x := Round(fx * ctx.ww)
        y := Round(fy * ctx.wh)
        BlockInput "MouseMove"
        MouseMove x, y
        Send "{LButton Down}"
        USleep(TimingService.GetClickDelay())
        Send "{LButton Up}"
        MouseMove ctx.origX, ctx.origY
        BlockInput "MouseMoveOff"
    }
}
