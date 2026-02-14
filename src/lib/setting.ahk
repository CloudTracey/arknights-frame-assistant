; == 设置相关 ==
; 从配置文件加载设置
LoadSettings() {
    for keyVar, _ in KeyNames {
        HotKeySettings[keyVar] := IniRead(INI_FILE, "Hotkeys", keyVar, DefaultHotKeySettings[keyVar])
    }
    for optionVar, _ in ImportantNames {
        ImportantSettings[optionVar] := IniRead(INI_FILE, "Main", optionVar, DefaultImportantSettings[optionVar])
    }
    DelaySetting()
}

; 操作延迟设置
DelaySetting() {
    global Delay
    if (ImportantSettings["Frame"] == 1) {
        Delay := DelayA
    }
    else if (ImportantSettings["Frame"] == 2) {
        Delay := DelayB
    }
    else if (ImportantSettings["Frame"] == 3) {
        Delay := DelayC
    }
}

; 记录热键并写入配置文件
HotkeyIniWrite() {
    if(ModifyHook.InProgress) {
        ModifyHook.Stop()
    }
    SavedObj := MyGui.Submit(0) 
    UsedKeys := Map()
    for keyVar, keyName in KeyNames {
        if (!SavedObj.HasProp(keyVar))
            continue
        currentKey := SavedObj.%keyVar%
        if (currentKey != "") {
            ; 按键冲突提示
            if (UsedKeys.Has(currentKey)) {
                prevKeyName := UsedKeys[currentKey]
                MsgBox("按键冲突！`n[" currentKey "] 已经被设置为: 【" prevKeyName "】`n请先修改重复的按键。", "保存失败", "Icon!")
                Exit
            }
            UsedKeys[currentKey] := keyName
        }
    }
    IniWrite(SavedObj.PressPause,  INI_FILE, "Hotkeys", "PressPause")
    IniWrite(SavedObj.ReleasePause,  INI_FILE, "Hotkeys", "ReleasePause")
    IniWrite(SavedObj.GameSpeed,   INI_FILE, "Hotkeys", "GameSpeed")
    IniWrite(SavedObj.Skill,       INI_FILE, "Hotkeys", "Skill")
    IniWrite(SavedObj.Retreat,     INI_FILE, "Hotkeys", "Retreat")
    IniWrite(SavedObj.PauseSkill,  INI_FILE, "Hotkeys", "PauseSkill")
    IniWrite(SavedObj.PauseRetreat,INI_FILE, "Hotkeys", "PauseRetreat")
    IniWrite(SavedObj.33ms,    INI_FILE, "Hotkeys", "33ms")
    IniWrite(SavedObj.166ms,   INI_FILE, "Hotkeys", "166ms")
    IniWrite(SavedObj.PauseSelect, INI_FILE, "Hotkeys", "PauseSelect")
    IniWrite(SavedObj.OneClickSkill,  INI_FILE, "Hotkeys", "OneClickSkill")
    IniWrite(SavedObj.OneClickRetreat, INI_FILE, "Hotkeys", "OneClickRetreat")
    IniWrite(SavedObj.AutoClose, INI_FILE, "Main", "AutoClose")
    IniWrite(SavedObj.AutoOpen,  INI_FILE, "Main", "AutoOpen")
    IniWrite(SavedObj.Frame,  INI_FILE, "Main", "Frame")
    IniWrite(SavedObj.AutoCheckUpdate, INI_FILE, "Main", "AutoCheckUpdate")
}

; 重置默认设置
SetDefaultSetting() {
    Result := MsgBox("  确定重置按键为默认设置吗 ？","重置按键设置", "YesNo")
    if (Result == "Yes") {
        for key, _ in DefaultHotKeySettings {
                MyGui[key].Value := DefaultHotKeySettings[key]
        }
    }
    HotkeyOff()
    HotkeyIniWrite()
    LoadSettings()
    HotkeyOn()
}

; 保存设置
SaveAndClose() {
    HotkeyOff()
    HotkeyIniWrite()
    LoadSettings()
    HotkeyOn()
    HideGui()
    MsgBox("设置已保存！后续可从右下角托盘区图标右键菜单打开设置", "保存成功", "Iconi")
}

; 应用设置
ApplySettings() {
    HotkeyOff()
    HotkeyIniWrite()
    LoadSettings()
    HotkeyOn()
    MsgBox("设置已应用！", "应用成功")
}

