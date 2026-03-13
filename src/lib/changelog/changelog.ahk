; == 更新公告内容数据 ==

class ChangelogData {
    static VersionList := Map(
        Version.Get(), {
            newFeatures: [
                
            ],
            improvements: [
                
            ],
            bugFixes: [
                "修复了保存或应用设置后，常规作战、快捷操作中与卫戍协议重复的部分按键失效的问题"
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
