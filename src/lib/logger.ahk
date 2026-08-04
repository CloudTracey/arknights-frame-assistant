; == 统一日志模块 ==
; 持久化 INFO/WARN/ERROR，并继续把所有级别输出到 DebugView。
; 普通日志与关键日志分轨滚动，避免容量清理时丢失错误上下文。

class Logger {
    static BaseDir := ""
    static LogDirectory := ""
    static CurrentFile := ""
    static CriticalCurrentFile := ""
    static PreviousSegmentFile := ""
    static PreviousAbnormalFile := ""
    static SessionId := ""
    static Initialized := false
    static FileAvailable := false
    static CriticalFileAvailable := false
    static DebugEnabled := false
    static IsWriting := false
    static Secrets := []
    static RecentLines := []
    static CurrentFileBytes := 0
    static CriticalCurrentFileBytes := 0
    static CachedOrdinaryFiles := 0
    static CachedOrdinaryBytes := 0
    static CachedCriticalFiles := 0
    static CachedCriticalBytes := 0
    static MetricsInitialized := false
    static CleanupPending := false
    static WritesSinceCleanup := 0

    ; 普通日志保留 15 MiB，关键日志单独保留 5 MiB，总容量仍为 20 MiB。
    static MaxAgeDays := 7
    static MaxFiles := 20
    static MaxBytes := 20 * 1024 * 1024
    static MaxOrdinaryBytes := 15 * 1024 * 1024
    static MaxOrdinarySegmentBytes := 4 * 1024 * 1024
    static MaxCriticalFiles := 5
    static MaxCriticalBytes := 5 * 1024 * 1024
    static MaxCriticalSegmentBytes := 1 * 1024 * 1024
    static RecentLineLimit := 100
    ; 普通日志没有发生轮换时，定期刷新一次目录状态，避免每条日志枚举目录。
    static CleanupWriteInterval := 64
    ; 按字符保守限制，确保 UTF-8 编码后的单行不会无限增长。
    static MaxLineCharacters := 15000

    ; 初始化当前会话日志。失败时保留 DebugView 降级路径，不抛出异常。
    static Init() {
        if this.Initialized
            return

        this.Initialized := true
        this.BaseDir := A_AppData "\ArknightsFrameAssistant\PC"
        this.LogDirectory := this.BaseDir "\logs"

        try {
            if !DirExist(this.LogDirectory)
                DirCreate(this.LogDirectory)

            this.FileAvailable := !!DirExist(this.LogDirectory)
            this.CriticalFileAvailable := this.FileAvailable
            if this.FileAvailable {
                ; 在创建新会话文件前识别上一会话是否异常退出，避免新空文件掩盖旧会话。
                this.PreviousAbnormalFile := this._FindPreviousAbnormalFile(this.GetOrdinaryLogFiles())
                this.SessionId := FormatTime(, "yyyyMMdd-HHmmss") "-" DllCall("GetCurrentProcessId") "-" A_TickCount
                this.CurrentFile := this.LogDirectory "\afa-" this.SessionId ".log"
                this.CriticalCurrentFile := this.LogDirectory "\critical-" this.SessionId ".log"
                this._EnsureFile(this.CurrentFile)
                this.CurrentFileBytes := FileGetSize(this.CurrentFile)
                this.CriticalCurrentFileBytes := 0
                this._RefreshLogMetrics()
                this._CleanupLogs()
                this.Info("Startup", "日志系统已初始化，日志目录=" this.LogDirectory)
            }
        } catch Error as e {
            this.FileAvailable := false
            this.CriticalFileAvailable := false
            OutputDebug("[Logger] 日志文件初始化失败：" e.Message)
        }

        OnError(ObjBindMethod(this, "HandleUnhandledError"))
    }

    static SetDebugEnabled(enabled) {
        this.DebugEnabled := !!enabled
        this.Debug("Logger", "DEBUG 持久化=" (this.DebugEnabled ? "enabled" : "disabled"))
    }

    static RegisterSecret(value) {
        if (value = "")
            return
        for secret in this.Secrets {
            if (secret = value)
                return
        }
        this.Secrets.Push(value)
    }

    static Debug(component, message) {
        this._Write("DEBUG", component, message, this.DebugEnabled)
    }

    static Info(component, message) {
        this._Write("INFO", component, message, true)
    }

    static Warn(component, message) {
        this._Write("WARN", component, message, true)
    }

    static Error(component, message) {
        this._Write("ERROR", component, message, true)
    }

