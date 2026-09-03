; == 随游戏自动启动AFA ==

class GameAutoStartManager {
    ; Windows 安全审核“进程创建”子类别 GUID
    static ProcessCreationAuditGuid := "{0CCE922B-69AE-11D9-BED3-505054503030}"
    static TaskNamePrefix := "ArknightsFrameAssistant-AutoStartWithGame-"
    ; SYSTEM 账户 SID：启动器/游戏服务可能在系统上下文拉起游戏进程，
    ; 4688 事件的 SubjectUserSid 会是 S-1-5-18，仅匹配用户 SID 会导致事件过滤器永不命中
    static SystemSid := "S-1-5-18"
    static ERROR_ACCESS_DENIED := 5
    static ERROR_NOT_ALL_ASSIGNED := 1300
    static ERROR_PRIVILEGE_NOT_HELD := 1314
    static ERROR_NO_SYSTEM_RESOURCES := 1450
    static POLICY_AUDIT_EVENT_SUCCESS := 0x1
    static AUDIT_RETRY_DELAYS := [250, 750]

    ; 校验游戏路径
    static ValidateGamePath(gamePath) {
        gamePath := Trim(gamePath)
        if (gamePath = "")
            return {success: false, message: I18n.T("请先设置明日方舟的游戏路径。")}

        normalizedPath := this._NormalizePath(gamePath)
        if (normalizedPath = "")
            return {success: false, message: I18n.T("无法将游戏路径转换为完整路径：`n{1}", gamePath)}

        fileAttributes := FileExist(normalizedPath)
        if (!fileAttributes || InStr(fileAttributes, "D"))
            return {success: false, message: I18n.T("游戏路径不存在或不是文件：`n{1}", normalizedPath)}

        normalizedPath := this._GetLongPath(normalizedPath)
        SplitPath(normalizedPath, &fileName)
        if (StrLower(fileName) != "arknights.exe")
            return {success: false, message: I18n.T("游戏路径的文件名必须是 Arknights.exe：`n{1}", normalizedPath)}

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

    ; 解析 reparse point（junction/符号链接）到文件系统的最终目标路径。
    ; 返回真实安装路径的盘符形式（win32 路径）；dwFlags=2 时返回 NT 设备路径形式
    ; GetFullPathNameW/GetLongPathNameW 都不解析 reparse point，而 Security 4688 的
    ; NewProcessName 记录的是内核解析后的路径。配置路径带 junction 前缀或与真实路径
    ; 存在大小写/短名差异时，精确匹配会永远失败。失败返回 ""，由调用方回退到配置路径变体。
    static _ResolveFinalPath(path, dwFlags := 0) {
        if (path = "")
            return ""
        ; FILE_READ_ATTRIBUTES(0x80) + 共享读写删(0x7) + OPEN_EXISTING(3)
        ; 不带 FILE_FLAG_OPEN_REPARSE_POINT：GetFinalPathNameByHandle 返回最终目标路径
        handle := DllCall("Kernel32\CreateFileW", "WStr", path, "UInt", 0x80, "UInt", 0x7,
            "Ptr", 0, "UInt", 3, "UInt", 0, "Ptr", 0, "Ptr")
        if (handle = -1)
            return ""
        try {
            ; dwFlags=0 => FILE_NAME_NORMALIZED | VOLUME_NAME_DOS
            ; dwFlags=2 => FILE_NAME_NORMALIZED | VOLUME_NAME_NT
            required := DllCall("Kernel32\GetFinalPathNameByHandleW", "Ptr", handle, "Ptr", 0, "UInt", 0, "UInt", dwFlags, "UInt")
            if (required <= 0)
                return ""
            pathBuffer := Buffer((required + 1) * 2, 0)
            resultSize := DllCall("Kernel32\GetFinalPathNameByHandleW", "Ptr", handle,
                "Ptr", pathBuffer, "UInt", required + 1, "UInt", dwFlags, "UInt")
            if (resultSize = 0 || resultSize > required)
                return ""
            resolved := StrGet(pathBuffer, "UTF-16")
            ; 去掉 VOLUME_NAME_DOS 产生的 \\?\ 前缀（NT 形式无此前缀，不匹配则原样返回）
            if RegExMatch(resolved, "^\\\\\?\\", &m)
                resolved := SubStr(resolved, m.Len[0] + 1)
            return resolved
        } finally {
            DllCall("Kernel32\CloseHandle", "Ptr", handle)
        }
    }

    ; 根据设置应用外部自动启动状态。gamePath 可为单个路径或路径数组。
    static Apply(enabled, gamePath := "") {
        if (enabled) {
            paths := this._AsPathArray(gamePath)
            if (paths.Length = 0)
                return {success: false, message: I18n.T("请先设置明日方舟的游戏路径。")}
            validated := []
            for path in paths {
                validation := this.ValidateGamePath(path)
                if (!validation.success)
                    return validation
                validated.Push(validation.path)
            }
            return this.Enable(validated)
        }
        return this.Disable()
    }

    ; 获取当前配置的全部游戏路径（GamePath + 各区服 GamePath*），用于随游戏自启
    static GetConfiguredGamePaths() {
        result := []
        seen := Map()
        candidates := [Config.GetImportant("GamePath")]
        for serverId in ServerProfile.Ids()
            candidates.Push(Config.GetImportant("GamePath" serverId))
        for path in candidates {
            if (path = "")
                continue
            norm := this._NormalizePath(path)
            if (norm != "" && !seen.Has(StrLower(norm))) {
                seen[StrLower(norm)] := true
                result.Push(this._GetLongPath(norm))
            }
        }
        return result
    }

    static _AsPathArray(gamePath) {
        if (IsObject(gamePath))
            return gamePath
        if (gamePath = "")
            return []
        return [gamePath]
    }

    ; 启用审核并注册计划任务。gamePaths 可为单个路径或路径数组。
    static Enable(gamePaths) {
        paths := this._AsPathArray(gamePaths)
        if (paths.Length = 0)
            return {success: false, message: I18n.T("请先设置明日方舟的游戏路径。")}
        auditResult := this.EnableProcessCreationAudit()
        if (!auditResult.success)
            return auditResult

        try {
            taskResult := this.EnsureTask(paths)
            return this._Result(true, {
                message: I18n.T("随游戏自动启动已启用。"),
                skipped: auditResult.skipped && taskResult.skipped,
                auditChanged: auditResult.auditChanged,
                taskChanged: taskResult.taskChanged,
                attempts: auditResult.attempts
            })
        } catch Error as e {
            Logger.Error("GameAutoStart", "计划任务注册失败：" e.Message)
            return this._Result(false, {stage: "task_ensure", reason: "task_ensure_failed",
                message: I18n.T("计划任务注册失败：`n{1}", e.Message)})
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
            } catch Error as e {
                errorCode := this._GetWin32ErrorCode(e)
                if (errorCode = 2 || errorCode = 3)
                    return this._Result(true, {message: I18n.T("随游戏自动启动已关闭。"), skipped: true})
                throw e
            }
            rootFolder.DeleteTask(taskName, 0)
            Logger.Info("GameAutoStart", "计划任务已删除")
            return this._Result(true, {message: I18n.T("随游戏自动启动已关闭。"), taskChanged: true})
        } catch Error as e {
            Logger.Error("GameAutoStart", "计划任务删除失败：" e.Message)
            return this._Result(false, {stage: "task_delete", reason: "task_delete_failed",
                message: I18n.T("计划任务删除失败：`n{1}", e.Message)})
        }
    }

