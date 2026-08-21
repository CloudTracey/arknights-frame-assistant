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
        "AutoExit", "自动退出",
        "Language", "语言",
        "AutoOpenSettings", "自动打开设置界面",
        "ExitOnWindowClose", "关闭窗口时退出小助手",
        "Frame", "游戏内帧率设置（兼容旧版）",
        "Frame155", "游戏内帧率设置",
        "AutoUpdate", "自动检查更新",
        "LastDismissedVersion", "上次忽略的更新版本",
        "UpdateChannel", "更新渠道",
        "UpdateSource", "更新源",
        "UseGitHubToken", "是否使用GitHub Token",
        "GitHubToken", "GitHub Token",
        "GamePath", "游戏路径",
        "AutoRunGame", "随小助手自动启动明日方舟",
        "AutoStartWithGame", "随明日方舟自动启动小助手",
        "DismissedChangelogVersion", "已忽略公告版本",
        "DefaultStrongHoldProtocol", "默认启动卫戍协议方案",
        "TabOrder", "标签页顺序",
        "HiddenTabs", "隐藏的标签页",
        "AutoBeginPause", "开局自动暂停",
        "BackCeaseOperations", "使用“返回上级菜单”放弃行动",
        "InLevelGuard", "在非战斗关卡场景禁用常规战斗热键",
        "DebugEnabled", "调试模式"
    )

    ; 自定义设置名称映射
    static CustomNames := Map(
        "ClickDelay", "点击延迟",
        "SwitchHotkey", "启用/禁用热键",
        "FrameSkip16msDelay", "前进16ms延迟",
        "FrameSkip33msDelay", "前进33ms延迟",
        "FrameSkip166msDelay", "前进166ms延迟",
        "HoverOperate", "游戏窗口未激活时允许鼠标悬停在窗口上触发热键"
    )
}
