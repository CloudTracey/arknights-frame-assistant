; == 界面类型分派（classic / web） ==
class UiShell {
    static Engine := "classic"
    static _Subscribed := false
    ; 启动设置界面
    static Start() {
        this.Engine := "classic"
        try {
            this.Engine := Constants.NormalizeUiEngine(Config.GetImportant("UiEngine"))
            this._Subscribe()
            TrayController.Init()
            Logger.Info("UiShell", "设置界面类型：" this.Engine)
            if (this.Engine = "web" && WebHost.Activate())
                return
            this.Engine := "classic"
        } catch Error as e {
            Logger.Error("UiShell", "界面类型初始化失败，回落到经典界面：" e.Message)
            this.Engine := "classic"
        }
        GuiManager.Start()
    }

    static Show() {
        if (this.Engine = "web")
            WebHost.Show()
        else
            GuiManager.Show()
    }

    static _Subscribe() {
        if (this._Subscribed)
            return
        this._Subscribed := true
        EventBus.Subscribe("SettingsShowRequested", (*) => this.Show())
    }
}
