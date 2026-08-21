# AHK v2 项目模板库

适用范围：当前仓库内的 AutoHotkey v2 开发。

目标：提供一组可直接复制、按需替换的项目级模板，减少重复造轮子，也避免写出不符合本仓库约定的 AHK v2 代码。

使用顺序建议：

1. 先看 `docs/reference/ahk-v2-rules.md`
2. 再查 `docs/reference/ahk-v2-api.md`
3. 最后从本文复制最接近的模板落地

---

## 1. 新模块类模板

适用场景：
- 新增一个服务类
- 通过 `Map` 注入依赖
- 需要和 `Main.ahk` 现有初始化风格保持一致

模板：

```ahk
#Requires AutoHotkey v2.0

class DemoService {
    __New(deps) {
        this.deps := deps
        this.cfg := deps.Has("cfg") ? deps["cfg"] : ""
        this.logger := deps.Has("logger") ? deps["logger"] : ""
        this.guiState := deps.Has("guiState") ? deps["guiState"] : ""
    }

    Run(*) {
        if !this.cfg
            return false
        return true
    }
}
```

替换点：
- `DemoService` 改为真实模块名
- `deps` 中只保留真正需要的依赖
- 公开方法优先用 `(*)` 兼容 GUI/回调调用

推荐搭配：
- 在 `Main.ahk` 中用 `global demoService := DemoService(Map(...))` 初始化

---

## 2. Main 中注册服务模板

适用场景：
- 在入口脚本里创建全局服务对象
- 需要给 GUI 或其他模块传回调

模板：

```ahk
global demoService := DemoService(Map(
    "cfg", cfg,
    "logger", appLogger,
    "guiState", g
))
```

如果要传方法回调：

```ahk
global workspace := SomeUi(Map(
    "onRunDemo", ObjBindMethod(demoService, "Run")
))
```

建议：
- 全局变量名不要和类名大小写相近
- 回调优先传 `ObjBindMethod(...)` 结果，不传字符串

---

## 3. GUI 事件处理模板

适用场景：
- 按钮点击
- GUI 关闭
- 不关心事件参数

模板：

```ahk
BuildGui() {
    g.gui := Gui(, "示例窗口")
    g.gui.SetFont("s10")
    g.gui.OnEvent("Close", OnGuiClose)

    btnRun := g.gui.Add("Button", "w120", "执行")
    btnRun.OnEvent("Click", BtnRunDemo)
}

BtnRunDemo(*) {
    MsgBox("开始执行")
}

OnGuiClose(*) {
    ExitApp()
}
```

建议：
- GUI 控件引用统一收口到 `g`
- 事件函数如果不使用参数，一律 `(*)`

---

## 4. 定时器模板

适用场景：
- 周期刷新 UI
- 轮询按键状态
- 一次性延迟执行

### 简单函数定时器

```ahk
SetTimer(SyncRunUI, 500)

SyncRunUI() {
    ; 刷新状态
}
```

### 类方法定时器

```ahk
class DemoPoller {
    __New() {
        this.timerFn := ""
    }

    Start() {
        this.timerFn := this.Tick.Bind(this)
        SetTimer(this.timerFn, 100)
    }

    Stop() {
        if this.timerFn
            SetTimer(this.timerFn, 0)
    }

    Tick() {
        ; 轮询逻辑
    }
}
```

### 一次性定时器

```ahk
SetTimer(() => ExitApp(), -200)
```

关键规则：
- 对象方法先 `Bind(this)` 再传
- 停止时传同一个函数对象
- 一次性执行用负数周期

---

## 5. 热键注册模板

适用场景：
- 全局热键
- 临时热键
- 模式进入/退出时动态开关热键

### 启动时注册全局热键

```ahk
Hotkey(cfg.Hotkey.StartStop, HotkeyStartStop)
Hotkey(cfg.Hotkey.EmergencyStop, HotkeyEmergencyStop)

HotkeyStartStop(*) {
    MsgBox("切换运行")
}

HotkeyEmergencyStop(*) {
    MsgBox("急停")
}
```

### 类中启用/停用临时热键

```ahk
class DemoMode {
    __New() {
        this.enterFn := ""
        this.escapeFn := ""
    }

    Start() {
        this.enterFn := this.OnEnter.Bind(this)
        this.escapeFn := this.OnEscape.Bind(this)
        Hotkey("Enter", this.enterFn, "On")
        Hotkey("Escape", this.escapeFn, "On")
    }

    Stop() {
        Hotkey("Enter", "Off")
        Hotkey("Escape", "Off")
    }

    OnEnter(*) {
    }

    OnEscape(*) {
        this.Stop()
    }
}
```

建议：
- 临时模式类把回调保存到成员变量
- 退出模式时记得把热键关掉

---

## 6. 窗口绑定前权限检查模板

适用场景：
- 需要绑定游戏窗口
- 需要访问管理员权限窗口

