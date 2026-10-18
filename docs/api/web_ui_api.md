# WebView2 Web UI API

> 面向 Web UI 开发者的接口契约。这里描述的是 **WebView2 页面与 AFA 内核之间的消息协议**，不是 HTTP API。
>
> 适用版本：AFA v2.2.0 · 协议 `v1`
> 最后核对：2026-10-18

## 1. 概览

AFA 在进程内承载 WebView2。页面从虚拟源 `https://afa.app/index.html` 加载，通过 WebView2 内置的 web message 通道与 AutoHotkey 内核通信：

```text
页面                          AFA 内核
 │                              │
 │── ready ────────────────────▶│
 │◀─ welcome ───────────────────│
 │── call {id, method, params} ─▶│
 │◀─ reply {id, ok, result} ────│
 │◀─ event {name, data} ────────│
```

- 页面 → 内核：`window.chrome.webview.postMessage(message)`
- 内核 → 页面：`window.chrome.webview.addEventListener("message", handler)`
- 页面必须发送**对象**，不要先 `JSON.stringify`；内核使用 `PostWebMessageAsJson` 回发，`event.data` 已经是对象。
- 只有 `https://afa.app/` 来源的消息会被处理，外部导航会被取消。
- 页面加载或刷新后必须重新完成 `ready → welcome` 握手；内核有 8 秒握手超时，失败时按现有策略提示/回退经典界面。

## 2. 生命周期

1. AFA 创建 WebView2 控制器，绑定消息与导航事件。
2. 页面脚本在 DOM 就绪后发 `ready`。
3. 内核回 `welcome`，携带应用状态和当前可用方法列表。
4. 页面可以开始发 `call`。
5. 页面刷新时，内核重置就绪态并重新等待 `ready`；页面应重新执行握手。
6. 关闭按钮按 `ExitOnWindowClose` 配置处理：`0` 隐藏并复用控制器，`1` 退出 AFA；隐藏后重新打开会复用同一页面。

`welcome` 是页面收到的第一条内核消息。`ready` 之前不要发 `call`；`ready` 之前的业务事件会被丢弃，页面应以 `welcome` + `settings.get` 的快照为准。

## 3. 消息格式

所有消息都带协议版本 `v`，当前固定为 `1`。

### 3.1 ready

页面 → 内核：

```json
{"v":1,"type":"ready"}
```

旧版页面发送字符串 `"ready"` 也兼容。推荐始终发送对象。

### 3.2 welcome

内核 → 页面：

```json
{
  "v": 1,
  "type": "welcome",
  "app": {
    "version": "v2.2.0",
    "locale": "zh-Hans",
    "theme": "auto",
    "engine": "web",
    "hotkeysEnabled": true
  },
  "methods": [
    "app.getState",
    "settings.get",
    "settings.setDraft",
    "settings.save",
    "settings.apply",
    "settings.cancel",
    "i18n.get"
  ]
}
```

- `methods` 是当前宿主支持的方法白名单，页面可据此做能力检测。
- `app.theme` 取值为 `auto | light | dark`；`app.engine` 在 web 模式下为 `web`。
- `app.hotkeysEnabled` 是布尔值。

### 3.3 call

页面 → 内核：

```json
{
  "v": 1,
  "type": "call",
  "id": 7,
  "method": "settings.get",
  "params": {}
}
```

- `id` 是页面生成的正整数，用于匹配回复。
- `method` 必须在 `welcome.methods` 中。
- `params` 必须是对象；没有参数时传 `{}`。

### 3.4 reply

内核 → 页面：

```json
{"v":1,"type":"reply","id":7,"ok":true,"result":{}}
```

```json
{
  "v": 1,
  "type": "reply",
  "id": 7,
  "ok": false,
  "error": {"code": "unknown_method", "message": "未知方法：nope"}
}
```

- `ok` 只表示**桥接层**是否成功。
- 设置域的业务失败通常仍是 `ok:true`，失败信息在 `result.success:false` + `result.code` 中。

### 3.5 event

内核 → 页面：

```json
{
  "v": 1,
  "type": "event",
  "name": "SettingsChanged",
  "data": {"key": "Frame155", "value": "180"}
}
```

没有数据的事件，`data` 为空对象 `{}`。

## 4. 方法

### 4.1 `app.getState`

获取当前应用状态。

**params**：`{}`

**result**：

```json
{
  "version": "v2.2.0",
  "locale": "zh-Hans",
  "theme": "auto",
  "engine": "web",
  "hotkeysEnabled": true
}
```

