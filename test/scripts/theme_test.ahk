#Requires AutoHotkey v2.0
#Warn All, Off
#Include ../../src/lib/base/theme.ahk

; 独立纯逻辑测试：不调用 Theme.Init，不创建窗口，不读取真实设置或注册表。
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
    if (Theme.Normalize("DARK") != "dark" || Theme.Normalize("unknown") != "auto")
        throw Error("Mode normalization failed")
    if (Theme._Ready || Theme._SubclassPtr || Theme._Windows.Count || Theme._Controls.Count)
        throw Error("Pure theme tests triggered initialization")
    FileAppend("PASS: 12 resolution cases, normalization and no initialization`n", "*", "UTF-8")
}

ThemeTestFailure(err, *) {
    message := "FAIL: " err.Message " (line " err.Line ")`n"
    try FileAppend(message, "**", "UTF-8")
    try FileAppend(message, A_Temp "\AFA-theme-test-error.txt", "UTF-8")
    ExitApp 1
}
