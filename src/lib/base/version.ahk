; == 版本管理 ==

class Version {
    ; AFA当前版本号
    static Number := "v2.0.0-alpha.1"

    ; ===== 编译元数据 =====
    ;@Ahk2Exe-Let U_afaVersion = %A_PriorLine~^.*\bNumber\s*:=\s*"v?(\S+)"\s*$~$1%
    ;@Ahk2Exe-SetVersion %U_afaVersion%
    ;@Ahk2Exe-SetLanguage 0x0804
    ;@Ahk2Exe-SetName 明日方舟帧操小助手 AFA
    ;@Ahk2Exe-SetCompanyName AFA Developer Team
    ;@Ahk2Exe-SetCopyright Copyright © 2026 AFA Developer Team
    ;@Ahk2Exe-SetDescription 明日方舟帧操小助手 AFA

    ; 获取版本号
    static Get() {
        return this.Number
    }
}
