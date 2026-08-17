; == 设置加载器 ==

class Loader {
    ; 从配置文件加载设置
    static LoadSettings() {
        Config.MigrateFrameRate()
        Config.MigrateGitHubToken()
        Config.LoadFromIni()
        ; 调试模式接线：同步 DEBUG 持久化与实时控制台开关（启动/保存/应用/重置均经此路径）
        debugOn := Config.ReadImportantFromIni("DebugEnabled") == "1"
        Logger.SetDebugEnabled(debugOn)
        Logger.SetConsoleEnabled(debugOn)
        TimingService.Refresh()
        ; 失焦悬停操作开关：从 INI 读取（不触碰工作副本），运行时由 HotkeyContext 消费
        HotkeyController.SetHoverOperate(Config.ReadCustomFromIni("HoverOperate") == "1")
        ; 关卡守卫开关变化时启停关卡检测轮询（关闭守卫→停轮询+强制 InLevel=true；开启守卫→恢复轮询）
        ; 虽然 level_detector.ahk 的 include 位于本文件之后，但 Loader.LoadSettings() 首次调用在 main.ahk 中
        ; 处于 level_detector include 之后（LevelDetector.Init 已执行）；保留 IsSet 判存在以防御 include 顺序调整
        if IsSet(LevelDetector)
            LevelDetector.SyncGuardSetting()
    }
}