模板：

```ahk
EnsureAdminForWindowBinding() {
    if A_IsAdmin
        return true

    result := MsgBox(
        "当前脚本不是管理员权限运行。`n`n"
        . "目标窗口可能是管理员权限，是否现在提权重启？",
        "需要管理员权限",
        "YesNo Icon!"
    )
    if (result != "Yes")
        return false
    return RelaunchScriptAsAdmin()
}

RelaunchScriptAsAdmin() {
    args := ""
    for _, arg in A_Args
        args .= " " QuoteCliArg(arg)
    try {
        Run('*RunAs "' A_AhkPath '" "' A_ScriptFullPath '"' args)
        ExitApp()
    } catch {
        MsgBox("自动提升权限失败，请手动以管理员身份运行。", "权限提升失败", "Iconx")
    }
    return false
}

QuoteCliArg(value) {
    return '"' StrReplace(value, '"', '\"') '"'
}
```

关键规则：
- 选窗前先检查，不要绑定失败后再补救
- 提权时把原有参数带上

---

## 7. 读取窗口信息模板

适用场景：
- 获取标题、进程名、客户区大小
- 定时器里轮询鼠标下窗口

模板：

```ahk
ReadWindowInfo(hwnd) {
    if !hwnd
        return ""

    try {
        title := WinGetTitle("ahk_id " hwnd)
        exeName := WinGetProcessName("ahk_id " hwnd)
        WinGetClientPos(&cx, &cy, &cw, &ch, "ahk_id " hwnd)
        return {title: title, exeName: exeName, width: cw, height: ch}
    } catch as err {
        return {
            title: "Unknown",
            exeName: "Unknown",
            width: 0,
            height: 0
        }
    }
}
```

关键规则：
- 已有句柄时统一用 `"ahk_id " hwnd`
- 外围必须有 `try...catch`

---

## 8. 选窗器类模板

适用场景：
- 模仿当前项目的窗口选择器
- 鼠标悬停实时提示，点击或回车确认

模板骨架：

```ahk
class DemoWindowPicker {
    __New() {
        this.picking := false
        this.timerFn := ""
        this.callback := ""
        this.enterFn := ""
        this.escapeFn := ""
    }

    Start(callback) {
        if this.picking
            return
        this.callback := callback
        this.picking := true
        this.timerFn := this.PickTimer.Bind(this)
        this.enterFn := this.OnEnter.Bind(this)
        this.escapeFn := this.OnEscape.Bind(this)
        SetTimer(this.timerFn, 100)
        Hotkey("Enter", this.enterFn, "On")
        Hotkey("Escape", this.escapeFn, "On")
    }

    Stop() {
        if !this.picking
            return
        this.picking := false
        if this.timerFn
            SetTimer(this.timerFn, 0)
        Hotkey("Enter", "Off")
        Hotkey("Escape", "Off")
        ToolTip
    }

    PickTimer() {
        MouseGetPos(&mx, &my, &hwnd)
        if hwnd
            ToolTip("当前窗口句柄: " . hwnd)
    }

    OnEnter(*) {
        MouseGetPos(&mx, &my, &hwnd)
        if hwnd && this.callback
            this.callback.Call(hwnd)
        this.Stop()
    }

    OnEscape(*) {
        this.Stop()
    }
}
```

如果要做成当前项目完整版，直接参考：
- `lib/WindowPicker.ahk`

---

## 9. 区域框选模板

适用场景：
- 在绑定窗口客户区内拖拽框选区域
- 需要把屏幕坐标转客户区坐标

模板骨架：

```ahk
class DemoRegionPicker {
    __New() {
        this.active := false
        this.dragging := false
        this.hwnd := 0
        this.callback := ""
        this.lbDownFn := ""
        this.lbUpFn := ""
        this.escapeFn := ""
        this.timerFn := ""
    }

    Start(hwnd, callback) {
        if !hwnd || !WinExist("ahk_id " hwnd)
            return false
        this.hwnd := hwnd
        this.callback := callback
        this.active := true
        this.lbDownFn := this.OnLButtonDown.Bind(this)
        this.lbUpFn := this.OnLButtonUp.Bind(this)
        this.escapeFn := this.OnEscape.Bind(this)
        this.timerFn := this.UpdateTooltip.Bind(this)
        Hotkey("*LButton", this.lbDownFn, "On")
        Hotkey("*LButton Up", this.lbUpFn, "On")
        Hotkey("Escape", this.escapeFn, "On")
        SetTimer(this.timerFn, 30)
        return true
    }

    Stop(invokeCallback := false) {
        SetTimer(this.timerFn, 0)
        Hotkey("*LButton", "Off")
        Hotkey("*LButton Up", "Off")
        Hotkey("Escape", "Off")
        this.active := false
    }

    OnLButtonDown(*) {
        ; 记录起点
    }

    OnLButtonUp(*) {
        ; 结束框选并回调
    }

    UpdateTooltip() {
        ; 实时刷新提示和覆盖层
    }
}
```

