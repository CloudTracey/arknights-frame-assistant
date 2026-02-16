; == 版本管理 ==
; 集中管理版本号，便于自动更新

class Version {
    ; 当前版本号
    static Number := "v1.0.10"
    
    ; 获取版本号
    static Get() {
        return this.Number
    }
}