字段含义与 `welcome.app` 相同。

### 4.2 `settings.get`

读取当前设置工作副本的快照。

**params**：`{}`

**result**：

```json
{
  "values": {
    "Frame155": "180",
    "AutoExit": "0",
    "ClickDelay": "20",
    "SwitchHotkey": "<+MButton"
  },
  "customHotkeys": [
    {
      "key": "F8",
      "name": "自定义按键 1",
      "func": "click",
      "arg": "(0.5, 0.5)",
      "type": "global"
    }
  ],
  "hasGitHubToken": true
}
```

说明：

- `values` 是扁平键值表，来自经典界面的重要设置、自定义设置和热键设置。
- `Frame` 以 `Frame155` 暴露；页面应使用 `Frame155` 读写。
- **不返回 `GitHubToken`**，只返回 `hasGitHubToken` 布尔值。
- `customHotkeys` 当前只读，`type` 取值为 `global | combat | quick | strongHold`；`func` 目前只有 `click`。
- 值通常是字符串（INI 形态）；页面自行转换为数字/布尔值。
- 快照读取的是内存工作副本，因此会包含尚未保存的草稿。保存/应用/取消后建议重新调用 `settings.get`，因为宿主会做归一化（帧率、热键大小写、主题、语言、路径等）。

### 4.3 `settings.setDraft`

修改草稿，只写内存，不落盘。

**params**：

```json
{"key": "ClickDelay", "value": "60"}
```

- `key` 必须是 `settings.get` 返回的键。
- `value` 必须是标量；建议前端转成字符串。
- `Frame` / `Frame155` 必须是 `30, 60, 90, 120, 144, 165, 180, 240+` 之一。
- `ThemeMode` 会立即 `Theme.Preview`；`UiEngine` / `Language` 在保存/应用后生效。
- `UiEngine` 变更可能在保存/应用后触发 AFA 重启；页面不要假设之后仍存活，重启后重新握手。
- `GitHubToken` 是只读键，不能写；需要修改 Token 时由后续专门接口处理。
- `customHotkeys` 暂不支持通过本接口编辑。

**成功**：

```json
{"success":true,"key":"ClickDelay","value":"60"}
```

`Frame155` 会以 `Frame` 内部键存储，返回的 `key` 仍是 `Frame155`。

**失败**：

```json
{"success":false,"code":"invalid_value","message":"非法帧率：999"}
```

常见 `code`：

| code | 含义 |
|---|---|
| `bad_request` | 缺少 key/value，或 value 不是标量 |
| `invalid_value` | 值不合法（如非法帧率） |
| `read_only` | 键只读（如 `GitHubToken`） |
| `unknown_key` | 键不存在或不可写 |
| `busy` | 已有保存/应用/取消操作在进行 |

### 4.4 `settings.save`

请求保存。经典界面保存后会关闭设置窗口；Web 页面由页面自己决定是否关闭。

**params**：`{}`

**成功受理**：

```json
{"started":true}
```

**忙**：

```json
{"started":false,"code":"busy","message":"已有设置操作进行中"}
```

`started:true` 只表示请求已受理，**不表示保存成功**。最终结果看事件：

- `SettingsSaveStarting`
- 成功：`SettingsSaved`
- 失败：`SettingsActionFailed`（`mode:"save"`）

保存仍会显示原生 MessageBox；页面不要只依赖弹窗判断结果。

### 4.5 `settings.apply`

请求保存但不结束设置流程。

**params**：`{}`

返回与 `settings.save` 相同，成功时最终事件为 `SettingsApplied`，失败时为 `SettingsActionFailed`（`mode:"apply"`）。

### 4.6 `settings.cancel`

放弃草稿，重新加载持久化配置。

**params**：`{}`

返回 `{started:true}` 或 `{started:false, code:"busy"}`。

取消成功后会收到：

1. `SettingsViewRefreshRequested`：建议重新调用 `settings.get`
2. `SettingsCancelled`

取消失败（异常）会收到 `SettingsActionFailed`，`mode:"cancel"`。

### 4.7 `i18n.get`

按 key 批量取当前语言翻译。

**params**：

```json
{"keys": ["保存", "应用", "取消"]}
```

`keys` 可省略；省略时返回当前语言和空 `values`。

**成功**：

```json
{
  "success": true,
  "locale": "zh-Hans",
  "values": {
    "保存": "保存",
    "应用": "应用",
    "取消": "取消"
  }
}
```

**失败**：

```json
{"success":false,"code":"key_too_long","message":"翻译键过长"}
```

限制：

