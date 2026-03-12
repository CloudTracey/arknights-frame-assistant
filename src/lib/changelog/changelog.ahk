; == 更新公告内容数据 ==

class ChangelogData {
    static VersionList := Map(
        Version.Get(), {
            newFeatures: [
                "新增了卫戍协议相关的功能按键，为卫戍协议按键增加单独的页面和设置项，卫戍协议按键与常规按键为不同方案，可重复绑定且互不干扰",
                "新增切换标签页时切换到对应方案并进行提醒的功能",
                "新增了在不同方案下切换的右下角提示",
                "新增了未保存提示，当设置未保存且尝试切换标签页时会进行提醒",
                "在其他设置中新增默认启动卫戍协议方案的选项"
            ],
            improvements: [
                "将快捷按键单独放置在一个标签页",
                "将返回上级菜单和放弃行动整合为同一个功能",
                "使“游戏内帧数”设置和“重置按键”按钮在所有按键设置页下保持可见，在“其他设置”页下不可见",
                "对UI的文本进行了一些补充和修改"
            ],
            bugFixes: [
                "修复了ESC的原有功能未能正确屏蔽的问题",
                "修复启用/禁用热键快捷键保存异常的问题",
                "修复了连按松开暂停和按下暂停时，松开暂停的松开判定会转移到按下暂停对应按键上的问题",
                "修复了暂停技能、暂停撤退的点击间隔与设置值不统一的问题"
            ]
        }
    )

    static GetContent(version) {
        if this.VersionList.Has(version)
            return this.VersionList[version]
        return {newFeatures: [], improvements: [], bugFixes: []}
    }

    static HasContent(version) {
        content := this.GetContent(version)
        return content.newFeatures.Length > 0 
            || content.improvements.Length > 0 
            || content.bugFixes.Length > 0
    }
}