    static Exception(component, error, context := "") {
        message := context != "" ? context ": " : ""
        try {
            message .= error.Message
        } catch {
            message .= "未知异常"
        }
        try message .= " | What=" error.What
        try message .= " | File=" error.File
        try message .= " | Line=" error.Line
        try message .= " | Stack=" error.Stack
        this.Error(component, message)
    }

    ; 全局未处理异常回调：返回 false，保留 AutoHotkey 原有错误处理。
    static HandleUnhandledError(error, mode := "") {
        if this.IsWriting
            return false
        try this.Exception("Unhandled", error, "未处理异常 mode=" mode)
        return false
    }

    static HandleExit(exitReason := "", exitCode := 0) {
        if this.Initialized
            this.Info("Shutdown", "程序退出 reason=" exitReason " code=" exitCode)
    }

    ; 兼容现有调用方和导出器的脱敏入口。
    static Redact(text, forExport := false) {
        text := "" text
        for secret in this.Secrets {
            if (secret != "")
                text := StrReplace(text, secret, "<REDACTED>")
        }

        ; 防御性遮盖常见 Authorization/Token 文本，即使调用方误传也不会落盘。
        text := RegExReplace(text, "i)(Authorization\s*[:=]\s*token\s+)[^\s,;]+", "$1<REDACTED>")
        text := RegExReplace(text, "i)(GitHubTokenProtected|GitHubToken)\s*[:=]\s*[^\s,;]+", "$1=<REDACTED>")

        if forExport {
            text := RegExReplace(text, "i)(Token验证成功，用户[:：]\s*)[^`r`n]+", "$1<REDACTED>")
            userProfile := EnvGet("USERPROFILE")
            tempDir := EnvGet("TEMP")
            if (userProfile != "")
                text := StrReplace(text, userProfile, "<USERPROFILE>")
            if (A_AppData != "")
                text := StrReplace(text, A_AppData, "<APPDATA>")
            if (tempDir != "")
                text := StrReplace(text, tempDir, "<TEMP>")
            computerName := EnvGet("COMPUTERNAME")
            if (computerName != "")
                text := StrReplace(text, computerName, "<COMPUTER>")
            userName := EnvGet("USERNAME")
            if (userName != "") {
                ; 用户名可能很短（如单字符 s），StrReplace 纯子串替换 + 默认大小写不敏感会误伤正常英文单词内部的字母。
                ; 改用边界感知正则替换：命中位置前后不允许是字母（Unicode \p{L}），且前面不能是 =（等号后的值可能是热键绑定键名，与用户名无关）。
                ; 由此同时避免误伤热键明细中的单字符绑定值（如 Freeze=s），只替换"独立出现"的用户名。
                ; \Q...\E 将用户名作为字面量匹配，避免用户名中的正则特殊字符被解释（Windows 用户名不含反斜杠，不会被截断）。
                text := RegExReplace(text, "i)(?<![=\p{L}])\Q" userName "\E(?!\p{L})", "<USER>")
            }
        }
        return text
    }

    static GetLogDirectory() {
        return this.LogDirectory
    }

    static GetLogFiles() {
        files := []
        if (this.LogDirectory = "" || !DirExist(this.LogDirectory))
            return files
        Loop Files, this.LogDirectory "\*.log", "F" {
            files.Push({
                path: A_LoopFileFullPath,
                name: A_LoopFileName,
                time: A_LoopFileTimeModified,
                size: A_LoopFileSize,
                critical: this._IsCriticalFile(A_LoopFileName)
            })
        }
        return files
    }

    static GetOrdinaryLogFiles() {
        files := []
        for file in this.GetLogFiles() {
            if !file.critical
                files.Push(file)
        }
        return files
    }

    static GetCriticalLogFiles() {
        files := []
        for file in this.GetLogFiles() {
            if file.critical
                files.Push(file)
        }
        return files
    }

