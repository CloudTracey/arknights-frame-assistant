<!-- 由 AI 根据 test/template/test_template.md 生成 -->
# 测试清单：`web_settings_save`

> 对应更改：Slice 3 新增 `settings.save` / `settings.apply` / `settings.cancel`、`i18n.get`，并转发保存开始/成功/失败/取消及语言变更事件。本 slice 仍使用原生 MessageBox，未改设置页 UI。

## 测试环境

| 项目 | 信息 |
|------|------|
| AFA 版本 | `v2.2.0` |
| AutoHotkey 版本 | `v2.0.26` |
| Windows 版本 | `Windows 11 10.0.26300.9711` |
| 测试日期 | `2026-10-18` |

> 本 slice 的保存/应用仍会弹原生 MessageBox；出现时按提示点击确定/取消，不要把它当作失败。

---

## 单元测试

### 功能点：`settings.save`

- [ ] **前置**：记录当前 `Settings.ini` 的 `[Custom] ClickDelay` 原值；确认 web UI 显示 `connected · ...`
- [ ] **操作**：DevTools Console 执行 `chrome.webview.addEventListener('message', e => console.log(e.data))`
- [ ] **操作**：执行 `chrome.webview.postMessage({v:1,type:'call',id:301,method:'settings.setDraft',params:{key:'ClickDelay',value:'60'}})`
- [ ] **预期**：收到 `id:301`、`ok:true`，`result.success` 为 `true`，`result.value` 为 `"60"`
- [ ] **操作**：执行 `chrome.webview.postMessage({v:1,type:'call',id:302,method:'settings.save',params:{}})`
- [ ] **预期**：立即收到 `id:302`、`ok:true`、`result.started` 为 `true`
- [ ] **预期**：随后收到 `type:'event'`、`name:'SettingsSaveStarting'` 和 `name:'SettingsSaved'`；原生「保存成功」提示出现，点击确定
- [ ] **操作**：执行 `settings.get`（id:303）
- [ ] **预期**：`values.ClickDelay` 为 `"60"`；`Settings.ini` 的 `ClickDelay` 已变为 `60`
- [ ] **操作**：重启 AFA 后再次执行 `settings.get`
- [ ] **预期**：`ClickDelay` 仍为 `"60"`，确认已落盘

### 功能点：`settings.apply`

- [ ] **操作**：执行 `settings.setDraft`，`key:'ClickDelay'`、`value:'61'`
- [ ] **操作**：执行 `chrome.webview.postMessage({v:1,type:'call',id:304,method:'settings.apply',params:{}})`
- [ ] **预期**：立即收到 `id:304`、`ok:true`、`result.started` 为 `true`
- [ ] **预期**：收到 `SettingsSaveStarting` 和 `SettingsApplied`；原生「设置已应用」提示出现，点击确定
- [ ] **预期**：web 设置窗口不关闭；`settings.get` 返回 `ClickDelay="61"`

### 功能点：`settings.cancel`

- [ ] **操作**：执行 `settings.setDraft`，`key:'ClickDelay'`、`value:'99'`
- [ ] **操作**：执行 `chrome.webview.postMessage({v:1,type:'call',id:305,method:'settings.cancel',params:{}})`
- [ ] **预期**：立即收到 `id:305`、`ok:true`、`result.started` 为 `true`
- [ ] **预期**：收到 `SettingsViewRefreshRequested` 和 `SettingsCancelled`
- [ ] **操作**：再次执行 `settings.get`
- [ ] **预期**：`ClickDelay` 恢复为 `"61"`，不是 `"99"`

### 功能点：`SettingsSaveFailed`

- [ ] **操作**：执行 `settings.setDraft`，`key:'GamePath'`、`value:'C:\NoSuchPath\Arknights.exe'`
- [ ] **操作**：执行 `settings.save`，id:306
- [ ] **预期**：原生「路径不存在」提示出现，选择「否」
- [ ] **预期**：收到 `id:306`、`ok:true`、`result.started` 为 `true`，随后收到 `type:'event'`、`name:'SettingsSaveFailed'`、`data.mode:'save'`
- [ ] **操作**：执行 `settings.cancel`，恢复草稿
- [ ] **预期**：`settings.get` 的 `GamePath` 恢复为原持久化值

