; web 设置适配：快照读取、草稿写入与保存请求。

class WebSettings {
    static Get(params) {
        values := Map()
        for key in GuiManager.GuiImportantKeys {
            if (key = "Frame") {
                values["Frame155"] := Config.GetImportant("Frame")
                continue
            }
            if (key = "GitHubToken")
                continue
            values[key] := Config.GetImportant(key)
        }
        for key in Config.AllCustom
            values[key] := Config.GetCustom(key)
        for key in Config.AllHotkeys
            values[key] := Config.GetHotkey(key)
        return Map(
            "values", values,
            "customHotkeys", this._CustomHotkeys(),
            "hasGitHubToken", Config.GetImportant("GitHubToken") != "" ? JSON.true : JSON.false
        )
    }

    static SetDraft(params) {
        if (!params.Has("key") || Type(params["key"]) != "String")
            return this._Fail("bad_request", "缺少 key")
        key := params["key"]
        if (!params.Has("value"))
            return this._Fail("bad_request", "缺少 value")
        value := params["value"]
        if (Type(value) = "Map" || Type(value) = "Array" || Type(value) = "Object")
            return this._Fail("bad_request", "value 必须是标量")
        value := "" value
        if (key = "Frame" || key = "Frame155") {
            if (!this._IsFrameValue(value))
                return this._Fail("invalid_value", "非法帧率：" value)
            Config.SetImportant("Frame", value)
            return Map("success", JSON.true, "key", "Frame155", "value", Config.GetImportant("Frame"))
        }
        if (!this._IsWritableKey(key))
            return this._Fail(this._IsReadOnlyKey(key) ? "read_only" : "unknown_key", "不可写入的配置键：" key)
        if (key = "ThemeMode") {
            mode := Constants.NormalizeThemeMode(value)
            Config.SetImportant("ThemeMode", mode)
            Theme.Preview(mode)
            return Map("success", JSON.true, "key", key, "value", mode)
        }
        if (key = "UiEngine") {
            engine := Constants.NormalizeUiEngine(value)
            Config.SetImportant("UiEngine", engine)
            return Map("success", JSON.true, "key", key, "value", engine)
        }
        if (Config.AllImportant.Has(key)) {
            Config.SetImportant(key, value)
            return Map("success", JSON.true, "key", key, "value", Config.GetImportant(key))
        }
        if (Config.AllCustom.Has(key)) {
            Config.SetCustom(key, value)
            return Map("success", JSON.true, "key", key, "value", Config.GetCustom(key))
        }
        Config.SetHotkey(key, value)
        return Map("success", JSON.true, "key", key, "value", Config.GetHotkey(key))
    }

    static RequestSave() {
        SetTimer(ObjBindMethod(this, "_Save"), -1)
        return Map("started", JSON.true)
    }

    static RequestApply() {
        SetTimer(ObjBindMethod(this, "_Apply"), -1)
        return Map("started", JSON.true)
    }

    static RequestCancel() {
        SetTimer(ObjBindMethod(this, "_Cancel"), -1)
        return Map("started", JSON.true)
    }

    static _Save() {
        SettingsService.Save()
    }

    static _Apply() {
        SettingsService.Apply()
    }

    static _Cancel() {
        SettingsService.Cancel()
    }

    static Read(key) {
        if (key = "Frame" || key = "Frame155")
            return Config.GetImportant("Frame")
        if (Config.AllImportant.Has(key))
            return Config.GetImportant(key)
        if (Config.AllCustom.Has(key))
            return Config.GetCustom(key)
        if (Config.AllHotkeys.Has(key))
            return Config.GetHotkey(key)
        return ""
    }

    static IsExposedKey(key) {
        if (key = "Frame155")
            return true
        if (key = "GitHubToken")
            return false
        for item in GuiManager.GuiImportantKeys {
            if (item = "Frame" || item = "GitHubToken")
                continue
            if (item = key)
                return true
        }
        return Config.AllCustom.Has(key) || Config.AllHotkeys.Has(key)
    }

    static _CustomHotkeys() {
        result := []
        for entry in Config.AllCustomHotkeys
            result.Push(Map("key", entry.Key, "name", entry.Name, "func", entry.Func, "arg", entry.Arg, "type", entry.Type))
        return result
    }

    static _IsFrameValue(value) {
        for opt in Constants.FrameOptions {
            if (opt = value)
                return true
        }
        return false
    }

    static _IsWritableKey(key) {
        if (key = "GitHubToken")
            return false
        if (this._IsImportantKey(key))
            return true
        return Config.AllCustom.Has(key) || Config.AllHotkeys.Has(key)
    }

    static _IsImportantKey(key) {
        if (key = "Frame" || key = "Frame155")
            return true
        for item in GuiManager.GuiImportantKeys {
            if (item = "Frame" || item = "GitHubToken")
                continue
            if (item = key)
                return true
        }
        return false
    }

    static _IsReadOnlyKey(key) {
        return key = "GitHubToken" || (Config.AllImportant.Has(key) && !this._IsImportantKey(key))
    }

    static _Fail(code, message) {
        return Map("success", JSON.false, "code", code, "message", message)
    }
}
