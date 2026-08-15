# AHK v2 API 速查

适用范围：当前仓库内的 AutoHotkey v2 脚本开发。

目标：给这个项目提供一份本地可查的 AHK v2 常用 API 参考，优先覆盖当前仓库高频场景，而不是照搬整站官方文档。

官方基线：
- AutoHotkey v2.0.26
- 官方入口：https://www.autohotkey.com/docs/v2/

使用原则：
- 遇到不确定语义时，以官方文档为准。
- 日常开发优先先查本文，再查官方详细页。
- 本项目统一按 AHK v2 写法，不使用 v1 命令式旧语法。

## 1. 脚本基础

### 必备指令

```ahk
#Requires AutoHotkey v2.0
#SingleInstance Force
```

常用内置变量：
- `A_ScriptDir`: 当前脚本目录
- `A_ScriptFullPath`: 当前脚本完整路径
- `A_AhkPath`: AutoHotkey 可执行文件路径
- `A_Args`: 启动参数数组
- `A_IsAdmin`: 当前脚本是否管理员权限
- `A_TickCount`: 开机后毫秒数，常用于生成简单唯一 ID

常用流程函数：
- `ExitApp(code := 0)`: 退出脚本
- `Sleep ms`: 阻塞等待
- `Run target`: 启动程序或命令
- `TrayTip title, text`: 托盘提示
- `MsgBox(text, title?, options?)`: 弹窗确认

示例：

```ahk
if !A_IsAdmin {
    MsgBox("请以管理员权限运行", "提示", "Icon!")
    ExitApp()
}
```

## 2. 函数与回调

### 函数定义

```ahk
QuoteCliArg(value) {
    return '"' StrReplace(value, '"', '\"') '"'
}
```

### 可变参数或忽略事件参数

```ahk
BtnRunToggle(*) {
    ; GUI 事件回调里常见写法，忽略框架传入参数
}
```

### 绑定对象方法

```ahk
fn := ObjBindMethod(service, "HandleClick")
fn.Call()
```

适用场景：
- `Gui.OnEvent(...)`
- `Hotkey(...)`
- `SetTimer(...)`
- 模块间回调桥接

## 3. 定时器

`SetTimer(Function, Period, Priority?)`

规则：
- `Function` 必须是函数对象或可调用对象
- `Period > 0`: 循环执行
- `Period < 0`: 只执行一次
- `Period = 0`: 停止并删除该定时器

项目高频用法：

```ahk
SetTimer(SyncRunUI, 500)
SetTimer(() => ExitApp(), -200)

this.timerFn := this.PickTimer.Bind(this)
SetTimer(this.timerFn, 50)
SetTimer(this.timerFn, 0)
```

注意：
- 传空值会报错，不能把空变量当回调传进去。
- 如果是对象方法，先 `Bind(this)` 再传给 `SetTimer`。

## 4. 热键与按键输入

### 注册热键

```ahk
Hotkey(cfg.Hotkey.StartStop, HotkeyStartStop)
Hotkey("*LButton", this.lButtonFn, "On")
Hotkey("Escape", this.escapeFn, "On")
Hotkey("Enter", "Off")
```

相关能力：
- `Hotkey(keyName, callback?, options?)`: 动态注册/启停热键
- `GetKeyState(keyName, "P")`: 读取物理按键状态
- `Send keys`: 发送按键
- `Click options?`: 模拟点击
- `MouseMove x, y, speed?`: 移动鼠标

项目经验：
- 游戏窗口可能吞掉热键钩子，必要时用 `GetKeyState(..., "P")` + `SetTimer` 轮询兜底。
- 热键动作依赖管理员权限时，脚本权限必须与目标窗口一致。

## 5. 坐标系统

项目默认使用屏幕坐标：

```ahk
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
```

相关 API：
- `CoordMode TargetType, RelativeTo`
- `MouseGetPos &x, &y, &winHwnd?, &control?`

建议：
- 录制、找图、取色、点位点击前先确认当前坐标系。
- 若某流程改成客户区坐标，要在对应模块里显式说明，不要混用。

## 6. 窗口操作

这是当前仓库最常用的一组 API。

### 常用函数

- `WinExist(winTitle?)`: 查询窗口
- `WinActivate(winTitle)`: 激活窗口
- `WinWaitActive(winTitle, text?, timeout?)`: 等待窗口激活
- `WinGetTitle(winTitle)`: 取窗口标题
- `WinGetProcessName(winTitle)`: 取进程名
- `WinGetPos &x, &y, &w, &h, winTitle?`: 取窗口位置和大小
- `WinGetID(winTitle?)`: 获取窗口句柄
- `ControlClick control?, winTitle?, text?, button?, clickCount?, options?`: 控件点击

通过句柄定位窗口的标准写法：

```ahk
hwnd := cfg.Window.Hwnd
WinActivate("ahk_id " hwnd)
title := WinGetTitle("ahk_id " hwnd)
exeName := WinGetProcessName("ahk_id " hwnd)
```

