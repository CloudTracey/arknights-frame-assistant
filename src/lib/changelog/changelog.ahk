; == 更新公告内容数据 ==

class ChangelogData {
    ; 已废弃：更新公告内容现从 GitHub Releases API 动态获取
    ; 类定义保留以避免其他文件引用报错
    static VersionList := Map()

    static GetContent(version) {
        return {newFeatures: [], improvements: [], bugFixes: []}
    }

    static HasContent(version) {
        return false
    }
}
