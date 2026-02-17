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
        
        ; 创建批处理脚本
        batchContent := this._GenerateBatchScript({
            newFilePath: newFilePath,
            currentExePath: currentExePath,
            backupPath: backupPath,
            batchFile: batchFile
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
        lines.Push("if errorlevel 1 (")
        lines.Push("    echo [%date% %time%] 删除原文件失败 >> `"%LOG_FILE%`"")
        lines.Push(") else (")
        lines.Push("    echo [%date% %time%] 原文件已删除 >> `"%LOG_FILE%`"")
        lines.Push(")")
        
        ; 复制新文件
        lines.Push("copy /Y `"" newFilePath "`" `"" currentExePath "`" >nul 2>&1")
        lines.Push("if errorlevel 1 (")
        lines.Push("    echo [%date% %time%] 复制新文件失败 >> `"%LOG_FILE%`"")
        lines.Push(") else (")
        lines.Push("    echo [%date% %time%] 新文件复制成功 >> `"%LOG_FILE%`"")
        lines.Push(")")
        
        ; 检查替换是否成功
        lines.Push("if exist `"" currentExePath "`" (")
        lines.Push("    echo [%date% %time%] 替换成功！ >> `"%LOG_FILE%`"")
        lines.Push("    echo 替换成功！")
        lines.Push("    goto launch")
        lines.Push(")")
        
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
        lines.Push("pause")
        lines.Push("goto cleanup")
        
        ; 启动新版本
        lines.Push(":launch")
        lines.Push("echo 正在启动新版本... >> `"%LOG_FILE%`"")
        lines.Push("echo 正在启动新版本...")
        lines.Push("start `"`" `"" currentExePath "`"")
        lines.Push("timeout /t 2 /nobreak >nul")
        lines.Push("echo [%date% %time%] 新版本已启动 >> `"%LOG_FILE%`"")
        
        ; 清理
        lines.Push(":cleanup")
        lines.Push("del /F /Q `"" batchFile "`" >nul 2>&1")
        lines.Push("if errorlevel 1 (")
        lines.Push("    echo [%date% %time%] 清理临时脚本失败 >> `"%LOG_FILE%`"")
        lines.Push(") else (")
        lines.Push("    echo [%date% %time%] 临时脚本已删除 >> `"%LOG_FILE%`"")
        lines.Push(")")
        lines.Push("del /F /Q `"" newFilePath "`" >nul 2>&1")
        lines.Push("if errorlevel 1 (")
        lines.Push("    echo [%date% %time%] 清理更新文件失败 >> `"%LOG_FILE%`"")
        lines.Push(") else (")
        lines.Push("    echo [%date% %time%] 更新文件已删除 >> `"%LOG_FILE%`"")
        lines.Push(")")
        lines.Push("echo [%date% %time%] 更新流程结束 >> `"%LOG_FILE%`"")
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