    ; 启动时校准审核和计划任务
    static Reconcile() {
        enabled := (Config.GetImportant("AutoStartWithGame") = "1")
        if (AppContext.GetStartedByGameAutoStart()) {
            if (enabled) {
                Logger.Info("GameAutoStart", "触发启动已跳过审核与计划任务校准")
                return this._Result(true, {message: I18n.T("触发启动无需校准。"), skipped: true})
            }
            result := this.Disable()
            result.shouldExit := true
            return result
        }
        if (enabled)
            return this.Enable(this.GetConfiguredGamePaths())
        return this.Disable()
    }

    ; 开启 Windows 进程创建成功审核。仅 1450 进行两次短退避重试。
    static EnableProcessCreationAudit() {
        startedAt := A_TickCount
        Loop this.AUDIT_RETRY_DELAYS.Length + 1 {
            attempt := A_Index
            result := this._RunAuditTransaction()
            result.attempts := attempt
            result.elapsedMs := A_TickCount - startedAt
            Logger.Info("GameAutoStart", "审核校准 stage=" result.stage " attempt=" attempt
                " success=" result.success " code=" result.errorCode " changed=" result.auditChanged
                " elapsedMs=" result.elapsedMs)
            if (result.success || result.errorCode != this.ERROR_NO_SYSTEM_RESOURCES)
                return result
            if (attempt <= this.AUDIT_RETRY_DELAYS.Length)
                Sleep(this.AUDIT_RETRY_DELAYS[attempt])
        }
        return result
    }

