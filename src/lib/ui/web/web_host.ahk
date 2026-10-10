; web 引擎宿主（WebView2）：创建承载窗口与控制器、映射静态资源目录、承载前端页面。
; 本类只订阅事件、不发布事件；界面失败一律回落经典界面。

class WebHost {
    static VIRTUAL_HOST := "afa.app"
    static CREATE_TIMEOUT_MS := 15000
    static READY_TIMEOUT_MS := 8000

    static Gui := ""
    static Controller := ""
    static CoreWV := ""
    static Ready := false      ; 控制器已创建并已导航，不代表页面已加载
    static PageReady := false  ; 前端已上报 ready

    static _Activated := false
    static _FellBack := false
    static _Notified := false
    static _ReadyFn := ""
    static _Starting := false  ; _StartCore 进行中；await2 期间可被新线程重入
    static _AltF4Cond := ""

    ; 入口。安检！安检！通过则由 web 引擎接管并返回 true；否则返回 false，false就会让调用的那个地方自己处理回落经典界面。
    static Activate() {
        if (this._Activated)
            return !this._FellBack
        this._Activated := true
        reason := ""
        if (!this._CheckViable(&reason)) {
            this._FellBack := true
            Logger.Warn("WebHost", "web 引擎不可用：" reason)
            this._Notify()
            return false
        }
        EventBus.Subscribe("LocaleChanged", (*) => this._OnLocaleChanged())
        Logger.Info("WebHost", "web 引擎已就绪，Runtime=" WebViewRuntime.GetVersion())
        if (Config.ReadImportantFromIni("AutoOpenSettings") = "1")
            this.Show()
        return true
    }

    static Show() {
        if (this._FellBack) {
            GuiManager.Show()
            return
        }
        if (this.Ready && this.Gui != "") {
            this.Gui.Show()
            this._FillController()
            return
        }
        this._Start()
    }

    static RequestHide() {
        if (this.Gui != "")
            this.Gui.Hide()
    }

    ; 创建中守卫：await2 期间（最长 15 s）若有新线程再次请求显示，不得二次进入创建流程覆盖 Gui/Controller。
    static _Start() {
        if (this._Starting)
            return
        this._Starting := true
        try {
            this._StartCore()
        } finally {
            this._Starting := false
        }
    }

    static _StartCore() {
        try {
            this.Gui := Gui("+Resize", this._WindowTitle())
            this.Gui.OnEvent("Close", (*) => this._OnClose())
            this.Gui.OnEvent("Size", (*) => this._FillController())
            ; 控制器必须在窗口可见时创建：隐藏窗口的客户区为 0，库的自动 Fill 会写入 0 尺寸视口，
            ; 渲染合成器不启动，之后显示也无法恢复（表现为页面全空白）。
            this.Gui.Show("w760 h620")
        } catch Error as e {
            this._Fallback("创建承载窗口失败：" e.Message)
            return
        }
        try {
            Theme.Attach(this.Gui)
        } catch Error as e {
            Logger.Warn("WebHost", "窗口主题登记失败（继续）：" e.Message)
        }
        try {
            this._BindAltF4()
        } catch Error as e {
            Logger.Warn("WebHost", "Alt+F4 注册失败（继续）：" e.Message)
        }
        try {
            this.Controller := WebView2.CreateControllerAsync(this.Gui.Hwnd, , this._UserDataDir(), , this._LoaderPath()).await2(this.CREATE_TIMEOUT_MS)
            this.CoreWV := this.Controller.CoreWebView2
        } catch Error as e {
            this._Fallback("WebView2 控制器创建失败：" e.Message)
            return
        }
        try {
            settings := this.CoreWV.Settings
            settings.IsWebMessageEnabled := true
            settings.AreDefaultContextMenusEnabled := false
            settings.IsStatusBarEnabled := false
            settings.IsSwipeNavigationEnabled := false
        } catch Error as e {
            Logger.Warn("WebHost", "WebView2 设置部分失败（继续加载）：" e.Message)
        }
        try {
            ; accessKind 1 = ALLOW；传 0（DENY）会拒绝虚拟源下的全部资源，页面全空白。
            this.CoreWV.SetVirtualHostNameToFolderMapping(this.VIRTUAL_HOST, this._AssetsDir(), 1)
        } catch Error as e {
            this._Fallback("虚拟源映射失败：" e.Message)
            return
        }
        try {
            this.CoreWV.add_WebMessageReceived(ObjBindMethod(this, "_OnWebMessageReceived"))
        } catch Error as e {
            Logger.Warn("WebHost", "绑定前端消息失败（界面将无法与内核通信）：" e.Message)
        }
        try {
            this.CoreWV.Navigate("https://" this.VIRTUAL_HOST "/index.html")
        } catch Error as e {
            this._Fallback("页面导航失败：" e.Message)
            return
        }
        this.Ready := true
        this.PageReady := false
        this._ArmReadyTimeout()
        if (Config.ReadImportantFromIni("DebugEnabled") = "1") {
            try this.CoreWV.OpenDevToolsWindow()
        }
        Logger.Info("WebHost", "web 引擎已启动")
    }

    static _CheckViable(&reason) {
        if (!WebViewRuntime.IsAvailable()) {
            reason := "未安装 WebView2 Runtime"
            return false
        }
        if (!this._EnsureAssets()) {
            reason := "界面资源缺失：" this._AssetsDir()
            return false
        }
        ; 加载器存在性检查：主要防护源码运行时的 DLL 劫持（编译版由 _EnsureAssets() 先行拦下）。
        if (!FileExist(this._LoaderPath())) {
            reason := "缺少 WebView2 加载器：" this._LoaderPath()
            return false
        }
        return true
    }

