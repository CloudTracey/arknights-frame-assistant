; == 全局常量定义 ==
; 全局常量定义；热键元数据由 base/hotkey_schema.ahk 单一来源生成。

class Constants {
    static DefaultTabOrder := "keyBind,quick,strongHoldProtocol,other"

    ; 延迟常量
    static Delay30 := 34      ; 30帧
    static Delay60 := 17      ; 60帧
    static Delay90 := 12      ; 90帧
    static Delay120 := 9      ; 120帧
    static Delay144 := 8      ; 144帧
    static Delay165 := 7      ; 165帧
    static Delay180 := 6      ; 180帧
    static Delay240 := 5      ; 240帧

    ; 帧率选项（下拉框显示文本→下拉框索引，1-based）
    static FrameOptions := ["30", "60", "90", "120", "144", "165", "180", "240+"]
    ; 帧率文本→旧版序号（用于Frame双写兼容）
    static FrameTextToOldIndex := Map("30","1", "60","2", "90","3", "120","4", "144","5", "165","6", "180","6", "240+","7")
    ; 旧版序号→帧率文本（用于迁移和回退）
    static FrameOldIndexToText := Map("1","30", "2","60", "3","90", "4","120", "5","144", "6","165", "7","240+")

    ; 按键名称映射（由 HotkeySchema 生成）
    static KeyNames := HotkeySchema.GetKeyNames()

    ; 热键启用分组，同时作为冲突检测的唯一分组数据源（由 HotkeySchema 生成）
    static CombatHotkeys := HotkeySchema.GetGroupMap("combat")
    static QuickHotkeys := HotkeySchema.GetGroupMap("quick")
    static StrongHoldHotkeys := HotkeySchema.GetGroupMap("strongHold")

    ; 重要设置名称映射
    static ImportantNames := Map(
        "AutoExit", "important.AutoExit",
        "AutoOpenSettings", "important.AutoOpenSettings",
        "ExitOnWindowClose", "important.ExitOnWindowClose",
        "Frame", "important.Frame",
        "Frame155", "important.Frame155",
        "AutoUpdate", "important.AutoUpdate",
        "LastDismissedVersion", "important.LastDismissedVersion",
        "UpdateChannel", "important.UpdateChannel",
        "UpdateSource", "important.UpdateSource",
        "UseGitHubToken", "important.UseGitHubToken",
        "GitHubToken", "important.GitHubToken",
        "GamePath", "important.GamePath",
        "GamePathCN", "important.GamePathCN",
        "GamePathJP", "important.GamePathJP",
        "GamePathKR", "important.GamePathKR",
        "GamePathEN", "important.GamePathEN",
        "PreferredServer", "important.PreferredServer",
        "LastActiveServer", "important.LastActiveServer",
        "AutoRunGame", "important.AutoRunGame",
        "AutoStartWithGame", "important.AutoStartWithGame",
        "DismissedChangelogVersion", "important.DismissedChangelogVersion",
        "DefaultStrongHoldProtocol", "important.DefaultStrongHoldProtocol",
        "TabOrder", "important.TabOrder",
        "HiddenTabs", "important.HiddenTabs",
        "AutoBeginPause", "important.AutoBeginPause",
        "BackCeaseOperations", "important.BackCeaseOperations",
        "InLevelGuard", "important.InLevelGuard",
        "DebugEnabled", "important.DebugEnabled",
        "Language", "important.Language"
    )

    ; 自定义设置名称映射
    static CustomNames := Map(
        "ClickDelay", "custom.ClickDelay",
        "SwitchHotkey", "custom.SwitchHotkey",
        "FrameSkip16msDelay", "custom.FrameSkip16msDelay",
        "FrameSkip33msDelay", "custom.FrameSkip33msDelay",
        "FrameSkip166msDelay", "custom.FrameSkip166msDelay",
        "HoverOperate", "custom.HoverOperate"
    )
}
