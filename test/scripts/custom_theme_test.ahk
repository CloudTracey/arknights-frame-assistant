#Requires AutoHotkey v2.0
#Warn All, Off
#Include ../../src/lib/base/hotkey_schema.ahk
#Include ../../src/lib/base/constants.ahk
#Include ../../src/lib/base/config.ahk
#Include ../../src/lib/base/appearance.ahk
#Include ../../src/lib/base/background_image.ahk
#Include ../../src/lib/base/theme.ahk
#Include ../../src/lib/core/settings/settings_service.ahk

; 隔离测试只调用纯运算与 _PersistAppearance；不运行 Bootstrap、GUI 或游戏逻辑。
; 消息翻译和失败日志替身，不替代实际 Config 原子写入实现。
class I18n {
    static T(key, args*) => args.Length ? Format(key, args*) : key
}
class Logger {
    static Warn(*) {
    }
    static Error(*) {
    }
}
OnError(CustomThemeTestFailure)
RunCustomThemeTests()

RunCustomThemeTests() {
    try CheckCustomTheme()
    catch as err
        CustomThemeTestFailure(err)
    ExitApp 0
}

CheckCustomTheme() {
    values := Appearance.Defaults.Clone()
    values["ThemeMode"] := "custom"
    values["ThemeWindow"] := "#123abc"
    values["ThemeImageOpacity"] := "200"
    values := Appearance.Normalize(values)
    Check(values["ThemeWindow"] = "123ABC", "hex normalization")
    Check(values["ThemeImageOpacity"] = "100", "opacity bounds")
    Check(Theme.Resolve("custom", "", 1) = "custom", "fixed mode")
    Check(Theme.Resolve("custom", "", 0, true) = "contrast", "high contrast")
    Check(Abs(Appearance.Contrast("000000", "FFFFFF") - 21) < 0.001, "contrast ratio")
    palette := Appearance.Palette(values)
    Check(palette["Window"] = "123ABC" && palette["Text"] = values["ThemeText"], "palette")
    copy := values.Clone()
    copy["ThemeAccent"] := "ABCDEF"
    Check(!Appearance.Equal(values, copy), "independent snapshot")
    r := Appearance.ImageRect(100, 50, 200, 200, "cover")
    Check(r.X = -100 && r.W = 400 && r.H = 200, "cover")
    r := Appearance.ImageRect(100, 50, 200, 200, "contain")
    Check(r.Y = 50 && r.W = 200 && r.H = 100, "contain")
    directory := A_Args.Length ? A_Args[1] : A_Temp "\AFA-custom-theme-tests-" A_TickCount
    DirCreate(directory)
    Config.IniFile := directory "\Settings.ini"
    if FileExist(Config.IniFile)
        throw Error("Test INI already exists")
    IniWrite("keep", Config.IniFile, "Main", "Unrelated")
    IniWrite("f", Config.IniFile, "Hotkeys", "PressPause")
    result := SettingsService._PersistAppearance(values)
    Check(result.success, "appearance write: " result.message)
    for key, value in values
        Check(IniRead(Config.IniFile, "Main", key) == value, "round trip " key)
    Check(IniRead(Config.IniFile, "Main", "Unrelated") = "keep", "unrelated main key")
    Check(IniRead(Config.IniFile, "Hotkeys", "PressPause") = "f", "hotkeys retained")
    before := FileRead(Config.IniFile, "RAW")
    FileSetAttrib("+R", Config.IniFile)
    try {
        result := SettingsService._PersistAppearance(copy)
        Check(!result.success, "readonly target fails")
        after := FileRead(Config.IniFile, "RAW")
        Check(before.Size = after.Size && DllCall("msvcrt\memcmp", "Ptr", before, "Ptr", after, "UPtr", before.Size) = 0, "failed write leaves bytes intact")
    } finally FileSetAttrib("-R", Config.IniFile)
    Check(!Theme._Ready && !BackgroundImage._Token, "no GUI/image initialization")
    FileAppend("PASS: model, palette, geometry, atomic INI round trip and failure preservation`n", "*", "UTF-8")
}

Check(value, message) {
    if !value
        throw Error(message)
}

CustomThemeTestFailure(err, *) {
    message := "FAIL: " err.Message " (" err.File ":" err.Line ")`n"
    try FileAppend(message, "**", "UTF-8")
    try FileAppend(message, A_Temp "\AFA-custom-theme-test-error.txt", "UTF-8")
    ExitApp 1
}
