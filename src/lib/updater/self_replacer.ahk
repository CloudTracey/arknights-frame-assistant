; == 自替换器 ==
; 用于在程序退出后替换自身的exe文件

class SelfReplacer {
    ; 创建替换脚本并执行
    ; params: 包含以下字段的对象
    ;   - newFilePath: 新exe文件的完整路径
    ;   - currentExePath: 当前运行的exe路径（可选，默认A_ScriptFullPath）
    ;   - backupOldVersion: 是否备份旧版本（可选，默认true）
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
            FileDelete(batchFile)
            FileAppend(batchContent, batchFile, "UTF-8")
        } catch Error as e {
            return {
                success: false,
                error: "创建批处理脚本失败: " e.Message
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
        
        ; 使用Format避免引号转义问题
        script := "@echo off" "`n"
        script .= "chcp 65001 >nul" "`n"
        script .= "title 方舟帧操助手更新中..." "`n"
        script .= "echo 正在等待程序关闭..." "`n"
        
        ; 等待原程序退出
        script .= ":wait_loop" "`n"
        script .= "timeout /t 1 /nobreak >nul" "`n"
        script .= "(call ) 2>nul || goto wait_loop" "`n"
        
        ; 尝试替换文件
        script .= "echo 正在替换文件..." "`n"
        script .= "set retry_count=0" "`n"
        script .= ":retry_loop" "`n"
        
        ; 如果开启了备份，先备份旧版本
        if (backupPath != "") {
            script .= Format('if not exist "{1}" (', backupPath) "`n"
            script .= Format('  copy /Y "{1}" "{2}" >nul 2>&1', currentExePath, backupPath) "`n"
            script .= ")" "`n"
        }
        
        ; 删除旧文件并复制新文件
        script .= Format('del /F /Q "{1}" >nul 2>&1', currentExePath) "`n"
        script .= Format('copy /Y "{1}" "{2}" >nul 2>&1', newFilePath, currentExePath) "`n"
        
        ; 检查是否成功
        script .= Format('if exist "{1}" (', currentExePath) "`n"
        script .= "  echo 替换成功！" "`n"
        script .= "  goto launch" "`n"
        script .= ")" "`n"
        
        ; 重试逻辑
        script .= "set /a retry_count+=1" "`n"
        script .= "if %retry_count% lss 5 (" "`n"
        script .= "  timeout /t 2 /nobreak >nul" "`n"
        script .= "  goto retry_loop" "`n"
        script .= ")" "`n"
        
        ; 重试失败
        script .= "echo 替换失败，请手动替换文件" "`n"
        script .= "echo 新文件位置: " newFilePath "`n"
        script .= "pause" "`n"
        script .= "goto cleanup" "`n"
        
        ; 启动新程序
        script .= ":launch" "`n"
        script .= "echo 正在启动新版本..." "`n"
        script .= Format('start "" "{1}"', currentExePath) "`n"
        script .= "timeout /t 2 /nobreak >nul" "`n"
        
        ; 清理
        script .= ":cleanup" "`n"
        script .= Format('del /F /Q "{1}" >nul 2>&1', batchFile) "`n"
        script .= Format('del /F /Q "{1}" >nul 2>&1', newFilePath) "`n"
        script .= "exit" "`n"
        
        return script
    }
    
    ; 检查是否存在待处理的更新（上次下载但未替换）
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
    
    ; 清理所有更新相关的临时文件（包括备份）
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