项目约定：
- 只要已经拿到句柄，就优先用 `"ahk_id " hwnd`。
- 读取游戏窗口标题、进程名等信息时必须允许失败，外围加 `try...catch`。

## 7. GUI

### 创建与显示

```ahk
guiObj := Gui(, "统一脚本编辑器")
guiObj.SetFont("s10")
guiObj.BackColor := "FFFFFF"
guiObj.Add("Text",, "ok")
guiObj.Show("w200 h100")
```

### 常用方法

- `Gui(Options?, Title?)`: 创建窗口
- `gui.Add(Type, Options?, Text?)`: 添加控件
- `gui.Show(Options?)`: 显示窗口
- `gui.Hide()`: 隐藏窗口
- `gui.Destroy()`: 销毁窗口
- `gui.OnEvent(Name, Callback)`: 绑定 GUI 事件
- `control.OnEvent(Name, Callback)`: 绑定控件事件

项目高频模式：

```ahk
g.gui := scriptEditorWorkspace.Build()
g.gui.OnEvent("Close", OnGuiClose)
```

建议：
- GUI 控件引用统一放进全局状态对象，例如 `g.xxx`。
- 事件回调不需要参数时，用 `(*)` 吞掉。

## 8. 对象、数组、Map

### 对象字面量

```ahk
step := {
    id: "step_" A_TickCount,
    type: type,
    enabled: true
}
```

### 数组

```ahk
names := []
names.Push("demo")
count := names.Length
```

### Map

```ahk
deps := Map(
    "cfg", cfg,
    "logger", appLogger
)

if deps.Has("cfg")
    this.cfg := deps["cfg"]
```

常用判断：
- `IsObject(value)`: 是否对象
- `obj.HasProp("name")`: 普通对象/类实例是否有属性
- `map.Has("key")`: `Map` 是否有某键

注意：
- 数组是 1 基索引，不是 0 基。
- 对象属性检查和 `Map` 键检查不是一回事，别混用。

## 9. 文件与配置

当前项目配置与脚本存储常用这些 API：
- `FileRead(path, encoding?)`
- `FileAppend(text, path, encoding?)`
- `FileExist(path)`
- `DirCreate(path)`
- `IniRead(file, section, key?, default?)`
- `IniWrite(value, file, section, key)`

示例：

```ahk
source := FileRead(A_ScriptDir "\..\Main.ahk", "UTF-8")
```

建议：
- 涉及中文内容时尽量显式指定 `UTF-8`。
- 相对路径优先从 `A_ScriptDir` 或项目根目录推导，不要依赖当前工作目录。

## 10. 异常处理

AHK v2 统一使用异常模型，很多系统调用失败时会直接抛错。

示例：

```ahk
try {
    title := WinGetTitle("ahk_id " hwnd)
    exeName := WinGetProcessName("ahk_id " hwnd)
} catch as err {
    title := "<无法读取标题>"
    exeName := "<权限不足或窗口失效>"
}
```

常用形式：
- `throw Error("message")`
- `try { ... } catch as err { ... }`

项目强约定：
- 读取窗口信息时必须允许权限失败。
- 定时器线程里更要避免未捕获异常，否则会中断选窗或轮询逻辑。

## 11. DLL 与系统调用

AHK v2 可直接调 Win32 API：

```ahk
DllCall("SystemParametersInfo", "UInt", 0x0057, "UInt", 0, "Ptr", 0, "UInt", 0)
```

建议：
- 参数类型写完整，避免隐式类型转换。
- 仅在标准 AHK API 无法满足时再用 `DllCall`。

## 12. 本项目最常用 API 清单

按仓库实际使用频率整理：

- 启动与流程：`Run`, `ExitApp`, `Sleep`, `SetTimer`, `TrayTip`, `MsgBox`
- 权限与参数：`A_IsAdmin`, `A_AhkPath`, `A_ScriptFullPath`, `A_Args`
- 热键输入：`Hotkey`, `GetKeyState`, `Send`, `Click`, `MouseMove`
- 坐标：`CoordMode`, `MouseGetPos`
- 窗口：`WinActivate`, `WinWaitActive`, `WinGetTitle`, `WinGetProcessName`, `WinExist`
- GUI：`Gui`, `Add`, `Show`, `Destroy`, `OnEvent`, `SetFont`
- 数据结构：`Array`, `Map`, `IsObject`, `HasProp`
- 文件配置：`FileRead`, `FileAppend`, `IniRead`, `IniWrite`, `DirCreate`
- 异常与系统：`try`, `catch`, `Error`, `DllCall`

## 13. 推荐联查顺序

写这个项目时，优先按这个顺序查：

1. 先看 `docs/reference/ahk-v2-rules.md`
2. 再看本文的 API 分组
3. 再看 `docs/reference/ahk-v2-templates.md`
4. 再看当前模块相邻实现
5. 最后查官方文档：https://www.autohotkey.com/docs/v2/
