; == 单例识别（命名互斥体） ==
; 与可执行文件名无关、不依赖 WMI/COM，启动早期即可安全使用。

class SingleInstance {
    static Name := "ArknightsFrameAssistant-Singleton"

    static Handle := 0

    ; 尝试成为唯一实例
    static Acquire() {
        handle := DllCall("CreateMutexW", "Ptr", 0, "Int", 0, "WStr", this.Name, "Ptr")
        this.Handle := handle
        return (handle != 0 && DllCall("GetLastError") != 183)
    }

    ; 释放互斥体句柄（幂等）
    static Release() {
        if (this.Handle != 0) {
            Logger.Info("SingleInstance", "释放单例互斥体，句柄=" this.Handle)
            DllCall("CloseHandle", "Ptr", this.Handle)
            this.Handle := 0
        }
    }

    ; 重启
    static Restart() {
        this.Release()
        Reload()
    }
}
