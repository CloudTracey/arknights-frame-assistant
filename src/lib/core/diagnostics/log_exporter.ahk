; == 日志压缩包导出 ==

class LogExporter {
    ; 订阅客户端集合变化，保持诊断信息所需缓存/日志最新（计划 2.6 事件契约）
    static Init() {
        EventBus.Subscribe("GameClientsChanged", (data) => this._HandleGameClientsChanged(data))
    }

    static _HandleGameClientsChanged(data) {
        Logger.Debug("Diagnostics", "游戏客户端集合变化，数量=" data.clients.Length)
    }

    static CreateArchiveInteractive() {
        defaultName := A_Desktop "\AFA-Logs-" Version.Get() "-" FormatTime(, "yyyyMMdd-HHmmss") ".zip"
        target := FileSelect("S", defaultName, I18n.T("log.createArchive"), "ZIP 压缩包 (*.zip)")
        if (target = "")
            return {success: false, cancelled: true, path: "", message: I18n.T("log.userCancelled")}

        result := this.CreateArchive(target)
        if (result.success)
            MessageBox.Info(I18n.T("msg.logArchiveCreated", result.path), I18n.T("msg.logArchiveCreatedTitle"))
        else
            MessageBox.Error(result.message, I18n.T("msg.logExportFailedTitle"))
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
            command := "powershell.exe -NoProfile -NonInteractive -Command `"" psCode "`""
            exitCode := RunWait(command, A_ScriptDir, "Hide")
            if (exitCode != 0 || !FileExist(tempZip)) {
                result.message := I18n.T("log.psFailed", exitCode)
                return result
            }

            FileMove(tempZip, targetPath, true)
            result.success := (FileExist(targetPath) != "")
            if (!result.success)
                result.message := I18n.T("log.moveFailed")
            else {
                SplitPath(targetPath, &targetName)
                Logger.Info("Diagnostics", "日志压缩包已生成：" targetName)
            }
        } catch Error as e {
            result.message := I18n.T("log.archiveFailed", e.Message)
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
            MessageBox.Error(I18n.T("msg.logOpenFailed", e.Message), I18n.T("msg.logOpenFailedTitle"))
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
        lines.Push("StartedByGameAutoStart=" AppContext.GetStartedByGameAutoStart())
        lines.Push("GamePathConfigured=" (gamePath != ""))
        lines.Push("GameFileExists=" ((gamePath != "" && FileExist(gamePath)) ? "true" : "false"))
        clients := GameClientRegistry.GetClients()
        lines.Push("GameRunning=" ((GameClientRegistry.HasClients() || GameTarget.ProcessExists()) ? "true" : "false"))
        lines.Push("ClientCount=" clients.Length)
        for i, client in clients
            lines.Push("Client" i "=" client.pid "|" client.hwnd "|" client.serverId "|" client.exePath)
        foreground := GameClientRegistry.GetForegroundClient()
        lines.Push("ForegroundClient=" (foreground = "" ? "" : foreground.pid "|" foreground.serverId))
        for serverId in ServerProfile.Ids()
            lines.Push("RegistryRoot" serverId "=" ServerProfile.RegistryRoot(serverId))
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
        gamePath := Config.GetImportant("GamePath")
        lines := ["[Hotkeys]"]
        for key, value in Config.AllHotkeys
            lines.Push(key "=" value)
        lines.Push("")
        lines.Push("[Custom]")
        for key, value in Config.AllCustom
            lines.Push(key "=" value)
        lines.Push("")
        lines.Push("[Main]")
        safeKeys := ["AutoExit", "AutoOpenSettings", "ExitOnWindowClose", "Frame", "Frame155", "AutoUpdate", "LastDismissedVersion", "LastLaunchedVersion", "UpdateChannel", "UpdateSource", "UseGitHubToken", "AutoRunGame", "AutoStartWithGame", "DismissedChangelogVersion", "DefaultStrongHoldProtocol", "AutoBeginPause", "DebugEnabled"]
        for key in safeKeys
            lines.Push(key "=" Config.GetImportant(key))
        lines.Push("GamePath=" gamePath)
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
