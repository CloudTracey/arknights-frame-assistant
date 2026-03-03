; == 更新公告内容数据 ==

class ChangelogData {
    static VersionList := Map(
        Version.Get(), {
            newFeatures: [
                
            ],
            improvements: [
                "将MsgBox提示修改为通过GUI窗口进行提示",
                "为更新下载增加了取消功能",
                "稍微加长了按键绑定edit控件的长度，使其可以正常显示较长的组合键",
                "为启用/禁用热键的托盘菜单添加快捷键提示",
                "当热键值为空时，提前结束正则表达式匹配，减少无用性能消耗"
            ],
            bugFixes: [
                "修复了只要文件路径存在，即便不是Arknights.exe也提示路径正确的问题",
                "修复了清除启用/禁用热键快捷键后，保存或应用修改不生效的问题"
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
