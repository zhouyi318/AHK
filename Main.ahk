#Requires AutoHotkey v2.0
#SingleInstance Force

; ====================================================================
; 传奇私服挂机脚本 - 可视化 GUI 主界面（AutoHotkey v2）
; --------------------------------------------------------------------
; 提供 4 个标签页：窗口选择 / 进图脚本 / 存仓设置 / 运行控制
; 依赖 lib\ 目录下的各模块，直接 #Include 使用：
;   Config / Logger / ImageHelper / WindowPicker / Recorder
;   / ScriptStore / Player / Bot
;
; 设计说明：
;   * 全局对象 g 统一保存 GUI 控件引用与编辑器状态，函数内读写其
;     属性无需 global 声明（g 本身为全局变量，仅读取、不重新赋值）。
;   * 模块对象 cfg/appLogger/img/store/playback/wp/rec/botRunner 为全局变量。
;   * 录制时 g.steps 为步骤缓冲区，停止录制后保存为脚本。
; ====================================================================

; 鼠标与像素坐标统一使用屏幕坐标系（前台模式）
CoordMode "Mouse", "Screen"
CoordMode "Pixel", "Screen"

; ===== 加载模块 =====
#Include lib\Config.ahk
#Include lib\Logger.ahk
#Include lib\ImageHelper.ahk
#Include lib\WindowPicker.ahk
#Include lib\RegionPicker.ahk
#Include lib\Recorder.ahk
#Include lib\StepRecorders.ahk
#Include lib\ScriptStore.ahk
#Include lib\ScriptRepository.ahk
#Include lib\FlowRepository.ahk
#Include lib\Player.ahk
#Include lib\StepSchema.ahk
#Include lib\StepRunner.ahk
#Include lib\FlowRunner.ahk
#Include lib\TextRecognizer.ahk
#Include lib\ScriptEditor.ahk
#Include lib\GuiHelper.ahk
#Include lib\ManualTools.ahk
#Include lib\Bot.ahk

class MainUiActionBridge {
    PickWindow(*) {
        BtnPickWindow()
    }

    RunBot(*) {
        BtnRunToggle()
    }
}

; GUI 共享状态容器
global g := {}

