; == 随游戏自动启动小助手 ==

class GameAutoStartManager {
    ; Windows 安全审核“进程创建”子类别 GUID
    static ProcessCreationAuditGuid := "{0CCE922B-69AE-11D9-BED3-505054503030}"
    static TaskNamePrefix := "ArknightsFrameAssistant-AutoStartWithGame-"

    ; 校验游戏路径
    static ValidateGamePath(gamePath) {
        gamePath := Trim(gamePath)
        if (gamePath = "")
            return {success: false, message: "请先设置明日方舟的游戏路径。"}

        normalizedPath := this._NormalizePath(gamePath)
        if (normalizedPath = "")
            return {success: false, message: "无法将游戏路径转换为完整路径：`n" gamePath}

        fileAttributes := FileExist(normalizedPath)
        if (!fileAttributes || InStr(fileAttributes, "D"))
            return {success: false, message: "游戏路径不存在或不是文件：`n" normalizedPath}

        normalizedPath := this._GetLongPath(normalizedPath)
        SplitPath(normalizedPath, &fileName)
        if (StrLower(fileName) != "arknights.exe")
            return {success: false, message: "游戏路径的文件名必须是 Arknights.exe：`n" normalizedPath}

        return {success: true, path: normalizedPath}
    }

    ; 转换为绝对路径，确保事件过滤器与 Windows 记录的完整进程路径一致
    static _NormalizePath(path) {
        requiredSize := DllCall("Kernel32\GetFullPathNameW", "Str", path, "UInt", 0, "Ptr", 0, "Ptr", 0, "UInt")
        if (requiredSize <= 0)
            return ""

        pathBuffer := Buffer(requiredSize * 2, 0)
        resultSize := DllCall("Kernel32\GetFullPathNameW", "Str", path, "UInt", requiredSize, "Ptr", pathBuffer, "Ptr", 0, "UInt")
        if (resultSize <= 0 || resultSize >= requiredSize)
            return ""
        return StrGet(pathBuffer, "UTF-16")
    }

    ; 展开 8.3 短路径并采用文件系统返回的名称形式，减少精确匹配差异
    static _GetLongPath(path) {
        requiredSize := DllCall("Kernel32\GetLongPathNameW", "Str", path, "Ptr", 0, "UInt", 0, "UInt")
        if (requiredSize <= 0)
            return path

        pathBuffer := Buffer(requiredSize * 2, 0)
        resultSize := DllCall("Kernel32\GetLongPathNameW", "Str", path, "Ptr", pathBuffer, "UInt", requiredSize, "UInt")
        if (resultSize <= 0 || resultSize >= requiredSize)
            return path
        return StrGet(pathBuffer, "UTF-16")
    }

    ; 根据设置应用外部自动启动状态
    static Apply(enabled, gamePath := "") {
        if (enabled) {
            validation := this.ValidateGamePath(gamePath)
            if (!validation.success)
                return validation
            return this.Enable(validation.path)
        }
        return this.Disable()
    }

    ; 启用审核并注册计划任务
    static Enable(gamePath) {
        auditResult := this.EnableProcessCreationAudit()
        if (!auditResult.success)
            return auditResult

        try {
            this.RegisterTask(gamePath)
            Logger.Info("GameAutoStart", "计划任务已注册：" gamePath)
            return {success: true, message: "随游戏自动启动已启用。"}
        } catch Error as e {
            Logger.Error("GameAutoStart", "计划任务注册失败：" e.Message)
            return {success: false, message: "计划任务注册失败：`n" e.Message}
        }
    }

