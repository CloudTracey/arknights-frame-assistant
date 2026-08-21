#Requires AutoHotkey v2.0
#Warn All, Off

#Include ../../src/lib/base/logger.ahk
#Include ../../src/lib/base/version.ahk
#Include ../../src/lib/base/message_box.ahk
#Include ../../src/lib/base/token_protector.ahk
#Include ../../src/lib/base/hotkey_schema.ahk
#Include ../../src/lib/base/constants.ahk
#Include ../../src/lib/base/config.ahk
#Include ../../src/lib/base/i18n.ahk
#Include ../../src/lib/base/eventbus.ahk
#Include ../../src/lib/base/file_extractor.ahk
#Include ../../src/lib/base/timing.ahk
#Include ../../src/lib/base/window.ahk
#Include ../../src/lib/base/key_format.ahk
#Include ../../src/lib/base/tray.ahk
#Include ../../src/lib/base/version_utils.ahk
#Include ../../src/lib/base/touch_injection.ahk
#Include ../../src/lib/core/diagnostics/log_exporter.ahk
#Include ../../src/lib/core/launch/app_context.ahk
#Include ../../src/lib/core/launch/game_auto_start.ahk
#Include ../../src/lib/core/hotkey/timing_service.ahk
#Include ../../src/lib/core/hotkey/game_keys.ahk
#Include ../../src/lib/core/hotkey/hotkey_actions.ahk
#Include ../../src/lib/core/monitor/level_detector.ahk
#Include ../../src/lib/ui/key_bind.ahk
#Include ../../src/lib/core/hotkey/hotkey_service.ahk
#Include ../../src/lib/core/settings/hotkey_conflict_validator.ahk
#Include ../../src/lib/core/settings/settings_service.ahk
#Include ../../src/lib/core/updater/github_token_service.ahk
#Include ../../src/lib/core/updater/release_repository.ahk
#Include ../../src/lib/core/updater/version_checker.ahk
#Include ../../src/lib/core/updater/downloader.ahk
#Include ../../src/lib/core/updater/self_replacer.ahk
#Include ../../src/lib/core/updater/updater_manager.ahk
#Include ../../src/lib/ui/updater_ui.ahk
#Include ../../src/lib/core/launch/game_launcher.ahk
#Include ../../src/lib/ui/changelog_ui.ahk
#Include ../../src/lib/core/changelog/changelog_checker.ahk
#Include ../../src/lib/ui/gui.ahk
#Include ../../src/lib/core/monitor/game_monitor.ahk

Config._HotkeySettings := Config._DefaultHotkeys.Clone()
Config._ImportantSettings := Config._DefaultImportant.Clone()
Config._CustomSettings := Config._DefaultCustom.Clone()
Config._ImportantSettings["Language"] := "en-US"
Config._ImportantSettings["AutoOpenSettings"] := "0"
Config._IsLoaded := true
FileExtractor.LogoPath := A_ScriptDir "\..\..\logo.ico"

I18n.Init("en-US")
GuiManager.Init()

if !InStr(GuiManager.TxtKeybind.Text, "Combat") || InStr(GuiManager.TxtKeybind.Text, "常规作战")
    ExitApp 1
if (I18n.T("卫戍协议") != "Stronghold Protocol")
    ExitApp 19
GuiManager.MainGui["UpdateChannel"].Value := 1
if (GuiManager.MainGui["UpdateChannel"].Text != "Stable")
    ExitApp 28
GuiManager.MainGui["UpdateChannel"].Value := 2
if (GuiManager.MainGui["UpdateChannel"].Text != "Beta")
    ExitApp 29
GuiManager.MainGui["UpdateSource"].Value := 1
if (GuiManager.MainGui["UpdateSource"].Text != "China Source")
    ExitApp 32
if !InStr(GuiManager.MainGui.Title, "Arknights Frame Assistant")
    ExitApp 17
if (GuiManager.BindLabelControls[1].Text != "Pause on Press")
    ExitApp 2
collectLabelWidth := 0
for control in GuiManager.BindLabelControls {
    if (control.Text = "Collect Integrated Strategies Items") {
        control.GetPos(,, &collectLabelWidth)
        break
    }
}
if (collectLabelWidth < 185)
    ExitApp 36
GuiManager.MainGui["PauseSkill"].GetPos(&pauseSkillX,, &pauseSkillWidth)
GuiManager.MainGui["PressPause"].GetPos(,, &pressPauseWidth)
if (pauseSkillWidth < 170 || pressPauseWidth != pauseSkillWidth)
    ExitApp 37
if (GuiManager.LaunchControls[2].Text != "  Launch & Exit Settings  ")
    ExitApp 3
if (GuiManager.TxtLanguage.Text != "Language")
    ExitApp 4
if (KeyFormat.VirtualNewkeyFormat("XButton1") != "Mouse Back Button")
    ExitApp 11
