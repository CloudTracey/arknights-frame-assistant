; == 热键 Schema（元数据唯一来源） ==
; 被 Constants / Config / HotkeyService / GUI 共同消费；不引用任何 core/ui 函数。

class HotkeySchema {
    ; id/nameKey/group/defaultKey 必填；descKey 为状态栏悬停说明（中文原文，可含 {1} 占位符）；
    ; guarded/onUp/noActivate 为热键行为元数据；可选 repeatable 默认 false；数组顺序即 GUI 显示顺序。
    static Items := [
        ; ---- 常规作战 ----
        {id: "PressPause", nameKey: "按下时暂停", descKey: "按下时切换暂停", group: "combat", defaultKey: "f", guarded: true, onUp: false, noActivate: false},
        {id: "ReleasePause", nameKey: "松开时暂停", descKey: "松开时切换暂停，还原模拟器“点击”的手感", group: "combat", defaultKey: "Space", guarded: false, onUp: true, noActivate: false},
        {id: "GameSpeed", nameKey: "切换倍速", descKey: "切换游戏倍速（1倍/2倍）", group: "combat", defaultKey: "d", guarded: true, onUp: false, noActivate: false},
        {id: "PauseSelect", nameKey: "暂停时选中", descKey: "暂停时，鼠标移动到想选中的单位上，点击选中", group: "combat", defaultKey: "w", guarded: true, onUp: false, noActivate: false},
        {id: "Skill", nameKey: "技能", descKey: "点击技能键", group: "combat", defaultKey: "s", guarded: true, onUp: false, noActivate: false},
        {id: "Retreat", nameKey: "撤退", descKey: "点击撤退键", group: "combat", defaultKey: "a", guarded: true, onUp: false, noActivate: false},
        {id: "SwitchView", nameKey: "视角切换", descKey: "暂停时，鼠标移动到单位上，点击后即可将摄像头中心切换到该单位上", group: "combat", defaultKey: "", guarded: true, onUp: false, noActivate: false},
        {id: "16ms", nameKey: "前进 16ms", descKey: "暂停时使用，游戏时间向前推进 {1} ms", group: "combat", defaultKey: "", guarded: true, onUp: false, noActivate: false},
        {id: "33ms", nameKey: "前进 33ms", descKey: "暂停时使用，游戏时间向前推进 {1} ms", group: "combat", defaultKey: "r", guarded: true, onUp: false, noActivate: false},
        {id: "166ms", nameKey: "前进 166ms", descKey: "暂停时使用，游戏时间向前推进 {1} ms", group: "combat", defaultKey: "t", guarded: true, onUp: false, noActivate: false},
        {id: "OneClickSkill", nameKey: "一键技能", descKey: "鼠标移动到想要开技能的单位上，按下后自动选中并开启技能", group: "combat", defaultKey: "e", guarded: true, onUp: false, noActivate: false},
        {id: "OneClickRetreat", nameKey: "一键撤退", descKey: "鼠标移动到想要撤退的单位上，按下后自动选中并撤退", group: "combat", defaultKey: "q", guarded: true, onUp: false, noActivate: false},
        {id: "PauseSkill", nameKey: "暂停技能", descKey: "暂停时，鼠标移动到想要开技能的单位上，按下后自动选中并开启技能", group: "combat", defaultKey: "XButton2", guarded: true, onUp: false, noActivate: false},
        {id: "PauseRetreat", nameKey: "暂停撤退", descKey: "暂停时，鼠标移动到想要撤退的单位上，按下后自动选中并撤退", group: "combat", defaultKey: "XButton1", guarded: true, onUp: false, noActivate: false},
        {id: "AutoBeginPauseSwitch", nameKey: "开局自动暂停开关", descKey: "切换「开局自动暂停」的开关", group: "combat", defaultKey: "", guarded: false, onUp: false, noActivate: true},
        {id: "AutoBeginSpeedSwitch", nameKey: "开局自动二倍速开关", descKey: "切换「开局自动二倍速」的开关", group: "combat", defaultKey: "", guarded: false, onUp: false, noActivate: true},
        {id: "AutoBeginPauseHold", nameKey: "按住开局暂停", descKey: "在关卡加载时按住，进入关卡后会自动暂停（不受「启用开局自动暂停」勾选与否的影响）", group: "combat", defaultKey: "", guarded: false, onUp: false, noActivate: true},
        ; ---- 快捷操作 ----
        {id: "LButtonClick", nameKey: "模拟左键点击", descKey: "模拟按下鼠标左键", group: "quick", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "Harvest", nameKey: "基建快速收取", descKey: "点击屏幕左下角的基建收取按钮收取产物", group: "quick", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "CeaseOperations", nameKey: "放弃行动", descKey: "放弃当前作战", group: "quick", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "Skip", nameKey: "跳过招募动画/剧情", descKey: "快速移动鼠标点击右上角的跳过按钮", group: "quick", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "CollectCollectibles", nameKey: "肉鸽收取道具", descKey: "快速移动鼠标点击集成战略的“收下”按钮", group: "quick", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "Back", nameKey: "返回上级菜单", descKey: "模拟点击ESC键，返回上一级菜单", group: "quick", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "MuteGame", nameKey: "一键静音", descKey: "切换明日方舟静音，不影响其他程序声音", group: "quick", defaultKey: "F8", guarded: false, onUp: false, noActivate: true},
        {id: "GameVolumeUp", nameKey: "提高游戏音量", descKey: "提高明日方舟音量 10%，并解除静音", group: "quick", defaultKey: "^Up", guarded: false, onUp: false, noActivate: true, repeatable: true},
        {id: "GameVolumeDown", nameKey: "降低游戏音量", descKey: "降低明日方舟音量 10%，不改变静音状态", group: "quick", defaultKey: "^Down", guarded: false, onUp: false, noActivate: true, repeatable: true},
        ; ---- 卫戍协议 ----
        {id: "CheckEnemies", nameKey: "查看敌人", descKey: "查看敌人信息", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "DispatchCenter", nameKey: "调度中心", descKey: "打开调度中心（商店）", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "Freeze", nameKey: "冻结", descKey: "冻结调度中心（商店）", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "Refresh", nameKey: "刷新", descKey: "刷新调度中心（商店）", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "Ready", nameKey: "准备就绪", descKey: "确认准备就绪", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "StrongHoldProtocolLButtonClick", nameKey: "模拟左键点击", descKey: "模拟按下鼠标左键", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "Upgrade", nameKey: "升级", descKey: "升级调度中心（商店）", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "Sell", nameKey: "出售/销毁", descKey: "出售干员/销毁装备", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "StrongHoldProtocolRetreat", nameKey: "单位撤退", descKey: "撤退选中单位", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "StrongHoldProtocolOneClickRetreat", nameKey: "一键撤退", descKey: "点击鼠标位置单位后自动撤退", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "OneClickSell", nameKey: "一键出售/销毁", descKey: "点击鼠标位置干员/装备后自动出售/销毁", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "OneClickPurchase", nameKey: "一键购买", descKey: "模拟双击左键，购买调度中心商店中的单位", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "StrongHoldProtocolBack", nameKey: "返回上级菜单", descKey: "模拟点击ESC键，返回上一级菜单", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false}
    ]

    ; id -> nameKey
    static GetKeyNames() {
        result := Map()
        for item in this.Items {
            result[item.id] := item.nameKey
        }
        return result
    }

    ; 指定分组的 id -> true 映射
    static GetGroupMap(group) {
        result := Map()
        for item in this.Items {
            if (item.group = group)
                result[item.id] := true
        }
        return result
    }

    ; id -> defaultKey
    static GetDefaultHotkeys() {
        result := Map()
        for item in this.Items {
            result[item.id] := item.defaultKey
        }
        return result
    }

    ; 按 id 获取 schema 条目
    static GetItem(id) {
        for item in this.Items {
            if (item.id = id)
                return item
        }
        return ""
    }

    ; 自定义按键「类型」行为元数据（仅此一处定义）：生效组与是否受关卡守卫
    static CustomTypeProfiles := Map(
        "global",     {Group: "all",                Guarded: false},
        "combat",     {Group: "combatQuick",        Guarded: true},
        "quick",      {Group: "combatQuick",        Guarded: false},
        "strongHold", {Group: "strongHoldProtocol", Guarded: false}
    )
}
