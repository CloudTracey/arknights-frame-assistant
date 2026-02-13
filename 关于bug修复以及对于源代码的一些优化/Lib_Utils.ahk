InitEnvironment() 
{
    if !DirExist(ConfigDir) 
    {
        DirCreate(ConfigDir)
    }
    OnExit(ExitFunc)
    if not A_IsAdmin 
    {
        try 
        {
            if A_IsCompiled 
                Run('*RunAs "' A_ScriptFullPath '" /restart')
            else 
                Run('*RunAs "' A_AhkPath '" /restart "' A_ScriptFullPath '"')
        }
        ExitApp()
    }
}

ExitFunc(*) 
{
    DllCall("winmm\timeEndPeriod", "UInt", 1)
    try 
    {
        Send("{f Up}{g Up}{e Up}{q Up}{Esc Up}{LButton Up}")
    }
}

USleep(delay_ms) 
{
    static freq := 0
    if (freq = 0) 
        DllCall("QueryPerformanceFrequency", "Int64*", &freq)
    
    l_start := 0, l_current := 0
    DllCall("QueryPerformanceCounter", "Int64*", &l_start)
    target := l_start + (delay_ms * freq / 1000)
    HardLimit := l_start + (2000 * freq / 1000) 
    
    PanicKey := AppSettings.Has("PanicKey") ? AppSettings["PanicKey"] : "F1"

    while (l_current < target) 
    {
        DllCall("QueryPerformanceCounter", "Int64*", &l_current)
        if (l_current > HardLimit) 
            break 
        
        if (PanicKey != "" && GetKeyState(PanicKey, "P")) 
            PerformPanicReset()
    }
}

PerformPanicReset(*) 
{
    Critical("Off")
    Send("{f Up}{g Up}{e Up}{q Up}{Esc Up}{LButton Up}{RButton Up}") 
    ToolTip("!!! 紧急停止 已重置 !!!")
    SoundBeep(1000, 200) 
    Sleep(500) 
    Reload()
}

LoadSettings() 
{
    for k, v in DefaultAppSettings 
    {
        AppSettings[k] := IniRead(INI_FILE, "Hotkeys", k, v)
    }
    AppSettings["PanicKey"] := IniRead(INI_FILE, "Hotkeys", "PanicKey", "F1") 
    AppSettings["AutoClose"] := IniRead(INI_FILE, "Main", "AutoClose", "1")
    AppSettings["AutoOpen"] := IniRead(INI_FILE, "Main", "AutoOpen", "1")
    AppSettings["Frame"] := IniRead(INI_FILE, "Main", "Frame", "3")
    DelaySetting()
}

DelaySetting() 
{
    global Delay
    Delay := (AppSettings["Frame"] == "1") ? DelayA : (AppSettings["Frame"] == "2") ? DelayB : DelayC
}

HotkeyOn() 
{
    HotIfWinActive("ahk_exe Arknights.exe") 
    FuncMap := Map("PauseA",ActionPause,"PauseB",ReleasePause,"GameSpeed",ActionGameSpeed,"33ms",Action33ms,"166ms",Action166ms,"Pauseselect",ActionPauseselect,"Skill",ActionSkill,"Retreat",ActionRetreat,"OneClickSkill",ActionOneClickSkill,"OneClickRetreat",ActionOneClickRetreat,"PauseSkill",ActionPauseSkill,"PauseRetreat",ActionPauseRetreat)
    for k, v in AppSettings 
    {
        if (v != "" && FuncMap.Has(k)) 
            try Hotkey(v, FuncMap[k], "On")
    }
    if (AppSettings["PanicKey"] != "") 
        try Hotkey("*" . AppSettings["PanicKey"], PerformPanicReset, "On")
}

HotkeyOff() 
{
    HotIfWinActive("ahk_exe Arknights.exe") 
    for k, v in AppSettings 
    {
        if (v != "" && !InStr(k, "Auto") && k != "Frame" && k != "PanicKey") 
            try Hotkey(v, "Off")
    }
}

CheckGameStatus() 
{
    if (AppSettings["AutoClose"] != "1") 
        return
    
    if WinExist("ahk_exe Arknights.exe") 
        global GameHasStarted := true
    else if (GameHasStarted == true) 
        ExitApp()
}