; ===== 初始化全局对象 =====
global cfg := Config(A_ScriptDir "\config\config.ini")
global appLogger := Logger(A_ScriptDir "\" cfg.Paths.LogDir)
global img := ImageHelper()
global store := ScriptRepository(A_ScriptDir "\" cfg.Paths.ScriptsDir)
global flowRepo := FlowRepository(A_ScriptDir "\" cfg.Paths.ScriptsDir "\flows")
global playback := Player(img, cfg, appLogger)
global ocrRecognizer := TextRecognizer(appLogger)
global wp := WindowPicker()
global regionTool := RegionPicker()
global rec := Recorder()
global stepRecorderService := StepRecorders(rec)
global stepRunnerService := StepRunner(playback, ocrRecognizer, appLogger)
global flowRunnerService := FlowRunner(stepRunnerService, store, appLogger)
global mainUiActionBridgeService := MainUiActionBridge()
appLogger.Info("启动来源 | script=" . A_ScriptFullPath . " | ahk=" . A_AhkPath . " | version=" . A_AhkVersion)
global manualToolService := ""
appLogger.Info("准备创建 ManualTools | script=" . A_ScriptFullPath . " | manualTools=" . A_ScriptDir "\lib\ManualTools.ahk")
try {
    manualToolService := ManualTools(Map(
        "cfg", cfg,
        "logger", appLogger,
        "playback", playback,
        "ocrRecognizer", ocrRecognizer,
        "regionTool", regionTool,
        "guiState", g,
        "onBotSimChanged", "InitWindowState"
    ))
    appLogger.Info("ManualTools 创建成功")
} catch as err {
    msg := "ManualTools 创建失败"
        . " | message=" . SafeErrorField(err, "Message")
        . " | what=" . SafeErrorField(err, "What")
        . " | file=" . SafeErrorField(err, "File")
        . " | line=" . SafeErrorField(err, "Line")
        . " | extra=" . SafeErrorField(err, "Extra")
        . " | stack=" . StrReplace(SafeErrorField(err, "Stack"), "`n", " || ")
    appLogger.Error(msg)
    throw err
}
global scriptEditorWorkspace := ScriptEditor(Map(
    "cfg", cfg,
    "logger", appLogger,
    "repo", store,
    "flowRepo", flowRepo,
    "runner", stepRunnerService,
    "flowRunner", flowRunnerService,
    "schema", StepSchema,
    "recorders", stepRecorderService,
    "manualTools", manualToolService,
    "onPickWindow", ObjBindMethod(mainUiActionBridgeService, "PickWindow"),
    "onRunBot", ObjBindMethod(mainUiActionBridgeService, "RunBot"),
    "onTestRegionFind", ObjBindMethod(manualToolService, "HandleTestRegionFind"),
    "onTestRegionOcr", ObjBindMethod(manualToolService, "HandleTestRegionOcr"),
    "onPreviewRegionOcr", ObjBindMethod(manualToolService, "HandlePreviewRegionOcr"),
    "onSetSim", ObjBindMethod(manualToolService, "HandleSetGlobalSim")
))
global botRunner := Bot(cfg, appLogger, playback, store, stepRunnerService)

appLogger.Info("传奇挂机脚本启动（可视化 GUI 版）")

; ===== 注册全局热键 =====
Hotkey(cfg.Hotkey.StartStop, HotkeyStartStop)
Hotkey(cfg.Hotkey.EmergencyStop, HotkeyEmergencyStop)

; ===== 构建 GUI 并初始化 =====
BuildGui()
InitGuiState()
g.gui.Show("w1360 h900")

; UI 刷新定时器（状态 + 日志），500ms 一次
SetTimer(SyncRunUI, 500)
SyncRunUI()

TrayTip("传奇挂机脚本已就绪", cfg.Hotkey.StartStop " 启动/暂停  |  " cfg.Hotkey.EmergencyStop " 急停")
return  ; 自动执行段结束，后续为函数定义


; ====================================================================
; ======================  GUI 构建  ==================================
; ====================================================================

SafeErrorField(err, name) {
    if IsObject(err) && err.HasProp(name)
        return err.%name%
    return ""
}

BuildGui() {
    g.gui := scriptEditorWorkspace.Build()
    g.gui.OnEvent("Close", OnGuiClose)
}


; ====================================================================
; =====================  初始化 GUI 状态  ============================
; ====================================================================

InitGuiState() {
    g.recording := false
    g.lastLogSize := -1
    InitWindowState()
    list := store.ListScripts()
    if (list.Length > 0) {
        scriptEditorWorkspace.LoadScriptByName(list[1])
    }
    if IsObject(flowRepo) {
        flowList := flowRepo.ListFlows()
        if (flowList.Length > 0)
            scriptEditorWorkspace.LoadFlowByName(flowList[1])
    }
}

InitWindowState() {
    ex := cfg.Window.ExeName
    tt := cfg.Window.Title
    hw := cfg.Window.Hwnd
    summary := "窗口: " . (tt = "" ? "(未选择)" : tt)
        . " | 进程: " . (ex = "" ? "(未选择)" : ex)
        . " | 句柄: " . ((hw = "" || hw = "0") ? "(未选择)" : hw)
        . " | 分辨率: " . cfg.Window.ExpectedWidth . "x" . cfg.Window.ExpectedHeight
        . " | 相似度: " . Format("{:.2f}", cfg.Bot.Sim)
    scriptEditorWorkspace.SetWindowSummary(summary)
}


; ====================================================================
; ===================  标签页1：窗口选择  ============================
; ====================================================================

BtnPickWindow(*) {
    appLogger.Info("开始选择游戏窗口")
    wp.Start(OnWindowPicked)
}

; WindowPicker 回调签名：callback(hwnd, exeName, title, w, h)
; 注意 Config.SaveWindow 参数顺序为 (exeName, title, hwnd, w, h)
OnWindowPicked(hwnd, exeName, title, w, h) {
    cfg.SaveWindow(exeName, title, hwnd, w, h)
    InitWindowState()
    appLogger.Info("已选择窗口: " . title . " (" . exeName . ") " . w . "x" . h)
}


; ====================================================================
; ===================  工具与手动测试  ===============================
; ====================================================================
; ====================================================================
; ===================  运行控制  =====================================
; ====================================================================

BtnRunToggle(*) {
    if (botRunner.IsRunning())
        StopBot()
    else
        StartBot()
}

StartBot() {
    if (cfg.Window.Hwnd = "" || cfg.Window.Hwnd = "0") {
        MsgBox("请先在「窗口选择」页选择游戏窗口。", "提示")
        return
    }
    if (!botRunner.Start()) {
        MsgBox("启动失败，请检查游戏窗口是否已选择并在前台。", "提示")
        return
    }
    appLogger.Info("用户点击开始挂机")
    SyncRunUI()
}

StopBot() {
    botRunner.Stop()
    appLogger.Info("用户点击停止挂机")
    SyncRunUI()
}

; 热键回调：启动/暂停 切换
HotkeyStartStop(*) {
    if (botRunner.IsRunning())
        StopBot()
    else
        StartBot()
}

; 热键回调：急停
HotkeyEmergencyStop(*) {
    StopBot()
}

; 定时刷新运行界面：状态文本、按钮文案、日志窗口
SyncRunUI() {
    scriptEditorWorkspace.SetRunState("当前状态：" . StateText(botRunner.state))
    if scriptEditorWorkspace.HasProp("btnRunBot")
        scriptEditorWorkspace.btnRunBot.Text := botRunner.IsRunning() ? "停止挂机" : "开始挂机"
    RefreshLog()
}

; 把 bot.state 状态码转为中文描述
StateText(s) {
    m := Map(
        "CheckTown", "检测土城",
        "RunEnterScript", "执行进图脚本",
        "VerifyMap", "校验地图",
        "EnableAutoFight", "开启挂机",
        "Monitoring", "挂机监测中",
        "StoreItems", "存仓中",
        "HandleDisconnect", "处理掉线",
        "HandleDead", "处理死亡",
        "Idle", "空闲")
    if m.Has(s)
        return m[s]
    return s
}

; 读取日志文件末尾若干行显示到日志框（文件大小未变化则跳过）
RefreshLog() {
    try {
        size := FileGetSize(appLogger.logPath)
    } catch {
        return
    }
    if (size = g.lastLogSize)
        return
    g.lastLogSize := size
    try {
        content := FileRead(appLogger.logPath, "UTF-8")
    } catch {
        return
    }
    lines := StrSplit(content, "`n", "`r")
    n := lines.Length
    start := n - 39
    if (start < 1)
        start := 1
    out := ""
    i := start
    while (i <= n) {
        out .= (lines[i] . "`n")
        i += 1
    }
    scriptEditorWorkspace.SetLogText(out)
}


; ====================================================================
; =======================  窗口关闭  =================================
; ====================================================================

OnGuiClose(*) {
    if (botRunner.IsRunning())
        botRunner.Stop()
    ExitApp()
}
