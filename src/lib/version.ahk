; == 版本管理 ==

class Version {
    ; AFA当前版本号
    static Number := "v1.8.1"

    ; 获取版本号
    static Get() {
        return this.Number
    }
}