### 功能点：`i18n.get`

- [ ] **操作**：执行 `chrome.webview.postMessage({v:1,type:'call',id:307,method:'i18n.get',params:{keys:['保存','应用','取消']}})`
- [ ] **预期**：收到 `ok:true`，`result.success` 为 `true`，`result.locale` 为当前语言，`result.values` 包含三个非空字符串
- [ ] **操作**：执行 `chrome.webview.postMessage({v:1,type:'call',id:308,method:'i18n.get',params:{keys:'保存'}})`
- [ ] **预期**：`result.success` 为 `false`，`result.code` 为 `bad_request`
- [ ] **操作**：执行 `i18n.get`，不传 `keys`
- [ ] **预期**：`result.success` 为 `true`，`result.values` 为空对象，`result.locale` 仍返回

---

## 集成测试

### 流程：保存事件顺序

> 涉及模块：`WebSettings`、`WebBridge`、`SettingsService`

- [ ] **操作**：保持 Console 监听，执行一次 `settings.setDraft` 后 `settings.save`
- [ ] **预期**：事件顺序为 `SettingsSaveStarting` → `SettingsSaved`（或失败时 `SettingsSaveFailed`）
- [ ] **预期**：`settings.save` 的 `reply` 先于原生 MessageBox 出现，页面不会被弹窗阻塞回复

### 流程：语言变更

> 涉及模块：`SettingsService`、`I18n`、`WebBridge`

- [ ] **操作**：`settings.setDraft` 设置 `Language` 为当前语言之外的值（如 `en-US`；若当前已是 `en-US` 则用 `ja-JP`），然后 `settings.apply`
- [ ] **预期**：收到 `SettingsApplied` 和 `LocaleChanged`，`data.locale` 为刚设置的语言
- [ ] **操作**：执行 `i18n.get`，`keys:['保存']`
- [ ] **预期**：`result.locale` 为新语言，`values['保存']` 为对应翻译
- [ ] **操作**：把 `Language` 恢复为原值并再次 `settings.apply`
- [ ] **预期**：再次收到 `LocaleChanged`，语言恢复；原生提示点击确定

### 流程：测试数据清理

> 涉及模块：`WebSettings`、`SettingsService`

- [ ] **操作**：把 `ClickDelay` 恢复为测试前记录的原值，执行 `settings.save`，点击原生确定
- [ ] **预期**：`Settings.ini` 中 `ClickDelay` 恢复原值
- [ ] **操作**：如果测试中改过 `Language`，恢复到原值并 `settings.apply`
- [ ] **预期**：页面的 `LocaleChanged` 与 `i18n.get` 结果回到原语言

### 流程：不改变现有经典保存流程

> 涉及模块：`SettingsService`、`GuiManager`

- [ ] **操作**：切回经典界面，打开设置，修改一个值并保存
- [ ] **预期**：经典界面的保存/应用/取消行为与之前一致；没有因为新增 `SettingsSaveFailed` 产生额外弹窗或错误

---

## 回归测试

### 功能：Slice 1/2 桥接

- [ ] 验证：`app.getState` 仍返回 `ok:true`，页面显示 `connected · ...`
- [ ] 验证：`settings.get` 快照仍不包含 `GitHubToken`
- [ ] 验证：`settings.setDraft` 仍只写内存，取消后恢复
- [ ] 验证：`location.reload()` 后重新握手正常
- [ ] 验证：外部导航 `location.href='https://example.com'` 仍被拦截

### 功能：经典界面

- [ ] 验证：切回经典界面后设置窗口、托盘、热键正常

---

## 测试结果

- [ ] 全部通过
- [ ] 存在问题（详见下方问题反馈）

## 问题反馈

### 问题1：[问题描述]
- [ ] 已解决