    ; 删除计划任务。按方案保留 Windows 进程创建审核开启状态。
    static Disable() {
        try {
            service := ComObject("Schedule.Service")
            service.Connect()
            rootFolder := service.GetFolder("\")
            taskName := this.GetTaskName(this.GetCurrentUserSid())
            try {
                rootFolder.GetTask(taskName)
            } catch {
                return {success: true, message: "随游戏自动启动已关闭。"}
            }
            rootFolder.DeleteTask(taskName, 0)
            Logger.Info("GameAutoStart", "计划任务已删除")
            return {success: true, message: "随游戏自动启动已关闭。"}
        } catch Error as e {
            Logger.Error("GameAutoStart", "计划任务删除失败：" e.Message)
            return {success: false, message: "计划任务删除失败：`n" e.Message}
        }
    }

    ; 启动时校准审核和计划任务
    static Reconcile() {
        if (Config.GetImportant("AutoStartWithGame") = "1")
            return this.Enable(Config.GetImportant("GamePath"))
        return this.Disable()
    }

    ; 开启 Windows 进程创建成功审核。命令幂等，并保留失败审核设置。
    static EnableProcessCreationAudit() {
        auditPolPath := A_WinDir "\System32\auditpol.exe"
        if !FileExist(auditPolPath)
            return {success: false, message: "找不到 Windows 审核工具 auditpol.exe。"}

        command := '"' auditPolPath '" /set /subcategory:"' this.ProcessCreationAuditGuid '" /success:enable'
        try {
            exitCode := RunWait(command, A_ScriptDir, "Hide")
        } catch Error as e {
            return {success: false, message: "无法执行 Windows 进程审核设置：`n" e.Message}
        }

        if (exitCode != 0)
            return {success: false, message: "Windows 进程创建审核设置失败，错误码：" exitCode}
        return {success: true, message: "进程创建审核已启用。"}
    }

    ; 注册针对当前用户和指定游戏路径的进程创建事件任务
    static RegisterTask(gamePath) {
        userSid := this.GetCurrentUserSid()
        accountName := this.GetCurrentUserName()
        taskName := this.GetTaskName(userSid)

        service := ComObject("Schedule.Service")
        service.Connect()
        rootFolder := service.GetFolder("\")
        taskDefinition := service.NewTask(0)

        taskDefinition.RegistrationInfo.Author := "Arknights Frame Assistant"
        taskDefinition.RegistrationInfo.Description := "检测明日方舟启动并自动启动 Arknights Frame Assistant"

        settings := taskDefinition.Settings
        settings.Enabled := true
        settings.Hidden := true
        settings.AllowDemandStart := true
        settings.StartWhenAvailable := false
        settings.DisallowStartIfOnBatteries := false
        settings.StopIfGoingOnBatteries := false
        settings.MultipleInstances := 2
        settings.ExecutionTimeLimit := "PT0S"

        principal := taskDefinition.Principal
        ; 任务主体使用 SAM 兼容格式的账户名；SID 仅用于事件过滤和任务隔离。
        principal.UserId := accountName
        principal.LogonType := 3
        principal.RunLevel := 1

        trigger := taskDefinition.Triggers.Create(0)
        trigger.Enabled := true
        trigger.Subscription := this.BuildEventSubscription(gamePath, userSid)

        action := taskDefinition.Actions.Create(0)
        if (A_IsCompiled) {
            action.Path := A_ScriptFullPath
            action.Arguments := "--game-autostart"
        } else {
            action.Path := A_AhkPath
            action.Arguments := '"' A_ScriptFullPath '" --game-autostart'
        }
        action.WorkingDirectory := A_ScriptDir

        ; 6 = TASK_CREATE_OR_UPDATE，3 = TASK_LOGON_INTERACTIVE_TOKEN。
        ; 交互式令牌使用任务定义中的主体，不向注册接口传递用户名或密码。
        rootFolder.RegisterTaskDefinition(taskName, taskDefinition, 6, , , 3)
    }

    ; 为每个 Windows 用户生成独立的计划任务名称
    static GetTaskName(userSid) {
        return this.TaskNamePrefix userSid
    }

    ; 获取当前用户的 SAM 兼容账户名（例如 DOMAIN\User）
    static GetCurrentUserName() {
        nameFormat := 2 ; NameSamCompatible
        nameLength := 0
        DllCall("Secur32\GetUserNameExW", "Int", nameFormat, "Ptr", 0, "UInt*", &nameLength)
        if (nameLength <= 0)
            throw Error("无法读取当前用户账户名，错误码：" A_LastError)

        nameBuffer := Buffer(nameLength * 2, 0)
        if !DllCall("Secur32\GetUserNameExW", "Int", nameFormat, "Ptr", nameBuffer, "UInt*", &nameLength)
            throw Error("无法读取当前用户账户名，错误码：" A_LastError)
        return StrGet(nameBuffer, "UTF-16")
    }

    ; 生成安全日志事件订阅。使用完整路径和用户 SID，避免误触发。
    static BuildEventSubscription(gamePath, userSid) {
        escapedPath := this.EscapeXml(gamePath)
        escapedSid := this.EscapeXml(userSid)
        subscription := "<QueryList>"
        subscription .= "<Query Id='0' Path='Security'>"
        subscription .= "<Select Path='Security'>"
        subscription .= "*[System[Provider[@Name='Microsoft-Windows-Security-Auditing'] and EventID=4688]]"
        subscription .= " and *[EventData[Data[@Name='NewProcessName']=" Chr(34) escapedPath Chr(34)
        subscription .= " and Data[@Name='SubjectUserSid']=" Chr(34) escapedSid Chr(34) "]]"
        subscription .= "</Select></Query></QueryList>"
        return subscription
    }

    ; XML 文本转义。Windows 文件名不能包含双引号，因此 XPath 可使用双引号包裹路径。
    static EscapeXml(value) {
        value := StrReplace(value, "&", "&amp;")
        value := StrReplace(value, "<", "&lt;")
        value := StrReplace(value, ">", "&gt;")
        value := StrReplace(value, '"', "&quot;")
        return value
    }

    ; 获取当前登录用户 SID
    static GetCurrentUserSid() {
        tokenHandle := 0
        currentProcess := DllCall("GetCurrentProcess", "Ptr")
        if !DllCall("Advapi32\OpenProcessToken", "Ptr", currentProcess, "UInt", 0x0008, "Ptr*", &tokenHandle)
            throw Error("无法打开当前用户令牌，错误码：" A_LastError)

        try {
            requiredSize := 0
            DllCall("Advapi32\GetTokenInformation", "Ptr", tokenHandle, "Int", 1, "Ptr", 0, "UInt", 0, "UInt*", &requiredSize)
            if (requiredSize <= 0)
                throw Error("无法读取当前用户令牌大小，错误码：" A_LastError)

            tokenInfo := Buffer(requiredSize, 0)
            if !DllCall("Advapi32\GetTokenInformation", "Ptr", tokenHandle, "Int", 1, "Ptr", tokenInfo, "UInt", requiredSize, "UInt*", &requiredSize)
                throw Error("无法读取当前用户 SID，错误码：" A_LastError)

            sidPointer := NumGet(tokenInfo, 0, "Ptr")
            stringSidPointer := 0
            if !DllCall("Advapi32\ConvertSidToStringSidW", "Ptr", sidPointer, "Ptr*", &stringSidPointer)
                throw Error("无法转换当前用户 SID，错误码：" A_LastError)

            try {
                return StrGet(stringSidPointer)
            } finally {
                DllCall("Kernel32\LocalFree", "Ptr", stringSidPointer)
            }
        } finally {
            DllCall("Kernel32\CloseHandle", "Ptr", tokenHandle)
        }
    }
}
