# AHK v2 规则与易错点

适用范围：当前仓库内所有 `.ahk` 文件。

目标：把 AHK v2 最容易写错的语法、调用方式和本项目特有约定固定下来，减少以后修改时的低级错误。

## 1. 统一使用 v2，不写 v1 旧语法

必须：

```ahk
MsgBox("text")
Run("notepad.exe")
```

不要写：

```ahk
MsgBox, text
Run, notepad.exe
```

结论：
- 所有能力都按“函数/方法调用”来写。
- 调用时默认带圆括号。
- 不引入任何 v1 兼容写法。

## 2. 类实例化不用 `new`

当前项目统一按 v2 写法直接调用类名：

```ahk
appLogger := Logger(logDir)
wp := WindowPicker(cfg, appLogger)
```

不要混入旧习惯：

```ahk
appLogger := new Logger(logDir)
```

## 3. 对象属性和 Map 键必须区分

普通对象或类实例：

```ahk
if obj.HasProp("name")
    value := obj.name
```

`Map`：

```ahk
if deps.Has("cfg")
    cfg := deps["cfg"]
```

高频错误：
- `Map` 上误写 `HasProp`
- 普通对象上误写 `Has`

## 4. 数组是 1 基索引

正确：

```ahk
first := arr[1]
last := arr[arr.Length]
```

不要按 JS/Python 的 0 基思维写 `arr[0]`。

## 5. 输出参数、引用参数调用要写 `&`

正确：

```ahk
MouseGetPos(&x, &y)
if this.playback.FindPic(imageName, hwnd, &x, &y, region, "测试", simValue) {
    ; ...
}
```

规则：
- 需要接收输出变量时，调用点显式写 `&var`
- 看到 `WinGetPos`, `MouseGetPos`, `PixelSearch`, 自定义输出参数函数时先确认是否需要 `&`

## 6. 回调必须传函数对象，不传字符串标签

正确：

```ahk
Hotkey("*LButton", this.lButtonFn, "On")
SetTimer(this.timerFn, 50)
guiObj.OnEvent("Close", OnGuiClose)
```

常见来源：
- 先 `Bind(this)` 得到方法回调
- `ObjBindMethod(obj, "Method")`
- 箭头函数 `() => ...`

不要再按旧式 label 思维传字符串去驱动逻辑。

## 7. GUI 事件默认会带参数，不用就用 `(*)`

推荐：

```ahk
BtnRunToggle(*) {
    StartBot()
}
```

原因：
- `OnEvent` 会传控件对象、事件信息等参数
- 如果函数签名不匹配，容易报错

经验：
- 不关心参数时，直接用 `(*)`
- 需要参数时，再按实际事件签名显式声明

## 8. 条件判断优先写清楚，不依赖模糊真值

推荐：

```ahk
if !hwnd
    return

if (result != "Yes")
    return false

if (script && script.type = type)
    return true
```

建议：
- 涉及字符串结果时，尽量显式比较
- 复杂条件加圆括号，减少误读

## 9. 字符串拼接统一用 `.`，不要省略

推荐：

```ahk
msg := "当前窗口：" . title . "`n进程：" . exeName
```

虽然某些上下文可隐式拼接，但项目里统一显式写 `.`，可读性更高，也更不容易出错。

## 10. 路径不要依赖当前工作目录

推荐：

```ahk
source := FileRead(A_ScriptDir "\..\Main.ahk", "UTF-8")
```

规则：
- 相对路径从 `A_ScriptDir` 推导
- 涉及测试、子脚本、外部工具时，不要假设调用者当前目录正确

## 11. 热键和窗口绑定必须考虑权限一致性

这是这个项目的硬约束。

规则：
- 目标程序若是管理员权限，脚本也必须管理员权限运行
- 否则可能出现“普通窗口能绑定，游戏窗口无法绑定”
- 提权入口统一在选窗前执行，不要等到绑定失败后再补救

推荐模式：

```ahk
if !A_IsAdmin
    return EnsureAdminForWindowBinding()
```

## 12. 读取窗口信息必须包 `try...catch`

这是当前仓库已经验证过的关键规则。

正确：

```ahk
try {
    title := WinGetTitle("ahk_id " hwnd)
    exeName := WinGetProcessName("ahk_id " hwnd)
} catch as err {
    title := "<无法读取标题>"
    exeName := "<权限不足或窗口失效>"
}
```

原因：
- UAC 权限隔离时，这类调用可能抛 `TargetError`
- 如果异常出现在 `SetTimer` 回调里，整段轮询逻辑会失效

## 13. 已拿到句柄时，统一用 `ahk_id`

推荐：

```ahk
winTitle := "ahk_id " hwnd
WinActivate(winTitle)
```

不要已经拿到句柄后又回退到标题匹配，因为：
- 标题可能变
- 同类窗口可能重名
- 句柄最稳定

## 14. 坐标系必须显式说明

当前项目默认：

```ahk
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"
```

规则：
- 录制、找图、点击、OCR 框选前确认坐标系
- 若某模块改成客户区坐标，必须在模块内注释说明
- 不允许屏幕坐标和客户区坐标混着传

## 15. 定时器要保留回调引用，停止时明确关闭

推荐：

```ahk
this.timerFn := this.PickTimer.Bind(this)
SetTimer(this.timerFn, 50)

; 停止
SetTimer(this.timerFn, 0)
```

规则：
- 对象方法回调先保存到成员变量
- 停止时传同一个函数对象
- 一次性定时器用负数周期，例如 `-200`

## 16. 变量命名不要和类名撞车

AHK 变量名大小写不敏感，类名/全局变量重名会带来很隐蔽的问题。

推荐：

```ahk
global mainUiActionBridgeService := MainUiActionBridge()
```

不要写：

```ahk
global mainUiActionBridge := MainUiActionBridge()
```

原因：
- 与类名仅大小写不同，在 AHK 里仍可能冲突或引发误判

## 17. 模块接口优先返回对象，缺失时返回统一空值风格

当前仓库常见模式：

```ahk
raw := super.LoadScript(name)
if !raw
    return ""
```

建议：
- 一个模块内保持返回风格一致
- 若返回对象前要访问属性，先判空、再判 `HasProp`

## 18. 编写本项目 AHK 代码时的建议顺序

每次修改前，先按这个顺序过一遍：

1. 确认是不是 AHK v2 写法
2. 确认当前数据是对象、数组还是 `Map`
3. 确认是否涉及 `&` 输出参数
4. 确认回调是不是函数对象
5. 确认坐标系和窗口定位方式
6. 确认是否存在管理员/UAC 风险
7. 确认定时器和窗口信息读取是否有异常保护

## 19. 本项目新增 AHK 代码的推荐模板

```ahk
#Requires AutoHotkey v2.0

class DemoService {
    __New(deps) {
        this.cfg := deps.Has("cfg") ? deps["cfg"] : ""
        this.logger := deps.Has("logger") ? deps["logger"] : ""
    }

    Run(*) {
        hwnd := this.cfg.HasProp("Window") && this.cfg.Window.HasProp("Hwnd")
            ? this.cfg.Window.Hwnd
            : 0
        if !hwnd
            return false

        try {
            WinActivate("ahk_id " hwnd)
            return true
        } catch as err {
            return false
        }
    }
}
```

## 20. 联查入口

相关文档：
- `docs/reference/ahk-v2-api.md`
- `docs/reference/ahk-v2-templates.md`
- `README.md`

官方文档：
- https://www.autohotkey.com/docs/v2/
