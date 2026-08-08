; == 版本管理 ==

class Version {
    ; AFA当前版本号
    static Number := "v1.9.2"

    ; 获取版本号
    static Get() {
        return this.Number
    }
}
