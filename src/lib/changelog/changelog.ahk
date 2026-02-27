; == 更新公告内容数据 ==

class ChangelogData {
    static VersionList := Map(
        Version.Get(), {
            newFeatures: [
                "增加了随小助手自动启动游戏的功能",
                "增加自定义技能和撤退点击延迟的设置",
                "增加通过快捷键和托盘区右键菜单启用或禁用热键的功能",
                "增加了组合键绑定的支持，现在支持单修饰键、修饰键+鼠标按键、修饰键+键盘按键、修饰键+修饰键等多种组合键绑定"
            ],
            improvements: [
                "重构了保存相关的实现逻辑",
                "将GameLauncher和Updater的初始化移动回自身",
                "重构了热键控制器",
                "将按键绑定功能重构为类管理",
                "使右下角弹出的切换通知反应更灵敏",
                "修改正则表达式以适应组合键",
                "分离GUI显示的热键值与实际的热键值，以便显示用户可读的按键",
                "补全了自定义设置保存与加载相关的功能",
                "调整了热键启用与禁用的逻辑，使其与实际启用和禁用的热键绑定，而非与内存中的热键值绑定",
                "重写了输入钩子和按键绑定相关的逻辑"
            ],
            bugFixes: [
                "调整了DPI感知模式，修复了多显示器下涉及坐标的功能错位的问题",
                "修复当快捷键设置为空时，保存设置报错的问题",
                "修复了应用或保存设置后热键的启用状态异常的问题",
                "修复了取消和关闭设置窗口未能正确关闭钩子导致的错误",
                "屏蔽ALT键原有的控制SysMenu的功能，避免GUI卡死",
                "修复了按键冲突检测不包括启用禁用热键快捷键的问题"
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
