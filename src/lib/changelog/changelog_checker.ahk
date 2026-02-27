; == 更新公告检查器 ==

class ChangelogChecker {
    static CheckAndShow() {
        currentVersion := Version.Get()
        lastVersion := Config.GetImportant("LastLaunchedVersion")
        dismissedVersion := Config.GetImportant("DismissedChangelogVersion")
        
        if dismissedVersion != currentVersion {
            if ChangelogData.HasContent(currentVersion) {
                content := ChangelogData.GetContent(currentVersion)
                ChangelogUI.Show(currentVersion, content)
            }
        }
    }
}
