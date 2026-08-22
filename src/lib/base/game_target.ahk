; == 游戏目标 ==
; 「当前目标游戏窗口」的唯一 owner：Hwnd / Pid / ExePath / ServerId。
; 未绑定任何客户端实例时，宽松回退旧语义 ahk_exe Arknights.exe（决策 D2），
; 保证升级零回归、降级不弹窗。禁止其他模块再直接写 "ahk_exe Arknights.exe"。
; 本模块只持有状态与查询 API；绑定 / 仲裁由 core/game/game_client_registry.ahk 驱动。

class GameTarget {
    ; ── 状态（唯一 owner）──
    static _Hwnd := 0
    static _Pid := 0
    static _ExePath := ""
    static _ServerId := ""

    ; ── 绑定 / 解绑 ──

    ; 绑定当前目标客户端实例（A3 前台仲裁调用）
    static Bind(hwnd, pid, exePath, serverId) {
        this._Hwnd := hwnd
        this._Pid := pid
        this._ExePath := exePath
        this._ServerId := serverId
    }

    ; 解绑；此后 WinTitle/Exists/IsActive/Activate 回到 ahk_exe 宽松回退
    static Unbind() {
        this._Hwnd := 0
        this._Pid := 0
        this._ExePath := ""
        this._ServerId := ""
    }

    ; ── 查询 ──

    static Hwnd() {
        return this._Hwnd
    }

    static Pid() {
        return this._Pid
    }

    static ExePath() {
        return this._ExePath
    }

    ; 前台客户端的区服 id（CN/JP/KR/EN/Unknown）；未绑定时为 ""
    static ServerId() {
        return this._ServerId
    }

    static IsBound() {
        return this._Hwnd != 0
    }

    ; 目标窗口标题；未绑定时回退 "ahk_exe Arknights.exe"（宽松回退，D2）
    static WinTitle() {
        if (this._Hwnd)
            return "ahk_id " this._Hwnd
        return "ahk_exe " ServerProfile.ExeName
    }

    ; 目标窗口是否存在（未绑定时按 ahk_exe 判定）
    static Exists() {
        return WinExist(this.WinTitle()) != 0
    }

    ; 是否存在任意区服的游戏进程（各区服可执行文件名相同，进程存在性天然是"任一实例"语义）
    static ProcessExists() {
        return ProcessExist(ServerProfile.ExeName) != 0
    }

    ; 目标窗口是否前台（未绑定时按 ahk_exe 判定）
    static IsActive() {
        return WinActive(this.WinTitle()) != 0
    }

    ; 热路径廉价校验：前台窗口是否就是当前缓存的客户端。
    ; 只允许 GetForegroundWindow + GetWindowThreadProcessId 两次轻量 Win32 调用。
    static IsForegroundCached() {
        if (!this.IsBound())
            return false
        fgHwnd := DllCall("GetForegroundWindow", "Ptr")
        if (fgHwnd != this._Hwnd)
            return false
        fgPid := 0
        DllCall("GetWindowThreadProcessId", "Ptr", fgHwnd, "UInt*", &fgPid)
        return fgPid = this._Pid
    }

    ; 等待目标窗口成为前台；超时返回 false（不抛异常）
    static WaitActive(timeout := 500) {
        return WinWaitActive(this.WinTitle(), , timeout) != 0
    }

    ; 激活目标窗口；找不到返回 false 而非抛 TargetError（与 SafeWinGetClientPos 同风格）
    static Activate() {
        try {
            WinActivate(this.WinTitle())
        } catch TargetError {
            return false
        }
        return true
    }
}