    static GetRetentionSummary(files := "") {
        if IsObject(files) {
            ordinaryFiles := 0
            ordinaryBytes := 0
            criticalFiles := 0
            criticalBytes := 0
            for file in files {
                if file.critical {
                    criticalFiles += 1
                    criticalBytes += file.size
                } else {
                    ordinaryFiles += 1
                    ordinaryBytes += file.size
                }
            }
        } else {
            this._RefreshLogMetrics()
            ordinaryFiles := this.CachedOrdinaryFiles
            ordinaryBytes := this.CachedOrdinaryBytes
            criticalFiles := this.CachedCriticalFiles
            criticalBytes := this.CachedCriticalBytes
        }

        return {
            ordinaryFiles: ordinaryFiles,
            ordinaryBytes: ordinaryBytes,
            ordinaryBudgetBytes: this.MaxOrdinaryBytes,
            criticalFiles: criticalFiles,
            criticalBytes: criticalBytes,
            criticalBudgetBytes: this.MaxCriticalBytes,
            totalFiles: ordinaryFiles + criticalFiles,
            totalBytes: ordinaryBytes + criticalBytes,
            totalBudgetBytes: this.MaxBytes,
            ordinaryFileAvailable: this.FileAvailable,
            criticalFileAvailable: this.CriticalFileAvailable,
            previousAbnormalProtected: (this.PreviousAbnormalFile != "")
        }
    }

    ; 文件采用每次追加、立即关闭的方式；错误级别额外写入关键日志并带上最近上下文。
    static _Write(level, component, message, persist) {
        line := this._BuildLine(level, component, message)
        OutputDebug(line)
        if (!persist || this.IsWriting || (!this.FileAvailable && !this.CriticalFileAvailable))
            return

        if !this.MetricsInitialized
            this._RefreshLogMetrics()

        this.IsWriting := true
        try {
            if this.FileAvailable {
                try this._AppendOrdinaryLine(line)
                catch Error as e {
                    this.FileAvailable := false
                    OutputDebug("[Logger] 日志写入失败：" e.Message)
                }
            }

            if (level = "WARN" || level = "ERROR")
                this._AppendCriticalContext(line)

            this._RememberLine(line)
        } finally {
            this.IsWriting := false
        }

        this.WritesSinceCleanup += 1
        this._CleanupIfNeeded()
    }

    static _BuildLine(level, component, message) {
        safeMessage := this.Redact(message)
        safeMessage := StrReplace(safeMessage, "`r", " ")
        safeMessage := StrReplace(safeMessage, "`n", " ")
        line := this._Timestamp() " [" level "] [" component "] " safeMessage
        return this._LimitLine(line)
    }

    static _LimitLine(line) {
        marker := " ... [truncated]"
        if (StrLen(line) <= this.MaxLineCharacters)
            return line
        return SubStr(line, 1, this.MaxLineCharacters - StrLen(marker)) marker
    }

    static _RememberLine(line) {
        this.RecentLines.Push(line)
        while (this.RecentLines.Length > this.RecentLineLimit)
            this.RecentLines.RemoveAt(1)
    }

    static _AppendOrdinaryLine(line) {
        if (!this.FileAvailable || this.CurrentFile = "")
            return

        if !FileExist(this.CurrentFile) {
            this._EnsureFile(this.CurrentFile)
            this.CurrentFileBytes := FileGetSize(this.CurrentFile)
            this._RefreshLogMetrics()
        }
        if (this.CurrentFileBytes >= this.MaxOrdinarySegmentBytes
            && !this._RotateCurrentFile())
            throw Error("普通日志轮换失败")
        encodedBytes := this._GetUtf8Bytes(line "`n")
        previousBytes := this.CurrentFileBytes
        FileAppend(line "`n", this.CurrentFile, "UTF-8-RAW")
        this.CurrentFileBytes := previousBytes + encodedBytes
        this.CachedOrdinaryBytes += encodedBytes
        if (this.CurrentFileBytes > this.MaxOrdinarySegmentBytes
            && !this._RotateCurrentFile())
            throw Error("普通日志轮换失败")
    }

    static _AppendCriticalContext(line) {
        if (!this.CriticalFileAvailable || this.CriticalCurrentFile = "")
            return

        try {
            this._AppendCriticalLine("---- critical context begin ----")
            for contextLine in this.RecentLines
                this._AppendCriticalLine(contextLine)
            this._AppendCriticalLine(line)
            this._AppendCriticalLine("---- critical context end ----")
        } catch Error as e {
            this.CriticalFileAvailable := false
            OutputDebug("[Logger] 关键日志写入失败：" e.Message)
        }
    }

