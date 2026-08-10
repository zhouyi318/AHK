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
#Include lib\ScriptStore.ahk
#Include lib\Player.ahk
#Include lib\TextRecognizer.ahk
#Include lib\GuiHelper.ahk
#Include lib\Bot.ahk

; ===== 初始化全局对象 =====
global cfg := Config(A_ScriptDir "\config\config.ini")
global appLogger := Logger(A_ScriptDir "\" cfg.Paths.LogDir)
global img := ImageHelper()
global store := ScriptStore(A_ScriptDir "\" cfg.Paths.ScriptsDir)
global playback := Player(img, cfg, appLogger)
global ocrRecognizer := TextRecognizer(appLogger)
global wp := WindowPicker()
global regionTool := RegionPicker()
global rec := Recorder()
global botRunner := Bot(cfg, appLogger, playback, store)

; GUI 共享状态容器
global g := {}

appLogger.Info("传奇挂机脚本启动（可视化 GUI 版）")

; ===== 注册全局热键 =====
Hotkey(cfg.Hotkey.StartStop, HotkeyStartStop)
Hotkey(cfg.Hotkey.EmergencyStop, HotkeyEmergencyStop)

; ===== 构建 GUI 并初始化 =====
BuildGui()
InitGuiState()
g.gui.Show("w640 h520")

; UI 刷新定时器（状态 + 日志），500ms 一次
SetTimer(SyncRunUI, 500)
SyncRunUI()

TrayTip("传奇挂机脚本已就绪", cfg.Hotkey.StartStop " 启动/暂停  |  " cfg.Hotkey.EmergencyStop " 急停")
return  ; 自动执行段结束，后续为函数定义


; ====================================================================
; ======================  GUI 构建  ==================================
; ====================================================================

BuildGui() {
    MyGui := Gui(, "传奇挂机脚本 - 可视化控制台")
    MyGui.OnEvent("Close", OnGuiClose)
    g.gui := MyGui
    MyGui.SetFont("s10")

    ; 标签页控件（Section 作为后续 xs/ys 定位锚点）
    tab := MyGui.Add("Tab3", "w620 h450 Section", ["窗口选择", "进图脚本", "存仓设置", "运行控制"])

    ; ---------------- 标签页 1：窗口选择 ----------------
    tab.UseTab(1)
    g.btnPick := MyGui.Add("Button", "xs+15 ys+35 w240 h34", "◎ 选择游戏窗口")
    g.btnPick.OnEvent("Click", BtnPickWindow)
    MyGui.Add("Text", "xs+15 y+12 w590", "提示：点击按钮后，将鼠标移动到游戏窗口上点击即可锁定。")
    g.txtExeName     := MyGui.Add("Text", "xs+15 y+16 w590 h22", "")
    g.txtWinTitle    := MyGui.Add("Text", "xs+15 y+8 w590 h22", "")
    g.txtHwnd        := MyGui.Add("Text", "xs+15 y+8 w590 h22", "")
    g.txtResolution  := MyGui.Add("Text", "xs+15 y+8 w590 h22", "")
    g.txtAssetsDir   := MyGui.Add("Text", "xs+15 y+8 w590 h22", "")
    g.txtSim         := MyGui.Add("Text", "xs+15 y+8 w590 h22", "")
    g.btnSystemRegions := MyGui.Add("Button", "xs+15 y+14 w240 h34", "配置系统找图区域")
    g.btnSystemRegions.OnEvent("Click", BtnConfigSystemImageRegions)
    g.btnTestRegionFind := MyGui.Add("Button", "x+12 yp w240 h34", "测试区域找图")
    g.btnTestRegionFind.OnEvent("Click", BtnTestRegionFind)
    g.btnTestRegionOcr := MyGui.Add("Button", "xs+15 y+12 w240 h32", "测试区域 OCR 找字")
    g.btnTestRegionOcr.OnEvent("Click", BtnTestRegionOcr)
    g.btnPreviewRegionOcr := MyGui.Add("Button", "x+12 yp w240 h32", "查看区域 OCR 文本")
    g.btnPreviewRegionOcr.OnEvent("Click", BtnPreviewRegionOcr)
    g.btnSetSim := MyGui.Add("Button", "xs+15 y+12 w240 h32", "设置全局找图相似度")
    g.btnSetSim.OnEvent("Click", BtnSetGlobalSim)

    ; ---------------- 标签页 2：进图脚本 ----------------
    tab.UseTab(2)
    MyGui.Add("Text", "xs+15 ys+35 w70", "已有脚本:")
    g.ddlScripts := MyGui.Add("DropDownList", "x+5 yp w220", [])
    g.ddlScripts.OnEvent("Change", OnScriptChange)

    g.btnNewScript := MyGui.Add("Button", "xs+15 y+12 w90", "新建脚本")
    g.btnNewScript.OnEvent("Click", BtnNewScript)
    g.btnDelScript := MyGui.Add("Button", "x+8 yp w90", "删除脚本")
    g.btnDelScript.OnEvent("Click", BtnDeleteScript)
    g.btnRecord := MyGui.Add("Button", "x+8 yp w70", "录制")
    g.btnRecord.OnEvent("Click", BtnRecord)
    g.btnStopRec := MyGui.Add("Button", "x+8 yp w90", "停止录制")
    g.btnStopRec.OnEvent("Click", BtnStopRecord)
    g.btnTestPlay := MyGui.Add("Button", "x+8 yp w110", "测试回放当前")
    g.btnTestPlay.OnEvent("Click", BtnTestPlay)
    g.btnStopRec.Enabled := false

    g.btnAddWait := MyGui.Add("Button", "xs+15 y+10 w100", "+ 等待步骤")
    g.btnAddWait.OnEvent("Click", BtnAddWait)
    g.btnAddFindPic := MyGui.Add("Button", "x+8 yp w120", "+ 区域找图步骤")
    g.btnAddFindPic.OnEvent("Click", BtnAddFindPic)
    g.btnBindMap := MyGui.Add("Button", "x+8 yp w140", "绑定目标地图图")
    g.btnBindMap.OnEvent("Click", BtnBindMap)

    g.txtTargetMap := MyGui.Add("Text", "xs+15 y+10 w590 h20", "目标地图图: (未设置)")
    g.lvSteps := MyGui.Add("ListView", "xs+15 y+6 w590 h190", ["序号", "类型", "详情"])

    ; ---------------- 标签页 3：存仓设置 ----------------
    tab.UseTab(3)
    MyGui.Add("Text", "xs+15 ys+35 w120", "存仓间隔(分钟):")
    g.edtInterval := MyGui.Add("Edit", "x+5 yp w100 number", "60")
    MyGui.Add("Text", "xs+15 y+12 w590", "装备名截图需放在 assets 目录，文件名格式 item_<装备名>.bmp")
    g.lbItems := MyGui.Add("ListBox", "xs+15 y+10 w300 h170", [])
    g.btnAddItem := MyGui.Add("Button", "x+10 yp w110", "添加装备")
    g.btnAddItem.OnEvent("Click", BtnAddItem)
    g.btnDelItem := MyGui.Add("Button", "xp y+10 w110", "删除选中")
    g.btnDelItem.OnEvent("Click", BtnDeleteItem)
    g.btnSaveStore := MyGui.Add("Button", "xp y+10 w110", "保存配置")
    g.btnSaveStore.OnEvent("Click", BtnSaveStoreCfg)

    ; ---------------- 标签页 4：运行控制 ----------------
    tab.UseTab(4)
    g.btnRun := MyGui.Add("Button", "xs+15 ys+35 w260 h48", "▶ 开始挂机")
    g.btnRun.OnEvent("Click", BtnRunToggle)
    g.txtState := MyGui.Add("Text", "xs+15 y+12 w590 h24", "当前状态：空闲")
    MyGui.Add("Text", "xs+15 y+8 w590", "运行日志：")
    g.edtLog := MyGui.Add("Edit", "xs+15 y+6 w590 r12 ReadOnly", "")
    MyGui.Add("Text", "xs+15 y+10 w590 h40", "热键提示：" cfg.Hotkey.StartStop " 启动/暂停    " cfg.Hotkey.EmergencyStop " 急停")

    tab.UseTab()  ; 结束标签页关联
}


; ====================================================================
; =====================  初始化 GUI 状态  ============================
; ====================================================================

InitGuiState() {
    ; 编辑器缓冲区状态
    g.steps := []
    g.currentName := ""
    g.targetMapImage := ""
    g.targetMapRegion := ""
    g.recording := false
    g.lastLogSize := -1

    ; 标签页1：显示已保存的窗口信息
    InitWindowState()

    ; 标签页2：加载脚本列表，若存在则载入第一个
    RefreshScriptList()
    list := store.ListScripts()
    if (list.Length > 0) {
        g.ddlScripts.Choose(1)          ; Choose 不触发 Change 事件
        LoadScriptToEditor(list[1])
    }

    ; 标签页3：加载存仓配置
    g.storeCfg := store.LoadStoreConfig()
    g.edtInterval.Value := g.storeCfg.intervalMinutes
    RefreshItemsList()
}

InitWindowState() {
    ex := cfg.Window.ExeName
    tt := cfg.Window.Title
    hw := cfg.Window.Hwnd
    g.txtExeName.Text := "进程名: " . (ex = "" ? "(未选择)" : ex)
    g.txtWinTitle.Text := "窗口标题: " . (tt = "" ? "(未选择)" : tt)
    g.txtHwnd.Text := "句柄: " . ((hw = "" || hw = "0") ? "(未选择)" : hw)
    g.txtResolution.Text := "客户区分辨率: " . cfg.Window.ExpectedWidth . " x " . cfg.Window.ExpectedHeight
    g.txtAssetsDir.Text := "图片目录: " . A_ScriptDir "\" cfg.Paths.AssetsDir
    g.txtSim.Text := "全局找图相似度: " . Format("{:.2f}", cfg.Bot.Sim) . "（值越高越严格）"
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
    g.txtExeName.Text := "进程名: " . (exeName = "" ? "(未选择)" : exeName)
    g.txtWinTitle.Text := "窗口标题: " . (title = "" ? "(未选择)" : title)
    g.txtHwnd.Text := "句柄: " . ((hwnd = "" || hwnd = "0") ? "(未选择)" : hwnd)
    g.txtResolution.Text := "客户区分辨率: " . w . " x " . h
    appLogger.Info("已选择窗口: " . title . " (" . exeName . ") " . w . "x" . h)
}


; ====================================================================
; ===================  标签页2：进图脚本  ============================
; ====================================================================

; 下拉框切换脚本 -> 加载到编辑器
OnScriptChange(ctrl, *) {
    name := ctrl.Text
    if (name = "")
        return
    LoadScriptToEditor(name)
}

LoadScriptToEditor(name) {
    script := store.LoadScript(name)
    if (!script) {
        MsgBox("无法加载脚本: " . name, "提示")
        return
    }
    g.currentName := name
    g.steps := (script.HasProp("steps") && IsObject(script.steps)) ? script.steps : []
    g.targetMapImage := script.HasProp("targetMapImage") ? script.targetMapImage : ""
    g.targetMapRegion := script.HasProp("targetMapRegion") ? script.targetMapRegion : ""
    RefreshStepsListView()
    UpdateTargetMapText()
}

BtnNewScript(*) {
    if (g.recording) {
        MsgBox("请先停止录制再新建脚本。", "提示")
        return
    }
    ib := InputBox("请输入新脚本名称：", "新建脚本")
    if (ib.Result = "Cancel" || ib.Value = "")
        return
    g.currentName := ib.Value
    g.steps := []
    g.targetMapImage := ""
    g.targetMapRegion := ""
    RefreshStepsListView()
    UpdateTargetMapText()
    g.ddlScripts.Text := ""   ; 清除下拉框选择
    MsgBox("已新建空脚本「" . g.currentName . "」。`n点击「录制」开始记录操作，停止后自动保存。", "提示")
}

BtnDeleteScript(*) {
    name := g.ddlScripts.Text
    if (name = "") {
        MsgBox("请先在列表中选择要删除的脚本。", "提示")
        return
    }
    if (MsgBox("确定删除脚本「" . name . "」？", "确认", "YesNo") = "No")
        return
    store.DeleteScript(name)
    if (g.currentName = name) {
        g.currentName := ""
        g.steps := []
        g.targetMapImage := ""
        g.targetMapRegion := ""
        RefreshStepsListView()
        UpdateTargetMapText()
    }
    RefreshScriptList()
}

BtnRecord(*) {
    if (g.recording)
        return
    if (cfg.Window.Hwnd = "" || cfg.Window.Hwnd = "0" || !WinExist("ahk_id " cfg.Window.Hwnd)) {
        MsgBox("请先在「窗口选择」页绑定正在运行的游戏窗口。", "提示")
        return
    }
    if (g.currentName = "") {
        ib := InputBox("请输入新脚本名称：", "录制脚本")
        if (ib.Result = "Cancel" || ib.Value = "")
            return
        g.currentName := ib.Value
    }
    g.steps := []
    g.targetMapImage := ""
    g.targetMapRegion := ""
    RefreshStepsListView()
    UpdateTargetMapText()
    rec.Start(cfg.Window.Hwnd, OnRecordStep)
    g.recording := true
    g.btnRecord.Enabled := false
    g.btnStopRec.Enabled := true
    appLogger.Info("开始录制脚本: " . g.currentName)
}

BtnStopRecord(*) {
    if (!g.recording)
        return
    rec.Stop()
    g.recording := false
    g.btnRecord.Enabled := true
    g.btnStopRec.Enabled := false
    if (SaveCurrentScript()) {
        RefreshScriptList()
        SelectScriptInDDL(g.currentName)
        appLogger.Info("录制完成并保存: " . g.currentName . " (" . g.steps.Length . " 步)")
    }
}

BtnTestPlay(*) {
    if (g.recording) {
        MsgBox("请先停止录制，再测试回放。", "提示")
        return
    }
    if (cfg.Window.Hwnd = "" || cfg.Window.Hwnd = "0" || !WinExist("ahk_id " cfg.Window.Hwnd)) {
        MsgBox("请先在「窗口选择」页绑定正在运行的游戏窗口。", "提示")
        return
    }
    if (g.steps.Length = 0) {
        MsgBox("当前脚本没有可回放的步骤。", "提示")
        return
    }
    name := (g.currentName = "" ? "(未命名脚本)" : g.currentName)
    appLogger.Info("开始测试回放脚本: " . name)
    if playback.Play(g.steps, cfg.Window.Hwnd) {
        appLogger.Info("测试回放完成: " . name)
    } else {
        appLogger.Warn("测试回放失败: " . name)
        MsgBox("测试回放失败，请检查绑定窗口、脚本步骤和找图资源。", "提示")
    }
}

; 录制器每录到一步的回调：追加到 g.steps 并实时刷新 ListView
OnRecordStep(step) {
    g.steps.Push(step)
    g.lvSteps.Add("", g.steps.Length, step.type, StepDetail(step))
}

BtnAddWait(*) {
    if (!g.recording) {
        MsgBox("请先点击「录制」开始录制，再插入等待步骤。", "提示")
        return
    }
    ib := InputBox("请输入等待时间（毫秒）：", "插入等待步骤", , "1000")
    if (ib.Result = "Cancel" || ib.Value = "")
        return
    try {
        ms := Integer(ib.Value)
    } catch {
        MsgBox("请输入有效的整数毫秒数。", "提示")
        return
    }
    rec.AddWait(ms)   ; 内部会触发 OnRecordStep
}

BtnAddFindPic(*) {
    if (!g.recording) {
        MsgBox("请先点击「录制」开始录制，再插入找图步骤。", "提示")
        return
    }
    rec.SuspendCapture()
    try {
        stepInfo := ShowImageRegionDialog("添加区域找图步骤", "", 10000, "", true)
    } finally {
        rec.ResumeCapture()
    }
    if (!stepInfo)
        return
    rec.AddFindPic(stepInfo.image, stepInfo.timeout, stepInfo.region)   ; 内部会触发 OnRecordStep
}

BtnBindMap(*) {
    mapInfo := ShowImageRegionDialog("绑定目标地图图", g.targetMapImage, "", g.targetMapRegion, false, true)
    if (!mapInfo)
        return
    if (mapInfo.HasProp("clear") && mapInfo.clear) {
        g.targetMapImage := ""
        g.targetMapRegion := ""
    } else {
        g.targetMapImage := mapInfo.image
        g.targetMapRegion := mapInfo.region
    }
    UpdateTargetMapText()
    if (!g.recording && g.currentName != "")
        SaveCurrentScript()
    MsgBox("目标地图图已设置为：" . (g.targetMapImage = "" ? "(无)" : g.targetMapImage) . "  " . RegionSummary(g.targetMapRegion), "提示")
}

BtnConfigSystemImageRegions(*) {
    ShowSystemImageRegionManager()
}

BtnTestRegionFind(*) {
    if (cfg.Window.Hwnd = "" || cfg.Window.Hwnd = "0" || !WinExist("ahk_id " cfg.Window.Hwnd)) {
        MsgBox("请先在「窗口选择」页绑定正在运行的游戏窗口。", "提示")
        return
    }

    info := ShowImageRegionDialog("测试区域找图", "", "", "", false, false
        , "选择图片并框选区域后，立即测试这张图是否出现在当前绑定窗口里。浏览器场景建议先试 0.65 ~ 0.80。"
        , true, cfg.Bot.Sim)
    if (!info || (info.HasProp("clear") && info.clear))
        return

    imageName := info.image
    region := info.region
    simValue := info.HasProp("sim") ? info.sim : cfg.Bot.Sim
    WinActivate "ahk_id " cfg.Window.Hwnd
    try WinWaitActive("ahk_id " cfg.Window.Hwnd, , 1)
    Sleep 150
    if playback.FindPic(imageName, cfg.Window.Hwnd, &x, &y, region, "手动测试找图", simValue) {
        hitText := playback.HitPointText(cfg.Window.Hwnd, x, y)
        MsgBox("找图成功：`n图片: " . imageName . "`n命中: " . hitText . "`n区域: " . RegionSummary(region) . "`n相似度: " . Format("{:.2f}", simValue), "测试结果")
    } else {
        sweep := RunFindPicSimilaritySweep(imageName, region, simValue)
        if sweep.found {
            hitText := playback.HitPointText(cfg.Window.Hwnd, sweep.x, sweep.y)
            MsgBox("当前相似度 " . Format("{:.2f}", simValue) . " 失败，但在更低相似度命中了。`n`n图片: " . imageName . "`n命中: " . hitText . "`n区域: " . RegionSummary(region) . "`n可命中相似度: " . Format("{:.2f}", sweep.sim) . "`n已扫描: " . sweep.scannedText . "`n`n这说明更像是匹配度过高，建议把全局找图相似度调到 " . Format("{:.2f}", sweep.sim) . " 附近再验证。", "测试结果")
        } else {
            MsgBox("找图失败：`n图片: " . imageName . "`n区域: " . RegionSummary(region) . "`n起始相似度: " . Format("{:.2f}", simValue) . "`n已扫描: " . sweep.scannedText . "`n`n连更低相似度都没有命中，更可能不是简单的相似度问题，而是模板图本身不适合当前页面渲染。建议改截更小、更稳定的局部，优先截图标、边角特征，不要只截文字。", "测试结果")
        }
    }
}

BtnTestRegionOcr(*) {
    if (cfg.Window.Hwnd = "" || cfg.Window.Hwnd = "0" || !WinExist("ahk_id " cfg.Window.Hwnd)) {
        MsgBox("请先在「窗口选择」页绑定正在运行的游戏窗口。", "提示")
        return
    }

    info := ShowTextOcrDialog("测试区域 OCR 找字")
    if !info
        return

    WinActivate "ahk_id " cfg.Window.Hwnd
    try WinWaitActive("ahk_id " cfg.Window.Hwnd, , 1)
    Sleep 150

    result := ocrRecognizer.Recognize(cfg.Window.Hwnd, info.region, info.targetText, "手动 OCR 找字")
    if result.ok {
        displayText := ocrRecognizer.BuildDisplayText(result.text)
        if (result.reason = "NO_TEXT") {
            MsgBox("OCR 已执行，但这个区域里没有识别到可用文本。`n`n目标文本: " . info.targetText . "`n区域: " . RegionSummary(info.region) . "`n`n识别文本:`n" . displayText . "`n`n这通常说明框选区域太大/太小、文字太糊、颜色对比不够，或者刚好没框到字。", "测试结果")
        } else {
            matchedText := result.matched ? "命中" : "未命中"
            MsgBox("OCR 成功：`n目标文本: " . info.targetText . "`n匹配结果: " . matchedText . "`n区域: " . RegionSummary(info.region) . "`n`n识别文本:`n" . displayText, "测试结果")
        }
    } else {
        MsgBox("OCR 失败：`n目标文本: " . info.targetText . "`n区域: " . RegionSummary(info.region) . "`n错误: " . result.error, "测试结果")
    }
}

BtnPreviewRegionOcr(*) {
    if (cfg.Window.Hwnd = "" || cfg.Window.Hwnd = "0" || !WinExist("ahk_id " cfg.Window.Hwnd)) {
        MsgBox("请先在「窗口选择」页绑定正在运行的游戏窗口。", "提示")
        return
    }

    info := ShowTextOcrDialog("查看区域 OCR 文本", "", "", false)
    if !info
        return

    WinActivate "ahk_id " cfg.Window.Hwnd
    try WinWaitActive("ahk_id " cfg.Window.Hwnd, , 1)
    Sleep 150

    result := ocrRecognizer.Recognize(cfg.Window.Hwnd, info.region, "", "查看 OCR 文本")
    if !result.ok {
        MsgBox("OCR 失败：`n区域: " . RegionSummary(info.region) . "`n错误: " . result.error, "测试结果")
        return
    }
    ShowOcrPreviewResult(info.region, result)
}

BtnSetGlobalSim(*) {
    ib := InputBox("请输入全局找图相似度（0.10 ~ 1.00，值越高越严格）：", "设置找图相似度", , Format("{:.2f}", cfg.Bot.Sim))
    if (ib.Result = "Cancel" || Trim(ib.Value) = "")
        return
    try simValue := Float(Trim(ib.Value))
    catch {
        MsgBox("请输入有效的小数，例如 0.75。", "提示")
        return
    }
    if (simValue < 0.10 || simValue > 1.00) {
        MsgBox("相似度必须在 0.10 到 1.00 之间。", "提示")
        return
    }
    cfg.SaveBotSim(simValue)
    InitWindowState()
    appLogger.Info("已更新全局找图相似度: " . Format("{:.2f}", cfg.Bot.Sim))
    MsgBox("全局找图相似度已更新为 " . Format("{:.2f}", cfg.Bot.Sim) . "。", "提示")
}

RunFindPicSimilaritySweep(imageName, region, baseSim) {
    sims := BuildSimSweepList(baseSim)
    scannedText := JoinSimValues(sims)
    for _, simValue in sims {
        if playback.FindPic(imageName, cfg.Window.Hwnd, &x, &y, region, "手动测试找图扫描", simValue)
            return {found: true, sim: simValue, x: x, y: y, scannedText: scannedText}
    }
    return {found: false, scannedText: scannedText}
}

BuildSimSweepList(baseSim) {
    values := []
    seen := Map()
    AddSimCandidate(values, seen, baseSim)
    for _, candidate in [baseSim - 0.05, baseSim - 0.10, baseSim - 0.15, baseSim - 0.20, 0.50, 0.40, 0.30] {
        AddSimCandidate(values, seen, candidate)
    }
    return values
}

AddSimCandidate(values, seen, candidate) {
    if !(candidate is Number)
        return
    if (candidate < 0.10 || candidate > 1.00)
        return
    key := Format("{:.2f}", candidate)
    if seen.Has(key)
        return
    seen[key] := true
    values.Push(Float(key))
}

JoinSimValues(values) {
    text := ""
    for index, value in values {
        if (index > 1)
            text .= ", "
        text .= Format("{:.2f}", value)
    }
    return text
}

UpdateTargetMapText() {
    g.txtTargetMap.Text := "目标地图图: " . (g.targetMapImage = "" ? "(未设置)" : g.targetMapImage) . "  搜索区域: " . RegionSummary(g.targetMapRegion)
}

; 保存当前缓冲区为脚本（name/targetMapImage/steps）。无名称则弹框输入。
SaveCurrentScript() {
    if (g.currentName = "") {
        ib := InputBox("请输入脚本名称以保存：", "保存脚本")
        if (ib.Result = "Cancel" || ib.Value = "")
            return false
        g.currentName := ib.Value
    }
    script := {name: g.currentName, targetMapImage: g.targetMapImage, targetMapRegion: g.targetMapRegion, steps: g.steps}
    store.SaveScript(script)
    return true
}

RefreshScriptList() {
    list := store.ListScripts()
    g.ddlScripts.Delete()
    if (list.Length > 0)
        g.ddlScripts.Add(list)
}

; 在下拉框中选中指定脚本（用 Choose，不触发 Change 事件）
SelectScriptInDDL(name) {
    list := store.ListScripts()
    loop list.Length {
        if (list[A_Index] = name) {
            g.ddlScripts.Choose(A_Index)
            return
        }
    }
}

RefreshStepsListView() {
    g.lvSteps.Delete()
    n := g.steps.Length
    loop n {
        step := g.steps[A_Index]
        g.lvSteps.Add("", A_Index, step.type, StepDetail(step))
    }
    g.lvSteps.ModifyCol()   ; 自动调整列宽
}

; 把一个步骤对象转为可读详情
StepDetail(step) {
    switch step.type {
        case "click":
            return step.button . "键 (" . step.x . "," . step.y . ") 延迟" . step.delay . "ms"
        case "wait":
            return "等待 " . step.ms . "ms"
        case "findPic":
            region := step.HasProp("region") ? step.region : ""
            return "找图 " . step.image . " 区域" . RegionSummary(region) . " 超时" . step.timeout . "ms"
        default:
            return "(未知步骤)"
    }
}

ListAssetImages() {
    files := []
    assetsDir := A_ScriptDir "\" cfg.Paths.AssetsDir
    if !DirExist(assetsDir)
        return files
    loop files, assetsDir "\*.*" {
        ext := LTrim(StrLower(A_LoopFileExt), ".")
        if (ext = "bmp" || ext = "png" || ext = "jpg" || ext = "jpeg")
            files.Push(A_LoopFileName)
    }
    return files
}

NormalizeRegionObject(region) {
    if (!region || !IsObject(region))
        return ""
    x1 := Min(region.x1, region.x2)
    y1 := Min(region.y1, region.y2)
    x2 := Max(region.x1, region.x2)
    y2 := Max(region.y1, region.y2)
    return {x1: x1, y1: y1, x2: x2, y2: y2}
}

RegionSummary(region) {
    if (!region || !IsObject(region))
        return "(全窗口)"
    return "(" . region.x1 . "," . region.y1 . ")-(" . region.x2 . "," . region.y2 . ")"
}

SystemImageDefs() {
    return [
        {key: "Town", label: "土城检测图"},
        {key: "AutoFightBtn", label: "挂机按钮图"},
        {key: "AutoFightOn", label: "挂机已开启图"},
        {key: "ReturnStone", label: "回城石图"},
        {key: "Disconnect", label: "掉线重连图"},
        {key: "Dead", label: "死亡复活图"}
    ]
}

SystemImageLabel(imgKey) {
    for _, item in SystemImageDefs() {
        if (item.key = imgKey)
            return item.label
    }
    return imgKey
}

SystemImageSummaryText(imgKey) {
    imageName := cfg.Images.%imgKey%
    region := cfg.ImageRegions.%imgKey%
    return imageName . "  " . RegionSummary(region)
}

ShowSystemImageRegionManager() {
    dlg := Gui(, "系统找图区域配置")
    dlg.Opt("+Owner" g.gui.Hwnd)
    dlg.SetFont("s10")

    dlg.Add("Text", "xm ym w470 h36", "这些区域会用于 BOT 内置找图与点击。区域越聚焦，查找越快；留空则仍按整个绑定窗口搜索。")

    for _, item in SystemImageDefs() {
        dlg.Add("Text", "xm y+12 w120 h22", item.label . ":")
        txtSummary := dlg.Add("Text", "x+8 yp w260 h22", SystemImageSummaryText(item.key))
        btnEdit := dlg.Add("Button", "x+8 yp-4 w90", "设置区域")
        btnEdit.__imgKey := item.key
        btnEdit.__summaryCtrl := txtSummary
        btnEdit.OnEvent("Click", OnSystemImageRegionEdit)
    }

    btnClose := dlg.Add("Button", "xm y+18 w90 Default", "关闭")
    btnClose.OnEvent("Click", OnSystemRegionManagerClose)
    dlg.OnEvent("Close", OnSystemRegionManagerGuiClose)
    dlg.Show("AutoSize Center")
}

OnSystemImageRegionEdit(ctrl, *) {
    imgKey := ctrl.__imgKey
    currentRegion := cfg.ImageRegions.%imgKey%
    imageName := cfg.Images.%imgKey%
    info := ShowImageRegionDialog("设置" . SystemImageLabel(imgKey) . "区域", imageName, "", currentRegion, false, true)
    if (!info)
        return
    if (info.HasProp("clear") && info.clear)
        cfg.SaveImageRegion(imgKey, "")
    else
        cfg.SaveImageSetting(imgKey, info.image, info.region)
    ctrl.__summaryCtrl.Text := SystemImageSummaryText(imgKey)
    appLogger.Info("已更新系统找图区域: " . imgKey . " " . RegionSummary(cfg.ImageRegions.%imgKey%))
}

OnSystemRegionManagerClose(ctrl, *) {
    ctrl.Gui.Destroy()
}

OnSystemRegionManagerGuiClose(guiObj, *) {
    guiObj.Destroy()
}

ShowImageRegionDialog(title, defaultImage := "", defaultTimeout := "", initialRegion := "", requireTimeout := true, allowClear := false, tipText := "", allowSim := false, defaultSim := "") {
    if (cfg.Window.Hwnd = "" || cfg.Window.Hwnd = "0" || !WinExist("ahk_id " cfg.Window.Hwnd)) {
        MsgBox("请先在「窗口选择」页绑定正在运行的游戏窗口。", "提示")
        return ""
    }

    dlg := Gui(, title)
    dlg.Opt("+Owner" g.gui.Hwnd)
    dlg.SetFont("s10")

    state := {
        done: false,
        result: "",
        region: NormalizeRegionObject(initialRegion),
        requireTimeout: requireTimeout,
        prompt: requireTimeout ? "请在绑定窗口内拖拽框选找图搜索区域" : "请在绑定窗口内拖拽框选目标地图搜索区域"
    }
    dlg.__state := state

    dlg.Add("Text", "xm ym w80", "图片文件:")
    cmbImage := dlg.Add("ComboBox", "x+8 yp-3 w260", ListAssetImages())
    cmbImage.Text := defaultImage
    dlg.__cmbImage := cmbImage

    if (allowSim) {
        dlg.Add("Text", "xm y+14 w80", "相似度:")
        edtSim := dlg.Add("Edit", "x+8 yp-3 w120", defaultSim = "" ? Format("{:.2f}", cfg.Bot.Sim) : Format("{:.2f}", Float(defaultSim)))
        dlg.__edtSim := edtSim
    }

    if (requireTimeout) {
        dlg.Add("Text", "xm y+14 w80", "超时(ms):")
        edtTimeout := dlg.Add("Edit", "x+8 yp-3 w120 number", defaultTimeout = "" ? "10000" : String(defaultTimeout))
        dlg.__edtTimeout := edtTimeout
    }

    txtRegion := dlg.Add("Text", "xm y+14 w380", "搜索区域: " . RegionSummary(state.region))
    dlg.__txtRegion := txtRegion

    btnPick := dlg.Add("Button", "xm y+10 w120", "框选搜索区域")
    btnPick.OnEvent("Click", OnRegionDialogPick)

    btnOk := dlg.Add("Button", "xm y+18 w90 Default", "确定")
    btnOk.OnEvent("Click", OnImageRegionDialogOk)

    if (allowClear) {
        btnClear := dlg.Add("Button", "x+8 yp w90", "清除绑定")
        btnClear.OnEvent("Click", OnImageRegionDialogClear)
    }

    btnCancel := dlg.Add("Button", "x+8 yp w90", "取消")
    btnCancel.OnEvent("Click", OnImageRegionDialogCancel)
    dlg.OnEvent("Close", OnImageRegionDialogCancel)

    if (tipText = "") {
        tip := requireTimeout
            ? "建议：图片先选资源，再点“框选搜索区域”在绑定窗口内截定局部范围。"
            : "建议：目标地图图也尽量只框选小区域，地图校验会更快。"
    } else {
        tip := tipText
    }
    dlg.Add("Text", "xm y+14 w400 h36", tip)

    dlg.Show("AutoSize Center")
    while !state.done
        Sleep 30
    return state.result
}

ShowTextOcrDialog(title, defaultTargetText := "", initialRegion := "", requireTargetText := true) {
    if (cfg.Window.Hwnd = "" || cfg.Window.Hwnd = "0" || !WinExist("ahk_id " cfg.Window.Hwnd)) {
        MsgBox("请先在「窗口选择」页绑定正在运行的游戏窗口。", "提示")
        return ""
    }

    dlg := Gui(, title)
    dlg.Opt("+Owner" g.gui.Hwnd)
    dlg.SetFont("s10")

    state := {
        done: false,
        result: "",
        region: NormalizeRegionObject(initialRegion),
        prompt: "请在绑定窗口内拖拽框选要 OCR 的文字区域",
        requireTargetText: requireTargetText
    }
    dlg.__state := state

    if (requireTargetText) {
        dlg.Add("Text", "xm ym w80", "目标文本:")
        edtText := dlg.Add("Edit", "x+8 yp-3 w280", defaultTargetText)
        dlg.__edtText := edtText
    } else {
        dlg.Add("Text", "xm ym w400 h36", "框选一个区域后，直接查看 OCR 识别出的原始文本。这个模式不做命中判断，只负责把识别结果展示出来。")
    }

    txtRegion := dlg.Add("Text", "xm y+16 w380", "搜索区域: " . RegionSummary(state.region))
    dlg.__txtRegion := txtRegion

    btnPick := dlg.Add("Button", "xm y+10 w120", "框选文字区域")
    btnPick.OnEvent("Click", OnTextOcrDialogPick)

    btnOk := dlg.Add("Button", "xm y+18 w90 Default", "确定")
    btnOk.OnEvent("Click", OnTextOcrDialogOk)

    btnCancel := dlg.Add("Button", "x+8 yp w90", "取消")
    btnCancel.OnEvent("Click", OnTextOcrDialogCancel)
    dlg.OnEvent("Close", OnTextOcrDialogCancel)

    dlg.Add("Text", "xm y+14 w400 h36", "建议：只框住文字本身，尽量缩小区域。OCR 对纯文字按钮/NPC 名称比图片匹配更稳，但仍会受字号和遮挡影响。")

    dlg.Show("AutoSize Center")
    while !state.done
        Sleep 30
    return state.result
}

OnRegionDialogPick(ctrl, *) {
    dlg := ctrl.Gui
    state := dlg.__state
    if !regionTool.Start(cfg.Window.Hwnd, OnRegionDialogPicked.Bind(dlg), state.prompt)
        MsgBox("无法启动区域框选，请先确认绑定窗口存在。", "提示")
}

OnRegionDialogPicked(dlg, region) {
    state := dlg.__state
    state.region := NormalizeRegionObject(region)
    dlg.__txtRegion.Text := "搜索区域: " . RegionSummary(state.region)
}

OnImageRegionDialogOk(ctrl, *) {
    dlg := ctrl.Gui
    state := dlg.__state
    image := Trim(dlg.__cmbImage.Text)
    if (image = "") {
        MsgBox("请选择或输入图片文件名。", "提示")
        return
    }
    if (!state.region) {
        MsgBox("请先框选搜索区域。", "提示")
        return
    }

    result := {image: image, region: state.region}
    if dlg.HasProp("__edtSim") {
        try simValue := Float(Trim(dlg.__edtSim.Value))
        catch {
            MsgBox("请输入有效的相似度，例如 0.75。", "提示")
            return
        }
        if (simValue < 0.10 || simValue > 1.00) {
            MsgBox("相似度必须在 0.10 到 1.00 之间。", "提示")
            return
        }
        result.sim := simValue
    }
    if (state.requireTimeout) {
        try timeout := Integer(Trim(dlg.__edtTimeout.Value))
        catch {
            MsgBox("请输入有效的整数超时毫秒数。", "提示")
            return
        }
        if (timeout <= 0) {
            MsgBox("超时时间必须大于 0。", "提示")
            return
        }
        result.timeout := timeout
    }

    state.result := result
    state.done := true
    if (regionTool.active)
        regionTool.Stop(false)
    dlg.Destroy()
}

OnImageRegionDialogClear(ctrl, *) {
    dlg := ctrl.Gui
    state := dlg.__state
    state.result := {clear: true}
    state.done := true
    if (regionTool.active)
        regionTool.Stop(false)
    dlg.Destroy()
}

OnImageRegionDialogCancel(guiObj, *) {
    state := guiObj.__state
    state.done := true
    if (regionTool.active)
        regionTool.Stop(false)
    guiObj.Destroy()
}

OnTextOcrDialogPick(ctrl, *) {
    dlg := ctrl.Gui
    state := dlg.__state
    if !regionTool.Start(cfg.Window.Hwnd, OnTextOcrDialogPicked.Bind(dlg), state.prompt)
        MsgBox("无法启动区域框选，请先确认绑定窗口存在。", "提示")
}

OnTextOcrDialogPicked(dlg, region) {
    state := dlg.__state
    state.region := NormalizeRegionObject(region)
    dlg.__txtRegion.Text := "搜索区域: " . RegionSummary(state.region)
}

OnTextOcrDialogOk(ctrl, *) {
    dlg := ctrl.Gui
    state := dlg.__state
    targetText := ""
    if (state.requireTargetText) {
        targetText := Trim(dlg.__edtText.Value)
        if (targetText = "") {
            MsgBox("请输入要匹配的目标文本。", "提示")
            return
        }
    }
    if (!state.region) {
        MsgBox("请先框选文字区域。", "提示")
        return
    }

    state.result := {targetText: targetText, region: state.region}
    state.done := true
    if (regionTool.active)
        regionTool.Stop(false)
    dlg.Destroy()
}

ShowOcrPreviewResult(region, result) {
    dlg := Gui(, "OCR 识别文本")
    dlg.Opt("+Owner" g.gui.Hwnd)
    dlg.SetFont("s10")

    displayText := ocrRecognizer.BuildDisplayText(result.text)
    dlg.__ocrText := displayText

    dlg.Add("Text", "xm ym w420", "区域: " . RegionSummary(region))
    if (result.reason = "NO_TEXT")
        dlg.Add("Text", "xm y+8 w420 h36", "这次 OCR 已执行，但没有识别到可用文本。你仍然可以复制下面的结果，方便确认当前返回值。")
    else
        dlg.Add("Text", "xm y+8 w420 h20", "下面是当前区域的 OCR 原始识别结果，可以直接复制。")

    edtText := dlg.Add("Edit", "xm y+10 w420 r10 ReadOnly -Wrap", displayText)
    edtText.Focus()

    btnCopy := dlg.Add("Button", "xm y+14 w90 Default", "复制文本")
    btnCopy.OnEvent("Click", OnOcrPreviewCopy)

    btnClose := dlg.Add("Button", "x+8 yp w90", "关闭")
    btnClose.OnEvent("Click", OnOcrPreviewClose)
    dlg.OnEvent("Close", OnOcrPreviewClose)

    dlg.Show("AutoSize Center")
}

OnOcrPreviewCopy(ctrl, *) {
    dlg := ctrl.Gui
    A_Clipboard := dlg.__ocrText
    MsgBox("OCR 文本已复制到剪贴板。", "提示")
}

OnOcrPreviewClose(guiObj, *) {
    GuiHelper.DestroyOwner(guiObj)
}

OnTextOcrDialogCancel(guiObj, *) {
    state := guiObj.__state
    state.done := true
    if (regionTool.active)
        regionTool.Stop(false)
    guiObj.Destroy()
}


; ====================================================================
; ===================  标签页3：存仓设置  ============================
; ====================================================================

BtnAddItem(*) {
    ib := InputBox("请输入装备名称：", "添加装备")
    if (ib.Result = "Cancel" || ib.Value = "")
        return
    g.storeCfg.itemNames.Push(ib.Value)
    RefreshItemsList()
}

BtnDeleteItem(*) {
    idx := g.lbItems.Value      ; ListBox.Value = 选中项索引，0 表示未选
    if (idx = 0) {
        MsgBox("请先在列表中选择要删除的装备。", "提示")
        return
    }
    g.storeCfg.itemNames.RemoveAt(idx)
    RefreshItemsList()
}

BtnSaveStoreCfg(*) {
    try {
        minutes := Integer(Trim(g.edtInterval.Value))
    } catch {
        MsgBox("请输入有效的整数分钟数。", "提示")
        return
    }
    if (minutes <= 0) {
        MsgBox("存仓间隔必须大于 0 分钟。", "提示")
        return
    }
    g.storeCfg.intervalMinutes := minutes
    store.SaveStoreConfig(g.storeCfg)
    MsgBox("存仓配置已保存。", "提示")
}

RefreshItemsList() {
    g.lbItems.Delete()
    if (g.storeCfg.itemNames.Length > 0)
        g.lbItems.Add(g.storeCfg.itemNames)
}


; ====================================================================
; ===================  标签页4：运行控制  ============================
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
    g.txtState.Text := "当前状态：" . StateText(botRunner.state)
    if (botRunner.IsRunning())
        g.btnRun.Text := "■ 停止挂机"
    else
        g.btnRun.Text := "▶ 开始挂机"
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
    g.edtLog.Value := out
    ; 滚动到底部：EM_LINESCROLL(0x00B6)，lParam=垂直行数
    try {
        SendMessage(0x00B6, 0, 999999, g.edtLog)
    } catch {
        ; 忽略滚动失败
    }
}


; ====================================================================
; =======================  窗口关闭  =================================
; ====================================================================

OnGuiClose(*) {
    if (botRunner.IsRunning())
        botRunner.Stop()
    ExitApp()
}