如果要做成当前项目完整版，直接参考：
- `lib/RegionPicker.ahk`

---

## 10. 配置读取与写回模板

适用场景：
- 从 `ini` 加载配置
- 回写窗口、区域、相似度等设置

模板：

```ahk
class DemoConfig {
    __New(iniPath) {
        this.iniPath := iniPath
        this.Bot := {}
        this.Bot.Sim := Float(IniRead(iniPath, "Bot", "Sim", "0.75"))
    }

    SaveBotSim(sim) {
        simValue := this.NormalizeSim(sim)
        IniWrite(simValue, this.iniPath, "Bot", "Sim")
        this.Bot.Sim := Float(simValue)
    }

    NormalizeSim(sim) {
        try value := Float(sim)
        catch
            value := 0.75
        if (value < 0.10)
            value := 0.10
        if (value > 1.00)
            value := 1.00
        return Format("{:.2f}", value)
    }
}
```

如果要保持当前仓库风格，优先参考：
- `lib/Config.ahk`

原因：
- 当前项目不是简单 `IniRead/IniWrite` 即可，已有更完整的 section 批量写回逻辑

---

## 11. FindPic / OCR 前的窗口准备模板

适用场景：
- 手动测试找图
- OCR 识别前确保目标窗口激活

模板：

```ahk
PrepareTargetWindow(hwnd) {
    if !hwnd
        return false
    WinActivate("ahk_id " hwnd)
    try WinWaitActive("ahk_id " hwnd, , 1)
    Sleep 150
    return true
}
```

建议：
- 找图/OCR 前统一走这个准备动作
- 游戏窗口常对前台状态敏感，别直接跳过激活

---

## 12. 日志 + 异常保护模板

适用场景：
- 创建服务失败
- 调用外部依赖可能抛错
- 想把错误写全便于排查

模板：

```ahk
SafeErrorField(err, name) {
    if IsObject(err) && err.HasProp(name)
        return err.%name%
    return ""
}

try {
    service := DemoService(Map("cfg", cfg, "logger", appLogger))
    appLogger.Info("DemoService 创建成功")
} catch as err {
    msg := "DemoService 创建失败"
        . " | message=" . SafeErrorField(err, "Message")
        . " | what=" . SafeErrorField(err, "What")
        . " | file=" . SafeErrorField(err, "File")
        . " | line=" . SafeErrorField(err, "Line")
        . " | extra=" . SafeErrorField(err, "Extra")
    appLogger.Error(msg)
    throw err
}
```

建议：
- 初始化阶段异常尽量记录完整字段
- 定时器线程里异常至少要兜底，避免线程逻辑静默中断

---

## 13. 回调桥接模板

适用场景：
- GUI 模块不能直接依赖主流程函数
- 需要把 UI 动作桥接到 `Main.ahk`

模板：

```ahk
class MainUiActionBridge {
    PickWindow(*) {
        BtnPickWindow()
    }

    RunBot(*) {
        BtnRunToggle()
    }
}

global mainUiActionBridgeService := MainUiActionBridge()

global workspace := ScriptEditor(Map(
    "onPickWindow", ObjBindMethod(mainUiActionBridgeService, "PickWindow"),
    "onRunBot", ObjBindMethod(mainUiActionBridgeService, "RunBot")
))
```

关键规则：
- 变量名不要和类名只差大小写
- 回调桥接可以降低模块耦合

---

## 14. 常见替换清单

从模板复制到实际代码时，优先替换这些位置：

- 类名：`DemoService`、`DemoWindowPicker`、`DemoRegionPicker`
- 全局变量名：`demoService`
- 回调名：`Run`, `OnEnter`, `OnEscape`, `OnGuiClose`
- 配置路径：`iniPath`
- 句柄变量：`hwnd`
- UI 状态对象：`g`
- 日志对象：`appLogger`

---

## 15. 推荐复用路径

以后在这个项目里加功能，优先这样复用：

1. 新服务类：从“新模块类模板”开始
2. 新 GUI 按钮动作：从“GUI 事件处理模板”开始
3. 新轮询逻辑：从“定时器模板”开始
4. 新游戏窗口交互：从“窗口绑定前权限检查模板”与“读取窗口信息模板”开始
5. 新区域工具：从“区域框选模板”开始
6. 新配置项：从“配置读取与写回模板”开始

---

## 16. 对应现有实现

这些模板都能在现有仓库里找到对应落地版本：

- `lib/WindowPicker.ahk`
- `lib/RegionPicker.ahk`
- `lib/Config.ahk`
- `lib/ManualTools.ahk`
- `Main.ahk`

如果模板和业务需求不完全一致，优先按现有实现风格扩展，不要另起一套写法。
