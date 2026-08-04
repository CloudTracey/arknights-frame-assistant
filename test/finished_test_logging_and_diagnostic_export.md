# 测试清单：日志记录与诊断压缩包导出

## 测试环境

- AFA 版本: v1.5.10 或待测版本
- AutoHotkey 版本: 2.0.26
- Windows 版本: Windows 10/11

## 测试步骤

### 测试 1：日志初始化与启动记录

- [x] 启动 AFA，并确认程序正常进入托盘和设置界面
- [x] 打开 `%AppData%\ArknightsFrameAssistant\PC\logs`
- [x] 验证生成 `afa-*.log` 会话文件，内容为 UTF-8
- [x] 验证日志包含启动、配置加载和热键初始化记录
- [x] 验证日志行包含时间、级别和模块名称

### 测试 2：关键流程日志

- [x] 启动/关闭游戏，验证游戏启动器或游戏监控记录状态变化
- [x] 修改并应用设置，验证设置保存记录出现
- [x] 修改游戏内按键或模拟注册表读取失败，验证 GameKeys 警告/错误记录出现
- [x] 手动检查更新并执行一次取消或失败流程，验证更新流程记录出现
- [x] 确认连续触发热键和过帧操作不会逐次刷写日志

### 测试 3：日志目录按钮

- [x] 在设置的“日志”页面点击“打开日志文件夹”
- [x] 验证资源管理器打开 `%AppData%\ArknightsFrameAssistant\PC\logs`
- [x] 删除或暂时改名日志目录后再次点击，验证目录会自动创建并打开

### 测试 4：生成日志压缩包

- [x] 点击“生成日志压缩包”，在保存对话框中选择目标 ZIP 路径
- [x] 验证导出成功提示包含实际文件路径
- [x] 解压 ZIP，确认包含 `logs/`、`diagnostics.txt` 和 `settings-sanitized.ini`
- [x] 验证日志文件可读，且导出内容为 UTF-8
- [x] 验证取消保存不会弹出错误提示，也不会生成残留临时文件
- [x] 使用包含中文、空格和单引号的目标路径重复测试

### 测试 5：敏感信息过滤

- [x] 配置 GitHub Token 后生成压缩包
- [x] 在解压目录中搜索 Token 明文、`GitHubTokenProtected` 密文、GitHub 用户名、Windows 用户名、计算机名、用户目录和完整游戏路径
- [x] 验证以上内容均未出现在压缩包中
- [x] 验证原始 `Settings.ini` 未被打包

### 测试 6：日志保留与降级

- [x] 在日志目录创建超过 7 天的普通旧日志，重启 AFA 后验证其被清理
- [x] 创建超过 7 天的关键日志，验证其不受期限清理影响，仅按关键轨容量和文件数预算清理
- [x] 创建超过 20 个普通日志文件，验证清理最旧文件直到数量不超过上限
- [x] 创建普通日志总大小超过 15 MiB 的日志，验证清理最旧文件直到普通日志低于预算
- [x] 将日志目录设置为不可写，验证 AFA 仍可启动且 DebugView 仍有输出

### 测试 7：双轨滚动与关键上下文

- [x] 连续生成超过 4 MiB 的普通日志，验证生成 `.part-*.log`，当前普通日志单文件不超过分片阈值
- [x] 触发 WARN/ERROR，验证生成 `critical-*.log`，并包含错误前最近日志上下文
- [x] 生成超过 5 个关键日志分片，验证关键日志最多保留 5 个且不被普通日志清理挤占
- [x] 非正常结束 AFA 后重新启动，验证上一会话最后分片仍被保留
- [x] 写入超长单条消息，验证日志包含 `[truncated]` 且单行长度受到限制
- [x] 生成诊断压缩包，验证 `diagnostics.txt` 包含普通、关键、总容量统计和双轨可用性字段

### 测试 8：写入性能与双轨可用性诊断

- [x] 连续触发 1000 条 INFO 日志，确认设置界面和托盘操作保持响应，且未达到分片阈值时不会频繁生成分片
- [x] 连续触发 WARN/ERROR，确认关键上下文写入完成，普通日志和关键日志均未出现异常卡顿
- [x] 模拟关键日志文件写入/轮换失败，生成诊断包，确认 `LogOrdinaryFileAvailable` 与 `LogCriticalFileAvailable` 分别反映两条日志轨状态
- [x] 确认诊断统计字段与导出时日志快照的实际文件数量、容量一致

## 追加测试

> 对应更改：修复 Logger.Redact(forExport=true) 的用户名脱敏——将 `StrReplace` 子串替换改为边界感知正则（`\p{L}` 边界），避免过短用户名（如单字符 `s`）在大小写不敏感下误伤正常英文单词内部的 `s`/`S` 字符

- AFA 版本: v1.7.2
- AutoHotkey 版本: 2.0.26
- Windows 版本: Windows 11 25H2
- 测试日期: 2026-08-04

### 功能点 1：导出日志的英文单词完整性

- [x] **前置**：AFA 正常运行，进过一次关卡（使日志含 `LevelDetector`、`PauseButton`、`HotkeyActions` 等英文文本）
- [x] **操作**：设置 → "日志"页 → 点击"生成日志压缩包" → 保存到桌面 → 解压 → 打开 `logs/afa-*.log`
- [x] **预期**：英文单词完整可读，`[Startup]`、`ArknightsFrameAssistant`、`PauseButton`、`GameSpeed`、`CeaseOperations`、`reason` 等均不被 `<USER>` 打散
- [x] **预期**：不再出现 `<U<USER>ERPROFILE>`、`Pau<USER>eButton`、`Game<USER>peed` 这类被污染文本
- [x] **预期**：日志目录路径以完整占位符 `<USERPROFILE>` 显示，其内部字母不被替换

### 功能点 2：隐私脱敏仍生效

- [x] **操作**：在解压日志、`diagnostics.txt` 中搜索本机 Windows 用户名、计算机名、`%USERPROFILE%` 完整路径
- [x] **预期**：完整用户目录路径显示为 `<USERPROFILE>`/`<APPDATA>` 占位符，未泄露真实路径；独立出现的用户名仍被替换为 `<USER>`；GitHub Token 仍为 `<REDACTED>`

### 功能点 3：原始落盘日志不受影响（回归）

- [x] **操作**：直接打开 `%AppData%\ArknightsFrameAssistant\PC\logs\afa-*.log`（未导出版）
- [x] **预期**：原始日志显示真实路径（如 `C:\Users\CloudTrace\...`），英文单词完整，无任何 `<USER>`/`<USERPROFILE>` 占位符（`forExport=false` 不触发环境变量脱敏）

### 功能点 4（可选）：单字符用户名场景复现

> **已跳过**：该场景已通过代码模拟验证（误伤数 222→0）

- [ ] **操作**：`set USERNAME=s` 后启动 AFA，执行一次导出，解压检查
- [ ] **预期**：`[Startup]`、`PauseButton`、`ArknightsFrameAssistant`、`reason` 等单词完整

### 追加回归测试

- [x] **验证**：配置 GitHub Token 后导出，Token 明文在解压日志/`settings-sanitized.ini` 中仍为 `<REDACTED>`，脱敏未被破坏

## 测试结果

- [x] 全部通过
- [ ] 存在问题（请详细描述）

## 问题反馈
