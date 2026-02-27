; == 版本管理 ==

class Version {
    ; 当前版本号
    static Number := "v1.3.0-beta.1"
    
    ; 获取版本号
    static Get() {
        return this.Number
    }
}
