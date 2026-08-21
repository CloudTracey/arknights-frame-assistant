#Requires AutoHotkey v2.0
#Warn All, Off

; 冒烟测试骨架：
; 逐一 include 全部业务模块，确认所有 .ahk 只定义、零顶层副作用。
; 若某个模块在 include 时启动 GUI/定时器/写文件/弹窗等，本脚本会在 include 阶段暴露错误或非预期行为。
; 注意：这里不 include src/main.ahk，避免执行 App.Bootstrap()。

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

; 骨架断言：关键类/函数应已定义（类名在 AHK v2 中可作为值访问）
if !IsSet(Config) || !IsSet(Constants) || !IsSet(HotkeySchema) || !IsSet(I18n)
    ExitApp 1
if !IsSet(GuiManager) || !IsSet(KeyBinder) || !IsSet(HotkeyService)
    ExitApp 1
if !IsSet(GameMonitor) || !IsSet(VersionUtils) || !IsSet(KeyFormat) || !IsSet(HotkeyActions)
    ExitApp 1
if !IsSet(SettingsService) || !IsSet(HotkeyConflictValidator)
    ExitApp 1
if !IsSet(ReleaseRepository) || !IsSet(GitHubTokenService) || !IsSet(ChangelogChecker)
    ExitApp 1

; ---- HotkeySchema 完整性校验 ----
HotkeyService._BuildActionCallbacks()

; id 唯一 + 行为标志为布尔
seenIds := Map()
for item in HotkeySchema.Items {
    if seenIds.Has(item.id)
        ExitApp 1
    seenIds[item.id] := true
    if (item.guarded != true && item.guarded != false)
        ExitApp 1
    if (item.onUp != true && item.onUp != false)
        ExitApp 1
    if (item.noActivate != true && item.noActivate != false)
        ExitApp 1
}

; ActionBindings 与 Schema 双向覆盖
for id, _ in HotkeyService.ActionBindings {
    if (HotkeySchema.GetItem(id) = "")
        ExitApp 1
}
for item in HotkeySchema.Items {
    if !HotkeyService.ActionBindings.Has(item.id)
        ExitApp 1
}

; ActionCallbacks 数量与绑定一致，且行为标志与 Schema 一致
if (HotkeyService.ActionCallbacks.Count != HotkeyService.ActionBindings.Count)
    ExitApp 1
for item in HotkeySchema.Items {
    profile := HotkeyService.ActionCallbacks[item.id]
    if (profile.HasOwnProp("Guarded") != item.guarded)
        ExitApp 1
    if (profile.HasOwnProp("OnUp") != item.onUp)
        ExitApp 1
    if (profile.HasOwnProp("NoActivate") != item.noActivate)
        ExitApp 1
}

; 分组 Map 与 Schema 一致
for group, constantsMap in Map("combat", Constants.CombatHotkeys, "quick", Constants.QuickHotkeys, "strongHold", Constants.StrongHoldHotkeys) {
    schemaMap := HotkeySchema.GetGroupMap(group)
    if (schemaMap.Count != constantsMap.Count)
        ExitApp 1
    for id, _ in schemaMap {
        if !constantsMap.Has(id)
            ExitApp 1
    }
}

; 探针：确认没有顶层副作用把 Config.IniFile 提前初始化（应仍为空）
if (Config.IniFile != "")
    ExitApp 1

; ---- I18n 完整性与回退校验 ----
I18n.SetLocale("en-US")
if (I18n.T("卫戍协议") != "STRONGHOLD PROTOCOL")
    ExitApp 1
I18n.SetLocale("ja-JP")
if (I18n.T("卫戍协议") != "堅守協定")
    ExitApp 1
if (I18n.T("肉鸽") != "統合戦略" || I18n.T("基建") != "基地")
    ExitApp 1

; 热键标签和主要设置控件必须同时具备英、日翻译，避免界面局部回退中文。
for item in HotkeySchema.Items {
    if !I18n.Texts["en-US"].Has(item.displayName) || !I18n.Texts["ja-JP"].Has(item.displayName)
        ExitApp 1
}
requiredUiTexts := ["常规作战", "快捷操作", "卫戍协议", "其他设置", "语言", "游戏内帧率",
    "  启动与退出设置  ", " 随游戏进程关闭自动退出（强烈建议开启）", " 启动时打开设置窗口",
    "  更新设置  ", "更新渠道", "更新源", "  自定义设置  ", "点击延迟", "  日志设置  ",
    "保存并关闭", "应用设置", "取消", "打开设置界面", "启用/禁用热键"]
for sourceText in requiredUiTexts {
    if !I18n.Texts["en-US"].Has(sourceText) || !I18n.Texts["ja-JP"].Has(sourceText)
        ExitApp 1
}
I18n.SetLocale("invalid")
if (I18n.Locale != "zh-CN")
    ExitApp 1

ExitApp 0
