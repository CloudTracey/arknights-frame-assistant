; == 时序服务 ==
; CurrentDelay/ClickDelay 的唯一 owner。

class TimingService {
    static _CurrentDelay := 17     ; 默认60帧（自动适配未识别时的回退值）
    static _ClickDelay := 50       ; 默认50ms
    static _AutoFps := 0           ; 游戏帧率自动识别结果；0 表示未识别/识别失败

    static GetCurrentDelay() {
        return this._CurrentDelay
    }

    static GetClickDelay() {
        return this._ClickDelay
    }

    ; 订阅设置变更事件（由 bootstrap 调用，避免顶层副作用）
    static Init() {
        EventBus.Subscribe("SettingsChanged", (data) => this._HandleSettingsChanged(data))
        EventBus.Subscribe("SettingsSaved", (*) => this.Refresh())
        EventBus.Subscribe("SettingsApplied", (*) => this.Refresh())
        EventBus.Subscribe("SettingsReset", (*) => this.Refresh())
        EventBus.Subscribe("GameFrameRateChanged", (data) => this._HandleGameFrameRateChanged(data))
    }

    ; 处理单键设置变更：帧率/点击延迟变化时刷新缓存
    static _HandleSettingsChanged(data) {
        if (data.key = "Frame" || data.key = "ClickDelay")
            this.Refresh()
    }

    ; 处理游戏帧率识别结果：仅「自动适配」模式使用该结果；手动档位不受影响
    static _HandleGameFrameRateChanged(data) {
        this._AutoFps := data.ok ? data.fps : 0
        this.Refresh()
    }

    ; 根据帧率模式刷新延迟缓存：自动适配用识别结果，手动档位用所选档位对应常量
    static Refresh() {
        oldDelay := this._CurrentDelay
        oldClickDelay := this._ClickDelay
        frame := Config.GetImportant("Frame")
        if (frame = Constants.FrameAutoValue) {
            if (this._AutoFps > 0) {
                this._CurrentDelay := Constants.DelayForFrameRate(this._AutoFps)
                frameSource := "自动识别 " this._AutoFps "fps"
            } else {
                this._CurrentDelay := Constants.Delay60
                frameSource := "自动适配未识别，回退 60fps"
            }
        } else {
            manualDelay := Constants.DelayForFrameText(frame)
            this._CurrentDelay := manualDelay > 0 ? manualDelay : Constants.Delay60
            frameSource := "手动档位 " (frame = "" ? "未知" : frame)
        }
        this._ClickDelay := Config.ReadCustomFromIni("ClickDelay")
        if (oldDelay != this._CurrentDelay || oldClickDelay != this._ClickDelay) {
            Logger.Info("Timing", "时序缓存刷新：帧率来源=" frameSource
                . "，CurrentDelay " oldDelay "→" this._CurrentDelay
                . "，ClickDelay " oldClickDelay "→" this._ClickDelay)
        }
    }
}
