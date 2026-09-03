; == 单例识别（命名互斥体） ==
; 与可执行文件名无关（编译版 AFA.exe / 未编译版 AutoHotkey*.exe 行为一致），
; 且不依赖 WMI/COM，启动早期即可安全使用。
; 使用范式：
;   - Bootstrap 启动时 if (!SingleInstance.Acquire()) { ...已有实例... }
;   - 本轮次有意退出并交给新进程接管前（托盘重启 / 提权重启），先 SingleInstance.Release()
;     释放互斥体句柄，避免新进程在旧进程尚未退出时被误判为重复启动。

class SingleInstance {
    ; 互斥体命名；进程退出时由 OS 自动释放，无需在任何路径手动清理
    static Name := "ArknightsFrameAssistant-Singleton"

    ; 当前进程持有的互斥体句柄（DllCall 句柄不会被 AHK 自动关闭，需显式 CloseHandle）
    static Handle := 0

    ; 尝试成为唯一实例：成功（本实例为第一个）返回 true。
    ; CreateMutexW 返回 NULL（如跨完整性级别被拒）或 GetLastError=183（ERROR_ALREADY_EXISTS）
    ; 都视为已有实例，返回 false。GetLastError 必须紧跟 CreateMutexW 读取。
    static Acquire() {
        handle := DllCall("CreateMutexW", "Ptr", 0, "Int", 0, "WStr", this.Name, "Ptr")
        this.Handle := handle
        return (handle != 0 && DllCall("GetLastError") != 183)
    }

    ; 释放互斥体句柄（幂等）。调用后本进程不再持有单例，供重启/提权重启前让位。
    ; 注：Bootstrap 的 Acquire 早于 Logger.Init（此时无文件可写，冲突提示走 OutputDebug），
    ; 故只在 Release（托盘重启路径）记录——提权路径调用时若 Logger 仍未初始化则安全降级到 DebugView。
    static Release() {
        if (this.Handle != 0) {
            Logger.Info("SingleInstance", "释放单例互斥体，句柄=" this.Handle)
            DllCall("CloseHandle", "Ptr", this.Handle)
            this.Handle := 0
        }
    }
}