- 每次最多 512 个 key。
- 单个 key 最长 128 字符。
- key 必须是字符串；缺失 key 回退到中文原文，并可能记录一次警告。
- 语言切换后，页面会收到 `LocaleChanged`，应重新调用 `i18n.get`。

## 5. 事件

| 事件 | data | 触发时机 |
|---|---|---|
| `SettingsChanged` | `{key, value}` | 单键持久化变更（如热键动作、自动识别路径），不是每次 `setDraft` |
| `SettingsSaveStarting` | `{}` | 保存/应用开始校验前 |
| `SettingsSaved` | `{}` | 保存成功 |
| `SettingsApplied` | `{}` | 应用成功 |
| `SettingsCancelled` | `{}` | 取消成功 |
| `SettingsViewRefreshRequested` | `{}` | 需要重新读取设置快照（取消/重置等） |
| `SettingsActionFailed` | `{mode:"save"\|"apply"\|"cancel"}` | 保存/应用/取消的终止失败 |
| `LocaleChanged` | `{locale, previous}` | 界面语言变化 |

补充：

- `SettingsChanged` 的 `key` 已经过白名单过滤；`Frame` 会转成 `Frame155`；`value` 是宿主读取的规范化值。
- 保存/应用的终止事件只有一个：成功是 `SettingsSaved` / `SettingsApplied`，失败是 `SettingsActionFailed`。页面应在终止事件后清理 busy 状态。
- 取消会先发 `SettingsViewRefreshRequested`，再发 `SettingsCancelled`。
- 原生 MessageBox 的显示时机与事件不保证严格先后；以事件作为状态机依据。
- 事件只在 `ready` 之后发送；`ready` 之前的事件会被丢弃。

## 6. 保存/应用/取消的状态机

```text
页面                         宿主
 │── save/apply/cancel ──────▶│
 │◀─ reply {started:true} ────│
 │                            │  busy = true
 │◀─ SettingsSaveStarting ────│  （仅 save/apply）
 │                            │  校验、原生提示、持久化
 │◀─ SettingsSaved/Applied ───│  成功（cancel 为 SettingsCancelled）
 │◀─ SettingsActionFailed ────│  失败
 │                            │  busy = false
```

约定：

- 同一时间只允许一个 save/apply/cancel。
- busy 期间：
  - `settings.save/apply/cancel` 返回 `started:false, code:"busy"`；
  - `settings.setDraft` 返回 `success:false, code:"busy"`；
  - `settings.get` / `app.getState` 仍可读取。
- `started:false` 不应触发任何后续事件，页面可以提示用户稍后再试。
- `SettingsSaveStarting` 可以用来进入“保存中”界面状态；终止事件用来退出。
- 修改 `UiEngine` 时，保存/应用可能触发 AFA 重启；页面可能来不及收到终止事件，重启后重新握手。
- 保存/应用仍会显示原生 MessageBox，这是当前版本的已知限制，不是失败信号。

## 7. 错误码

### 桥接层（`reply.ok:false`）

| code | 含义 |
|---|---|
| `unsupported_version` | 协议版本不匹配 |
| `unknown_method` | 方法不在白名单 |
| `bad_request` | 请求格式错误，或 `params` 不是对象 |
| `internal` | 方法执行异常 |

### 设置域（`reply.ok:true` 但 `result.success:false`）

| code | 出现位置 |
|---|---|
| `bad_request` | `settings.setDraft` / `i18n.get` 参数错误 |
| `invalid_value` | `settings.setDraft` 值非法 |
| `read_only` | `settings.setDraft` 写入只读键 |
| `unknown_key` | `settings.setDraft` 键不可写 |
| `busy` | `settings.setDraft` 或保存动作被忙状态拒绝 |
| `too_many_keys` | `i18n.get` 超过 512 个 key |
| `key_too_long` | `i18n.get` 单个 key 超过 128 字符 |

## 8. 安全与限制

- 只处理来源为 `https://afa.app/` 的消息。
- 顶层导航只允许本地虚拟源，外部导航会被取消；页面内不要依赖外部页面跳转。
- 方法必须命中 `_Methods` 白名单，不提供任意 `EventBus` 或脚本执行入口。
- `GitHubToken` 不返回给页面，只返回 `hasGitHubToken`。
- 消息使用 JSON；页面传对象，宿主回 `PostWebMessageAsJson`。
- `i18n.get` 有 key 数量和长度上限；`I18n` 缺失键去重表也有上限。
- 页面运行在 AFA 进程的 WebView2 中，不假设普通浏览器 API 可用。

