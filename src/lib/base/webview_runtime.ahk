; WebView2 Runtime 探测（注册表 pv 值），供 web 引擎预检使用。

class WebViewRuntime {
    static CLIENT_GUID := "{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"

    static _RootsNative := [
        "HKLM\SOFTWARE\Microsoft\EdgeUpdate\Clients\",
        "HKCU\SOFTWARE\Microsoft\EdgeUpdate\Clients\"
    ]

    static _RootsWow := [
        "HKLM\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\",
        "HKCU\SOFTWARE\WOW6432Node\Microsoft\EdgeUpdate\Clients\"
    ]

    ; 与进程架构匹配的注册表视图优先，另一个兜底；两组内 HKLM 均在 HKCU 之前。
    static _Roots() {
        if (A_PtrSize = 8)
            return [this._RootsNative[1], this._RootsWow[1], this._RootsNative[2], this._RootsWow[2]]
        return [this._RootsWow[1], this._RootsNative[1], this._RootsWow[2], this._RootsNative[2]]
    }

    static _Availability := ""

    ; 运行时是否可用。结果缓存
    ; 检测失败不抛异常
    static IsAvailable() {
        if (this._Availability != "")
            return this._Availability = "1"
        this._Availability := this._FindVersion() = "" ? "0" : "1"
        return this._Availability = "1"
    }

    ; 首个可用运行时的版本号；读不到返回空串。不走缓存，供日志使用。
    static GetVersion() {
        return this._FindVersion()
    }

    static _FindVersion() {
        for root in this._Roots() {
            version := this._ReadVersion(root . this.CLIENT_GUID)
            if (version != "")
                return version
        }
        return ""
    }

    static _ReadVersion(clientKey) {
        try {
            version := RegRead(clientKey, "pv")
            if (StrLen(version) = 0 || version = "0.0.0.0")
                return ""
            return version
        }
        return ""
    }
}
