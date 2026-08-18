# 测试清单：更新/公告域重构（阶段 7）

> 对应更改：更新/公告模块迁入 core/updater 与 core/changelog；抽取 GitHubTokenService/ReleaseRepository；Updater/UpdateUI 与 ChangelogChecker/ChangelogUI 全面事件化；删除孤儿事件。

## 测试环境

| 项目 | 信息 |
|------|------|
| AutoHotkey 版本 | v2.0.26 |
| Windows 版本 | Windows 11 26200.9168 |
| 测试日期 | 2026-08-17 |

---

## 单元测试

### 功能点：手动检查更新按钮

- [x] **操作**：打开设置窗口 → “其他设置 → 更新”，点击“手动检查更新”
- [x] **预期**：检查期间按钮变为“检查中...”并禁用；检查完成后恢复“手动检查更新”（`UpdateCheckStarted/Completed` 事件驱动）

### 功能点：更新弹窗按钮

- [x] **操作**：手动检查发现新版本后，点击“是”
- [x] **预期**：弹窗关闭，进入下载流程（`UpdateConfirmRequested` 事件）
- [x] **操作**：再次发现新版本，点击“否”
- [x] **预期**：弹窗关闭，无额外报错（`UpdateDismissed` 已删除）
- [x] **操作**：再次发现新版本，点击“忽略此版本”
- [x] **预期**：提示“已忽略版本”，后续自动检查不再提示该版本（`UpdateIgnoreRequested` 事件）

### 功能点：下载弹窗与进度

- [x] **操作**：确认更新后观察下载窗口
- [x] **预期**：出现“下载中”窗口，显示进度、速度、剩余时间；取消按钮可点击
- [x] **操作**：下载过程中点击“取消下载”
- [x] **预期**：按钮变为“正在取消下载...”，随后显示“下载已取消”（`UpdateDownloadCancelRequested` → `UpdateDownloadCancelled` 事件）
- [x] **操作**：下载过程中点击“手动下载”
- [x] **预期**：打开默认浏览器访问下载页面（`UpdateManualDownloadRequested` 事件；不取消当前下载）

### 功能点：更新公告

- [x] **操作**：启动 AFA，若有未忽略公告则自动弹出更新公告窗口
- [x] **预期**：公告窗口正常显示 Markdown 内容（`ChangelogShowRequested` → `ChangelogAvailable` 事件）
- [x] **操作**：勾选“直到下次更新前不再弹出”并确定
- [x] **预期**：窗口关闭，下次启动不再弹出当前版本公告（`ChangelogDismissRequested` 事件）

---

## 集成测试

### 流程：完整更新检查（正常路径）

> 涉及模块：`GuiManager`、`Updater`、`VersionChecker`、`ReleaseRepository`、`UpdateUI`

- [x] **前置**：网络可用，AFA 版本低于远程最新版
- [x] **操作**：手动检查更新
- [x] **预期**：`UpdateCheckStarted` 发布；检查完成后 `UpdateCheckCompleted` 发布；发现新版本时 `UpdateAvailable` 发布并由 UpdateUI 弹窗；确认后下载窗口出现，进度更新，下载完成后提示“下载完成”

### 流程：完整更新检查（异常路径）

> 涉及模块：`Updater`、`VersionChecker`、`ReleaseRepository`、`UpdateUI`

- [x] **异常**：网络不可用/断网时手动检查 → **预期**：显示检查失败弹窗（由 `UpdateCheckCompleted` 驱动）
- [x] **异常**：GitHub 源限流且自动检查 → **预期**：自动降级国内源，不弹错误；若手动检查则显示失败/Token 引导
- [x] **异常**：下载失败重试耗尽且备选源不可用 → **预期**：显示下载失败弹窗（`UpdateDownloadFailed` 事件）

### 流程：公告事件链

> 涉及模块：`Bootstrap`、`ChangelogChecker`、`ChangelogUI`、`SettingsService`

- [x] **前置**：`changelog.json` 存在或可联网获取
- [x] **操作**：启动 AFA，触发 `ChangelogShowRequested`
- [x] **预期**：`ChangelogChecker` 构建 body 并发布 `ChangelogAvailable`；`ChangelogUI` 弹出公告窗口
- [x] **操作**：勾选“不再弹出”并确定
- [x] **预期**：`ChangelogDismissRequested` 由 SettingsService 单键写入，不干扰其他未保存设置

---

## 回归测试

### 功能：设置保存/应用

- [x] 验证：阶段 6 的保存/应用/取消/重置仍正常，`SettingsService` 未受更新事件化影响

### 功能：热键与托盘

- [x] 验证：热键开关、托盘提示、切到“其他设置”不失效等阶段 5/6 修复仍正常

### 功能：启动流程

- [x] 验证：AFA 启动不报 include 错误，公告与自动更新检查均按事件触发

---

## 测试结果

- [x] 全部通过
- [ ] 存在问题（详见下方问题反馈）

## 问题反馈

### 问题1：[问题描述]
- [ ] 已解决

### 问题2：[问题描述]
- [ ] 已解决
