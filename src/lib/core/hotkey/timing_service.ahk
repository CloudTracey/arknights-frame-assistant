; == 时序服务 ==
; 从 State 收归的 CurrentDelay/ClickDelay 唯一 owner。

class TimingService {
    static _CurrentDelay := 11.3  ; 默认120帧
    static _ClickDelay := 50      ; 默认50ms

    static GetCurrentDelay() {
        return this._CurrentDelay
    }

    static GetClickDelay() {
        return this._ClickDelay
    }

    ; 根据当前配置刷新延迟缓存（由 SettingsService/Loader 在配置变更后调用）
    static Refresh() {
        frame := Config.GetImportant("Frame")
        if (frame == "30") {
            this._CurrentDelay := Constants.Delay30
        } else if (frame == "60") {
            this._CurrentDelay := Constants.Delay60
        } else if (frame == "90") {
            this._CurrentDelay := Constants.Delay90
        } else if (frame == "120") {
            this._CurrentDelay := Constants.Delay120
        } else if (frame == "144") {
            this._CurrentDelay := Constants.Delay144
        } else if (frame == "165") {
            this._CurrentDelay := Constants.Delay165
        } else if (frame == "180") {
            this._CurrentDelay := Constants.Delay180
        } else if (frame == "240+") {
            this._CurrentDelay := Constants.Delay240
        }
        this._ClickDelay := Config.ReadCustomFromIni("ClickDelay")
    }
}
