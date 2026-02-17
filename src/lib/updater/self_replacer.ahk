; == 自替换器 ==
; 用于在程序退出后替换自身的exe文件

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
        
        ; 验证新文件存在
        if !FileExist(newFilePath) {
            return {
                success: false,
                error: "新文件不存在: " newFilePath
            }
        }

        ; 生成批处理脚本路径
        tempDir := A_Temp "\ArknightsFrameAssistant"
        if !DirExist(tempDir)
            DirCreate(tempDir)
        
        batchFile := tempDir "\update_replacer.bat"
        
        ; 构建批处理脚本内容
        backupPath := ""
        if (backupOldVersion) {
            backupName := "AFA_" A_Now "_backup.exe"
            backupPath := tempDir "\" backupName
        }
        
        ; 扫描并收集所有残留的备份文件（供清理）
        oldBackups := []
        loop files tempDir "\AFA_*_backup.exe" {
            if (A_LoopFileFullPath != backupPath) {
                oldBackups.Push(A_LoopFileFullPath)
            }
        }
        
        ; 创建批处理脚本
        batchContent := this._GenerateBatchScript({
            newFilePath: newFilePath,
            currentExePath: currentExePath,
            backupPath: backupPath,
            batchFile: batchFile,
            oldBackups: oldBackups
        })
        
        ; 写入批处理文件（使用UTF-8编码）
        try {
            ; 确保目录存在
            batchDir := tempDir
            if !DirExist(batchDir)
                DirCreate(batchDir)
            ; 如果存在旧文件先删除
            if FileExist(batchFile)
                FileDelete(batchFile)
            FileAppend(batchContent, batchFile, "`n UTF-8-RAW")
            ; FileAppend(batchContent, "E:\AFA\src\update_replacer.bat", "`n UTF-8-RAW")
        } catch Error as e {
            return {
                success: false,
                error: "创建批处理脚本失败: " e.Message " (路径: " batchFile ")"
            }
        }
        
        ; 启动批处理脚本（隐藏窗口）
        try {
            Run batchFile,, "Hide"
        } catch Error as e {
            return {
                success: false,
                error: "启动替换脚本失败: " e.Message
            }
        }
        
        ; 发布替换已启动事件
        EventBus.Publish("SelfReplacementStarted", {
            newFilePath: newFilePath,
            currentExePath: currentExePath,
            backupPath: backupPath
        })
        
        ; 延迟后退出当前程序（给批处理时间启动）
        SetTimer(() => ExitApp(), -500)
        
        return {
            success: true,
            batchFile: batchFile,
            backupPath: backupPath
        }
    }
    
    ; 生成批处理脚本内容
    static _GenerateBatchScript(params) {
        newFilePath := params.newFilePath
        currentExePath := params.currentExePath
        backupPath := params.backupPath
        batchFile := params.batchFile
        oldBackups := params.HasProp("oldBackups") ? params.oldBackups : []
        
        ; 使用文本块方式构建批处理脚本
        lines := []
        lines.Push("@echo off")
        lines.Push("setlocal enabledelayedexpansion")
        lines.Push("chcp 65001 >nul")
        lines.Push("title AFA更新中...")
        ; 设置日志文件路径
        lines.Push("set `"LOG_FILE=%Temp%\ArknightsFrameAssistant\log\update.log`"")
        ; 创建日志目录（如果不存在）
        lines.Push("if not exist `"%Temp%\ArknightsFrameAssistant\log`" mkdir `"%Temp%\ArknightsFrameAssistant\log`"")
        
        ; 获取当前exe文件名
        SplitPath(currentExePath, &currentExeName)
        
        ; 初始化日志，记录开始时间
        lines.Push("echo [%date% %time%] 开始更新流程 >> `"%LOG_FILE%`"")
        lines.Push("echo 正在等待程序关闭... >> `"%LOG_FILE%`"")
        lines.Push("echo 正在等待程序关闭...")
        
        ; 等待循环：检测进程是否退出
        lines.Push("set wait_count=0")
        lines.Push(":wait_loop")
        lines.Push("timeout /t 1 /nobreak >nul")
        lines.Push("tasklist /fi `"imagename eq " currentExeName "`" 2>nul | find /i `"" currentExeName "`" >nul")
        lines.Push("if not errorlevel 1 (")
        lines.Push("    set /a wait_count+=1")
        lines.Push("    if !wait_count! geq 30 (")
        lines.Push("        echo [%date% %time%] 等待超时（30秒），继续尝试替换 >> `"%LOG_FILE%`"")
        lines.Push("        echo 等待超时，尝试继续...")
        lines.Push("        goto continue_update")
        lines.Push("    )")
        lines.Push("    goto wait_loop")
        lines.Push(")")
        lines.Push("echo [%date% %time%] 程序已关闭 >> `"%LOG_FILE%`"")
        lines.Push("echo 程序已关闭")
        
        ; 继续更新
        lines.Push(":continue_update")
        lines.Push("echo 正在替换文件... >> `"%LOG_FILE%`"")
        lines.Push("echo 正在替换文件...")
        lines.Push("set retry_count=0")
        lines.Push(":retry_loop")
        
        ; 备份原文件（如果启用了备份）
        if (backupPath != "") {
            SplitPath(backupPath, &backupName)
            lines.Push("if not exist `"" backupPath "`" (")
            lines.Push("    copy /Y `"" currentExePath "`" `"" backupPath "`" >nul 2>&1")
            lines.Push("    if errorlevel 1 (")
            lines.Push("        echo [%date% %time%] 备份原文件失败 >> `"%LOG_FILE%`"")
            lines.Push("    ) else (")
            lines.Push("        echo [%date% %time%] 原文件已备份为 " backupName " >> `"%LOG_FILE%`"")
            lines.Push("    )")
            lines.Push(")")
        }
        
        ; 删除原文件
        lines.Push("del /F /Q `"" currentExePath "`" >nul 2>&1")
        lines.Push("set del_result=%errorlevel%")
        lines.Push("if %del_result% neq 0 (")
        lines.Push("    echo [%date% %time%] 删除原文件失败（错误码: %del_result%） >> `"%LOG_FILE%`"")
        lines.Push(") else (")
        lines.Push("    echo [%date% %time%] 原文件已删除 >> `"%LOG_FILE%`"")
        lines.Push(")")
        
        ; 复制新文件
        lines.Push("copy /Y `"" newFilePath "`" `"" currentExePath "`" >nul 2>&1")
        lines.Push("set copy_result=%errorlevel%")
        lines.Push("if %copy_result% neq 0 (")
        lines.Push("    echo [%date% %time%] 复制新文件失败（错误码: %copy_result%） >> `"%LOG_FILE%`"")
        lines.Push(") else (")
        lines.Push("    echo [%date% %time%] 新文件复制成功 >> `"%LOG_FILE%`"")
        lines.Push(")")
        
        ; 检查替换是否成功：必须同时满足：原文件删除成功 AND 新文件复制成功 AND 文件存在
        lines.Push("if %del_result% equ 0 if %copy_result% equ 0 if exist `"" currentExePath "`" (")
        lines.Push("    echo [%date% %time%] 替换成功！ >> `"%LOG_FILE%`"")
        lines.Push("    echo 替换成功！")
        lines.Push("    goto launch")
        lines.Push(")")
        lines.Push("echo [%date% %time%] 文件存在性检查: del_result=%del_result%, copy_result=%copy_result%, exist check failed >> `"%LOG_FILE%`"")
        
        ; 重试机制
        lines.Push("set /a retry_count+=1")
        lines.Push("if %retry_count% lss 5 (")
        lines.Push("    echo [%date% %time%] 替换失败，第%retry_count%次重试... >> `"%LOG_FILE%`"")
        lines.Push("    timeout /t 2 /nobreak >nul")
        lines.Push("    goto retry_loop")
        lines.Push(")")
        
        ; 最终失败处理
        lines.Push("echo [%date% %time%] 替换失败，请手动替换文件 >> `"%LOG_FILE%`"")
        lines.Push("echo 替换失败，请手动替换文件")
        lines.Push("echo 新文件位置: " newFilePath)
        if (backupPath != "") {
            lines.Push("echo 备份文件位置: " backupPath)
        }
        lines.Push("pause")
        lines.Push("goto cleanup_failed")
        
        ; 启动新版本
        lines.Push(":launch")
        lines.Push("echo 正在启动新版本... >> `"%LOG_FILE%`"")
        lines.Push("echo 正在启动新版本...")
        lines.Push("start `"`" `"" currentExePath "`"")
        lines.Push("timeout /t 2 /nobreak >nul")
        lines.Push("echo [%date% %time%] 新版本已启动 >> `"%LOG_FILE%`"")
        lines.Push("goto cleanup")
        
        ; 失败后的清理（保留备份和更新文件供用户手动处理）
        lines.Push(":cleanup_failed")
        lines.Push("echo [%date% %time%] 更新失败，保留备份和更新文件供手动恢复 >> `"%LOG_FILE%`"")
        lines.Push("echo 更新失败，保留备份和更新文件供手动恢复")
        ; 只删除批处理自身，保留其他所有文件
        lines.Push("(goto) 2>nul & del `"" batchFile "`" >nul 2>&1")
        lines.Push("exit")
        
        ; 成功后的清理
        lines.Push(":cleanup")
        lines.Push("echo [%date% %time%] 开始清理临时文件... >> `"%LOG_FILE%`"")
        lines.Push("echo 正在清理临时文件...")
        
        ; 先关闭日志文件句柄（通过复制到新日志然后切换）
        lines.Push("set final_log=%Temp%\ArknightsFrameAssistant\log\update_final.log")
        lines.Push("copy /Y `"%LOG_FILE%`" `"%final_log%`" >nul 2>&1")
        
        ; 删除更新文件
        lines.Push("if exist `"" newFilePath "`" (")
        lines.Push("    del /F /Q `"" newFilePath "`" >nul 2>&1")
        lines.Push("    if exist `"" newFilePath "`" (")
        lines.Push("        echo [%date% %time%] 清理更新文件失败（文件仍被占用） >> `"%final_log%`"")
        lines.Push("    ) else (")
        lines.Push("        echo [%date% %time%] 更新文件已删除 >> `"%final_log%`"")
        lines.Push("    )")
        lines.Push(")")
        
        ; 清理备份文件（如果存在且不是用户手动备份的）
        if (backupPath != "") {
            lines.Push("if exist `"" backupPath "`" (")
            lines.Push("    del /F /Q `"" backupPath "`" >nul 2>&1")
            lines.Push("    if exist `"" backupPath "`" (")
            lines.Push("        echo [%date% %time%] 清理备份文件失败（文件仍被占用） >> `"%final_log%`"")
            lines.Push("    ) else (")
            lines.Push("        echo [%date% %time%] 备份文件已删除 >> `"%final_log%`"")
            lines.Push("    )")
            lines.Push(")")
        }
        
        ; 清理之前更新残留的备份文件
        for oldBackup in oldBackups {
            lines.Push("if exist `"" oldBackup "`" (")
            lines.Push("    del /F /Q `"" oldBackup "`" >nul 2>&1")
            lines.Push("    if not exist `"" oldBackup "`" (")
            lines.Push("        echo [%date% %time%] 清理旧备份文件 " oldBackup " >> `"%final_log%`"")
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
        
        ; 尝试删除日志目录（现在应该为空了）
        lines.Push("rmdir `"%Temp%\ArknightsFrameAssistant\log`" 2>nul")
        ; 尝试删除临时目录（如果为空）
        lines.Push("rmdir `"%Temp%\ArknightsFrameAssistant`" 2>nul")
        
        ; 删除批处理文件自身（使用批处理经典自删除方法）
        lines.Push("echo [%date% %time%] 更新流程结束 >> `"%LOG_FILE%`"")
        lines.Push("(goto) 2>nul & del `"" batchFile "`" >nul 2>&1")
        lines.Push("exit")
        
        ; 用换行符连接所有行
        script := ""
        for line in lines {
            script .= line "`n"
        }
        
        return script
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
                    FileDelete(tempDir "\update_replacer.bat")
                }
            }
        }
    }
}
