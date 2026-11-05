; 运行环境探测

class Environment {
    static IsWine := FileExist("C:\windows\system32\wineboot.exe") != ""
    static HasTouchInjection := Environment._DetectTouchInjection()

    static _DetectTouchInjection() {
        hMod := DllCall("GetModuleHandle", "Str", "user32.dll", "Ptr")
        if (!hMod)
            return false
        return DllCall("GetProcAddress", "Ptr", hMod, "AStr", "InjectTouchInput", "Ptr") ? true : false
    }
}
