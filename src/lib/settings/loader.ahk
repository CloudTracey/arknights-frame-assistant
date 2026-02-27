; == 设置加载器 ==

class Loader {
    ; 从配置文件加载设置
    static LoadSettings() {
        Config.LoadFromIni()
        State.UpdateDelay()
        State.UpdateSkillAndRetreatDelay()
    }
}