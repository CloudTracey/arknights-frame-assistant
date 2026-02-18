; == 版本管理 ==

class Version {
    ; 当前版本号
    static Number := "v1.1.0-alpha.3"
    
    ; 获取版本号
    static Get() {
        return this.Number
    }
}
