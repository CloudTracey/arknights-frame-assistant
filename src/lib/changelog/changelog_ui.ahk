; == 更新公告界面 ==

class ChangelogUI {
    static GuiObj := ""
    static CurrentVersion := ""

    static Show(version, body) {
        this.CurrentVersion := version

        this.GuiObj := Gui("+AlwaysOnTop", "更新公告")
        this.GuiObj.MarginX := 25
        this.GuiObj.MarginY := 20
        this.GuiObj.BackColor := "FFFFFF"
        this.GuiObj.Opt("+Owner")
        hWnd := this.GuiObj.Hwnd
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hWnd, "int", 38, "int*", true, "int", 4)

        this.GuiObj.SetFont("s16 bold", "Microsoft YaHei UI")
        this.GuiObj.Add("Text", "y10 w450 Center", "AFA版本更新公告")

        ; Edit 控件显示 Markdown 原文
        this.GuiObj.SetFont("s10 Norm", "Microsoft YaHei UI")
        this.GuiObj.Add("Edit", "xs y+15 w450 h350 ReadOnly +VScroll", body)

        chkDontShowAgain := this.GuiObj.Add("Checkbox", "xs y+20", "直到下次更新前不再弹出")

        btnConfirm := this.GuiObj.Add("Button", "x375 yp-12 w100 Default", "确定")
        btnConfirm.OnEvent("Click", (*) => this._OnConfirm(chkDontShowAgain))

        this.GuiObj.OnEvent("Close", (*) => this._OnConfirm(chkDontShowAgain))

        this.GuiObj.Show()

        btnConfirm.Focus
    }

    static _OnConfirm(chkBox) {
        if chkBox.Value {
            try {
                IniWrite(this.CurrentVersion, Config.IniFile, "Main", "DismissedChangelogVersion")
                Config.SetImportant("DismissedChangelogVersion", this.CurrentVersion)
            } catch Error as e {
                Logger.Warn("Changelog", "忽略版本保存失败：" e.Message)
                MessageBox.Warning("更新公告已关闭，但忽略状态未能保存。下次启动可能会再次显示，请检查 Settings.ini 的写入权限。", "配置未保存")
            }
        }
        this.GuiObj.Destroy()
    }
}
