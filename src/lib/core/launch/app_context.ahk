; == 应用启动上下文 ==
; StartedByGameAutoStart 的唯一 owner。

class AppContext {
    static _StartedByGameAutoStart := false

    static SetStartedByGameAutoStart(value) {
        this._StartedByGameAutoStart := value
    }

    static GetStartedByGameAutoStart() {
        return this._StartedByGameAutoStart
    }
}
