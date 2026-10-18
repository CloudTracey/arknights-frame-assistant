; web 通信桥：WebView2 消息握手、请求/回复、方法白名单与 JSON 编解码。
; 只负责传输；业务方法通过 _Methods 白名单暴露。

class WebBridge {
    static VERSION := 1
    static ORIGIN := "https://afa.app"
    static CoreWV := ""
    static Ready := false

    static _OnReady := ""
    static _OnNavigating := ""
    static _MessageHandler := ""
    static _NavHandler := ""
    static _MessageToken := 0
    static _NavToken := 0
    static _Methods := Map()
    static _EventHandlers := Map()

    ; 绑定消息与导航事件
    static Attach(coreWV, onReady, onNavigating) {
        if (!IsObject(coreWV))
            return false
        this.Detach()
        this.CoreWV := coreWV
        this._OnReady := onReady
        this._OnNavigating := onNavigating
        this._Methods := Map(
            "app.getState", ObjBindMethod(this, "_GetAppState"),
            "settings.get", ObjBindMethod(this, "_GetSettings"),
            "settings.setDraft", ObjBindMethod(this, "_SetSettingsDraft"),
            "settings.save", ObjBindMethod(this, "_SaveSettings"),
            "settings.apply", ObjBindMethod(this, "_ApplySettings"),
            "settings.cancel", ObjBindMethod(this, "_CancelSettings"),
            "i18n.get", ObjBindMethod(this, "_GetI18n")
        )
        try {
            this._MessageHandler := ObjBindMethod(this, "_OnMessage")
            this._NavHandler := ObjBindMethod(this, "_OnNavigationStarting")
            this._MessageToken := coreWV.add_WebMessageReceived(this._MessageHandler)
            this._NavToken := coreWV.add_NavigationStarting(this._NavHandler)
            this._SubscribeEvents()
        } catch Error as e {
            Logger.Error("WebBridge", "绑定前端消息失败：" e.Message)
            this.Detach()
            return false
        }
        return true
    }

    ; 幂等
    static Detach() {
        coreWV := this.CoreWV
        this._UnsubscribeEvents()
        this.CoreWV := ""
        this.Ready := false
        this._OnReady := ""
        this._OnNavigating := ""
        this._Methods := Map()
        if (coreWV != "") {
            if (this._MessageToken)
                try coreWV.remove_WebMessageReceived(this._MessageToken)
            if (this._NavToken)
                try coreWV.remove_NavigationStarting(this._NavToken)
        }
        this._MessageHandler := ""
        this._NavHandler := ""
        this._MessageToken := 0
        this._NavToken := 0
    }

    ; 页面刷新/跳转后重新等 ready
    static _OnNavigationStarting(sender, args) {
        if (!this._IsLocalSource(args.Uri)) {
            args.Cancel := true
            Logger.Warn("WebBridge", "已拦截非本地导航：" args.Uri)
            return
        }
        this.Ready := false
        if IsObject(this._OnNavigating)
            this._OnNavigating.Call()
    }

    static _SubscribeEvents() {
        if (this._EventHandlers.Count > 0)
            return
        handler := ObjBindMethod(this, "_OnSettingsChanged")
        this._EventHandlers["SettingsChanged"] := handler
        EventBus.Subscribe("SettingsChanged", handler)

        handler := ObjBindMethod(this, "_OnBridgeEvent", "SettingsSaveStarting")
        this._EventHandlers["SettingsSaveStarting"] := handler
        EventBus.Subscribe("SettingsSaveStarting", handler)

        handler := ObjBindMethod(this, "_OnBridgeEvent", "SettingsSaveFailed")
        this._EventHandlers["SettingsSaveFailed"] := handler
        EventBus.Subscribe("SettingsSaveFailed", handler)

        handler := ObjBindMethod(this, "_OnBridgeEvent", "SettingsSaved")
        this._EventHandlers["SettingsSaved"] := handler
        EventBus.Subscribe("SettingsSaved", handler)

        handler := ObjBindMethod(this, "_OnBridgeEvent", "SettingsApplied")
        this._EventHandlers["SettingsApplied"] := handler
        EventBus.Subscribe("SettingsApplied", handler)

        handler := ObjBindMethod(this, "_OnBridgeEvent", "SettingsCancelled")
        this._EventHandlers["SettingsCancelled"] := handler
        EventBus.Subscribe("SettingsCancelled", handler)

        handler := ObjBindMethod(this, "_OnBridgeEvent", "SettingsViewRefreshRequested")
        this._EventHandlers["SettingsViewRefreshRequested"] := handler
        EventBus.Subscribe("SettingsViewRefreshRequested", handler)

        handler := ObjBindMethod(this, "_OnBridgeEvent", "LocaleChanged")
        this._EventHandlers["LocaleChanged"] := handler
        EventBus.Subscribe("LocaleChanged", handler)
    }

    static _UnsubscribeEvents() {
        for name, handler in this._EventHandlers
            EventBus.Unsubscribe(name, handler)
        this._EventHandlers := Map()
    }

    static _OnBridgeEvent(eventName, data) {
        if (!this.Ready)
            return
        if (!IsObject(data))
            data := Map()
        this._Post(Map(
            "v", this.VERSION,
            "type", "event",
            "name", eventName,
            "data", data
        ))
    }

    static _OnSettingsChanged(data) {
        if (!this.Ready)
            return
        key := data.key
        if (key = "Frame")
            key := "Frame155"
        if (!WebSettings.IsExposedKey(key))
            return
        this._Post(Map(
            "v", this.VERSION,
            "type", "event",
            "name", "SettingsChanged",
            "data", Map("key", key, "value", WebSettings.Read(key))
        ))
    }

