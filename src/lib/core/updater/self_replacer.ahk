; == 自替换器 ==
; 用于在程序退出后替换自身的exe文件
;
; #283（v1.9.3+）批处理改为双层结构，规避“cmd 内部 chcp 65001 重读同一文件导致中文行错位”：
; - update_replacer.bat（主脚本）：内容纯 ASCII（内嵌英文默认文案），chcp 后的重读不会错位；
; - update_replacer_text.bat（文案子脚本，仅 zh-Hans/zh-Hant 生成）：UTF-8 中文，由主脚本在
;   chcp 65001 生效后 call 从头读入，规避“同一文件 chcp 后重读”的触发条件（AGENTS.md 陷阱）。
; 等待逻辑改按精确 PID 匹配（不再按镜像名模糊匹配），10s 超时 + 5s 心跳：
; 失败日志可区分“仍在等待 / 已检测到退出 / 进入替换后失败”。

class SelfReplacer {
    ; 创建替换脚本并执行
    ; params: 包含以下字段的对象
    ; - newFilePath: 新exe文件的完整路径
    ; - currentExePath: 当前运行的exe路径（可选，默认A_ScriptFullPath）
    ; - backupOldVersion: 是否备份旧版本（可选，默认true）
    static ExecuteReplacement(params) {
        newFilePath := params.newFilePath
        currentExePath := params.HasProp("currentExePath") ? params.currentExePath : A_ScriptFullPath
        backupOldVersion := params.HasProp("backupOldVersion") ? params.backupOldVersion : true
        Logger.Info("SelfReplacer", "开始自替换：新文件=" newFilePath "，当前=" currentExePath "，备份旧版本=" (backupOldVersion ? "开" : "关"))

        ; 验证新文件存在
        if !FileExist(newFilePath) {
            Logger.Warn("SelfReplacer", "自替换验证失败：新文件不存在=" newFilePath)
            return {
                success: false,
                error: I18n.T("新文件不存在: {1}", newFilePath)
            }
        }

        ; 生成批处理脚本路径
        tempDir := A_Temp "\ArknightsFrameAssistant"
        if !DirExist(tempDir)
            DirCreate(tempDir)

        mainBatch := tempDir "\update_replacer.bat"
        textBatch := tempDir "\update_replacer_text.bat"

        ; 构建批处理脚本内容
        backupPath := ""
        backupName := ""
        if (backupOldVersion) {
            backupName := "AFA_" A_Now "_backup.exe"
            backupPath := tempDir "\" backupName
        }

        ; #283：嵌入精确 PID 与 ASCII 起始时间，批处理按 PID 等待退出
        currentPid := DllCall("GetCurrentProcessId", "UInt")
        startedAt := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        updateLogFile := Logger.GetLogDirectory() "\update-" A_Now "-" Random(1000, 9999) ".log"

        ; 扫描并收集所有残留的备份文件（供清理）
        oldBackups := []
        loop files tempDir "\AFA_*_backup.exe" {
            if (A_LoopFileFullPath != backupPath) {
                oldBackups.Push(A_LoopFileFullPath)
            }
        }

        ; 主脚本：纯 ASCII + 英文默认文案（始终写盘）
        mainContent := this._GenerateMainBatch({
            newFilePath: newFilePath,
            currentExePath: currentExePath,
            backupPath: backupPath,
            backupName: backupName,
            oldBackups: oldBackups,
            textBatch: textBatch,
            logDirectory: Logger.GetLogDirectory(),
            logFile: updateLogFile,
            currentPid: currentPid,
            startedAt: startedAt
        })

        ; 文案子脚本：仅 zh-Hans/zh-Hant 生成（UTF-8 中文）；ja-JP/ko-KR/en-US 用主脚本英文默认值
        textContent := this._GenerateTextBatch({
            backupName: backupName,
            oldBackups: oldBackups
        })

        ; 写入批处理文件（UTF-8；主脚本内容为纯 ASCII；子脚本仅 zh 生成）
        try {
            if !DirExist(tempDir)
                DirCreate(tempDir)
            if FileExist(mainBatch)
                FileDelete(mainBatch)
            FileAppend(mainContent, mainBatch, "`n UTF-8-RAW")
            ; 先清旧子脚本再决定是否写入，避免上次 zh 会话残留被子脚本缺失场景误用
            if FileExist(textBatch)
                FileDelete(textBatch)
            if (textContent != "")
                FileAppend(textContent, textBatch, "`n UTF-8-RAW")
        } catch Error as e {
            Logger.Error("SelfReplacer", "创建批处理脚本失败：" e.Message "（路径：" mainBatch "）")
            return {
                success: false,
                error: I18n.T("创建批处理脚本失败: {1} (路径: {2})", e.Message, mainBatch)
            }
        }

        ; #285：AFA 调试控制台由 AllocConsole 创建。若带着该控制台 Run cmd.exe，
        ; cmd 会附加到同一控制台，AFA 退出时的 [Shutdown] 日志会混入更新窗口。
        ; 先关闭控制台，让批处理自建独立控制台窗口。
        hadDebugConsole := Logger.ConsoleEnabled
        if (hadDebugConsole) {
            Logger.Info("SelfReplacer", "启动更新脚本前关闭调试控制台，避免退出日志混入更新窗口")
            Logger.CloseConsole()
        }

        ; 启动批处理脚本（可见窗口，用户可看到更新进度）
        try {
            Run mainBatch
        } catch Error as e {
            ; 启动失败时恢复调试控制台，避免用户丢失实时日志
            if (hadDebugConsole)
                Logger.SetConsoleEnabled(true)
            Logger.Error("SelfReplacer", "启动替换脚本失败：" e.Message)
            return {
                success: false,
                error: I18n.T("启动替换脚本失败: {1}", e.Message)
            }
        }

        ; 延迟后退出当前程序（给批处理时间启动）
        SetTimer(() => ExitApp(), -500)

        return {
            success: true,
            batchFile: mainBatch,
            backupPath: backupPath
        }
    }