    static _EnsureAssets() {
        return StrLen(FileExist(this._AssetsDir() "\index.html")) > 0
    }

    static _AssetsDir() {
        return FileExtractor.WebDir
    }

    ; 库的默认用户数据目录是本机共享的 Edge 用户数据根，多应用会互相干扰，故指定应用私有目录。
    static _UserDataDir() {
        return A_AppData "\ArknightsFrameAssistant\PC\webview2"
    }

    ; 加载器必须给绝对路径：库的默认值是相对名 'WebView2Loader.dll'，会命中进程工作目录里的同名文件（DLL 劫持）。
    static _LoaderPath() {
        return FileExtractor.LoaderPath
    }

    ; Alt+F4 始终退出（与经典界面一致）：经典模式由 GuiManager.Start() 注册，web 模式走这里。
    static _BindAltF4() {
        if (!IsObject(this._AltF4Cond))
            this._AltF4Cond := (*) => WebHost.Gui != "" && WinActive("ahk_id " WebHost.Gui.Hwnd)
        HotIf(this._AltF4Cond)
        Hotkey("!F4", (*) => ExitApp(), "On")
        HotIf
    }

    static _UnbindAltF4() {
        if (!IsObject(this._AltF4Cond))
            return
        HotIf(this._AltF4Cond)
        try Hotkey("!F4", "Off")
        HotIf
    }

    static _WindowTitle() {
        return I18n.T("明日方舟帧操小助手 ArknightsFrameAssistant - {1}", Version.Get())
    }

    static _OnClose() {
        if (Config.ReadImportantFromIni("ExitOnWindowClose") = "1") {
            ExitApp()
            return
        }
        this.RequestHide()
    }

    static _OnLocaleChanged() {
        if (this.Gui != "")
            this.Gui.Title := this._WindowTitle()
    }

    ; 让控制器填满当前客户区：创建时窗口可能尚未布局完成，库的自动 Fill 会拿到 0 尺寸，
    ; 故每次显示与尺寸变化后都要重新 Fill，否则内容区为 0 宽、页面空白。
    static _FillController() {
        if (this.Controller = "")
            return
        try this.Controller.Fill()
    }

    static _OnWebMessageReceived(sender, args) {
        try {
            text := this._ExtractMessageText(args)
            if (text = "ready")
                this._OnPageReady()
            else if (StrLen(text) > 0)
                Logger.Debug("WebHost", "收到前端消息：" text)
        } catch Error as e {
            Logger.Error("WebHost", "处理前端消息失败：" e.Message)
        }
    }

    static _OnPageReady() {
        if (this.PageReady)
            return
        this.PageReady := true
        this._DisarmReadyTimeout()
        Logger.Info("WebHost", "界面已上报 ready")
    }

    ; 前端 postMessage(字符串) 时 WebMessageAsJson 是带引号的 JSON 字符串字面量，需还原。
    static _ExtractMessageText(args) {
        try {
            json := args.WebMessageAsJson
            if (StrLen(json) > 0)
                return this._UnwrapJsonString(json)
        }
        try
            return args.TryGetWebMessageAsString()
        return ""
    }

    static _UnwrapJsonString(json) {
        if (SubStr(json, 1, 1) = '"' && SubStr(json, -1) = '"')
            return SubStr(json, 2, StrLen(json) - 2)
        return json
    }

    static _ArmReadyTimeout() {
        this._DisarmReadyTimeout()
        this._ReadyFn := ObjBindMethod(this, "_OnReadyTimeout")
        SetTimer(this._ReadyFn, -this.READY_TIMEOUT_MS)
    }

    ; SetTimer 的启动与取消必须用同一函数对象，故函数对象缓存在静态属性上。
    static _DisarmReadyTimeout() {
        if (!IsObject(this._ReadyFn))
            return
        SetTimer(this._ReadyFn, 0)
        this._ReadyFn := ""
    }

    static _OnReadyTimeout() {
        this._ReadyFn := ""
        if (this.PageReady || this._FellBack)
            return
        reason := "界面未在 " this.READY_TIMEOUT_MS " ms 内上报 ready"
        Logger.Warn("WebHost", reason)
        ; 调试模式默认保留窗口供查 DevTools
        if (Config.ReadImportantFromIni("DebugEnabled") = "1") {
            if (MessageBox.Confirm(I18n.T("界面未能加载。是否回退到经典界面？选择「否」可保留当前窗口以便排查。"), I18n.T("界面类型")) != "Yes") {
                this._Notify(I18n.T("界面未能加载，已保留窗口供排查，详见日志"))
                return
            }
        }
        this._Fallback(reason)
    }

    ; 运行期失败：提示一次、销毁窗口并回落经典界面。预检失败不走这里（由 UiShell 接住）。
    static _Fallback(reason) {
        this._FellBack := true
        Logger.Warn("WebHost", "web 引擎回落经典界面：" reason)
        this._Notify()
        this._DestroyGui()
        GuiManager.Start()
    }

    static _DestroyGui() {
        this._UnbindAltF4()
        this._DisarmReadyTimeout()
        try {
            if (this.Controller != "")
                this.Controller.Close()
        }
        if (this.Gui != "") {
            try Theme.Destroy(this.Gui)
        }
        this.Gui := ""
        this.Controller := ""
        this.CoreWV := ""
        this.Ready := false
    }

    ; 托盘通知
    ; 提示一次
    static _Notify(message := "") {
        if (this._Notified)
            return
        this._Notified := true
        text := StrLen(message) > 0 ? message : I18n.T("WebView2 界面不可用，已回退到 Windows 原生 GUI，详见日志")
        try TrayTip(text, I18n.T("界面类型"))
    }
}