## 9. 前端接入示例

下面是最小桥接层示意；生产代码建议拆成 `app/js/bridge.js`，并处理页面刷新、超时和错误展示。

```js
const webview = window.chrome?.webview;
const pending = new Map();
const handlers = new Map();
let nextId = 0;

export const ready = new Promise((resolve) => {
  const onMessage = (event) => {
    if (event.data?.type === 'welcome') {
      webview.removeEventListener('message', onMessage);
      resolve(event.data);
    }
  };
  webview.addEventListener('message', onMessage);
  webview.postMessage({ v: 1, type: 'ready' });
});

export function call(method, params = {}) {
  return new Promise((resolve, reject) => {
    const id = ++nextId;
    pending.set(id, { resolve, reject });
    webview.postMessage({ v: 1, type: 'call', id, method, params });
    setTimeout(() => {
      if (pending.delete(id))
        reject(new Error(`timeout: ${method}`));
    }, 10000);
  });
}

export function on(name, handler) {
  if (!handlers.has(name))
    handlers.set(name, new Set());
  handlers.get(name).add(handler);
  return () => handlers.get(name)?.delete(handler);
}

webview.addEventListener('message', (event) => {
  const message = event.data;
  if (message?.type === 'reply' && pending.has(message.id)) {
    const request = pending.get(message.id);
    pending.delete(message.id);
    if (message.ok)
      request.resolve(message.result);
    else
      request.reject(new Error(message.error?.message ?? 'request failed'));
    return;
  }
  if (message?.type === 'event') {
    for (const handler of handlers.get(message.name) ?? [])
      handler(message.data);
  }
});
```

调用示例：

```js
await ready;
const state = await call('app.getState');
const settings = await call('settings.get');
await call('settings.setDraft', { key: 'ClickDelay', value: '60' });
const accepted = await call('settings.save');
if (!accepted.started)
  console.warn('保存未受理：', accepted.code);
```

注意：

- 页面刷新后要重新 `ready` 并重新挂事件；旧 `pending` 不应继续使用。
- 不要把 `event.data` 当字符串再次 `JSON.parse`，它已经是对象。
- 不要把 `reply.ok` 当作业务成功；检查 `result.success` / `started`。
- 当前设置页仍是占位页；真实控件应在后续 UI slice 中接入。

## 10. 类型定义（参考）

```ts
type Reply<T> =
  | { v: 1; type: 'reply'; id: number; ok: true; result: T }
  | { v: 1; type: 'reply'; id: number; ok: false; error: { code: string; message: string } };

type EventMessage = {
  v: 1;
  type: 'event';
  name: string;
  data: Record<string, unknown>;
};

type AppState = {
  version: string;
  locale: string;
  theme: 'auto' | 'light' | 'dark';
  engine: 'web' | 'classic';
  hotkeysEnabled: boolean;
};

type SettingsSnapshot = {
  values: Record<string, string>;
  customHotkeys: Array<{
    key: string;
    name: string;
    func: 'click';
    arg: string;
    type: 'global' | 'combat' | 'quick' | 'strongHold';
  }>;
  hasGitHubToken: boolean;
};
```

## 11. 版本与维护

- 协议版本在每条消息的 `v` 字段中；当前为 `1`。
- 新增方法或事件属于向后兼容扩展，更新 `welcome.methods` 和本文档即可；破坏性变更需提升 `v`。
- 新增方法时，宿主在 `WebBridge._Methods` 注册，页面通过 `welcome.methods` 判断可用性。
- 新增事件时，页面应忽略未知事件名，避免旧页面因新事件崩溃。
- 本文档是面向人的契约；实现以 [`web_bridge.ahk`](../../src/lib/ui/web/web_bridge.ahk) 和 [`web_settings.ahk`](../../src/lib/ui/web/web_settings.ahk) 为准。两者不一致时，以源码为准并修正本文档。

## 12. 相关文件

- [`src/lib/ui/web/web_bridge.ahk`](../../src/lib/ui/web/web_bridge.ahk) — 协议、方法白名单、事件转发、安全边界
- [`src/lib/ui/web/web_settings.ahk`](../../src/lib/ui/web/web_settings.ahk) — 快照、草稿、保存/应用/取消、忙状态
- [`src/lib/ui/web/app/index.html`](../../src/lib/ui/web/app/index.html) — 当前占位页
- [`docs/design/module_responsibilities.md`](../design/module_responsibilities.md) — WebBridge / WebSettings 职责
- [`docs/design/reference.md`](../design/reference.md) — 事件清单