if (I18n.T("请按键") != "Press a key")
    ExitApp 12
GuiManager.MainGui["PauseSkill"].GetPos(,, &mouseEditWidth)
if (mouseEditWidth < 150)
    ExitApp 37

for controlName in ["AutoExit", "AutoOpenSettings", "ExitOnWindowClose"] {
    GuiManager.MainGui[controlName].GetPos(,,, &controlHeight)
    if (controlHeight < 30)
        ExitApp 13
}
for controlName in ["AutoRunGame", "AutoStartWithGame"] {
    GuiManager.MainGui[controlName].GetPos(,, &controlWidth, &controlHeight)
    if (controlHeight < 30)
        ExitApp 38
    if (controlWidth < 500)
        ExitApp 39
}
GuiManager.MainGui["InLevelGuard"].GetPos(,,, &guardHeight)
if (guardHeight < 40)
    ExitApp 14
GuiManager.MainGui["BackCeaseOperations"].GetPos(,,, &backCeaseHeight)
if (backCeaseHeight < 40)
    ExitApp 34
GuiManager.MainGui["Frame"].GetPos(, &frameY)
GuiManager.MainGui["AutoBeginPause"].GetPos(, &autoPauseY)
GuiManager.MainGui["BackCeaseOperations"].GetPos(, &backCeaseY)
if (Abs(autoPauseY - frameY) > 2 || backCeaseY != autoPauseY - 4)
    ExitApp 35
GuiManager.MainGui["GamePath"].GetPos(,, &pathEditWidth)
if (pathEditWidth > 430)
    ExitApp 15

GuiManager.TxtLanguage.GetPos(&labelX, &labelY, &labelW, &labelH)
GuiManager.MainGui["Language"].GetPos(&dropdownX, &dropdownY, &dropdownW, &dropdownH)
if (labelX + labelW > dropdownX)
    ExitApp 5

Config.SetImportant("Language", "ja-JP")
GuiManager._ApplyLocale()
if !InStr(GuiManager.TxtKeybind.Text, "通常作戦")
    ExitApp 6
if (GuiManager.BindLabelControls[1].Text != "押下時に一時停止")
    ExitApp 7
if (GuiManager.TxtLanguage.Text != "言語")
    ExitApp 8
GuiManager.TxtSwitchHotkey.GetPos(,, &switchLabelWidth)
if (switchLabelWidth != 280)
    ExitApp 22
GuiManager.TxtSwitchHotkey.GetPos(&switchLabelX, &switchLabelY, &switchLabelWidth, &switchLabelHeight)
GuiManager.SwitchHotkey.GetPos(&switchEditX, &switchEditY, &switchEditWidth, &switchEditHeight)
if (switchEditX != switchLabelX || switchEditY <= switchLabelY + switchLabelHeight)
    ExitApp 27
if !InStr(GuiManager.MainGui["AutoBeginPause"].Text, "開幕自動停止を切替")
    ExitApp 20
GuiManager.MainGui["AutoBeginPause"].GetPos(,, &autoPauseWidth)
if (autoPauseWidth < 150)
    ExitApp 21
if !InStr(GuiManager.MainGui.Title, "アークナイツフレーム操作アシスタント")
    ExitApp 18
if (KeyFormat.VirtualNewkeyFormat("XButton1") != "マウス後側ボタン")
    ExitApp 16
if !InStr(GuiManager.MainGui["AutoUpdate"].Text, "更新を自動確認")
    ExitApp 23
if !InStr(GuiManager.MainGui["HoverOperate"].Text, "非アクティブ時もホットキーを許可")
    ExitApp 24
if !InStr(GuiManager.MainGui["DebugEnabled"].Text, "デバッグモードを有効化")
    ExitApp 25
GuiManager.MainGui["UpdateChannel"].Value := 1
if (GuiManager.MainGui["UpdateChannel"].Text != "正式版")
    ExitApp 30
GuiManager.MainGui["UpdateChannel"].Value := 2
if (GuiManager.MainGui["UpdateChannel"].Text != "テスト版")
    ExitApp 31
GuiManager.MainGui["UpdateSource"].Value := 1
if (GuiManager.MainGui["UpdateSource"].Text != "中国ソース")
    ExitApp 33
for controlName in ["AutoUpdate", "HoverOperate", "DebugEnabled"] {
    GuiManager.MainGui[controlName].GetPos(,,, &controlHeight)
    if (controlHeight < 30)
        ExitApp 26
}

Config.SetImportant("Language", "zh-CN")
GuiManager._ApplyLocale()
if !InStr(GuiManager.TxtKeybind.Text, "常规作战")
    ExitApp 9
if (GuiManager.BindLabelControls[1].Text != "按下时暂停")
    ExitApp 10

GuiManager.MainGui.Destroy()
ExitApp 0
