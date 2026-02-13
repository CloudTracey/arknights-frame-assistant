; == 全局变量 ==
; 版本号
global Version := "v1.1.0-beta.2"
; 按键默认设置
global DefaultHotKeySettings := Map()
DefaultHotKeySettings["PressPause"] := "f"
DefaultHotKeySettings["ReleasePause"] := "Space"
DefaultHotKeySettings["GameSpeed"] := "d"
DefaultHotKeySettings["PauseSelect"] := "w"
DefaultHotKeySettings["Skill"] := "s"
DefaultHotKeySettings["Retreat"] := "a"
DefaultHotKeySettings["33ms"] := "r"
DefaultHotKeySettings["166ms"] := "t"
DefaultHotKeySettings["OneClickSkill"] := "e"
DefaultHotKeySettings["OneClickRetreat"] := "q"
DefaultHotKeySettings["PauseSkill"] := "XButton2"
DefaultHotKeySettings["PauseRetreat"] := "XButton1"
; 按键设置
global HotkeySettings := DefaultHotKeySettings.Clone()
; 按键设置映射
global KeyNames := Map(
    "PressPause", "额外暂停键A",
    "ReleasePause", "额外暂停键B",
    "GameSpeed",   "切换倍速",
    "PauseSelect", "暂停选中",
    "Skill",       "干员技能",
    "Retreat",     "干员撤退",
    "33ms",   "前进 33ms",
    "166ms",  "前进 166ms",
    "OneClickSkill",  "一键技能",
    "OneClickRetreat", "一键撤退",
    "PauseSkill",  "暂停技能",
    "PauseRetreat","暂停撤退"
)

; 其他默认设置
global DefaultMainSettings := Map()
DefaultMainSettings["AutoClose"] := "1"
DefaultMainSettings["AutoOpen"] := "1"
DefaultMainSettings["Frame"] := "3"
; 其他设置
global MainSettings := DefaultMainSettings.Clone()

; 游戏状态
global GameHasStarted := false 

; 按键绑定相关全局变量
global LastEditObject := ""
global OriginalValue := ""
global ModifyHook := InputHook("L0")
global ControlObj := ""
global WaitingModify := false

; 默认延迟
global DelayA := 35.3 ; 30帧
global DelayB := 19.6 ; 60帧
global DelayC := 11.3 ; 120帧

; ==配置文件路径==
ConfigDir := A_AppData "\ArknightsFrameAssistant\PC"
if !DirExist(ConfigDir)
    DirCreate(ConfigDir)
INI_FILE := ConfigDir "\Settings.ini"