    ; 在一个短事务内启用权限、查询/按需设置审核，并恢复令牌原状态。
    static _RunAuditTransaction() {
        privilegeResult := this._EnableSecurityAuditPrivilege()
        if (!privilegeResult.success)
            return privilegeResult

        try {
            subCategoryGuid := Buffer(16, 0)
            parseResult := DllCall(
                "Ole32\CLSIDFromString",
                "WStr", this.ProcessCreationAuditGuid,
                "Ptr", subCategoryGuid,
                "Int"
            )
            if (parseResult != 0)
                return this._AuditError("audit_guid_invalid", I18n.T("无法解析 Windows 进程创建审核标识"), parseResult)

            queryResult := this._QueryAuditPolicy(subCategoryGuid)
            if (!queryResult.success)
                return queryResult
            if (queryResult.flags & this.POLICY_AUDIT_EVENT_SUCCESS)
                return this._Result(true, {stage: "audit_query", reason: "already_enabled",
                    skipped: true, message: I18n.T("进程创建审核已启用。")})

            ; AUDIT_POLICY_INFORMATION = SubCategoryGuid(16) + AuditingInformation(4) + CategoryGuid(16)
            policyInfo := Buffer(36, 0)
            Loop 16
                NumPut("UChar", NumGet(subCategoryGuid, A_Index - 1, "UChar"), policyInfo, A_Index - 1)
            NumPut("UInt", queryResult.flags | this.POLICY_AUDIT_EVENT_SUCCESS, policyInfo, 16)

            A_LastError := 0
            setSucceeded := DllCall(
                "Advapi32\AuditSetSystemPolicy",
                "Ptr", policyInfo,
                "UInt", 1,
                "Int"
            )
            setError := A_LastError
            if (!setSucceeded)
                return this._AuditError("audit_set_failed", I18n.T("Windows 进程创建审核设置失败"), setError)

            verifyResult := this._QueryAuditPolicy(subCategoryGuid, "audit_verify")
            if (!verifyResult.success)
                return verifyResult
            if !(verifyResult.flags & this.POLICY_AUDIT_EVENT_SUCCESS)
                return this._AuditError("audit_verify_mismatch", I18n.T("Windows 进程创建审核设置未生效"), 0)
            return this._Result(true, {stage: "audit_verify", reason: "enabled",
                auditChanged: true, message: I18n.T("进程创建审核已启用。")})
        } finally {
            this._RestoreSecurityAuditPrivilege(privilegeResult)
        }
    }

    static _QueryAuditPolicy(subCategoryGuid, stage := "audit_query") {
        policyPointer := 0
        A_LastError := 0
        querySucceeded := DllCall(
            "Advapi32\AuditQuerySystemPolicy",
            "Ptr", subCategoryGuid,
            "UInt", 1,
            "Ptr*", &policyPointer,
            "Int"
        )
        queryError := A_LastError
        if (!querySucceeded)
            return this._AuditError(stage "_failed", I18n.T("无法读取 Windows 进程创建审核状态"), queryError, stage)
        try
            return this._Result(true, {stage: stage, reason: "queried", flags: NumGet(policyPointer, 16, "UInt")})
        finally {
            if (policyPointer)
                DllCall("Advapi32\AuditFree", "Ptr", policyPointer)
        }
    }

