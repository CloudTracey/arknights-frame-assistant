; == 应用启动上下文 ==
; StartedByGameAutoStart 的唯一 owner。

class AppContext {
    static _StartedByGameAutoStart := false

    static SetStartedByGameAutoStart(value) {
        this._StartedByGameAutoStart := value
        if (value)
            Logger.Info("AppContext", "本次启动来源：随游戏自动启动（--game-autostart）")
    }

    static GetStartedByGameAutoStart() {
        return this._StartedByGameAutoStart
    }
}