    ; 生成主批处理脚本内容（纯 ASCII；中文文案一律由文案子脚本覆盖，子脚本缺失时用英文默认值）
    static _GenerateMainBatch(params) {
        newFilePath := params.newFilePath
        currentExePath := params.currentExePath
        backupPath := params.backupPath
        backupName := params.HasProp("backupName") ? params.backupName : ""
        oldBackups := params.HasProp("oldBackups") ? params.oldBackups : []
        textBatch := params.textBatch
        logDirectory := params.HasProp("logDirectory") ? params.logDirectory : (A_AppData "\ArknightsFrameAssistant\PC\logs")
        logFile := params.HasProp("logFile") ? params.logFile : (logDirectory "\update-" A_Now ".log")
        currentPid := params.currentPid
        startedAt := params.startedAt

        ; 英文默认文案（纯 ASCII；zh 由文案子脚本覆盖）
        msgs := this._BuildBatchMessages("en", backupName, oldBackups)

        ; 使用文本块方式构建批处理脚本
        lines := []
        lines.Push("@echo off")
        lines.Push("setlocal enabledelayedexpansion")
        lines.Push("chcp 65001 >nul")
        lines.Push("set `"START_TS=" startedAt "`"")

        ; 英文默认文案（zh-Hans/zh-Hant 由文案子脚本 call 覆盖）
        for name, value in msgs {
            lines.Push("set `"" name "=" value "`"")
        }

        ; 日志文件路径与目录
        lines.Push("set `"LOG_FILE=" logFile "`"")
        lines.Push("if not exist `"" logDirectory "`" mkdir `"" logDirectory "`"")

        ; 可选中文文案子脚本：chcp 65001 已生效，call 将从文件头按 UTF-8 读取，规避重读错位
        lines.Push("if exist `"" textBatch "`" call `"" textBatch "`"")

        lines.Push("title %MSG_TITLE%")
        lines.Push("echo [%START_TS%] %MSG_START% >> `"%LOG_FILE%`"")
        lines.Push("echo %MSG_WAITING% >> `"%LOG_FILE%`"")
        lines.Push("echo %MSG_WAITING%")

        ; 求饶彩蛋（仅 zh 子脚本定义 MSG_RITUAL 时显示；用延迟展开避免值中的括号破坏 if 块）
        lines.Push("if defined MSG_RITUAL (")
        lines.Push("    echo !MSG_RITUAL!")
        for pleadIndex in 1..5 {
            lines.Push("    echo !MSG_PLEAD" pleadIndex "!")
        }
        lines.Push("    echo.")
        lines.Push("    echo ================")
        lines.Push("    echo.")
        lines.Push(")")

        ; 等待循环：按精确 PID 判断 AFA 是否退出（不再按镜像名模糊匹配），10s 超时 + 5s 心跳
        lines.Push("set wait_count=0")
        lines.Push(":wait_loop")
        lines.Push("timeout /t 1 /nobreak >nul")
        lines.Push("`"%SystemRoot%\System32\tasklist.exe`" /fi `"PID eq " currentPid "`" /nh 2>nul | `"%SystemRoot%\System32\find.exe`" `"" currentPid "`" >nul")
        lines.Push("if errorlevel 1 goto process_exited")
        lines.Push("set /a wait_count+=1")
        lines.Push("if !wait_count! equ 5 echo [!time!] !MSG_WAITING! - PID " currentPid ", 5s >> `"%LOG_FILE%`"")
        lines.Push("if !wait_count! lss 10 goto wait_loop")
        lines.Push("echo [!time!] !MSG_TIMEOUT! >> `"%LOG_FILE%`"")
        lines.Push("echo !MSG_TIMEOUT!")
        lines.Push("goto continue_update")
        lines.Push(":process_exited")
        lines.Push("echo [!time!] !MSG_EXITED! - PID " currentPid " >> `"%LOG_FILE%`"")
        lines.Push("echo !MSG_EXITED!")

        ; 继续更新
        lines.Push(":continue_update")
        lines.Push("echo !MSG_REPLACING! >> `"%LOG_FILE%`"")
        lines.Push("echo !MSG_REPLACING!")
        lines.Push("set retry_count=0")
        lines.Push(":retry_loop")

        ; 备份原文件（如果启用了备份）
        if (backupPath != "") {
            lines.Push("if not exist `"" backupPath "`" (")
            lines.Push("    copy /Y `"" currentExePath "`" `"" backupPath "`" >nul 2>&1")
            lines.Push("    if errorlevel 1 (")
            lines.Push("        echo [!time!] !MSG_BACKUP_FAILED! >> `"%LOG_FILE%`"")
            lines.Push("    ) else (")
            lines.Push("        echo [!time!] !MSG_BACKUPED! >> `"%LOG_FILE%`"")
            lines.Push("    )")
            lines.Push(")")
        }

        ; 删除原文件
        lines.Push("del /F /Q `"" currentExePath "`" >nul 2>&1")
        lines.Push("set del_result=%errorlevel%")
        lines.Push("if %del_result% neq 0 (")
        lines.Push("    echo [!time!] !MSG_DEL_FAILED!!del_result!!MSG_DEL_FAILED_TAIL! >> `"%LOG_FILE%`"")
        lines.Push(") else (")
        lines.Push("    echo [!time!] !MSG_DELETED! >> `"%LOG_FILE%`"")
        lines.Push(")")

        ; 复制新文件
        lines.Push("copy /Y `"" newFilePath "`" `"" currentExePath "`" >nul 2>&1")
        lines.Push("set copy_result=%errorlevel%")
        lines.Push("if %copy_result% neq 0 (")
        lines.Push("    echo [!time!] !MSG_COPY_FAILED!!copy_result!!MSG_COPY_FAILED_TAIL! >> `"%LOG_FILE%`"")
        lines.Push(") else (")
        lines.Push("    echo [!time!] !MSG_COPIED! >> `"%LOG_FILE%`"")
        lines.Push(")")

        ; 检查替换是否成功：必须同时满足：原文件删除成功 AND 新文件复制成功 AND 文件存在
        lines.Push("if %del_result% equ 0 if %copy_result% equ 0 if exist `"" currentExePath "`" (")
        lines.Push("    echo [!time!] !MSG_SUCCESS! >> `"%LOG_FILE%`"")
        lines.Push("    if defined MSG_SUCCESS_RITUAL echo !MSG_SUCCESS_RITUAL!")
        lines.Push("    goto launch")
        lines.Push(")")
        lines.Push("echo [!time!] !MSG_EXIST_CHECK!: del_result=!del_result!, copy_result=!copy_result!, exist check failed >> `"%LOG_FILE%`"")

        ; 重试机制
        lines.Push("set /a retry_count+=1")
        lines.Push("if %retry_count% lss 5 (")
        lines.Push("    echo [!time!] !MSG_RETRY!!retry_count!!MSG_RETRY_TAIL! >> `"%LOG_FILE%`"")
        lines.Push("    timeout /t 2 /nobreak >nul")
        lines.Push("    goto retry_loop")
        lines.Push(")")

        ; 最终失败处理：提示与还原统一在 cleanup_failed 处理，避免重复提示
        lines.Push("goto cleanup_failed")

        ; 启动新版本
        lines.Push(":launch")
        lines.Push("echo [!time!] !MSG_LAUNCHING! >> `"%LOG_FILE%`"")
        lines.Push("echo !MSG_LAUNCHING!")
        lines.Push("start `"`" `"" currentExePath "`"")
        lines.Push("timeout /t 2 /nobreak >nul")
        lines.Push("echo [!time!] !MSG_STARTED! >> `"%LOG_FILE%`"")
        lines.Push("goto cleanup")

        ; 失败后的清理：先尝试用备份还原原文件，避免程序从原位置消失
        lines.Push(":cleanup_failed")
        lines.Push("echo [!time!] !MSG_FAILED! >> `"%LOG_FILE%`"")
        lines.Push("if defined MSG_FAILED_RITUAL echo !MSG_FAILED_RITUAL!")
        lines.Push("echo !MSG_RESTORE_FAILED!")
        if (backupPath != "") {
            lines.Push("if exist `"" backupPath "`" (")
            lines.Push("    copy /Y `"" backupPath "`" `"" currentExePath "`" >nul 2>&1")
            lines.Push("    if errorlevel 1 (")
            lines.Push("        echo [!time!] !MSG_RESTORE_FAILED! >> `"%LOG_FILE%`"")
            lines.Push("        echo !MSG_RESTORE_FAILED!")
            lines.Push("    ) else (")
            lines.Push("        echo [!time!] !MSG_RESTORED! >> `"%LOG_FILE%`"")
            lines.Push("        echo !MSG_RESTORED!")
            lines.Push("    )")
            lines.Push(")")
        }
        ; 提示用户失败的可能原因（指向新文件：下载的更新文件被删除/损坏，而非原文件）
        lines.Push("echo [!time!] !MSG_DOWNLOAD_HINT! >> `"%LOG_FILE%`"")
        lines.Push("echo !MSG_DOWNLOAD_HINT!")
        if (backupPath != "") {
            lines.Push("echo !MSG_BACKUP_PATH! `"" backupPath "`"")
        }
        lines.Push("echo !MSG_NEWFILE_PATH! `"" newFilePath "`"")
        ; 暂停让用户看到失败信息，按键后关闭窗口
        lines.Push("pause")
        ; 只删除两个批处理自身，保留其他所有文件
        lines.Push("if exist `"" textBatch "`" del /F /Q `"" textBatch "`" >nul 2>&1")
        lines.Push("del /F /Q `"%~f0`" >nul 2>&1")
        lines.Push("exit")

        ; 成功后的清理
        lines.Push(":cleanup")
        lines.Push("echo [!time!] !MSG_CLEANUP! >> `"%LOG_FILE%`"")
        lines.Push("echo !MSG_CLEANUP!")

        ; 先关闭日志文件句柄（通过复制到新日志然后切换）
        lines.Push("set final_log=%LOG_FILE%.final")
        lines.Push("copy /Y `"%LOG_FILE%`" `"%final_log%`" >nul 2>&1")

        ; 删除更新文件
        lines.Push("if exist `"" newFilePath "`" (")
        lines.Push("    del /F /Q `"" newFilePath "`" >nul 2>&1")
        lines.Push("    if exist `"" newFilePath "`" (")
        lines.Push("        echo [!time!] !MSG_CLEANUP_NEWFILE_FAILED! >> `"%final_log%`"")
        lines.Push("    ) else (")
        lines.Push("        echo [!time!] !MSG_NEWFILE_DELETED! >> `"%final_log%`"")
        lines.Push("    )")
        lines.Push(")")

        ; 清理备份文件（如果存在且不是用户手动备份的）
        if (backupPath != "") {
            lines.Push("if exist `"" backupPath "`" (")
            lines.Push("    del /F /Q `"" backupPath "`" >nul 2>&1")
            lines.Push("    if exist `"" backupPath "`" (")
            lines.Push("        echo [!time!] !MSG_CLEANUP_BACKUP_FAILED! >> `"%final_log%`"")
            lines.Push("    ) else (")
            lines.Push("        echo [!time!] !MSG_BACKUP_DELETED! >> `"%final_log%`"")
            lines.Push("    )")
            lines.Push(")")
        }

        ; 清理之前更新残留的备份文件
        for i, oldBackup in oldBackups {
            lines.Push("if exist `"" oldBackup "`" (")
            lines.Push("    del /F /Q `"" oldBackup "`" >nul 2>&1")
            lines.Push("    if not exist `"" oldBackup "`" (")
            lines.Push("        echo [!time!] !MSG_OLDBACKUP_DELETED_" i "! >> `"%final_log%`"")
            lines.Push("    )")
            lines.Push(")")
        }

        ; 删除原日志文件
        lines.Push("if exist `"%LOG_FILE%`" (")
        lines.Push("    del /F /Q `"%LOG_FILE%`" >nul 2>&1")
        lines.Push(")")

        ; 将最终日志内容移到原位置
        lines.Push("if exist `"%final_log%`" (")
        lines.Push("    move /Y `"%final_log%`" `"%LOG_FILE%`" >nul 2>&1")
        lines.Push(")")

        ; 尝试删除临时目录（如果为空）
        lines.Push("rmdir `"%Temp%\ArknightsFrameAssistant`" 2>nul")

        ; 完成日志与双批处理自删除
        lines.Push("echo [!time!] !MSG_DONE! >> `"%LOG_FILE%`"")
        lines.Push("if exist `"" textBatch "`" del /F /Q `"" textBatch "`" >nul 2>&1")
        lines.Push("del /F /Q `"%~f0`" >nul 2>&1")
        lines.Push("exit")

        ; 用换行符连接所有行
        script := ""
        for line in lines {
            script .= line "`n"
        }

        return script
    }

    ; 生成中文文案子脚本（仅 zh-Hans/zh-Hant；由主脚本在 chcp 65001 生效后 call，从头按 UTF-8 读取）
    static _GenerateTextBatch(params) {
        current := I18n.GetCurrent()
        if (current != "zh-Hans" && current != "zh-Hant")
            return ""

        backupName := params.HasProp("backupName") ? params.backupName : ""
        oldBackups := params.HasProp("oldBackups") ? params.oldBackups : []
        msgs := this._BuildBatchMessages("zh", backupName, oldBackups)

        ; 每行以 ASCII 双引号结尾，规避 chcp 重读时行尾多字节吞换行（AGENTS.md 陷阱）
        lines := []
        for name, value in msgs {
            lines.Push("set `"" name "=" value "`"")
        }

        ; zh 专属求饶彩蛋（主脚本以 if defined MSG_RITUAL 判断显示；其余语言不生成子脚本）
        lines.Push("set `"MSG_RITUAL=" I18n.T("(正在施展阿梅利亚神秘仪式)") "`"")
        lines.Push("set `"MSG_PLEAD1=求求你了360安全卫士放过我 求求你了360杀毒放过我 求求你了腾讯电脑管家放过我 求求你了火绒安全软件放过我...`"")
        lines.Push("set `"MSG_PLEAD2=求求你了金山毒霸放过我 求求你了瑞星杀毒软件放过我 求求你了联想电脑管家放过我 求求你了华为电脑管家放过我...`"")
        lines.Push("set `"MSG_PLEAD3=求求你了卡巴斯基放过我 求求你了ESETNOD32放过我 求求你了诺顿放过我 求求你了迈克菲放过我...`"")
        lines.Push("set `"MSG_PLEAD4=求求你了小红伞放过我 求求你了比特梵德放过我 求求你了AVG放过我 求求你了Avast放过我...`"")
        lines.Push("set `"MSG_PLEAD5=求求你了WindowsDefender放过我 求求你了Malwarebytes放过我...`"")
        lines.Push("set `"MSG_SUCCESS_RITUAL=" I18n.T("替换成功！阿梅利亚式祈祷是对的！") "`"")
        lines.Push("set `"MSG_FAILED_RITUAL=" I18n.T("！？不放过我？！") "`"")

        script := ""
        for line in lines {
            script .= line "`n"
        }
        return script
    }

    ; 构建批处理文案 Map（变量名 → 值）
    ; mode="zh"：经 I18n.T 取当前语言（生成文案子脚本用，仅 zh-Hans/zh-Hant）；
    ; mode="en"：英文默认值（主脚本内嵌，纯 ASCII；子脚本缺失/其它语言时生效）。
    static _BuildBatchMessages(mode, backupName, oldBackups) {
        zh := (mode = "zh")
        msgs := Map()
        msgs["MSG_TITLE"] := zh ? I18n.T("AFA更新中...") : "AFA Update"
        msgs["MSG_START"] := zh ? I18n.T("开始更新流程") : "Update process started"
        msgs["MSG_WAITING"] := zh ? I18n.T("正在等待程序关闭...") : "Waiting for AFA to exit..."
        msgs["MSG_EXITED"] := zh ? I18n.T("程序已关闭") : "AFA process has exited"
        msgs["MSG_TIMEOUT"] := zh ? I18n.T("等待超时，尝试继续...") : "Wait timeout, continuing anyway."
        msgs["MSG_REPLACING"] := zh ? I18n.T("正在替换文件...") : "Replacing files..."
        msgs["MSG_SUCCESS"] := zh ? I18n.T("替换成功！") : "Replacement successful"
        msgs["MSG_LAUNCHING"] := zh ? I18n.T("正在启动新版本...") : "Starting new version..."
        msgs["MSG_CLEANUP"] := zh ? I18n.T("正在清理临时文件...") : "Cleaning temporary files..."
        msgs["MSG_FAILED"] := zh ? I18n.T("替换失败，正在尝试自动还原原文件...") : "Replacement failed, attempting to restore..."
        msgs["MSG_DONE"] := zh ? I18n.T("更新流程结束") : "Update finished"
        msgs["MSG_BACKUP_FAILED"] := zh ? I18n.T("备份原文件失败") : "Backing up original file failed"
        ; 备份名在生成期已知，直接烘入值
        msgs["MSG_BACKUPED"] := zh ? I18n.T("原文件已备份为 {1}", backupName) : Format("Original file backed up as {1}", backupName)
        msgs["MSG_DELETED"] := zh ? I18n.T("原文件已删除") : "Original file deleted"
        msgs["MSG_COPIED"] := zh ? I18n.T("新文件复制成功") : "New file copied"
        msgs["MSG_STARTED"] := zh ? I18n.T("新版本已启动") : "New version has started"
        msgs["MSG_EXIST_CHECK"] := zh ? I18n.T("文件存在性检查") : "File existence check"
        msgs["MSG_RESTORE_FAILED"] := zh ? I18n.T("还原原文件失败，请手动从备份恢复") : "Restoring original file failed, please restore manually from backup"
        msgs["MSG_RESTORED"] := zh ? I18n.T("原文件已还原") : "Original file restored"
        msgs["MSG_DOWNLOAD_HINT"] := zh ? I18n.T("复制新文件失败：下载的更新文件可能已损坏或被安全软件删除，请检查后手动处理，或向开发者反馈此问题") : "Copy failed: the downloaded update file may be corrupted or deleted by antivirus software; please check it manually, or report this issue to the developer"
        msgs["MSG_BACKUP_PATH"] := zh ? I18n.T("备份文件位置:") : "Backup file location:"
        msgs["MSG_NEWFILE_PATH"] := zh ? I18n.T("新文件位置:") : "New file location:"
        msgs["MSG_NEWFILE_DELETED"] := zh ? I18n.T("更新文件已删除") : "Update file deleted"
        msgs["MSG_CLEANUP_NEWFILE_FAILED"] := zh ? I18n.T("清理更新文件失败（文件仍被占用）") : "Cleaning update file failed (file still in use)"
        msgs["MSG_BACKUP_DELETED"] := zh ? I18n.T("备份文件已删除") : "Backup file deleted"
        msgs["MSG_CLEANUP_BACKUP_FAILED"] := zh ? I18n.T("清理备份文件失败（文件仍被占用）") : "Cleaning backup file failed (file still in use)"

        ; 含运行时占位符的文案拆两段（错误码/重试次数），批处理运行时用 !var! 组合
        delFailed := this._SplitBatchText(zh,
            "删除原文件失败（错误码: %del_result%）", "%del_result%",
            "Delete original file failed (error code: %del_result%)")
        msgs["MSG_DEL_FAILED"] := delFailed[1]
        msgs["MSG_DEL_FAILED_TAIL"] := delFailed[2]
        copyFailed := this._SplitBatchText(zh,
            "复制新文件失败（错误码: %copy_result%）", "%copy_result%",
            "Copy new file failed (error code: %copy_result%)")
        msgs["MSG_COPY_FAILED"] := copyFailed[1]
        msgs["MSG_COPY_FAILED_TAIL"] := copyFailed[2]
        retryText := this._SplitBatchText(zh,
            "替换失败，第%retry_count%次重试...", "%retry_count%",
            "Replacement failed, retry %retry_count%...")
        msgs["MSG_RETRY"] := retryText[1]
        msgs["MSG_RETRY_TAIL"] := retryText[2]

        ; 旧备份路径在生成期已知，直接烘入值
        for i, oldBackup in oldBackups {
            msgs["MSG_OLDBACKUP_DELETED_" i] := zh
                ? I18n.T("清理旧备份文件 {1}", oldBackup)
                : Format("Cleaned old backup file {1}", oldBackup)
        }
        return msgs
    }

    ; 按运行时占位符拆分批处理文案（zh 用 I18n.T 结果 / en 用给定英文模板）
    ; 返回数组 [前半, 后半]（若占位符缺失则整体作为前半）
    static _SplitBatchText(zhMode, key, placeholder, enTemplate) {
        full := zhMode ? I18n.T(key) : enTemplate
        idx := InStr(full, placeholder)
        if (idx = 0)
            return [full, ""]
        return [
            SubStr(full, 1, idx - 1),
            SubStr(full, idx + StrLen(placeholder))
        ]
    }

    ; 检查是否存在待处理的更新
    static CheckPendingUpdate(version) {
        tempFile := UpdateDownloader.GetTempFilePath(version)
        if FileExist(tempFile) {
            return {
                exists: true,
                filePath: tempFile,
                version: version
            }
        }
        return {
            exists: false,
            filePath: "",
            version: version
        }
    }

    ; 清理所有更新相关的临时文件
    static CleanupAll() {
        tempDir := A_Temp "\ArknightsFrameAssistant"
        if DirExist(tempDir) {
            try {
                DirDelete(tempDir, true)
            } catch {
                try {
                    if FileExist(tempDir "\update_replacer.bat")
                        FileDelete(tempDir "\update_replacer.bat")
                    if FileExist(tempDir "\update_replacer_text.bat")
                        FileDelete(tempDir "\update_replacer_text.bat")
                }
            }
        }
    }
}