    ; 为当前管理员令牌显式启用“管理审核和安全日志”用户权利。
    static _EnableSecurityAuditPrivilege() {
        tokenHandle := 0
        keepHandle := false
        currentProcess := DllCall("Kernel32\GetCurrentProcess", "Ptr")
        desiredAccess := 0x0008 | 0x0020 ; TOKEN_QUERY | TOKEN_ADJUST_PRIVILEGES
        if !DllCall(
            "Advapi32\OpenProcessToken",
            "Ptr", currentProcess,
            "UInt", desiredAccess,
            "Ptr*", &tokenHandle,
            "Int"
        )
            return this._AuditError("token_open_failed", I18n.T("无法打开当前进程令牌"), A_LastError)

        try {
            privilegeLuid := Buffer(8, 0)
            if !DllCall(
                "Advapi32\LookupPrivilegeValueW",
                "Ptr", 0,
                "WStr", "SeSecurityPrivilege",
                "Ptr", privilegeLuid,
                "Int"
            )
                return this._AuditError("privilege_lookup_failed", I18n.T("无法查找 Windows 审核权限"), A_LastError)

            tokenPrivileges := Buffer(16, 0)
            previousState := Buffer(16, 0)
            returnLength := 0
            NumPut("UInt", 1, tokenPrivileges, 0)
            NumPut("Int64", NumGet(privilegeLuid, 0, "Int64"), tokenPrivileges, 4)
            NumPut("UInt", 0x00000002, tokenPrivileges, 12) ; SE_PRIVILEGE_ENABLED

            A_LastError := 0
            adjusted := DllCall(
                "Advapi32\AdjustTokenPrivileges",
                "Ptr", tokenHandle,
                "Int", false,
                "Ptr", tokenPrivileges,
                "UInt", previousState.Size,
                "Ptr", previousState,
                "UInt*", &returnLength,
                "Int"
            )
            adjustError := A_LastError
            if (!adjusted)
                return this._AuditError("privilege_enable_failed", I18n.T("无法启用 Windows 审核权限"), adjustError)
            if (adjustError = this.ERROR_NOT_ALL_ASSIGNED)
                return this._AuditError("privilege_not_assigned", I18n.T("当前 Windows 账户未被授予审核权限"), adjustError)

            keepHandle := true
            return this._Result(true, {stage: "privilege_enable", reason: "enabled",
                tokenHandle: tokenHandle, previousState: previousState, message: I18n.T("Windows 审核权限已启用。")})
        } finally {
            if (!keepHandle && tokenHandle)
                DllCall("Kernel32\CloseHandle", "Ptr", tokenHandle)
        }
    }

    static _RestoreSecurityAuditPrivilege(privilegeResult) {
        if (!privilegeResult.HasProp("tokenHandle") || !privilegeResult.tokenHandle)
            return
        try {
            if (privilegeResult.HasProp("previousState")) {
                A_LastError := 0
                restored := DllCall("Advapi32\AdjustTokenPrivileges",
                    "Ptr", privilegeResult.tokenHandle, "Int", false,
                    "Ptr", privilegeResult.previousState, "UInt", 0,
                    "Ptr", 0, "Ptr", 0, "Int")
                if (!restored)
                    Logger.Warn("GameAutoStart", "恢复 Windows 审核权限状态失败 code=" A_LastError)
            }
        } finally {
            DllCall("Kernel32\CloseHandle", "Ptr", privilegeResult.tokenHandle)
        }
    }

    static _AuditError(reason, action, errorCode, stage := "") {
        if (errorCode = this.ERROR_ACCESS_DENIED
            || errorCode = this.ERROR_NOT_ALL_ASSIGNED
            || errorCode = this.ERROR_PRIVILEGE_NOT_HELD) {
            message := action "。`n"
            message .= I18n.T("当前账户缺少“管理审核和安全日志”(SeSecurityPrivilege) 用户权利。`n请由系统管理员检查本地或域组策略，重新登录 Windows 后再试。`n错误码：{1}", errorCode)

            return this._Result(false, {stage: stage != "" ? stage : reason,
                reason: reason, errorCode: errorCode, message: message})
        }

        detail := errorCode ? OSError(errorCode).Message : I18n.T("未知 Windows 错误")
        message := action "。`n" detail
        return this._Result(false, {stage: stage != "" ? stage : reason,
            reason: reason, errorCode: errorCode, message: message})
    }