    static _AppendCriticalLine(line) {
        if (!this.CriticalFileAvailable || this.CriticalCurrentFile = "")
            return

        if !FileExist(this.CriticalCurrentFile) {
            this._EnsureFile(this.CriticalCurrentFile)
            this.CriticalCurrentFileBytes := FileGetSize(this.CriticalCurrentFile)
            this._RefreshLogMetrics()
        }
        if (this.CriticalCurrentFileBytes >= this.MaxCriticalSegmentBytes
            && !this._RotateCriticalFile())
            throw Error("关键日志轮换失败")
        encodedBytes := this._GetUtf8Bytes(line "`n")
        previousBytes := this.CriticalCurrentFileBytes
        FileAppend(line "`n", this.CriticalCurrentFile, "UTF-8-RAW")
        this.CriticalCurrentFileBytes := previousBytes + encodedBytes
        this.CachedCriticalBytes += encodedBytes
        if (this.CriticalCurrentFileBytes > this.MaxCriticalSegmentBytes
            && !this._RotateCriticalFile())
            throw Error("关键日志轮换失败")
    }

    static _Timestamp() {
        return FormatTime(, "yyyy-MM-dd HH:mm:ss.") A_MSec
    }

    static _GetUtf8Bytes(text) {
        return StrPut(text, "UTF-8") - 1
    }

    static _CleanupLogs() {
        try {
            this._CleanupExpiredLogs()
            this._CleanupOrdinaryLogs()
            this._CleanupCriticalLogs()
        } catch Error as e {
            ; 清理失败不影响主日志和 DebugView 降级路径。
            OutputDebug("[Logger] 日志清理失败：" e.Message)
        } finally {
            this._RefreshLogMetrics()
            this.CleanupPending := false
            this.WritesSinceCleanup := 0
        }
    }

    static _CleanupExpiredLogs() {
        cutoff := DateAdd(A_Now, -this.MaxAgeDays, "Days")
        ; 期限清理只处理普通历史日志；关键日志仅受自身容量和文件数预算约束。
        for file in this.GetOrdinaryLogFiles() {
            if this._IsProtectedPath(file.path)
                continue
            try {
                ; DateDiff 的结果为 DateTime1 - DateTime2；截止时间晚于文件时间才表示文件已过期。
                if (file.time != "" && DateDiff(cutoff, file.time, "Seconds") > 0)
                    FileDelete(file.path)
            }
        }
    }

    static _CleanupOrdinaryLogs() {
        loop {
            files := this.GetOrdinaryLogFiles()
            totalBytes := this._GetTotalBytes(files)
            if (files.Length <= this.MaxFiles && totalBytes <= this.MaxOrdinaryBytes)
                break

            oldest := this._FindOldest(files)
            if (oldest = "")
                break
            if !this._TryDelete(oldest)
                break
        }
    }

    static _CleanupCriticalLogs() {
        loop {
            files := this.GetCriticalLogFiles()
            totalBytes := this._GetTotalBytes(files)
            if (files.Length <= this.MaxCriticalFiles && totalBytes <= this.MaxCriticalBytes)
                break

            oldest := this._FindOldest(files)
            if (oldest = "") {
                ; 只有当前关键文件时，先轮换出可清理分片，再重新计算容量。
                if (totalBytes > this.MaxCriticalBytes && this._RotateCriticalFile())
                    continue
                break
            }
            if !this._TryDelete(oldest)
                break
        }
    }

    static _CleanupIfNeeded() {
        if !this.MetricsInitialized
            this._RefreshLogMetrics()

        cachedPressure := (this.CachedOrdinaryFiles > this.MaxFiles
            || this.CachedOrdinaryBytes > this.MaxOrdinaryBytes
            || this.CachedCriticalFiles > this.MaxCriticalFiles
            || this.CachedCriticalBytes > this.MaxCriticalBytes
            || (this.CachedOrdinaryBytes + this.CachedCriticalBytes) > this.MaxBytes)
        if (!this.CleanupPending && !cachedPressure && this.WritesSinceCleanup < this.CleanupWriteInterval)
            return

        try {
            if (this.WritesSinceCleanup >= this.CleanupWriteInterval)
                this._RefreshLogMetrics()
            cachedPressure := (this.CachedOrdinaryFiles > this.MaxFiles
                || this.CachedOrdinaryBytes > this.MaxOrdinaryBytes
                || this.CachedCriticalFiles > this.MaxCriticalFiles
                || this.CachedCriticalBytes > this.MaxCriticalBytes
                || (this.CachedOrdinaryBytes + this.CachedCriticalBytes) > this.MaxBytes)
            if cachedPressure
                this._CleanupLogs()
            else {
                this.CleanupPending := false
                this.WritesSinceCleanup := 0
            }
        }
    }

