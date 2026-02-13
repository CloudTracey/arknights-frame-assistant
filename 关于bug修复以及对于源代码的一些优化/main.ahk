#Requires AutoHotkey v2.0
#SingleInstance Force
#Warn All, Off

global WindowName := "明日方舟帧操小助手 ArknightsFrameAssistant - v1.1.28"
global ConfigDir := A_AppData "\ArknightsFrameAssistant\PC"
global INI_FILE := ConfigDir "\Settings.ini"
global GameHasStarted := false, LastEditObject := "", OriginalValue := ""
global ModifyHook := InputHook("L0"), WaitingModify := false
global DelayA := 35.3, DelayB := 19.6, DelayC := 11.3, Delay := 11.3

global DefaultAppSettings := Map()
DefaultAppSettings["PauseA"] := "f"
DefaultAppSettings["PauseB"] := "Space"
DefaultAppSettings["GameSpeed"] := "d"
DefaultAppSettings["33ms"] := "r"
DefaultAppSettings["166ms"] := "t"
DefaultAppSettings["Pauseselect"] := "w"
DefaultAppSettings["Skill"] := "s"
DefaultAppSettings["Retreat"] := "a"
DefaultAppSettings["OneClickSkill"] := "e"
DefaultAppSettings["OneClickRetreat"] := "q"
DefaultAppSettings["PauseSkill"] := "XButton2"
DefaultAppSettings["PauseRetreat"] := "XButton1"
DefaultAppSettings["PanicKey"] := "F1" 
DefaultAppSettings["AutoClose"] := "1"
DefaultAppSettings["AutoOpen"] := "1"
DefaultAppSettings["Frame"] := "3"

global AppSettings := DefaultAppSettings.Clone()

#Include Lib_Utils.ahk
#Include Lib_Actions.ahk
#Include Lib_GUI.ahk

; ==============================================================================
;性能配置与启动逻辑
; ==============================================================================
ListLines(False)
KeyHistory(0)
ProcessSetPriority("Realtime")
SendMode("Input")
SetKeyDelay(-1, -1)
SetMouseDelay(-1)
SetControlDelay(-1)
SetWinDelay(-1)
SetDefaultMouseSpeed(0)
SetTitleMatchMode(3)
#MaxThreads 255          
#MaxThreadsPerHotkey 2
DetectHiddenWindows(True) 
DllCall("winmm\timeBeginPeriod", "UInt", 1)

InitEnvironment() 
LoadSettings()    
HotkeyOn()        

SetTimer(CheckGameStatus, 1000)

if (AppSettings["AutoOpen"] == "1") 
{
    ShowMainGui()
}

A_TrayMenu.Delete()
A_TrayMenu.Add("设置", (*) => MyGui.Show())
A_TrayMenu.Add("退出", (*) => ExitApp())