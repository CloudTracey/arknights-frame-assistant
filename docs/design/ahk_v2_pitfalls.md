# AHK v2 语言陷阱合集

> AGENTS.md 参考资料分册。**这些条目全部只关乎语法/API 事实，与项目业务无关**，聚在一处便于查阅。
> 危险项（静默出错、运行才炸、容易写出隐性 bug）已同步进 [AGENTS.md 铁律速查](../../AGENTS.md#铁律速查新代码必须遵守)。

## 异常与删除类

### `FileDelete`/`Map.Delete`/`HasOwnProp`

`FileDelete` 对不存在的文件会抛异常，与 `Map.Delete` 同类，删除前必须先 `FileExist`/`Has` 判断；普通对象属性检测用 `HasOwnProp`，Map 键检测才用 `Has`（原子 INI entries 是普通对象）。

### `Map.Delete` 陷阱

AHK v2 的 `Map.Delete(key)` 对不存在的键抛 `UnsetItemError`（`Item has no value`），删除前需 `Has` 检查（带默认值参数的是 `Get`，`Delete` 没有）。

## 文件 IO

### `File.Read` 只接受 1 参数

AHK v2 的 `File.Read(Characters)` 只读字符串，不支持 v1 的 `Read(&Buffer, Count)` 二参形式——传 2 参会抛 `Too many parameters passed to function.`。读原始字节到 Buffer 须用 `File.RawRead(&Buffer, Bytes)`（返回实际读取字节数）；哈希等二进制读取建议分块流式，避免大文件整体载入内存。

## 函数与回调

### AHK 箭头函数限制与函数名引用

AHK v2 的箭头函数 `(p) => expr` **只支持单一表达式，不支持 `{ }` 语句块**——多行逻辑需用**嵌套函数闭包**实现（`Functions.htm#closures`：在函数内 `Name(params) { ... }`，捕获外层局部变量即闭包，可用于 Hotkey 回调）。

另外 `ActionCallbacks` 等 Map 里的 `Fn: ActionBack` 存的是**函数引用（Func 对象）**而非字符串——AHK v2 中函数定义即同名只读变量、其值即 Func 对象，可直接 `Fn(ThisHotkey)` 调用（`Hotkey` 回调同样接受函数对象）。AHK v2 的 `Func()` 只接受**函数名字符串**，对函数对象套 `IsObject(fn) ? fn : Func(fn)` 规范化是死代码（v1 残留认知），空 `catch` 还会掩盖动作内部真实异常（修复见 `core/hotkey/hotkey_service.ahk` 的 `_WrapAction`）。

### 回调/定时器/热键按函数对象身份匹配

（`custom_key_editor.ahk` 拾取会话）

`SetTimer` 的启动与取消必须用**同一函数对象**（缓存 `ObjBindMethod` 结果到静态属性），每次新建对象会导致取消失效、定时器永不停歇；`HotIf`/`Hotkey` 的注册/注销同样按**条件对象**区分热键变体，条件必须用唯一实例（如静态箭头函数属性）。销毁 `Gui` 前先置空引用：销毁瞬间仍在跑的轮询/条件回调访问 `Gui.Hwnd` 会抛 `Gui has no window`。

### `SetTimer Func, 0` 是解除定时器

AHK v2 中它取消待触发的回调、**不调用函数**；与 `SetTimer Func, -8000`（一次性定时调用）含义不同，勿混淆（曾有审查误判"0 会触发回调"）。

### 线程优先级与事件丢弃

AHK 优先级规则是"**新线程优先级低于当前线程才不能中断**"，且低优先级事件按下会被**直接丢弃（not buffered）**而非排队（`misc/Threads.htm#Priority`）。`Thread "Critical"` 因能缓冲事件而优于调 Priority；`Thread "NoTimers"` 只挡定时器、放行热键。线程层面的选用原则见 [key_designs_hotkey.md](key_designs_hotkey.md#ahk-线程优先级-vs-criticalnotimers)。

## 数值与比较

### AHK 数值比较陷阱

`=`/`!=`（大小写不敏感）与 `==`/`!==`（大小写敏感）只有在**至少一侧是数字（Number）**时才做数值比较（此时另一侧可转数字、空串按 0，实测 `0.0 = ""` 为真）；**两侧都是字符串**时永远按字符串（字典序）比较（实测 `"0" != ""` 为真、`"0" = ""` 为假）——判"是否数字"用 `IsNumber`，判"是否空串"用 `StrLen(value) = 0`，**不要用 `= ""`/`!= ""` 参与数值真值判断**；`<`/`<=`/`>`/`>=` 强制数值比较（非数值抛 "Expected a Number but got a String"），字符串排序/字典序比较必须用 `StrCompare`。

### AHK v2 没有范围运算符

`for i in 1..5` 不是 v2 语法——`1..5` 会被解析为对 Float 取属性 `"5"`，**编译不报错**，运行时报 `This value of type "Float" has no property named "5"`（#283 debug 实测踩坑）。循环用 `loop 5` + `A_Index`，或数组字面量（如 `[1,2,3,4,5]`）；不要使用 `..` 连写。

## GUI 控件

### `DropDownList.Value` 陷阱

AHK v2 的 `DropDownList.Value` **始终使用索引**（1-based），与 `AltSubmit` 无关。`AltSubmit` 只影响 `Gui.Submit()` 的返回值格式（有→索引，无→文本）。如果下拉框去掉 `AltSubmit` 以让 Submit 返回文本，赋值 `.Value` 时仍需传索引，需做文本→索引转换。

### AHK 控件无 `Destroy()`

Gui 控件对象没有 `Destroy`/`Delete` 方法（只有 `Gui` 窗口可 `Destroy()`）；Text 控件改 `.Value` **不会**自动重新量宽（需 `Move`）。"测量后重定位"一律用临时 Gui 窗口或 `GetPos` + `Move`。

## Send 与钩子

### Send 注入会触发热键

AHK 的 Send 命令注入的按键事件默认会被自身钩子捕获并触发热键——回调内"Send 同键"必须加防递归标志，且**须键级作用域**。详见 [key_designs_hotkey.md](key_designs_hotkey.md#send-注入会触发热键)。

### Send 的 CapsLock 与修饰键副作用

非 Blind Send 会改写 CapsLock 并释放-重注入物理按住的修饰键。详见 [key_designs_hotkey.md](key_designs_hotkey.md#send-的-capslock-与修饰键副作用)。