    ; 计划任务语义一致时不重写；仅缺失或关键字段漂移时更新。gamePaths 为路径数组。
    static EnsureTask(gamePaths) {
        paths := this._AsPathArray(gamePaths)
        if (paths.Length = 0)
            return this._Result(false, {message: I18n.T("请先设置至少一个游戏路径。"), reason: "empty_paths"})
        userSid := this.GetCurrentUserSid()
        accountName := this.GetCurrentUserName()
        taskName := this.GetTaskName(userSid)

        service := ComObject("Schedule.Service")
        service.Connect()
        rootFolder := service.GetFolder("\")
        desiredTask := this._BuildTaskDefinition(service, paths, userSid, accountName)
        try {
            existingTask := rootFolder.GetTask(taskName)
            if (this._IsTaskEquivalent(existingTask.Definition, desiredTask, userSid)) {
                Logger.Info("GameAutoStart", "计划任务已匹配，跳过重写")
                return this._Result(true, {stage: "task_compare", reason: "already_current",
                    skipped: true, message: I18n.T("计划任务已是最新状态。")})
            }
        } catch Error as e {
            errorCode := this._GetWin32ErrorCode(e)
            if (errorCode != 2 && errorCode != 3)
                throw e
        }
        rootFolder.RegisterTaskDefinition(taskName, desiredTask, 6, , , 3)
        pathSummary := ""
        for p in paths
            pathSummary .= (pathSummary = "" ? "" : " | ") p
        Logger.Info("GameAutoStart", "计划任务已创建或更新：" pathSummary)
        return this._Result(true, {stage: "task_register", reason: "created_or_updated",
            taskChanged: true, message: I18n.T("计划任务已创建或更新。")})
    }

    static RegisterTask(gamePaths) => this.EnsureTask(gamePaths)

    static _BuildTaskDefinition(service, gamePaths, userSid, accountName) {
        paths := this._AsPathArray(gamePaths)
        taskDefinition := service.NewTask(0)

        taskDefinition.RegistrationInfo.Author := "AFA"
        taskDefinition.RegistrationInfo.Description := I18n.T("检测明日方舟启动并自动启动 AFA")

        settings := taskDefinition.Settings
        settings.Enabled := true
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
        trigger.Subscription := this.BuildEventSubscription(paths, userSid)

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
        return taskDefinition
    }

    static _IsTaskEquivalent(existing, desired, userSid := "") {
        try {
            if (existing.Settings.Enabled != desired.Settings.Enabled
                || existing.Settings.AllowDemandStart != desired.Settings.AllowDemandStart
                || existing.Settings.StartWhenAvailable != desired.Settings.StartWhenAvailable
                || existing.Settings.DisallowStartIfOnBatteries != desired.Settings.DisallowStartIfOnBatteries
                || existing.Settings.StopIfGoingOnBatteries != desired.Settings.StopIfGoingOnBatteries
                || existing.Settings.MultipleInstances != desired.Settings.MultipleInstances
                || existing.Settings.ExecutionTimeLimit != desired.Settings.ExecutionTimeLimit)
                return this._TaskMismatch("settings")
            existingPrincipalId := StrLower(existing.Principal.UserId)
            desiredPrincipalId := StrLower(desired.Principal.UserId)
            expectedSid := StrLower(userSid)
            if !this._IsSamePrincipalUserId(existingPrincipalId, desiredPrincipalId, expectedSid)
                return this._TaskMismatch("principal_user")
            if (existing.Principal.LogonType != desired.Principal.LogonType)
                return this._TaskMismatch("principal_logon_type")
            if (existing.Principal.RunLevel != desired.Principal.RunLevel)
                return this._TaskMismatch("principal_run_level")
            if (existing.Triggers.Count != 1 || existing.Actions.Count != 1)
                return this._TaskMismatch("collection_count")
            existingTrigger := existing.Triggers.Item(1)
            desiredTrigger := desired.Triggers.Item(1)
            if (existingTrigger.Type != desiredTrigger.Type
                || existingTrigger.Enabled != desiredTrigger.Enabled
                || existingTrigger.Subscription != desiredTrigger.Subscription)
                return this._TaskMismatch("trigger")
            existingAction := existing.Actions.Item(1)
            desiredAction := desired.Actions.Item(1)
            equivalent := existingAction.Type = desiredAction.Type
                && StrLower(existingAction.Path) = StrLower(desiredAction.Path)
                && Trim(existingAction.Arguments) = Trim(desiredAction.Arguments)
                && StrLower(existingAction.WorkingDirectory) = StrLower(desiredAction.WorkingDirectory)
            return equivalent ? true : this._TaskMismatch("action")
        } catch Error as e {
            Logger.Warn("GameAutoStart", "读取现有计划任务字段失败，将执行修复：" e.Message)
            return false
        }
    }

    static _TaskMismatch(field) {
        Logger.Info("GameAutoStart", "计划任务字段漂移：" field)
        return false
    }

    static _IsSamePrincipalUserId(existingId, desiredId, expectedSid) {
        if (existingId = desiredId || existingId = expectedSid)
            return true
        resolvedSid := this._ResolveAccountSid(existingId)
        return (resolvedSid != "" && StrLower(resolvedSid) = expectedSid)
    }

    ; Task Scheduler 读取任务时可能把 DOMAIN\User 规范化为 User；统一解析到 SID 后比较。
    static _ResolveAccountSid(accountName) {
        if (accountName = "")
            return ""
        if RegExMatch(accountName, "i)^S-1-")
            return accountName

        sidSize := 0
        domainSize := 0
        sidUse := 0
        DllCall("Advapi32\LookupAccountNameW",
            "Ptr", 0, "WStr", accountName, "Ptr", 0, "UInt*", &sidSize,
            "Ptr", 0, "UInt*", &domainSize, "UInt*", &sidUse, "Int")
        if (sidSize <= 0)
            return ""

        sidBuffer := Buffer(sidSize, 0)
        domainBuffer := Buffer(Max(domainSize, 1) * 2, 0)
        if !DllCall("Advapi32\LookupAccountNameW",
            "Ptr", 0, "WStr", accountName, "Ptr", sidBuffer, "UInt*", &sidSize,
            "Ptr", domainBuffer, "UInt*", &domainSize, "UInt*", &sidUse, "Int")
            return ""

        stringSidPointer := 0
        if !DllCall("Advapi32\ConvertSidToStringSidW", "Ptr", sidBuffer, "Ptr*", &stringSidPointer)
            return ""
        try return StrGet(stringSidPointer)
        finally DllCall("Kernel32\LocalFree", "Ptr", stringSidPointer)
    }

    static _Result(success, overrides := 0) {
        result := {success: success, degraded: false, skipped: false,
            auditChanged: false, taskChanged: false, stage: "", reason: "",
            errorCode: 0, attempts: 1, elapsedMs: 0, message: ""}
        if IsObject(overrides) {
            for name, value in overrides.OwnProps()
                result.%name% := value
        }
        return result
    }

    ; Task Scheduler COM 错误通常是普通 Error，错误码只出现在 Message 的 HRESULT 中。
    static _GetWin32ErrorCode(error) {
        if (error.HasProp("Number"))
            return error.Number & 0xFFFF
        if RegExMatch(error.Message, "i)\(0x([0-9a-f]{8})\)", &match) {
            try return Integer("0x" match[1]) & 0xFFFF
        }
        return 0
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
            throw Error(I18n.T("无法读取当前用户账户名，错误码：{1}", A_LastError))

        nameBuffer := Buffer(nameLength * 2, 0)
        if !DllCall("Secur32\GetUserNameExW", "Int", nameFormat, "Ptr", nameBuffer, "UInt*", &nameLength)
            throw Error(I18n.T("无法读取当前用户账户名，错误码：{1}", A_LastError))
        return StrGet(nameBuffer, "UTF-16")
    }

    ; 生成安全日志事件订阅。使用一个或多个完整路径和用户 SID，避免误触发。
    ; 多个路径在同一个 Select 内用 or 连接，保持单 trigger（Triggers.Count == 1）。
    ; 三个加固点：
    ;   1. 路径同时注册「配置路径」「盘符形式真实路径」「NT 设备路径」三个变体：
    ;      GetFullPathNameW/GetLongPathNameW 不解析 reparse point（junction/符号链接），
    ;      而 Security 4688 的 NewProcessName 记录的是内核解析后的路径；部分环境（如
    ;      提权启动器拉起游戏）记录的是 NT 设备路径而非
    ;      盘符路径，两种形式的精确匹配都会永久失配。
    ;   2. SubjectUserSid 同时匹配当前用户与 SYSTEM（S-1-5-18）：Hypergryph Launcher
    ;      可能由系统上下文服务拉起游戏进程，此时事件里的 SubjectUserSid 是 SYSTEM，
    ;      仅匹配用户 SID 会导致事件过滤器永不命中。
    static BuildEventSubscription(gamePaths, userSid) {
        paths := this._AsPathArray(gamePaths)
        if (paths.Length = 0)
            return ""
        escapedUserSid := this.EscapeXml(userSid)
        escapedSystemSid := this.EscapeXml(this.SystemSid)
        pathConditions := []
        for gamePath in paths {
            ; 配置路径 + 盘符真实路径 + NT 设备路径三个变体（按原样去重；大小写差异保留为独立变体以覆盖事件记录差异）
            variants := Map()
            variants[gamePath] := true
            canonicalPath := this._ResolveFinalPath(gamePath, 0)
            if (canonicalPath != "" && !variants.Has(canonicalPath))
                variants[canonicalPath] := true
            ntPath := this._ResolveFinalPath(gamePath, 2)
            if (ntPath != "" && !variants.Has(ntPath))
                variants[ntPath] := true
            for variant in variants {
                escapedPath := this.EscapeXml(variant)
                pathConditions.Push("*[EventData[Data[@Name='NewProcessName']=" Chr(34) escapedPath Chr(34)
                    . " and (Data[@Name='SubjectUserSid']=" Chr(34) escapedUserSid Chr(34)
                    . " or Data[@Name='SubjectUserSid']=" Chr(34) escapedSystemSid Chr(34) ")]]")
            }
        }
        subscription := "<QueryList>"
        subscription .= "<Query Id='0' Path='Security'>"
        subscription .= "<Select Path='Security'>"
        subscription .= "*[System[Provider[@Name='Microsoft-Windows-Security-Auditing'] and EventID=4688]]"
        if (pathConditions.Length = 1) {
            subscription .= " and " pathConditions[1]
        } else if (pathConditions.Length > 1) {
            combined := pathConditions[1]
            Loop pathConditions.Length - 1
                combined .= " or " pathConditions[A_Index + 1]
            subscription .= " and (" combined ")"
        }
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
            throw Error(I18n.T("无法打开当前用户令牌，错误码：{1}", A_LastError))

        try {
            requiredSize := 0
            DllCall("Advapi32\GetTokenInformation", "Ptr", tokenHandle, "Int", 1, "Ptr", 0, "UInt", 0, "UInt*", &requiredSize)
            if (requiredSize <= 0)
                throw Error(I18n.T("无法读取当前用户令牌大小，错误码：{1}", A_LastError))

            tokenInfo := Buffer(requiredSize, 0)
            if !DllCall("Advapi32\GetTokenInformation", "Ptr", tokenHandle, "Int", 1, "Ptr", tokenInfo, "UInt", requiredSize, "UInt*", &requiredSize)
                throw Error(I18n.T("无法读取当前用户 SID，错误码：{1}", A_LastError))

            sidPointer := NumGet(tokenInfo, 0, "Ptr")
            stringSidPointer := 0
            if !DllCall("Advapi32\ConvertSidToStringSidW", "Ptr", sidPointer, "Ptr*", &stringSidPointer)
                throw Error(I18n.T("无法转换当前用户 SID，错误码：{1}", A_LastError))

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
