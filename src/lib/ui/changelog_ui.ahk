; == 更新公告界面 ==

class ChangelogUI {
    static GuiObj := ""
    static CurrentVersion := ""

    ; 订阅公告可用事件（由 bootstrap 调用，避免顶层副作用）
    static Init() {
        EventBus.Subscribe("ChangelogAvailable", (data) => this.Show(data.version, data.body))
    }

    static Show(version, body) {
        this.CurrentVersion := version

        this.GuiObj := Gui("+AlwaysOnTop", I18n.T("更新公告"))
        this.GuiObj.MarginX := 25
        this.GuiObj.MarginY := 20
        this.GuiObj.BackColor := "FFFFFF"
        this.GuiObj.Opt("+Owner")
        hWnd := this.GuiObj.Hwnd
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hWnd, "int", 38, "int*", true, "int", 4)

        this.GuiObj.SetFont("s16 bold", Metrics.FontFor(I18n.GetCurrent()))
        this.GuiObj.Add("Text", "y10 w450 Center", I18n.T("AFA版本更新公告"))

        ; Edit 控件显示 Markdown 原文
        this.GuiObj.SetFont("s10 Norm", Metrics.FontFor(I18n.GetCurrent()))
        this.GuiObj.Add("Edit", "xs y+15 w450 h350 ReadOnly +VScroll", body)

        chkDontShowAgain := this.GuiObj.Add("Checkbox", "xs y+20", I18n.T("直到下次更新前不再弹出"))

        btnConfirm := this.GuiObj.Add("Button", "x375 yp-12 w100 Default", I18n.T("确定"))
        btnConfirm.OnEvent("Click", (*) => this._OnConfirm(chkDontShowAgain))

        this.GuiObj.OnEvent("Close", (*) => this._OnConfirm(chkDontShowAgain))

        this.GuiObj.Show()

        btnConfirm.Focus
    }

    static _OnConfirm(chkBox) {
        if chkBox.Value {
            EventBus.Publish("ChangelogDismissRequested", {version: this.CurrentVersion})
        }
        this.GuiObj.Destroy()
    }
}
