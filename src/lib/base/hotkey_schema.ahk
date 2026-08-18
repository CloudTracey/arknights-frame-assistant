; == 热键 Schema（元数据唯一来源） ==
; 本文件只承载热键元数据与读取 API，不引用任何 core/ui 函数。
; 由 Constants.KeyNames / 分组 Map / Config._DefaultHotkeys / HotkeyService.ActionCallbacks /
; GuiManager 热键行共同消费，避免平行维护多份热键元数据。

class HotkeySchema {
    ; id / displayName / group / defaultKey 为必填；
    ; guarded / onUp / noActivate 为热键行为元数据（供 HotkeyService 生成回调 profile）。
    ; 顺序即 GUI 显示顺序：常规作战左列→右列，快捷操作左列→右列，卫戍协议左列→右列。
    static Items := [
        ; ---- 常规作战 ----
        {id: "PressPause", displayName: "按下时暂停", group: "combat", defaultKey: "f", guarded: true, onUp: false, noActivate: false},
        {id: "ReleasePause", displayName: "松开时暂停", group: "combat", defaultKey: "Space", guarded: false, onUp: true, noActivate: false},
        {id: "GameSpeed", displayName: "切换倍速", group: "combat", defaultKey: "d", guarded: true, onUp: false, noActivate: false},
        {id: "PauseSelect", displayName: "暂停时选中", group: "combat", defaultKey: "w", guarded: true, onUp: false, noActivate: false},
        {id: "Skill", displayName: "技能", group: "combat", defaultKey: "s", guarded: true, onUp: false, noActivate: false},
        {id: "Retreat", displayName: "撤退", group: "combat", defaultKey: "a", guarded: true, onUp: false, noActivate: false},
        {id: "SwitchView", displayName: "视角切换", group: "combat", defaultKey: "", guarded: true, onUp: false, noActivate: false},
        {id: "16ms", displayName: "前进 16ms", group: "combat", defaultKey: "", guarded: true, onUp: false, noActivate: false},
        {id: "33ms", displayName: "前进 33ms", group: "combat", defaultKey: "r", guarded: true, onUp: false, noActivate: false},
        {id: "166ms", displayName: "前进 166ms", group: "combat", defaultKey: "t", guarded: true, onUp: false, noActivate: false},
        {id: "OneClickSkill", displayName: "一键技能", group: "combat", defaultKey: "e", guarded: true, onUp: false, noActivate: false},
        {id: "OneClickRetreat", displayName: "一键撤退", group: "combat", defaultKey: "q", guarded: true, onUp: false, noActivate: false},
        {id: "PauseSkill", displayName: "暂停技能", group: "combat", defaultKey: "XButton2", guarded: true, onUp: false, noActivate: false},
        {id: "PauseRetreat", displayName: "暂停撤退", group: "combat", defaultKey: "XButton1", guarded: true, onUp: false, noActivate: false},
        {id: "AutoBeginPauseSwitch", displayName: "开局自动暂停开关", group: "combat", defaultKey: "", guarded: false, onUp: false, noActivate: true},
        ; ---- 快捷操作 ----
        {id: "LButtonClick", displayName: "模拟左键点击", group: "quick", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "Harvest", displayName: "基建快速收取", group: "quick", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "CeaseOperations", displayName: "放弃行动", group: "quick", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "Skip", displayName: "跳过招募动画/剧情", group: "quick", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "CollectCollectibles", displayName: "肉鸽收取道具", group: "quick", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "Back", displayName: "返回上级菜单", group: "quick", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        ; ---- 卫戍协议 ----
        {id: "CheckEnemies", displayName: "查看敌人", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "DispatchCenter", displayName: "调度中心", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "Freeze", displayName: "冻结", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "Refresh", displayName: "刷新", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "Ready", displayName: "准备就绪", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "StrongHoldProtocolLButtonClick", displayName: "模拟左键点击", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "Upgrade", displayName: "升级", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "Sell", displayName: "出售/销毁", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "StrongHoldProtocolRetreat", displayName: "单位撤退", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "StrongHoldProtocolOneClickRetreat", displayName: "一键撤退", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "OneClickSell", displayName: "一键出售/销毁", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false},
        {id: "OneClickPurchase", displayName: "一键购买", group: "strongHold", defaultKey: "", guarded: false, onUp: false, noActivate: false}
    ]

    ; 获取热键的 id -> displayName 映射（等价 Constants.KeyNames）
    static GetKeyNames() {
        result := Map()
        for item in this.Items {
            result[item.id] := item.displayName
        }
        return result
    }

    ; 获取指定分组的 id -> true 映射（等价 Constants.Combat/Quick/StrongHoldHotkeys）
    static GetGroupMap(group) {
        result := Map()
        for item in this.Items {
            if (item.group = group)
                result[item.id] := true
        }
        return result
    }

    ; 获取热键的 id -> defaultKey 映射（等价 Config._DefaultHotkeys）
    static GetDefaultHotkeys() {
        result := Map()
        for item in this.Items {
            result[item.id] := item.defaultKey
        }
        return result
    }

    ; 按 id 获取 schema 条目；不存在返回 ""
    static GetItem(id) {
        for item in this.Items {
            if (item.id = id)
                return item
        }
        return ""
    }
}