; 取消设置
CancleSetting() {
    for key, _ in HotkeySettings {
        MyGui[key].Value := HotkeySettings[key]
    }
    for key, _ in ImportantSettings {
        MyGui[key].Value := ImportantSettings[key]
    }
    HideGui()
}

; 启用热键
HotkeyOn() {
    HotIfWinActive("ahk_exe Arknights.exe") 
    for keyVar, _ in KeyNames {
        if (HotkeySettings[keyVar] != "") {
            Action := "Action" . keyVar
            if (HotkeySettings[keyVar] ~= "^(E|Q|F|G)$") {
                Hotkey(HotkeySettings[keyVar], %Action%, "On")
            }
            else {
                Hotkey("~" HotkeySettings[keyVar], %Action%, "On")
            }
        }
    }
    HotIf
}

; 禁用热键
HotkeyOff() {
    HotIfWinActive("ahk_exe Arknights.exe") 
    for keyVar, _ in KeyNames {
        if (HotkeySettings[keyVar] != "") {
            Action := "Action" . keyVar
            if (HotkeySettings[keyVar] ~= "^(E|Q|F|G)$") {
                Hotkey(HotkeySettings[keyVar], %Action%, "Off")
            }
            else {
                Hotkey("~" HotkeySettings[keyVar], %Action%, "Off")
            }
        }
    }
    HotIf
}

; 自动退出计时器
SetTimer CheckGameStatus, 1000

; 检查游戏状态
CheckGameStatus() {
    global GameHasStarted
    if (ImportantSettings["AutoClose"] != "1")
        return
    if WinExist("ahk_exe Arknights.exe") {
        GameHasStarted := true
    }
    else {
        if (GameHasStarted == true) {
            ExitApp
        }
    }
}
; 检查更新主函数
CheckUpdate(Silent := false) 
{
    global Version, UpdateAPI, Repo
    try 
    {
        whr := ComObject("WinHttp.WinHttpRequest.5.1")
        whr.Open("GET", UpdateAPI, true)
        whr.SetRequestHeader("User-Agent", "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AHK-Updater")
        whr.Send()
        whr.WaitForResponse()
        
        if (whr.Status != 200) 
        {
            if (!Silent)
                MsgBox("网络连接失败，无法获取更新信息。`n状态码: " whr.Status, "更新失败", "Icon!")
            return
        }

        if (RegExMatch(whr.ResponseText, '"tag_name":\s*"(.*?)"', &match)) 
        {
            LatestVersion := match[1]
            
            if (LatestVersion != Version) 
            {
                Result := MsgBox("发现新版本: " LatestVersion "`n当前版本: " Version "`n`n是否立即更新并自动重启助手？", "自动更新", "YesNo Iconi")
                if (Result == "Yes") 
                {
                    if (RegExMatch(whr.ResponseText, '"browser_download_url":\s*"(.*?\.exe)"', &dlMatch)) 
                        DownloadAndReplace(dlMatch[1])
                    else 
                    {
                        MsgBox("未找到 EXE 附件，请手动前往发布页下载。", "提示")
                        Run("https://github.com/" . Repo . "/releases/latest")
                    }
                }
            } 
            else 
            {
                if (!Silent)
                    MsgBox("当前已是最新版本 (" Version ")`n无需更新。", "自动更新", "Iconi")
            }
        }
    } 
    catch 
    {
        if (!Silent)
            MsgBox("检查更新时发生异常，请检查网络连接或稍后再试。", "错误", "Icon!")
    }
}

DownloadAndReplace(url) 
{
    ToolTip("正在下载更新，请勿关闭程序...")
    TempFile := A_ScriptDir "\update_temp.exe"
    try 
    {
        Download(url, TempFile)
    } 
    catch 
    {
        MsgBox("下载更新失败，请检查网络权限。", "失败")
        ToolTip()
        return
    }

    ; 创建接力批处理脚本
    BatContent := "@echo off`ntimeout /t 1 /nobreak > nul`nmove /y `"" TempFile "`" `"" A_ScriptFullPath "`"`nstart `"`" `"" A_ScriptFullPath "`"`ndel %0"
    BatFile := A_ScriptDir "\updater.bat"
    
    if FileExist(BatFile)
        FileDelete(BatFile)
        
    FileAppend(BatContent, BatFile, "CP0")
    
    ; 隐藏运行并立刻退出
    Run(BatFile, , "Hide")
    ExitApp()
}