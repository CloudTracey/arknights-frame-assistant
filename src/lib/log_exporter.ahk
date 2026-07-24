; == 日志压缩包导出 ==

class LogExporter {
    static CreateArchiveInteractive() {
        defaultName := A_Desktop "\AFA-Logs-" Version.Get() "-" FormatTime(, "yyyyMMdd-HHmmss") ".zip"
        target := FileSelect("S", defaultName, "生成日志压缩包", "ZIP 压缩包 (*.zip)")
        if (target = "")
            return {success: false, cancelled: true, path: "", message: "用户取消导出。"}

        result := this.CreateArchive(target)
        if (result.success)
            MessageBox.Info("日志压缩包已生成：`n" result.path, "导出成功")
        else
            MessageBox.Error(result.message, "导出失败")
        return result
    }

    static CreateArchive(targetPath) {
        Logger.Info("Diagnostics", "开始生成日志压缩包")
        if !RegExMatch(targetPath, "i)\.zip$")
            targetPath .= ".zip"

        staging := A_Temp "\ArknightsFrameAssistant\diagnostics-" FormatTime(, "yyyyMMdd-HHmmss") "-" Random(1000, 9999)
        tempZip := staging ".zip"
        result := {success: false, cancelled: false, path: targetPath, message: ""}

        try {
            DirCreate(staging "\logs")
            logFiles := Logger.GetLogFiles()
            retention := Logger.GetRetentionSummary(logFiles)
            for file in logFiles {
                SplitPath(file.path, &fileName)
                try {
                    content := FileRead(file.path, "UTF-8")
                    FileAppend(Logger.Redact(content, true), staging "\logs\" fileName, "UTF-8-RAW")
                } catch Error as e {
                    errorMessage := Logger.Redact(e.Message, true)
                    FileAppend("读取日志失败：" errorMessage "`n", staging "\logs\read-errors.txt", "UTF-8-RAW")
                }
            }

            FileAppend(this._BuildDiagnostics(retention), staging "\diagnostics.txt", "UTF-8-RAW")
            FileAppend(this._BuildSanitizedSettings(), staging "\settings-sanitized.ini", "UTF-8-RAW")

            psStage := this._PowerShellQuote(staging)
            psZip := this._PowerShellQuote(tempZip)
            psCode := "Add-Type -AssemblyName System.IO.Compression.FileSystem; [IO.Compression.ZipFile]::CreateFromDirectory(" psStage "," psZip ",[IO.Compression.CompressionLevel]::Optimal,$false)"
            command := "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command `"" psCode `""
            exitCode := RunWait(command, A_ScriptDir, "Hide")
            if (exitCode != 0 || !FileExist(tempZip)) {
                result.message := "压缩日志失败，PowerShell 返回码：" exitCode
                return result
            }

            FileMove(tempZip, targetPath, true)
            result.success := (FileExist(targetPath) != "")
            if (!result.success)
                result.message := "压缩包已生成但无法移动到目标位置。"
            else {
                SplitPath(targetPath, &targetName)
                Logger.Info("Diagnostics", "日志压缩包已生成：" targetName)
            }
        } catch Error as e {
            result.message := "生成日志压缩包失败：" e.Message
            Logger.Exception("Diagnostics", e, "压缩包导出失败")
        } finally {
            try {
                if DirExist(staging)
                    DirDelete(staging, true)
            }
            try {
                if FileExist(tempZip)
                    FileDelete(tempZip)
            }
        }
        return result
    }

    static OpenLogDirectory() {
        logDirectory := Logger.GetLogDirectory()
        try {
            if !DirExist(logDirectory)
                DirCreate(logDirectory)
            Run(logDirectory)
        } catch Error as e {
            Logger.Exception("Diagnostics", e, "打开日志目录失败")
            MessageBox.Error("无法打开日志目录：`n" e.Message, "打开失败")
        }
    }

    static _BuildDiagnostics(retention := "") {
        gamePath := Config.GetImportant("GamePath")
        lines := []
        lines.Push("AFA 诊断信息")
        lines.Push("Version=" Version.Get())
        lines.Push("AutoHotkey=" A_AhkVersion)
        lines.Push("OS=" A_OSVersion)
        lines.Push("OS64=" A_Is64bitOS)
        lines.Push("Compiled=" A_IsCompiled)
        lines.Push("Admin=" A_IsAdmin)
        lines.Push("StartedByGameAutoStart=" State.StartedByGameAutoStart)
        lines.Push("GamePathConfigured=" (gamePath != ""))
        lines.Push("GameFileExists=" ((gamePath != "" && FileExist(gamePath)) ? "true" : "false"))
        lines.Push("GameRunning=" (ProcessExist("Arknights.exe") ? "true" : "false"))
        lines.Push("GeneratedAt=" FormatTime(, "yyyy-MM-dd HH:mm:ss.") A_MSec)
        lines.Push("LogDirectoryAvailable=" (Logger.FileAvailable ? "true" : "false"))
        if !IsObject(retention)
            retention := Logger.GetRetentionSummary()
        lines.Push("LogOrdinaryFileAvailable=" (retention.ordinaryFileAvailable ? "true" : "false"))
        lines.Push("LogCriticalFileAvailable=" (retention.criticalFileAvailable ? "true" : "false"))
        lines.Push("LogOrdinaryFiles=" retention.ordinaryFiles)
        lines.Push("LogOrdinaryBytes=" retention.ordinaryBytes)
        lines.Push("LogOrdinaryBudgetBytes=" retention.ordinaryBudgetBytes)
        lines.Push("LogCriticalFiles=" retention.criticalFiles)
        lines.Push("LogCriticalBytes=" retention.criticalBytes)
        lines.Push("LogCriticalBudgetBytes=" retention.criticalBudgetBytes)
        lines.Push("LogTotalBytes=" retention.totalBytes)
        lines.Push("LogTotalBudgetBytes=" retention.totalBudgetBytes)
        lines.Push("LogPreviousAbnormalProtected=" (retention.previousAbnormalProtected ? "true" : "false"))
        return this._JoinLines(lines)
    }

    static _BuildSanitizedSettings() {
        lines := ["[Hotkeys]"]
        for key, value in Config.AllHotkeys
            lines.Push(key "=" value)
        lines.Push("")
        lines.Push("[Custom]")
        for key, value in Config.AllCustom
            lines.Push(key "=" value)
        lines.Push("")
        lines.Push("[Main]")
        safeKeys := ["AutoExit", "AutoOpenSettings", "ExitOnWindowClose", "Frame", "Frame155", "AutoUpdate", "LastDismissedVersion", "LastLaunchedVersion", "UpdateChannel", "UpdateSource", "UseGitHubToken", "AutoRunGame", "AutoStartWithGame", "DismissedChangelogVersion", "DefaultStrongHoldProtocol", "AutoBeginPause"]
        for key in safeKeys
            lines.Push(key "=" Config.GetImportant(key))
        lines.Push("GamePath=<redacted>")
        lines.Push("GitHubToken=<redacted>")
        lines.Push("GitHubTokenProtected=<redacted>")
        return this._JoinLines(lines)
    }

    static _JoinLines(lines) {
        result := ""
        for line in lines
            result .= line "`n"
        return result
    }

    static _PowerShellQuote(value) {
        return "'" StrReplace(value, "'", "''") "'"
    }
}