    static _RefreshLogMetrics() {
        ordinaryFiles := 0
        ordinaryBytes := 0
        criticalFiles := 0
        criticalBytes := 0
        for file in this.GetLogFiles() {
            if file.critical {
                criticalFiles += 1
                criticalBytes += file.size
            } else {
                ordinaryFiles += 1
                ordinaryBytes += file.size
            }
        }
        this.CachedOrdinaryFiles := ordinaryFiles
        this.CachedOrdinaryBytes := ordinaryBytes
        this.CachedCriticalFiles := criticalFiles
        this.CachedCriticalBytes := criticalBytes
        if (this.CurrentFile != "" && FileExist(this.CurrentFile))
            this.CurrentFileBytes := FileGetSize(this.CurrentFile)
        if (this.CriticalCurrentFile != "" && FileExist(this.CriticalCurrentFile))
            this.CriticalCurrentFileBytes := FileGetSize(this.CriticalCurrentFile)
        this.MetricsInitialized := true
    }

    ; 当前会话日志轮换出可清理分片，当前路径保持不变以便继续追加。
    static _RotateCurrentFile() {
        if (this.CurrentFile = "" || !FileExist(this.CurrentFile))
            return false

        currentPath := this.CurrentFile
        archivePath := currentPath ".part-" A_TickCount "-" Random(1000, 9999) ".log"
        try {
            FileMove(currentPath, archivePath, true)
            this.PreviousSegmentFile := archivePath
            this._EnsureFile(currentPath)
            this.CachedOrdinaryFiles += 1
            this.CurrentFileBytes := FileGetSize(currentPath)
            this.CleanupPending := true
            return true
        } catch {
            try {
                if (!FileExist(currentPath) && FileExist(archivePath))
                    FileMove(archivePath, currentPath, true)
            }
            return false
        }
    }

    static _RotateCriticalFile() {
        if (this.CriticalCurrentFile = "" || !FileExist(this.CriticalCurrentFile))
            return false

        currentPath := this.CriticalCurrentFile
        archivePath := currentPath ".part-" A_TickCount "-" Random(1000, 9999) ".log"
        try {
            FileMove(currentPath, archivePath, true)
            this._EnsureFile(currentPath)
            this.CachedCriticalFiles += 1
            this.CriticalCurrentFileBytes := FileGetSize(currentPath)
            this.CleanupPending := true
            return true
        } catch {
            try {
                if (!FileExist(currentPath) && FileExist(archivePath))
                    FileMove(archivePath, currentPath, true)
            }
            return false
        }
    }

    static _FindOldest(files) {
        oldest := ""
        oldestTime := ""
        for file in files {
            if this._IsProtectedPath(file.path)
                continue
            if (oldest = "" || StrCompare(file.time, oldestTime) < 0) {
                oldest := file.path
                oldestTime := file.time
            }
        }
        return oldest
    }

    static _FindPreviousAbnormalFile(files) {
        latest := ""
        for file in files {
            SplitPath(file.path, &fileName)
            if (file.size = 0 || file.size > this.MaxOrdinarySegmentBytes
                || !RegExMatch(fileName, "i)^afa-"))
                continue
            if (!IsObject(latest) || StrCompare(file.time, latest.time) > 0)
                latest := file
        }

        if (!IsObject(latest) || this._HasShutdownMarker(latest.path))
            return ""
        return latest.path
    }

    static _HasShutdownMarker(path) {
        try {
            content := FileRead(path, "UTF-8")
            if (StrLen(content) > 65536)
                content := SubStr(content, -65536)
            return InStr(content, "[Shutdown]") > 0
        } catch {
            ; 无法读取的上一会话按异常退出处理，优先保留。
            return false
        }
    }

    static _EnsureFile(path) {
        handle := FileOpen(path, "a")
        if !IsObject(handle)
            throw Error("无法打开日志文件：" path)
        handle.Close()
    }

    static _TryDelete(path) {
        try {
            FileDelete(path)
            return !FileExist(path)
        } catch Error as e {
            OutputDebug("[Logger] 删除旧日志失败：" e.Message)
            return false
        }
    }

    static _GetTotalBytes(files) {
        totalBytes := 0
        for file in files
            totalBytes += file.size
        return totalBytes
    }

    static _IsCriticalFile(pathOrName) {
        SplitPath(pathOrName, &fileName)
        return !!RegExMatch(fileName, "i)^critical-")
    }

    static _IsProtectedPath(path) {
        return (path = this.CurrentFile
            || path = this.CriticalCurrentFile
            || path = this.PreviousSegmentFile
            || path = this.PreviousAbnormalFile)
    }
}
