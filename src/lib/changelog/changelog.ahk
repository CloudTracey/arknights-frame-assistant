; == 更新公告内容数据 ==

class ChangelogData {
    static VersionList := Map(
        Version.Get(), {
            newFeatures: [
                "增加了手动下载更新的渠道",
                "新增“放弃行动”、“跳过招募动画/剧情”、“返回上级菜单”、“基建快速收取”、“肉鸽收取道具”按键功能"
            ],
            improvements: [
                "通过新的暂停键对暂停相关功能进行优化",
                "增加部分按键的转义，将ESC由清除按键快捷键改为可绑定按键",
                "修改MessageBox的宽度，以适应更长的信息"
            ],
            bugFixes: [
                "修复了游戏内与AFA都设定空格或V为快捷键时按键冲突的问题",
                "修复了技能和撤退点击延迟未能正确保存的问题"
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
