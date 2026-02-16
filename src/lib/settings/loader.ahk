; == 设置加载器 ==
; 负责从配置文件加载设置到内存

; 从配置文件加载设置
LoadSettings() {
    Config.LoadFromIni()
    State.UpdateDelay()
}
