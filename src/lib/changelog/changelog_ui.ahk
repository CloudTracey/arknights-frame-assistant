; == 更新公告界面 ==

class ChangelogUI {
    static GuiObj := ""
    static CurrentVersion := ""

    static Show(version, content) {
        this.CurrentVersion := version
        
        this.GuiObj := Gui("+AlwaysOnTop", "更新公告")
        this.GuiObj.MarginX := 25
        this.GuiObj.MarginY := 20
        this.GuiObj.BackColor := "FFFFFF"
        this.GuiObj.Opt("+Owner")
        hWnd := this.GuiObj.Hwnd
        try DllCall("dwmapi\DwmSetWindowAttribute", "ptr", hWnd, "int", 38, "int*", true, "int", 4)
        
        this.GuiObj.SetFont("s16 bold", "Microsoft YaHei UI")
        this.GuiObj.Add("Text", "y10 w600 Center", "AFA " version " 版本更新公告")
        
        this.GuiObj.SetFont("s9", "Microsoft YaHei UI")
        this.GuiObj.Add("Text", "w600 h1 Backgroundd0d0d0 y+15")
        
        this._AddSection("新功能", content.newFeatures, "c1994d2")
        this._AddSection("改进", content.improvements, "cFFA500")
        this._AddSection("问题修复", content.bugFixes, "cFF6B6B")
        
        this.GuiObj.Add("Text", "x" this.GuiObj.MarginX " w600 h1 Backgroundd0d0d0 y+15")
        
        chkDontShowAgain := this.GuiObj.Add("Checkbox", "xs y+30", "直到下次更新前不再弹出")
        
        btnConfirm := this.GuiObj.Add("Button", "x275 yp-6 w100 Default", "确定")
        btnConfirm.OnEvent("Click", (*) => this._OnConfirm(chkDontShowAgain))
        
        this.GuiObj.OnEvent("Close", (*) => this._OnConfirm(chkDontShowAgain))
        
        this.GuiObj.Show()
    }

    static _AddSection(title, items, color) {
        if items.Length = 0
            return
        
        this.GuiObj.SetFont("s12 bold", "Microsoft YaHei UI")
        this.GuiObj.Add("Text", "x" this.GuiObj.MarginX " y+9 w450 Section", title)
        
        this.GuiObj.SetFont("s9", "Microsoft YaHei UI")
        for item in items {
            this.GuiObj.Add("Text", "xs+15 y+5 w570", "• " item)
        }
    }

    static _OnConfirm(chkBox) {
        if chkBox.Value {
            Config.SetImportant("DismissedChangelogVersion", this.CurrentVersion)
            IniWrite(Config._ImportantSettings["DismissedChangelogVersion"], Config.IniFile, "Main", "DismissedChangelogVersion")
        }
        this.GuiObj.Destroy()
    }
}