    static _OnMessage(sender, args) {
        source := ""
        try source := args.Source
        if (!this._IsLocalSource(source)) {
            Logger.Warn("WebBridge", "忽略非本地来源的前端消息：" source)
            return
        }
        try {
            text := args.WebMessageAsJson
            if (StrLen(text) = 0)
                return
            if (SubStr(text, 1, 1) = Chr(34)) {
                if (args.TryGetWebMessageAsString() = "ready")
                    this._OnReadyMessage(Map("v", this.VERSION, "type", "ready"))
                return
            }
            msg := JSON.parse(text)
            if (Type(msg) != "Map")
                return
            msgType := msg.Has("type") && Type(msg["type"]) = "String" ? msg["type"] : ""
            switch msgType {
                case "ready":
                    this._OnReadyMessage(msg)
                case "call":
                    this._OnCall(msg)
                default:
                    Logger.Warn("WebBridge", "未知前端消息类型：" msgType)
            }
        } catch Error as e {
            Logger.Error("WebBridge", "处理前端消息失败：" e.Message)
        }
    }

    static _OnReadyMessage(msg) {
        if (this.Ready)
            return
        if (!msg.Has("v") || msg["v"] != this.VERSION) {
            Logger.Warn("WebBridge", "ready 协议版本不匹配")
            return
        }
        payload := Map(
            "v", this.VERSION,
            "type", "welcome",
            "app", this._GetAppState(Map()),
            "methods", this._MethodNames()
        )
        this.Ready := true
        if (!this._Post(payload)) {
            this.Ready := false
            return
        }
        if IsObject(this._OnReady)
            this._OnReady.Call()
    }

    static _OnCall(msg) {
        if (!this.Ready) {
            Logger.Warn("WebBridge", "ready 之前收到请求，已忽略")
            return
        }
        id := msg.Has("id") ? msg["id"] : 0
        if (!IsInteger(id) || id <= 0) {
            Logger.Warn("WebBridge", "请求缺少有效 id")
            return
        }
        if (!msg.Has("v") || msg["v"] != this.VERSION) {
            this._ReplyError(id, "unsupported_version", "协议版本不匹配")
            return
        }
        method := msg.Has("method") && Type(msg["method"]) = "String" ? msg["method"] : ""
        if (!this._Methods.Has(method)) {
            this._ReplyError(id, "unknown_method", "未知方法：" method)
            return
        }
        if (msg.Has("params") && Type(msg["params"]) != "Map") {
            this._ReplyError(id, "bad_request", "params 必须是对象")
            return
        }
        params := msg.Has("params") ? msg["params"] : Map()
        try {
            result := this._Methods[method].Call(params)
            this._Reply(id, result)
        } catch Error as e {
            Logger.Error("WebBridge", "方法执行失败：" method "，" e.Message)
            this._ReplyError(id, "internal", e.Message)
        }
    }

    static _GetAppState(params) {
        return Map(
            "version", Version.Get(),
            "locale", I18n.GetCurrent(),
            "theme", Config.GetImportant("ThemeMode"),
            "engine", UiShell.Engine,
            "hotkeysEnabled", HotkeyService.HotkeyState ? JSON.true : JSON.false
        )
    }

    static _GetSettings(params) {
        return WebSettings.Get(params)
    }

    static _SetSettingsDraft(params) {
        return WebSettings.SetDraft(params)
    }

    static _SaveSettings(params) {
        return WebSettings.RequestSave()
    }

    static _ApplySettings(params) {
        return WebSettings.RequestApply()
    }

    static _CancelSettings(params) {
        return WebSettings.RequestCancel()
    }

    static _GetI18n(params) {
        locale := I18n.GetCurrent()
        values := Map()
        if (!params.Has("keys"))
            return Map("success", JSON.true, "locale", locale, "values", values)
        keys := params["keys"]
        if (Type(keys) != "Array")
            return Map("success", JSON.false, "code", "bad_request", "message", "keys 必须是数组")
        if (keys.Length > 512)
            return Map("success", JSON.false, "code", "too_many_keys", "message", "keys 数量超过 512")
        for key in keys {
            if (Type(key) != "String")
                return Map("success", JSON.false, "code", "bad_request", "message", "keys 必须是字符串数组")
            values[key] := I18n.T(key)
        }
        return Map("success", JSON.true, "locale", locale, "values", values)
    }

    static _MethodNames() {
        names := []
        for name in this._Methods
            names.Push(name)
        return names
    }

    static _Reply(id, result) {
        this._Post(Map(
            "v", this.VERSION,
            "type", "reply",
            "id", id,
            "ok", JSON.true,
            "result", result
        ))
    }

    static _ReplyError(id, code, message) {
        this._Post(Map(
            "v", this.VERSION,
            "type", "reply",
            "id", id,
            "ok", JSON.false,
            "error", Map("code", code, "message", message)
        ))
    }

    static _Post(message) {
        if (!this.Ready || this.CoreWV = "")
            return false
        try {
            this.CoreWV.PostWebMessageAsJson(JSON.stringify(message, 0, ""))
            return true
        } catch Error as e {
            Logger.Warn("WebBridge", "发送前端消息失败：" e.Message)
            return false
        }
    }

    static _IsLocalSource(source) {
        return (source = this.ORIGIN) || (InStr(source, this.ORIGIN "/") = 1)
    }
}
