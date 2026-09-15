#Requires AutoHotkey v2.0
; 加载期错误（缺 include、include 路径写错、语法错误）OnError 抓不到，只能靠 #ErrorStdOut 送 stderr，
; 否则会弹窗阻塞自动化：见 docs/ahk_docs/lib/_ErrorStdOut.htm 与 docs/ahk_docs/lib/OnError.htm
#ErrorStdOut "UTF-8"
#Warn All, Off
#Include ../../src/lib/base/hotkey_schema.ahk
#Include ../../src/lib/base/constants.ahk
#Include ../../src/lib/base/theme.ahk

; 独立纯逻辑测试：不调用 Theme.Init，不创建窗口，不读取真实设置或注册表。
; 包含 hotkey_schema/constants 仅为提供 Constants.NormalizeThemeMode（纯数据与纯函数）。
OnError(ThemeTestFailure)
RunThemeTests()

RunThemeTests() {
    try {
        CheckThemeCases()
        ExitApp 0
    } catch as err {
        ThemeTestFailure(err)
    }
}

CheckThemeCases() {
    cases := [
        ["auto", "", 1, false, "light"],
        ["auto", "", 0, false, "dark"],
        ["light", "", 0, false, "light"],
        ["dark", "", 1, false, "dark"],
        ["invalid", "", 0, false, "dark"],
        ["", "", 1, false, "light"],
        ["dark", "light", 0, false, "light"],
        ["light", "dark", 1, false, "dark"],
        ["dark", "auto", 1, false, "light"],
        ["light", "auto", 0, false, "dark"],
        ["dark", "light", 0, true, "contrast"],
        ["auto", "dark", 1, true, "contrast"]
    ]
    for index, item in cases {
        result := Theme.Resolve(item[1], item[2], item[3], item[4])
        if (result != item[5])
            throw Error("Resolve case " index ": expected " item[5] ", got " result)
    }
    if (Theme.Normalize("DARK") != "dark" || Theme.Normalize("LiGhT") != "light"
        || Theme.Normalize("Auto") != "auto" || Theme.Normalize("unknown") != "auto")
        throw Error("Mode normalization failed")
    ; 规范化规则唯一实现于 Constants；Theme.Normalize 必须是同一结果
    if (Constants.NormalizeThemeMode("DARK") != "dark" || Constants.NormalizeThemeMode("") != "auto"
        || Constants.NormalizeThemeMode("light") != "light" || Constants.NormalizeThemeMode("Unknown") != "auto")
        throw Error("Constants.NormalizeThemeMode failed")
    for mode in Constants.ThemeModes {
        if (Theme.Normalize(mode) != Constants.NormalizeThemeMode(mode))
            throw Error("Theme.Normalize diverged from Constants.NormalizeThemeMode for " mode)
    }
    if (Theme._Ready || Theme._SubclassPtr || Theme._Windows.Count || Theme._Controls.Count)
        throw Error("Pure theme tests triggered initialization")
    FileAppend("PASS: 12 resolution cases, normalization (single source in Constants) and no initialization`n", "*", "UTF-8")
}

ThemeTestFailure(err, *) {
    message := "FAIL: " err.Message " (line " err.Line ")`n"
    try FileAppend(message, "**", "UTF-8")
    try FileAppend(message, A_Temp "\AFA-theme-test-error.txt", "UTF-8")
    ExitApp 1
}
