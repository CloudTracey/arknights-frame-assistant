; == 托盘控制器 ==
; 托盘菜单与图标提示的唯一 owner

class TrayController {
    static _SubscribedRefresh := false
    static _LastServerId := ""       ; 最近一次前台区服

    ; 建立（或重建）托盘菜单
    static Init() {
        this._RenderTooltip(this._LastServerId)
        A_TrayMenu.Delete
        A_TrayMenu.Add(I18n.T("打开设置界面"), (*) => this.OpenSettings())
        A_TrayMenu.Add(I18n.T("启用/禁用热键"), (*) => EventBus.Publish("HotkeyToggleRequested"))
        if (UiShell.Engine = "web")
            A_TrayMenu.Add(I18n.T("切换到经典界面(Windows原生GUI)"), (*) => this.SwitchToClassic())
        else
            A_TrayMenu.Add(I18n.T("切换到现代界面(WebView2)"), (*) => this.SwitchToModern())
        A_TrayMenu.Add(I18n.T("重启AFA"), (*) => SingleInstance.Restart())
        A_TrayMenu.Add(I18n.T("退出"), (*) => ExitApp())
        this._SubscribeRefresh()
        A_TrayMenu.Default := I18n.T("打开设置界面")
        this.RefreshHotkeyItem(Config.ReadCustomFromIni("SwitchHotkey"))
    }

    static OpenSettings() {
        UiShell.Show()
    }

    ; web 模式的原生回退入口
    static SwitchToClassic() {
        this._SwitchEngine("classic", I18n.T("确认切换到经典界面并重启 AFA？"))
    }

    ; 经典模式切到 web
    static SwitchToModern() {
        if (Constants.NormalizeUiEngine(Config.GetImportant("UiEngine")) != "web"
            && !WebViewRuntime.IsAvailable()) {
            if (MessageBox.Confirm(I18n.T("未检测到 WebView2 运行时，切换到 WebView2 后会回退到 Windows 原生 GUI。是否仍要保存此设置？"), I18n.T("界面类型")) != "Yes")
                return
        }
        this._SwitchEngine("web", I18n.T("确认切换到现代界面并重启 AFA？"))
    }

    static _SwitchEngine(engine, confirmText) {
        if (MessageBox.Confirm(confirmText, I18n.T("界面类型")) != "Yes") {
            Logger.Info("TrayController", "用户取消切换界面类型")
            return
        }
        if (!this._PersistUiEngine(engine))
            return
        Logger.Info("TrayController", "用户确认切换界面类型，立即重启")
        SingleInstance.Restart()
    }

    static _PersistUiEngine(engine) {
        result := SettingsService.UpdatePersistedValue("UiEngine", engine)
        if (!result.success) {
            Logger.Error("TrayController", "切换界面类型失败：" result.message)
            MessageBox.Error(result.message, I18n.T("设置保存失败"))
            return false
        }
        Logger.Info("TrayController", "界面类型已切换为 " engine)
        return true
    }

    static SetTooltip(text) {
        A_IconTip := text
    }

    ; （启用/禁用热键）附带当前切换键
    static SetHotkeyItemLabel(text) {
        A_TrayMenu.Rename("2&", text)
    }
    static RefreshHotkeyItem(key) {
        if (StrLen(key) = 0)
            this.SetHotkeyItemLabel(I18n.T("启用/禁用热键"))
        else
            this.SetHotkeyItemLabel(I18n.T("启用/禁用热键") "(" KeyFormat.VirtualNewkeyFormat(key) ")")
    }

    ; 托盘提示带当前前台区服；切到桌面/非游戏窗口时保留上次游戏区服（否则显示“未知区服”）
    static UpdateServer(serverId) {
        if (serverId = "")
            return
        this._LastServerId := serverId
        this._RenderTooltip(serverId)
    }

    ; 提示内容的唯一渲染入口。状态取实时值；无区服时只显示状态
    static _RenderTooltip(serverId) {
        state := HotkeyService.HotkeyState ? I18n.T("热键已启用") : I18n.T("热键已禁用")
        if (StrLen(serverId) = 0)
            this.SetTooltip("AFA`n" state)
        else
            this.SetTooltip("AFA`n" this._ServerName(serverId) " - " state)
    }

    static _ServerName(serverId) {
        profile := ServerProfile.Get(serverId)
        return profile != "" ? I18n.T(profile.DisplayNameKey) : I18n.T("未知区服")
    }

    ; 运行期刷新订阅
    static _SubscribeRefresh() {
        if (this._SubscribedRefresh)
            return
        this._SubscribedRefresh := true
        EventBus.Subscribe("SwitchKeyChanged", (data) => this.RefreshHotkeyItem(data.key))
        EventBus.Subscribe("ForegroundClientChanged", (data) => this.UpdateServer(data.serverId))
        EventBus.Subscribe("HotkeyStateChanged", (*) => this._RenderTooltip(this._LastServerId))
    }
}
