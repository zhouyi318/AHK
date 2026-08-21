#Requires AutoHotkey v2.0

class ScriptEditor {
    __New(deps) {
        this.deps := deps
        this.currentScript := ""
        this.currentFlow := ""
        this.currentPage := "主页"
        this.selectedStepIndex := 1
        this.selectedFlowNodeIndex := 1
        this.scriptNames := []
        this.flowNames := []
        this.propInputs := Map()
        this.propLabels := []
        this.propEditors := []
        this.propHelpTexts := []
        this.homePageControls := []
        this.scriptPageControls := []
        this.flowPageControls := []
        this.settingsPageControls := []
        this.logPageControls := []
        this.mouseRecording := false
        this.botRunStateText := "当前状态：空闲"
        this.defaultStatusContextText := "运行上下文`n当前流程、脚本、步骤会在后续状态同步中继续补全。"
        this.statusContextText := this.defaultStatusContextText
        this.moveDirectionAdvice := Map()
    }

    Build() {
        guiObj := Gui(, "统一脚本编辑器")
        guiObj.SetFont("s10")
        guiObj.BackColor := "FFFFFF"  ; 改为亮色背景，确保黑色字体清晰可见


        outerMargin := 16
        columnGap := 12
        navX := outerMargin
        navY := outerMargin
        navW := 160
        shellH := 820
        workspaceX := navX + navW + columnGap
        workspaceY := outerMargin
        workspaceW := 890
        statusX := workspaceX + workspaceW + columnGap
        statusY := outerMargin
        statusW := 220
        pagePadding := 16
        pageX := workspaceX + pagePadding
        pageY := workspaceY + pagePadding
        pageW := workspaceW - (pagePadding * 2)
        pageH := shellH - (pagePadding * 2)
        this.shellMetrics := {
            navX: navX,
            navY: navY,
            navW: navW,
            shellH: shellH,
            workspaceX: workspaceX,
            workspaceY: workspaceY,
            workspaceW: workspaceW,
            statusX: statusX,
            statusY: statusY,
            statusW: statusW,
            pageX: pageX,
            pageY: pageY,
            pageW: pageW,
            pageH: pageH
        }

        this.pnlNav := guiObj.Add("Text", Format("x{} y{} w{} h{} Border", navX, navY, navW, shellH), "")
        this.txtNavTitle := guiObj.Add("Text", Format("x{} y{} w{} h24 +0x200", navX + 12, navY + 12, navW - 24), "控制台导航")
        this.btnNavHome := guiObj.Add("Button", Format("x{} y{} w{} h34", navX + 12, navY + 48, navW - 24), "主页")
        this.btnNavScripts := guiObj.Add("Button", Format("x{} y{} w{} h34", navX + 12, navY + 90, navW - 24), "脚本编辑")
        this.btnNavFlows := guiObj.Add("Button", Format("x{} y{} w{} h34", navX + 12, navY + 132, navW - 24), "流程调度")
        this.btnNavSettings := guiObj.Add("Button", Format("x{} y{} w{} h34", navX + 12, navY + 174, navW - 24), "挂机设置")
        this.btnNavLogs := guiObj.Add("Button", Format("x{} y{} w{} h34", navX + 12, navY + 216, navW - 24), "运行日志")

        this.pnlWorkspace := guiObj.Add("Text", Format("x{} y{} w{} h{} Border", workspaceX, workspaceY, workspaceW, shellH), "")
        this.txtWorkspaceTitle := guiObj.Add("Text", Format("x{} y{} w{} h24 +0x200", workspaceX + 12, workspaceY + 12, workspaceW - 24), "工作区")

        this.pageHome := guiObj.Add("Text", Format("x{} y{} w{} h{} Border", pageX, pageY, pageW, pageH), "")
        this.lblHomeTitle := guiObj.Add("Text", Format("x{} y{} w{} h24 +0x200", pageX + 16, pageY + 12, pageW - 32), "主页")
        this.txtHomeRunCard := guiObj.Add("Text", Format("x{} y{} w{} h{} Border", pageX + 16, pageY + 48, 360, 122), "运行总控`n打开程序后可直接开始或停止挂机。")
        this.btnRunBot := guiObj.Add("Button", Format("x{} y{} w{} h30", pageX + 32, pageY + 90, 132), "开始/停止挂机")
        this.btnPickWindow := guiObj.Add("Button", Format("x{} y{} w{} h30", pageX + 180, pageY + 90, 132), "选择窗口")
        this.txtHomeWindowCard := guiObj.Add("Text", Format("x{} y{} w{} h{} Border", pageX + 392, pageY + 48, 420, 122), "窗口绑定`n当前绑定窗口信息会显示在右侧状态栏。")
        this.txtHomeTaskCard := guiObj.Add("Text", Format("x{} y{} w{} h{} Border", pageX + 16, pageY + 186, 360, 150), "运行信息`n开始挂机后这里显示当前状态、执行脚本与失败冷却。")
        this.txtHomeToolsCard := guiObj.Add("Text", Format("x{} y{} w{} h{} Border", pageX + 392, pageY + 186, 420, 150), "快捷工具`n保留 OCR 与找图测试入口，便于不进编辑页也能快速验证。")
        this.btnTestRegionFind := guiObj.Add("Button", Format("x{} y{} w{} h28", pageX + 416, pageY + 230, 120), "测试区域找图")
        this.btnTestRegionOcr := guiObj.Add("Button", Format("x{} y{} w{} h28", pageX + 548, pageY + 230, 120), "测试区域 OCR")
        this.btnPreviewRegionOcr := guiObj.Add("Button", Format("x{} y{} w{} h28", pageX + 680, pageY + 230, 120), "查看 OCR 文本")
        this.btnSetSim := guiObj.Add("Button", Format("x{} y{} w{} h28", pageX + 416, pageY + 268, 160), "设置找图相似度")

        scriptListX := pageX + 16
        scriptListY := pageY + 164
        scriptListW := 150
        stepListX := scriptListX + scriptListW + 12
        stepListW := 370
        detailPaneX := stepListX + stepListW + 12
        detailPaneW := (pageX + pageW - 16) - detailPaneX
        navHelperPrimaryY := pageY + 122
        navHelperQuickY := pageY + 156
        propsPanelY := pageY + 188

        this.pageScriptEditor := guiObj.Add("Text", Format("x{} y{} w{} h{} Border", pageX, pageY, pageW, pageH), "")
        this.lblScriptTitle := guiObj.Add("Text", Format("x{} y{} w{} h24 +0x200", pageX + 16, pageY + 12, pageW - 32), "脚本编辑")
        this.btnNewScript := guiObj.Add("Button", Format("x{} y{} w90 h28", pageX + 16, pageY + 48), "新建脚本")
        this.btnSaveScript := guiObj.Add("Button", Format("x{} y{} w90 h28", pageX + 114, pageY + 48), "保存脚本")
        this.btnDeleteScript := guiObj.Add("Button", Format("x{} y{} w90 h28", pageX + 212, pageY + 48), "删除脚本")
        this.btnRunScript := guiObj.Add("Button", Format("x{} y{} w110 h28", pageX + 310, pageY + 48), "运行整个脚本")
        this.btnRunFromStep := guiObj.Add("Button", Format("x{} y{} w130 h28", pageX + 428, pageY + 48), "从当前步骤运行")
        this.btnRunCurrentStep := guiObj.Add("Button", Format("x{} y{} w130 h28", pageX + 566, pageY + 48), "单步执行当前步骤")
        this.btnAddBranch := guiObj.Add("Button", Format("x{} y{} w60 h28", pageX + 704, pageY + 48), "+分支")
        this.btnConfigureStep := guiObj.Add("Button", Format("x{} y{} w60 h28", pageX + 772, pageY + 48), "配置")
        this.btnRecordClick := guiObj.Add("Button", Format("x{} y{} w110 h28", pageX + 16, pageY + 86), "录制点击")
        this.btnRecordKey := guiObj.Add("Button", Format("x{} y{} w110 h28", pageX + 134, pageY + 86), "录制按键")
        this.btnAddWait := guiObj.Add("Button", Format("x{} y{} w90 h28", pageX + 252, pageY + 86), "+ 等待")
        this.btnAddClick := guiObj.Add("Button", Format("x{} y{} w90 h28", pageX + 350, pageY + 86), "+ 点击")
        this.btnAddFindImage := guiObj.Add("Button", Format("x{} y{} w90 h28", pageX + 448, pageY + 86), "+ 找图")
        this.btnAddClickImage := guiObj.Add("Button", Format("x{} y{} w90 h28", pageX + 546, pageY + 86), "+ 图点")
        this.btnAddOcrMatch := guiObj.Add("Button", Format("x{} y{} w90 h28", pageX + 644, pageY + 86), "+ OCR")
        this.btnAddMoveToCoord := guiObj.Add("Button", Format("x{} y{} w90 h28", pageX + 742, pageY + 86), "+ 导航")
        this.btnPickMoveCoordRegion := guiObj.Add("Button", Format("x{} y{} w72 h28", detailPaneX, navHelperPrimaryY), "取坐标框")
        this.btnPickMoveCenter := guiObj.Add("Button", Format("x{} y{} w64 h28", detailPaneX + 76, navHelperPrimaryY), "取中心")
        this.btnTestMoveToCoord := guiObj.Add("Button", Format("x{} y{} w56 h28", detailPaneX + 144, navHelperPrimaryY), "试跑")
        this.btnCaptureCoordTemplates := guiObj.Add("Button", Format("x{} y{} w56 h28", detailPaneX + 204, navHelperPrimaryY), "截模板")
        this.btnReadCoord := guiObj.Add("Button", Format("x{} y{} w56 h28", detailPaneX + 264, navHelperPrimaryY), "读坐标")
        this.lstScripts := guiObj.Add("ListBox", Format("x{} y{} w{} h520", scriptListX, scriptListY, scriptListW), [])
        this.lvSteps := guiObj.Add("ListView", Format("x{} y{} w{} h520", stepListX, scriptListY, stepListW), ["序号", "启用", "类型", "摘要"])
        this.pnlProps := guiObj.Add("Edit", Format("x{} y{} w{} h34 ReadOnly -Wrap HScroll VScroll", detailPaneX, propsPanelY, detailPaneW), "步骤属性")
        this.BuildStepEditor(guiObj)

        this.pageFlowEditor := guiObj.Add("Text", Format("x{} y{} w{} h{} Border", pageX, pageY, pageW, pageH), "")
        this.lblFlowTitle := guiObj.Add("Text", Format("x{} y{} w{} h24 +0x200", pageX + 16, pageY + 12, pageW - 32), "流程调度")
        this.btnNewFlow := guiObj.Add("Button", Format("x{} y{} w90 h28", pageX + 16, pageY + 48), "新建流程")
        this.btnSaveFlow := guiObj.Add("Button", Format("x{} y{} w90 h28", pageX + 114, pageY + 48), "保存流程")
        this.btnDeleteFlow := guiObj.Add("Button", Format("x{} y{} w90 h28", pageX + 212, pageY + 48), "删除流程")
        this.btnAddFlowNode := guiObj.Add("Button", Format("x{} y{} w110 h28", pageX + 310, pageY + 48), "添加流程节点")
        this.btnRunFlow := guiObj.Add("Button", Format("x{} y{} w110 h28", pageX + 428, pageY + 48), "运行当前流程")
        this.lstFlows := guiObj.Add("ListBox", Format("x{} y{} w170 h520", pageX + 16, pageY + 92), [])
        this.lvFlowNodes := guiObj.Add("ListView", Format("x{} y{} w340 h520", pageX + 198, pageY + 92), ["序号", "启用", "节点", "脚本", "成功后", "失败后"])
        this.pnlFlowProps := guiObj.Add("Text", Format("x{} y{} w260 h92 Border", pageX + 550, pageY + 92), "流程节点属性")
        this.BuildFlowEditor(guiObj)

        this.pageSettings := guiObj.Add("Text", Format("x{} y{} w{} h{} Border", pageX, pageY, pageW, pageH), "")
        this.lblSettingsTitle := guiObj.Add("Text", Format("x{} y{} w{} h24 +0x200", pageX + 16, pageY + 12, pageW - 32), "挂机设置")
        
        ; ---- 基础运行 ----
        sX := pageX + 16
        sY := pageY + 48
        this.grpSettingsBasic := guiObj.Add("GroupBox", Format("x{} y{} w380 h190", sX, sY), "基础运行")
        this.lblSettingsTickMs := guiObj.Add("Text", Format("x{} y{} w230 h24 +0x200", sX + 20, sY + 36), "主循环间隔（毫秒）")
        this.edtSettingsTickMs := guiObj.Add("Edit", Format("x{} y{} w100 h26 Right", sX + 260, sY + 34), "500")
        this.lblSettingsAutoFightRetry := guiObj.Add("Text", Format("x{} y{} w230 h24 +0x200", sX + 20, sY + 74), "挂机开启失败重试次数")
        this.edtSettingsAutoFightRetry := guiObj.Add("Edit", Format("x{} y{} w100 h26 Right", sX + 260, sY + 72), "3")
        this.lblSettingsStoreIntervalMin := guiObj.Add("Text", Format("x{} y{} w230 h24 +0x200", sX + 20, sY + 112), "定时存仓间隔（分钟，0 表示不存仓）")
        this.edtSettingsStoreIntervalMin := guiObj.Add("Edit", Format("x{} y{} w100 h26 Right", sX + 260, sY + 110), "60")
        this.lblSettingsMonitorInterval := guiObj.Add("Text", Format("x{} y{} w230 h24 +0x200", sX + 20, sY + 150), "挂机监测找图间隔（毫秒）")
        this.edtSettingsMonitorInterval := guiObj.Add("Edit", Format("x{} y{} w100 h26 Right", sX + 260, sY + 148), "10000")
        
        ; ---- 识别参数 ----
        rX := pageX + 412
        this.grpSettingsRecog := guiObj.Add("GroupBox", Format("x{} y{} w396 h190", rX, sY), "识别参数")
        this.lblSettingsSim := guiObj.Add("Text", Format("x{} y{} w230 h24 +0x200", rX + 20, sY + 36), "找图相似度（0.10~1.00）")
        this.edtSettingsSim := guiObj.Add("Edit", Format("x{} y{} w100 h26 Right", rX + 260, sY + 34), "0.85")
        this.txtSettingsSimHint := guiObj.Add("Text", Format("x{} y{} w344 h96", rX + 20, sY + 78), "值越高越严格：找图误报多则调高，找不到图则调低。保存后立即对后续找图生效，无需重启。")
        
        ; ---- 进图可靠性 ----
        bY := sY + 206
        this.grpSettingsReliability := guiObj.Add("GroupBox", Format("x{} y{} w796 h258", sX, bY), "进图可靠性（死亡回城重新进图的兑底策略）")
        this.lblSettingsVerifyMapRetry := guiObj.Add("Text", Format("x{} y{} w240 h24 +0x200", sX + 20, bY + 36), "地图校验重试次数")
        this.edtSettingsVerifyMapRetry := guiObj.Add("Edit", Format("x{} y{} w110 h26 Right", sX + 270, bY + 34), "5")
        this.lblSettingsVerifyMapInterval := guiObj.Add("Text", Format("x{} y{} w240 h24 +0x200", sX + 20, bY + 84), "地图校验重试间隔（毫秒）")
        this.edtSettingsVerifyMapInterval := guiObj.Add("Edit", Format("x{} y{} w110 h26 Right", sX + 270, bY + 82), "2000")
        this.lblSettingsCheckTownTimeout := guiObj.Add("Text", Format("x{} y{} w240 h24 +0x200", sX + 20, bY + 132), "等待回土城超时（毫秒）")
        this.edtSettingsCheckTownTimeout := guiObj.Add("Edit", Format("x{} y{} w110 h26 Right", sX + 270, bY + 130), "60000")
        this.lblSettingsScriptMaxFails := guiObj.Add("Text", Format("x{} y{} w240 h24 +0x200", sX + 420, bY + 36), "脚本连续失败进入冷却的次数")
        this.edtSettingsScriptMaxFails := guiObj.Add("Edit", Format("x{} y{} w110 h26 Right", sX + 670, bY + 34), "3")
        this.lblSettingsScriptCooldown := guiObj.Add("Text", Format("x{} y{} w240 h24 +0x200", sX + 420, bY + 84), "失败脚本冷却时长（毫秒）")
        this.edtSettingsScriptCooldown := guiObj.Add("Edit", Format("x{} y{} w110 h26 Right", sX + 670, bY + 82), "600000")
        this.txtSettingsReliabilityHint := guiObj.Add("Text", Format("x{} y{} w740 h64", sX + 20, bY + 184), "说明：进图脚本失败会自动轮换下一个；连续失败达到次数后进入冷却跳过，冷却结束自动恢复尝试。地图校验重试用于防止进图加载慢被误判回城。")
        
        ; ---- 保存/恢复 ----
        aY := sY + 480
        this.btnSaveSettings := guiObj.Add("Button", Format("x{} y{} w110 h32", sX, aY), "保存设置")
        this.btnResetSettings := guiObj.Add("Button", Format("x{} y{} w110 h32", sX + 122, aY), "恢复默认")
        this.txtSettingsSaveHint := guiObj.Add("Text", Format("x{} y{} w520 h24 +0x200", sX + 250, aY + 6), "")

        this.pageLogs := guiObj.Add("Text", Format("x{} y{} w{} h{} Border", pageX, pageY, pageW, pageH), "")
        this.lblLogsTitle := guiObj.Add("Text", Format("x{} y{} w{} h24 +0x200", pageX + 16, pageY + 12, pageW - 32), "运行日志")
        this.txtLogsHint := guiObj.Add("Text", Format("x{} y{} w{} h24 +0x200", pageX + 16, pageY + 44, pageW - 32), "完整日志页保留大号滚动视图，右侧状态栏显示最近摘要。")
        this.edtRunLogs := guiObj.Add("Edit", Format("x{} y{} w{} h{} ReadOnly", pageX + 16, pageY + 80, pageW - 32, pageH - 96), "")

        this.pnlStatus := guiObj.Add("Text", Format("x{} y{} w{} h{} Border", statusX, statusY, statusW, shellH), "")
        this.txtStatusTitle := guiObj.Add("Text", Format("x{} y{} w{} h24 +0x200", statusX + 12, statusY + 12, statusW - 24), "状态栏")
        this.txtWindowSummary := guiObj.Add("Text", Format("x{} y{} w{} h72", statusX + 12, statusY + 44, statusW - 24), "窗口: (未绑定)")
        this.txtRunState := guiObj.Add("Text", Format("x{} y{} w{} h24", statusX + 12, statusY + 124, statusW - 24), "当前状态：空闲")
        this.txtStatusHotkeys := guiObj.Add("Text", Format("x{} y{} w{} h38", statusX + 12, statusY + 156, statusW - 24), "热键`n开始/暂停 与 急停 由 config.ini 控制。")
        this.txtStatusContext := guiObj.Add("Text", Format("x{} y{} w{} h56", statusX + 12, statusY + 202, statusW - 24), this.defaultStatusContextText)
        this.txtStatusLogTitle := guiObj.Add("Text", Format("x{} y{} w{} h24 +0x200", statusX + 12, statusY + 268, statusW - 24), "最近日志")
        this.edtLog := guiObj.Add("Edit", Format("x{} y{} w{} h{} ReadOnly", statusX + 12, statusY + 298, statusW - 24, 500), "")

        this.lstScripts.OnEvent("Change", ObjBindMethod(this, "OnScriptListChange"))
        this.lvSteps.OnEvent("ItemSelect", ObjBindMethod(this, "OnStepSelect"))
        this.btnNewScript.OnEvent("Click", ObjBindMethod(this, "HandleNewScript"))
        this.btnSaveScript.OnEvent("Click", ObjBindMethod(this, "HandleSaveScript"))
        this.btnDeleteScript.OnEvent("Click", ObjBindMethod(this, "HandleDeleteScript"))
        this.btnRunScript.OnEvent("Click", ObjBindMethod(this, "HandleRunScript"))
        this.btnRunFromStep.OnEvent("Click", ObjBindMethod(this, "HandleRunFromCurrentStep"))
        this.btnRunCurrentStep.OnEvent("Click", ObjBindMethod(this, "HandleRunCurrentStep"))
        this.btnRecordClick.OnEvent("Click", ObjBindMethod(this, "HandleRecordClick"))
        this.btnRecordKey.OnEvent("Click", ObjBindMethod(this, "HandleRecordKey"))
        this.btnAddWait.OnEvent("Click", ObjBindMethod(this, "HandleAddWait"))
        this.btnAddClick.OnEvent("Click", ObjBindMethod(this, "HandleAddClick"))
        this.btnAddFindImage.OnEvent("Click", ObjBindMethod(this, "HandleAddFindImage"))
        this.btnAddClickImage.OnEvent("Click", ObjBindMethod(this, "HandleAddClickImage"))
        this.btnAddOcrMatch.OnEvent("Click", ObjBindMethod(this, "HandleAddOcrMatch"))
        this.btnAddMoveToCoord.OnEvent("Click", ObjBindMethod(this, "HandleAddMoveToCoord"))
        this.btnAddBranch.OnEvent("Click", ObjBindMethod(this, "HandleAddBranch"))
        this.btnConfigureStep.OnEvent("Click", ObjBindMethod(this, "HandleConfigureStep"))
        this.btnTestMoveToCoord.OnEvent("Click", ObjBindMethod(this, "HandleTestMoveToCoord"))
        this.btnCaptureCoordTemplates.OnEvent("Click", ObjBindMethod(this, "HandleCaptureCoordTemplates"))
        this.btnReadCoord.OnEvent("Click", ObjBindMethod(this, "HandleReadCoord"))
        this.btnPickMoveCoordRegion.OnEvent("Click", ObjBindMethod(this, "HandlePickMoveCoordRegion"))
        this.btnPickMoveCenter.OnEvent("Click", ObjBindMethod(this, "HandlePickMoveCenter"))
        this.lstFlows.OnEvent("Change", ObjBindMethod(this, "OnFlowListChange"))
        this.lvFlowNodes.OnEvent("ItemSelect", ObjBindMethod(this, "OnFlowNodeSelect"))
        this.btnNewFlow.OnEvent("Click", ObjBindMethod(this, "HandleNewFlow"))
        this.btnSaveFlow.OnEvent("Click", ObjBindMethod(this, "HandleSaveFlow"))
        this.btnDeleteFlow.OnEvent("Click", ObjBindMethod(this, "HandleDeleteFlow"))
        this.btnAddFlowNode.OnEvent("Click", ObjBindMethod(this, "HandleAddFlowNode"))
        this.btnRunFlow.OnEvent("Click", ObjBindMethod(this, "HandleRunFlow"))
        this.btnApplyFlowNode.OnEvent("Click", ObjBindMethod(this, "HandleApplyFlowNode"))
        this.btnNavHome.OnEvent("Click", ObjBindMethod(this, "HandleNavClick", "主页"))
        this.btnNavScripts.OnEvent("Click", ObjBindMethod(this, "HandleNavClick", "脚本编辑"))
        this.btnNavFlows.OnEvent("Click", ObjBindMethod(this, "HandleNavClick", "流程调度"))
        this.btnNavSettings.OnEvent("Click", ObjBindMethod(this, "HandleNavClick", "挂机设置"))
        this.btnNavLogs.OnEvent("Click", ObjBindMethod(this, "HandleNavClick", "运行日志"))
        this.btnSaveSettings.OnEvent("Click", ObjBindMethod(this, "HandleSaveSettings"))
        this.btnResetSettings.OnEvent("Click", ObjBindMethod(this, "HandleResetSettings"))

        this.BindOptionalClick(this.btnPickWindow, "onPickWindow")
        this.BindOptionalClick(this.btnRunBot, "onRunBot")
        this.BindOptionalClick(this.btnTestRegionFind, "onTestRegionFind")
        this.BindOptionalClick(this.btnTestRegionOcr, "onTestRegionOcr")
        this.BindOptionalClick(this.btnPreviewRegionOcr, "onPreviewRegionOcr")
        this.BindOptionalClick(this.btnSetSim, "onSetSim")

        this.homePageControls := [
            "pageHome", "lblHomeTitle", "txtHomeRunCard", "txtHomeWindowCard", "txtHomeTaskCard", "txtHomeToolsCard",
            "btnRunBot", "btnPickWindow", "btnTestRegionFind", "btnTestRegionOcr", "btnPreviewRegionOcr", "btnSetSim"
        ]
        this.scriptPageControls := [
            "pageScriptEditor", "lblScriptTitle", "btnNewScript", "btnSaveScript", "btnDeleteScript", "btnRunScript",
            "btnRunFromStep", "btnRunCurrentStep", "btnRecordClick", "btnRecordKey", "btnAddWait", "btnAddClick",
            "btnAddFindImage", "btnAddClickImage", "btnAddOcrMatch", "btnAddMoveToCoord", "btnAddBranch", "btnConfigureStep", "btnTestMoveToCoord", "btnPickMoveCoordRegion", "btnPickMoveCenter",
            "lstScripts", "lvSteps", "pnlProps", "lblStepType", "edtStepType", "lblStepName", "edtStepName",
            "chkStepEnabled", "lblOnSuccessAction", "ddlOnSuccessAction", "lblOnSuccessTarget", "ddlOnSuccessTarget",
            "lblOnFailureAction", "ddlOnFailureAction", "lblOnFailureTarget", "ddlOnFailureTarget", "btnApplyStep", "txtStepHint"
        ]
        this.flowPageControls := [
            "pageFlowEditor", "lblFlowTitle", "btnNewFlow", "btnSaveFlow", "btnDeleteFlow", "btnAddFlowNode", "btnRunFlow",
            "lstFlows", "lvFlowNodes", "pnlFlowProps", "lblFlowNodeName", "edtFlowNodeName", "lblFlowScript", "cmbFlowNodeScript",
            "lblFlowSuccessAction", "ddlFlowSuccessAction", "lblFlowSuccessTarget", "cmbFlowSuccessTarget",
            "lblFlowFailureAction", "ddlFlowFailureAction", "lblFlowFailureTarget", "cmbFlowFailureTarget",
            "lblFlowMaxLoops", "edtFlowNodeMaxLoops", "btnApplyFlowNode"
        ]
        this.settingsPageControls := [
            "pageSettings", "lblSettingsTitle",
            "grpSettingsBasic", "lblSettingsTickMs", "edtSettingsTickMs", "lblSettingsAutoFightRetry", "edtSettingsAutoFightRetry",
            "lblSettingsStoreIntervalMin", "edtSettingsStoreIntervalMin", "lblSettingsMonitorInterval", "edtSettingsMonitorInterval",
            "grpSettingsRecog", "lblSettingsSim", "edtSettingsSim", "txtSettingsSimHint",
            "grpSettingsReliability", "lblSettingsVerifyMapRetry", "edtSettingsVerifyMapRetry", "lblSettingsVerifyMapInterval", "edtSettingsVerifyMapInterval",
            "lblSettingsCheckTownTimeout", "edtSettingsCheckTownTimeout", "lblSettingsScriptMaxFails", "edtSettingsScriptMaxFails",
            "lblSettingsScriptCooldown", "edtSettingsScriptCooldown", "txtSettingsReliabilityHint",
            "btnSaveSettings", "btnResetSettings", "txtSettingsSaveHint"
        ]
        this.logPageControls := [
            "pageLogs", "lblLogsTitle", "txtLogsHint", "edtRunLogs"
        ]

        this.gui := guiObj
        this.SetStepEditorEmptyState()
        this.SetFlowEditorEmptyState()
        this.UpdateLayout()
        if this.deps.Has("repo")
            this.RefreshScriptList()
        if this.deps.Has("flowRepo")
            this.RefreshFlowList()
        this.ShowPage(this.currentPage)
        return guiObj
    }

    HandleNavClick(pageName, *) {
        this.ShowPage(pageName)
    }

    ShowPage(pageName) {
        if !(pageName = "主页" || pageName = "脚本编辑" || pageName = "流程调度" || pageName = "挂机设置" || pageName = "运行日志")
            return false

        this.currentPage := pageName
        if (pageName = "脚本编辑")
            this.RefreshProps()
        else if (pageName = "流程调度")
            this.RefreshFlowNodeEditor()
        else if (pageName = "挂机设置")
            this.LoadSettingsIntoControls()
        this.EnforcePageVisibility()
        return true
    }

    NewScript(name, type := "enter_map") {
        this.currentScript := this.deps["repo"].CreateScript(name, type)
        this.selectedStepIndex := 1
        return this.currentScript
    }

    CreateAndPersistScript(name, type := "enter_map") {
        name := Trim(name)
        if (name = "")
            return ""
        this.NewScript(name, type)
        this.SaveCurrentScript()
        this.RefreshSteps()
        this.RefreshProps()
        this.SelectCurrentScriptInList()
        return this.currentScript
    }

    AddStep(type) {
        if !IsObject(this.currentScript)
            return ""
        step := this.deps["schema"].CreateStep(type)
        this.currentScript.steps.Push(step)
        this.selectedStepIndex := this.currentScript.steps.Length
        this.RefreshSteps()
        this.SelectStep(this.selectedStepIndex)
        return step
    }

    SaveCurrentScript() {
        if !IsObject(this.currentScript)
            return false
        this.deps["repo"].SaveScript(this.currentScript)
        this.RefreshScriptList()
        return true
    }

    DeleteCurrentScript() {
        if !IsObject(this.currentScript)
            return false

        this.deps["repo"].DeleteScript(this.currentScript.name)
        this.RefreshScriptList()
        if (this.scriptNames.Length > 0) {
            if this.HasProp("lstScripts")
                this.lstScripts.Choose(1)
            this.LoadScriptByName(this.scriptNames[1])
        } else {
            this.currentScript := ""
            this.selectedStepIndex := 1
            this.RefreshSteps()
            this.RefreshProps()
        }
        return true
    }

    NewFlow(name) {
        this.currentFlow := this.deps["flowRepo"].CreateFlow(name)
        this.selectedFlowNodeIndex := 1
        this.RefreshFlowNodes()
        this.RefreshFlowNodeEditor()
        return this.currentFlow
    }

    CreateAndPersistFlow(name) {
        name := Trim(name)
        if (name = "")
            return ""
        this.NewFlow(name)
        this.SaveCurrentFlow()
        this.RefreshFlowNodes()
        this.RefreshFlowNodeEditor()
        this.SelectCurrentFlowInList()
        return this.currentFlow
    }

    AddFlowNode(scriptName := "") {
        if !IsObject(this.currentFlow)
            return ""
        if (scriptName = "" && this.scriptNames.Length > 0)
            scriptName := this.scriptNames[1]
        node := {
            id: "node_" A_TickCount,
            name: "节点 " (this.currentFlow.nodes.Length + 1),
            enabled: true,
            scriptName: scriptName,
            onSuccess: {action: "next"},
            onFailure: {action: "stop"},
            maxLoops: 0
        }
        this.currentFlow.nodes.Push(node)
        if (this.currentFlow.entryNodeId = "")
            this.currentFlow.entryNodeId := node.id
        this.selectedFlowNodeIndex := this.currentFlow.nodes.Length
        this.RefreshFlowNodes()
        this.SelectFlowNode(this.selectedFlowNodeIndex)
        return node
    }

    SaveCurrentFlow() {
        if !(this.deps.Has("flowRepo") && IsObject(this.currentFlow))
            return false
        this.deps["flowRepo"].SaveFlow(this.currentFlow)
        this.RefreshFlowList()
        return true
    }

    DeleteCurrentFlow() {
        if !(this.deps.Has("flowRepo") && IsObject(this.currentFlow))
            return false
        this.deps["flowRepo"].DeleteFlow(this.currentFlow.name)
        this.RefreshFlowList()
        if (this.flowNames.Length > 0) {
            this.LoadFlowByName(this.flowNames[1])
        } else {
            this.currentFlow := ""
            this.selectedFlowNodeIndex := 1
            this.RefreshFlowNodes()
            this.RefreshFlowNodeEditor()
        }
        return true
    }

    GetBoundHwnd() {
        if !this.deps.Has("cfg")
            return 0
        return this.deps["cfg"].Window.Hwnd
    }

    RunCurrentScript() {
        return this.deps["runner"].RunScript(this.currentScript, this.GetBoundHwnd(), 1)
    }

    RunFromCurrentStep() {
        return this.deps["runner"].RunScript(this.currentScript, this.GetBoundHwnd(), this.selectedStepIndex)
    }

    RunCurrentStep() {
        step := this.currentScript.steps[this.selectedStepIndex]
        return this.deps["runner"].RunSingleStep(step, this.GetBoundHwnd())
    }

    RunSelectedMoveToCoordStep() {
        if !(IsObject(this.currentScript) && this.currentScript.steps.Length > 0)
            return false
        step := this.currentScript.steps[this.selectedStepIndex]
        if (step.type != "move_to_coord")
            return false
        result := this.deps["runner"].RunSingleStep(step, this.GetBoundHwnd())
        this.lastMoveToCoordTestResult := result
        return IsObject(result) ? !!result.ok : !!result
    }

    CalibrateSelectedMoveSpeed() {
        return true
    }

    DiagnoseSelectedMoveDirection() {
        return false
    }

    ApplySelectedMoveDirectionAdvice() {
        return false
    }

    RunCurrentFlow() {
        runner := this.deps.Has("flowRunner") ? this.deps["flowRunner"] : this.deps["runner"]
        return runner.RunFlow(this.currentFlow, this.GetBoundHwnd())
    }

    RefreshScriptList() {
        this.scriptNames := this.deps["repo"].ListScripts()
        if this.HasProp("lstScripts") {
            this.lstScripts.Delete()
            if (this.scriptNames.Length > 0)
                this.lstScripts.Add(this.scriptNames)
            this.SelectCurrentScriptInList()
        }
        this.RefreshFlowScriptChoices()
    }

    RefreshFlowList() {
        if !this.deps.Has("flowRepo")
            return
        this.flowNames := this.deps["flowRepo"].ListFlows()
        if this.HasProp("lstFlows") {
            this.lstFlows.Delete()
            if (this.flowNames.Length > 0)
                this.lstFlows.Add(this.flowNames)
            this.SelectCurrentFlowInList()
        }
    }

    LoadScriptByName(name) {
        this.currentScript := this.deps["repo"].LoadScript(name)
        this.selectedStepIndex := 1
        this.RefreshSteps()
        this.RefreshProps()
        return this.currentScript
    }

    LoadFlowByName(name) {
        if !this.deps.Has("flowRepo")
            return ""
        this.currentFlow := this.deps["flowRepo"].LoadFlow(name)
        this.selectedFlowNodeIndex := 1
        this.RefreshFlowNodes()
        this.RefreshFlowNodeEditor()
        return this.currentFlow
    }

    RefreshSteps() {
        if !this.HasProp("lvSteps")
            return
        this.lvSteps.Delete()
        if !IsObject(this.currentScript)
            return
        for index, step in this.currentScript.steps
            this.lvSteps.Add("", index, step.enabled ? "是" : "否", step.type, this.StepSummary(step))
        if (this.currentScript.steps.Length > 0)
            this.SelectStep(Min(this.selectedStepIndex, this.currentScript.steps.Length))
    }

    RefreshFlowNodes() {
        if !this.HasProp("lvFlowNodes")
            return
        this.lvFlowNodes.Delete()
        if !IsObject(this.currentFlow)
            return
        for index, node in this.currentFlow.nodes {
            successText := this.FormatFlowBranch(node.onSuccess)
            failureText := this.FormatFlowBranch(node.onFailure)
            this.lvFlowNodes.Add("", index, node.enabled ? "是" : "否", node.name, node.scriptName, successText, failureText)
        }
        if (this.currentFlow.nodes.Length > 0)
            this.SelectFlowNode(Min(this.selectedFlowNodeIndex, this.currentFlow.nodes.Length))
    }

    StepSummary(step) {
        params := step.HasProp("params") ? step.params : {}
        switch step.type {
            case "wait":
                return "等待 " (params.HasProp("ms") ? params.ms : 0) "ms"
            case "click":
                return "点击 (" (params.HasProp("x") ? params.x : 0) "," (params.HasProp("y") ? params.y : 0) ")"
            case "keypress":
                return "按键 " (params.HasProp("keyName") ? params.keyName : "")
            case "find_image", "click_image":
                return "图片 " (params.HasProp("image") ? params.image : "")
            case "ocr_match":
                return "OCR " (params.HasProp("targetText") ? params.targetText : "")
            case "move_to_coord":
                return "导航 " (params.HasProp("targetX") ? params.targetX : 0) "," (params.HasProp("targetY") ? params.targetY : 0)
            case "branch":
                return "条件 " (params.HasProp("conditionType") ? params.conditionType : "")
            default:
                return step.name
        }
    }

    FormatBranch(branch) {
        if !IsObject(branch)
            return "next"
        action := branch.HasProp("action") ? branch.action : "next"
        if (action = "jump")
            return action " -> " (branch.HasProp("targetStepId") ? branch.targetStepId : "")
        return action
    }

    FormatFlowBranch(branch) {
        if !IsObject(branch)
            return "next"
        action := branch.HasProp("action") ? branch.action : "next"
        if (action = "goto")
            return action " -> " (branch.HasProp("targetNodeId") ? branch.targetNodeId : "")
        return action
    }

    SelectStep(index) {
        if !IsObject(this.currentScript)
            return
        if (index < 1 || index > this.currentScript.steps.Length)
            return
        this.selectedStepIndex := index
        if this.HasProp("lvSteps")
            this.lvSteps.Modify(index, "Select Focus Vis")
        this.RefreshProps()
    }

    SelectFlowNode(index) {
        if !IsObject(this.currentFlow)
            return
        if (index < 1 || index > this.currentFlow.nodes.Length)
            return
        this.selectedFlowNodeIndex := index
        if this.HasProp("lvFlowNodes")
            this.lvFlowNodes.Modify(index, "Select Focus Vis")
        this.RefreshFlowNodeEditor()
    }

    RefreshProps() {
        if !this.HasProp("pnlProps")
            return
        if !IsObject(this.currentScript) || this.currentScript.steps.Length = 0 {
            this.pnlProps.Value := "步骤属性"
            this.SetStepEditorEmptyState()
            this.EnforcePageVisibility()
            return
        }
        step := this.currentScript.steps[this.selectedStepIndex]
        text := "步骤类型: " step.type "`n"
            . "步骤名称: " step.name "`n"
            . "启用: " (step.enabled ? "是" : "否") "`n"
            . "成功: " this.FormatBranch(step.onSuccess) "`n"
            . "失败: " this.FormatBranch(step.onFailure)
        text .= this.StepParamsSummaryText(step)
        hint := this.StepPropsHintText(step)
        if (hint != "")
            text .= "`n" hint
        this.pnlProps.Value := text
        this.FillStepEditor(step)
        this.EnforcePageVisibility()
    }

    RefreshFlowNodeEditor() {
        if !this.HasProp("pnlFlowProps")
            return
        if !IsObject(this.currentFlow) || this.currentFlow.nodes.Length = 0 {
            this.pnlFlowProps.Text := "流程节点属性"
            this.SetFlowEditorEmptyState()
            this.EnforcePageVisibility()
            return
        }
        node := this.currentFlow.nodes[this.selectedFlowNodeIndex]
        this.pnlFlowProps.Text := "节点 ID: " node.id "`n"
            . "名称: " node.name "`n"
            . "脚本: " node.scriptName "`n"
            . "成功: " this.FormatFlowBranch(node.onSuccess) "`n"
            . "失败: " this.FormatFlowBranch(node.onFailure)
        this.FillFlowNodeEditor(node)
        this.EnforcePageVisibility()
    }

    ParamValueText(value) {
        if !IsObject(value)
            return value ""
        if (value.HasProp("x1") && value.HasProp("y1") && value.HasProp("x2") && value.HasProp("y2"))
            return "{ x1: " value.x1 ", y1: " value.y1 ", x2: " value.x2 ", y2: " value.y2 " }"
        parts := []
        for key, item in value.OwnProps()
            parts.Push(key ": " this.ParamValueText(item))
        return "{ " . this.JoinParts(parts) . " }"
    }

    ParamEditorText(value) {
        if IsObject(value)
            return this.ParamValueText(value)
        return value ""
    }

    JoinParts(parts) {
        text := ""
        for index, part in parts {
            if (index > 1)
                text .= ", "
            text .= part
        }
        return text
    }

    SelectCurrentScriptInList() {
        if !(this.HasProp("lstScripts") && IsObject(this.currentScript))
            return
        for index, name in this.scriptNames {
            if (name = this.currentScript.name) {
                this.lstScripts.Choose(index)
                return
            }
        }
    }

    SelectCurrentFlowInList() {
        if !(this.HasProp("lstFlows") && IsObject(this.currentFlow))
            return
        for index, name in this.flowNames {
            if (name = this.currentFlow.name) {
                this.lstFlows.Choose(index)
                return
            }
        }
    }

    GetControlBottom(ctrl) {
        ctrl.GetPos(, &y, , &h)
        return y + h
    }

    UpdateLayout() {
        if !this.HasProp("shellMetrics")
            return

        statusX := this.shellMetrics.statusX
        statusY := this.shellMetrics.statusY
        statusW := this.shellMetrics.statusW
        pageX := this.shellMetrics.pageX
        pageY := this.shellMetrics.pageY
        pageW := this.shellMetrics.pageW
        pageH := this.shellMetrics.pageH

        if this.HasProp("txtWindowSummary")
            this.txtWindowSummary.Move(statusX + 12, statusY + 44, statusW - 24, 72)
        if this.HasProp("txtRunState")
            this.txtRunState.Move(statusX + 12, statusY + 124, statusW - 24, 24)
        if this.HasProp("txtStatusHotkeys")
            this.txtStatusHotkeys.Move(statusX + 12, statusY + 156, statusW - 24, 38)
        if this.HasProp("txtStatusContext")
            this.txtStatusContext.Move(statusX + 12, statusY + 202, statusW - 24, 56)
        if this.HasProp("txtStatusLogTitle")
            this.txtStatusLogTitle.Move(statusX + 12, statusY + 268, statusW - 24, 24)
        if this.HasProp("edtLog")
            this.edtLog.Move(statusX + 12, statusY + 298, statusW - 24, 500)
        if this.HasProp("edtRunLogs")
            this.edtRunLogs.Move(pageX + 16, pageY + 80, pageW - 32, pageH - 96)
    }

    SetControlsVisible(names, visible) {
        for _, name in names {
            if this.HasProp(name)
                this.%name%.Visible := visible
        }
    }

    EnforcePageVisibility() {
        this.SetControlsVisible(this.homePageControls, this.currentPage = "主页")
        this.SetControlsVisible(this.scriptPageControls, this.currentPage = "脚本编辑")
        this.SetControlsVisible(this.flowPageControls, this.currentPage = "流程调度")
        this.SetControlsVisible(this.settingsPageControls, this.currentPage = "挂机设置")
        this.SetControlsVisible(this.logPageControls, this.currentPage = "运行日志")

        if (this.currentPage != "脚本编辑") {
            for _, ctrl in this.propLabels
                ctrl.Visible := false
            for _, ctrl in this.propEditors
                ctrl.Visible := false
            for _, ctrl in this.propHelpTexts
                ctrl.Visible := false
        }
    }

    OnScriptListChange(ctrl, *) {
        if (ctrl.Text != "")
            this.LoadScriptByName(ctrl.Text)
    }

    OnFlowListChange(ctrl, *) {
        if (ctrl.Text != "")
            this.LoadFlowByName(ctrl.Text)
    }

    OnStepSelect(ctrl, rowNumber, selected) {
        if selected
            this.SelectStep(rowNumber)
    }

    OnFlowNodeSelect(ctrl, rowNumber, selected) {
        if selected
            this.SelectFlowNode(rowNumber)
    }

    SetWindowSummary(text) {
        if this.HasProp("txtWindowSummary")
            this.txtWindowSummary.Text := text
    }

    SetBotRunState(text) {
        this.botRunStateText := text
        if !this.mouseRecording
            this.SetRunState(text)
    }

    ; 主页运行信息卡：状态/当前脚本/失败计数/冷却
    SetBotOverview(text) {
        this.botOverviewText := text
        if this.HasProp("txtHomeTaskCard")
            this.txtHomeTaskCard.Text := text
    }

    ; 从配置读值填入设置页输入框（进入页面与保存后刷新）
    LoadSettingsIntoControls() {
        if !this.deps.Has("cfg")
            return
        cfg := this.deps["cfg"]
        this.edtSettingsTickMs.Value := String(this.ReadBotSettingNumber(cfg, "TickMs", 500))
        this.edtSettingsAutoFightRetry.Value := String(this.ReadBotSettingNumber(cfg, "AutoFightRetry", 3))
        this.edtSettingsStoreIntervalMin.Value := String(this.ReadBotSettingNumber(cfg, "StoreIntervalMin", 60))
        this.edtSettingsMonitorInterval.Value := String(this.ReadBotSettingNumber(cfg, "MonitorIntervalMs", 10000))
        this.edtSettingsSim.Value := Format("{:.2f}", this.ReadBotSettingNumber(cfg, "Sim", 0.75))
        this.edtSettingsVerifyMapRetry.Value := String(this.ReadBotSettingNumber(cfg, "VerifyMapRetry", 5))
        this.edtSettingsVerifyMapInterval.Value := String(this.ReadBotSettingNumber(cfg, "VerifyMapRetryIntervalMs", 2000))
        this.edtSettingsCheckTownTimeout.Value := String(this.ReadBotSettingNumber(cfg, "CheckTownTimeoutMs", 60000))
        this.edtSettingsScriptMaxFails.Value := String(this.ReadBotSettingNumber(cfg, "ScriptMaxConsecutiveFails", 3))
        this.edtSettingsScriptCooldown.Value := String(this.ReadBotSettingNumber(cfg, "ScriptFailCooldownMs", 600000))
    }

    HandleSaveSettings(*) {
        if !this.deps.Has("cfg") {
            this.ShowSettingsSaveHint("配置不可用，无法保存")
            return
        }
        values := {
            TickMs: this.ParseSettingsNumber(this.edtSettingsTickMs.Value, 100, 5000, 500),
            AutoFightRetry: this.ParseSettingsNumber(this.edtSettingsAutoFightRetry.Value, 1, 10, 3),
            StoreIntervalMin: this.ParseSettingsNumber(this.edtSettingsStoreIntervalMin.Value, 0, 1440, 60),
            MonitorIntervalMs: this.ParseSettingsNumber(this.edtSettingsMonitorInterval.Value, 1000, 600000, 10000),
            Sim: this.ParseSettingsNumber(this.edtSettingsSim.Value, 0.10, 1.00, 0.75, true),
            VerifyMapRetry: this.ParseSettingsNumber(this.edtSettingsVerifyMapRetry.Value, 1, 20, 5),
            VerifyMapRetryIntervalMs: this.ParseSettingsNumber(this.edtSettingsVerifyMapInterval.Value, 0, 30000, 2000),
            CheckTownTimeoutMs: this.ParseSettingsNumber(this.edtSettingsCheckTownTimeout.Value, 5000, 600000, 60000),
            ScriptMaxConsecutiveFails: this.ParseSettingsNumber(this.edtSettingsScriptMaxFails.Value, 1, 10, 3),
            ScriptFailCooldownMs: this.ParseSettingsNumber(this.edtSettingsScriptCooldown.Value, 0, 3600000, 600000)
        }
        if !this.deps["cfg"].SaveBotSettings(values) {
            this.ShowSettingsSaveHint("保存失败，请检查输入")
            return
        }
        this.LoadSettingsIntoControls()
        this.ShowSettingsSaveHint("已保存到 config.ini，立即生效")
        if this.deps.Has("logger") {
            logger := this.deps["logger"]
            if IsObject(logger)
                logger.Info("挂机设置已保存: 相似度=" Format("{:.2f}", values.Sim) " 校验重试=" values.VerifyMapRetry " 土城超时=" values.CheckTownTimeoutMs "ms")
        }
    }

    HandleResetSettings(*) {
        this.edtSettingsTickMs.Value := "500"
        this.edtSettingsAutoFightRetry.Value := "3"
        this.edtSettingsStoreIntervalMin.Value := "60"
        this.edtSettingsMonitorInterval.Value := "10000"
        this.edtSettingsSim.Value := "0.75"
        this.edtSettingsVerifyMapRetry.Value := "5"
        this.edtSettingsVerifyMapInterval.Value := "2000"
        this.edtSettingsCheckTownTimeout.Value := "60000"
        this.edtSettingsScriptMaxFails.Value := "3"
        this.edtSettingsScriptCooldown.Value := "600000"
        this.ShowSettingsSaveHint("已填入默认值，点击「保存设置」后生效")
    }

    ; 解析输入框数值：非法/越界时钳制到范围内
    ParseSettingsNumber(text, minValue, maxValue, fallback, isFloat := false) {
        trimmed := Trim(text)
        value := fallback
        if (trimmed != "") {
            try {
                value := isFloat ? Float(trimmed) : Integer(trimmed)
            } catch {
                value := fallback
            }
        }
        if (value < minValue)
            value := minValue
        if (value > maxValue)
            value := maxValue
        return value
    }

    ReadBotSettingNumber(cfg, key, fallback) {
        try {
            if (IsObject(cfg.Bot) && cfg.Bot.HasProp(key) && cfg.Bot.%key% is Number)
                return cfg.Bot.%key%
        } catch {
        }
        return fallback
    }

    ShowSettingsSaveHint(text) {
        if this.HasProp("txtSettingsSaveHint")
            this.txtSettingsSaveHint.Text := text
    }

    SetRunState(text) {
        if this.HasProp("txtRunState")
            this.txtRunState.Text := text
    }

    SetStatusContext(text) {
        this.statusContextText := text
        if this.HasProp("txtStatusContext")
            this.txtStatusContext.Text := text
    }

    SetLogText(text) {
        if this.HasProp("edtLog")
            this.edtLog.Value := text
        if this.HasProp("edtRunLogs")
            this.edtRunLogs.Value := text
    }

    AppendStepObject(step) {
        return this.AppendStepObjects([step]) > 0
    }

    AppendStepObjects(steps) {
        if !IsObject(this.currentScript) || !IsObject(steps)
            return 0
        appended := 0
        for _, step in steps {
            if !IsObject(step)
                continue
            this.currentScript.steps.Push(step)
            appended += 1
        }
        if (appended = 0)
            return 0
        this.selectedStepIndex := this.currentScript.steps.Length
        this.RefreshSteps()
        return appended
    }

    StartMouseRecording() {
        if !(IsObject(this.currentScript) && this.deps.Has("recorders"))
            return false
        hwnd := this.GetBoundHwnd()
        if !hwnd
            return false
        if this.mouseRecording
            return this.StopMouseRecording()
        if this.deps["recorders"].HasMethod("RecordMouseSequence") {
            started := this.deps["recorders"].RecordMouseSequence(hwnd, ObjBindMethod(this, "OnRecordedStepsReady"))
            if started
                this.SetMouseRecordingState(true)
            return started
        }
        return this.RecordNextClickStep()
    }

    StopMouseRecording() {
        if !this.mouseRecording
            return false
        if !(this.deps.Has("recorders") && this.deps["recorders"].HasMethod("StopMouseSequence"))
            return false
        return this.deps["recorders"].StopMouseSequence()
    }

    RecordNextClickStep() {
        if !(IsObject(this.currentScript) && this.deps.Has("recorders"))
            return false
        hwnd := this.GetBoundHwnd()
        if !hwnd
            return false
        return this.deps["recorders"].RecordNextClick(hwnd, ObjBindMethod(this, "OnRecordedStepReady"))
    }

    RecordKeypressStep() {
        if !(IsObject(this.currentScript) && this.deps.Has("recorders"))
            return false
        if !this.deps["recorders"].HasMethod("PromptKeypressStep")
            return false
        step := this.deps["recorders"].PromptKeypressStep()
        if !step
            return false
        return this.AppendStepObject(step)
    }

    OnRecordedStepReady(step) {
        this.AppendStepObject(step)
    }

    OnRecordedStepsReady(steps) {
        recordedCount := this.AppendStepObjects(steps)
        this.SetMouseRecordingState(false, recordedCount)
    }

    SetMouseRecordingState(active, recordedCount := "") {
        this.mouseRecording := active
        if active {
            this.SetRunState("当前状态：录制鼠标中")
            this.SetStatusContext("录制上下文`n正在录制鼠标事件，点击“停止录制（ESC）”或按 ESC 结束录制。")
            if this.HasProp("btnRecordClick")
                this.btnRecordClick.Text := "停止录制（ESC）"
            return
        }
        if this.HasProp("btnRecordClick")
            this.btnRecordClick.Text := "录制点击"
        if (recordedCount != "" && recordedCount is Number && recordedCount > 0) {
            this.SetRunState("当前状态：已录制 " recordedCount " 个鼠标步骤")
            this.SetStatusContext("录制上下文`n最近一次录制：已录制 " recordedCount " 个鼠标步骤，可继续录制或直接编辑参数。")
            return
        }
        this.SetRunState(this.botRunStateText)
        this.SetStatusContext(this.defaultStatusContextText)
    }

    ApplyStepEdits() {
        if !IsObject(this.currentScript) || this.currentScript.steps.Length = 0
            return false

        step := this.currentScript.steps[this.selectedStepIndex]
        newName := Trim(this.edtStepName.Value)
        if (newName = "")
            newName := this.GetDefaultStepName(step.type)

        step.name := newName
        step.enabled := this.chkStepEnabled.Value = 1
        for key, ctrl in this.propInputs {
            currentValue := step.params.%key%
            step.params.%key% := this.CoerceEditorValue(ctrl.Value, currentValue)
        }
        step.onSuccess := this.ReadStepBranchConfig(this.ddlOnSuccessAction, this.ddlOnSuccessTarget)
        step.onFailure := this.ReadStepBranchConfig(this.ddlOnFailureAction, this.ddlOnFailureTarget)

        this.RefreshSteps()
        this.SelectStep(this.selectedStepIndex)
        return true
    }

    ApplyFlowNodeEdits() {
        if !IsObject(this.currentFlow) || this.currentFlow.nodes.Length = 0
            return false
        node := this.currentFlow.nodes[this.selectedFlowNodeIndex]
        node.name := Trim(this.edtFlowNodeName.Value)
        if (node.name = "")
            node.name := "节点 " this.selectedFlowNodeIndex
        node.scriptName := Trim(this.cmbFlowNodeScript.Text)
        node.onSuccess := this.ReadFlowBranchConfig(this.ddlFlowSuccessAction, this.cmbFlowSuccessTarget)
        node.onFailure := this.ReadFlowBranchConfig(this.ddlFlowFailureAction, this.cmbFlowFailureTarget)
        try node.maxLoops := Integer(Trim(this.edtFlowNodeMaxLoops.Value))
        catch
            node.maxLoops := 0
        if (node.maxLoops < 0)
            node.maxLoops := 0
        this.RefreshFlowNodes()
        this.SelectFlowNode(this.selectedFlowNodeIndex)
        return true
    }

    ReadStepBranchConfig(actionCtrl, targetCtrl) {
        action := Trim(actionCtrl.Text)
        if (action = "")
            action := "next"
        branch := {action: action}
        if (action = "jump") {
            target := Trim(targetCtrl.Text)
            if (target != "")
                branch.targetStepId := target
        }
        return branch
    }

    ReadFlowBranchConfig(actionCtrl, targetCtrl) {
        action := Trim(actionCtrl.Text)
        if (action = "")
            action := "next"
        branch := {action: action}
        if (action = "goto") {
            target := Trim(targetCtrl.Text)
            if (target != "")
                branch.targetNodeId := target
        }
        return branch
    }

    BindOptionalClick(ctrl, key) {
        if !this.deps.Has(key)
            return
        callback := this.deps[key]
        if IsObject(callback)
            ctrl.OnEvent("Click", callback)
    }

    HandleNewScript(*) {
        ib := InputBox("请输入新脚本名称：", "新建脚本")
        if (ib.Result = "Cancel" || Trim(ib.Value) = "")
            return
        this.CreateAndPersistScript(Trim(ib.Value), "enter_map")
    }

    HandleSaveScript(*) {
        this.SaveCurrentScript()
    }

    HandleRunScript(*) {
        if !IsObject(this.currentScript)
            return
        result := this.RunCurrentScript()
        this.ShowRunResult(result)
    }

    HandleRunFromCurrentStep(*) {
        if !IsObject(this.currentScript)
            return
        result := this.RunFromCurrentStep()
        this.ShowRunResult(result)
    }

    ShowRunResult(result) {
        if !IsObject(result)
            return
        if (result.HasProp("ok") && result.ok) {
            MsgBox("脚本执行完成。", "运行结果")
            return
        }
        failedId := result.HasProp("failedStepId") ? result.failedStepId : ""
        failedIndex := 0
        failedSummary := ""
        if IsObject(this.currentScript) && (failedId != "") {
            for index, step in this.currentScript.steps {
                if (step.id = failedId) {
                    failedIndex := index
                    failedSummary := this.StepSummary(step)
                    break
                }
            }
        }
        message := "脚本执行中断。"
        if (failedIndex > 0)
            message .= "`n失败步骤: 第 " failedIndex " 步 [" failedSummary "]"
        message .= "`n`n该步骤的「失败后」动作为停止，因此后续步骤未执行。"
        MsgBox(message, "运行结果")
    }

    HandleRunCurrentStep(*) {
        if IsObject(this.currentScript) && this.currentScript.steps.Length > 0
            this.RunCurrentStep()
    }

    HandleDeleteScript(*) {
        if !IsObject(this.currentScript)
            return
        result := MsgBox("确定删除脚本「" this.currentScript.name "」吗？", "删除脚本", "YesNo Icon! Default2")
        if (result = "Yes")
            this.DeleteCurrentScript()
    }

    HandleApplyStep(*) {
        this.ApplyStepEdits()
    }

    HandleRecordClick(*) {
        if !IsObject(this.currentScript) {
            MsgBox("请先新建或选择一个脚本。", "提示")
            return
        }
        if !this.GetBoundHwnd() {
            MsgBox("请先绑定窗口后再录制点击步骤。", "提示")
            return
        }
        if !this.StartMouseRecording()
            MsgBox("当前录制服务不可用。", "提示")
    }

    HandleRecordKey(*) {
        if !IsObject(this.currentScript) {
            MsgBox("请先新建或选择一个脚本。", "提示")
            return
        }
        this.RecordKeypressStep()
    }

    HandleAddWait(*) {
        this.AddStep("wait")
    }

    HandleAddClick(*) {
        this.AddStep("click")
    }

    HandleAddFindImage(*) {
        step := this.AddStep("find_image")
        if step
            this.ConfigureSelectedStep()
    }

    HandleAddClickImage(*) {
        step := this.AddStep("click_image")
        if step
            this.ConfigureSelectedStep()
    }

    HandleAddOcrMatch(*) {
        step := this.AddStep("ocr_match")
        if step
            this.ConfigureSelectedStep()
    }

    HandleAddMoveToCoord(*) {
        step := this.AddStep("move_to_coord")
        if step
            this.ConfigureSelectedStep()
    }

    HandleApplyMovePreset(*) {
        MsgBox("点击式导航已不再提供预设工具。", "提示")
    }

    HandleFlipMoveAxis(axisName, *) {
        MsgBox("点击式导航已不再提供方向翻转工具。", "提示")
    }

    HandleSwapMoveAxes(*) {
        MsgBox("点击式导航已不再提供交换轴工具。", "提示")
    }

    HandleAdjustMoveDirectionScale(delta, *) {
        MsgBox("点击式导航已不再提供缩放纠偏工具。", "提示")
    }

    ApplySelectedMovePreset() {
        return false
    }

    FlipSelectedMoveAxis(axisName) {
        return false
    }

    SwapSelectedMoveAxes() {
        return false
    }

    AdjustSelectedMoveDirectionScale(delta) {
        return false
    }

    DefaultMovePreset() {
        return {}
    }

    HandleAddBranch(*) {
        step := this.AddStep("branch")
        if step
            this.ConfigureSelectedStep()
    }

    HandleConfigureStep(*) {
        this.ConfigureSelectedStep()
    }

    HandleTestMoveToCoord(*) {
        if !IsObject(this.currentScript) {
            MsgBox("请先新建或选择一个脚本。", "提示")
            return
        }
        if !this.GetBoundHwnd() {
            MsgBox("请先绑定窗口后再测试导航步骤。", "提示")
            return
        }
        if !this.RunSelectedMoveToCoordStep() {
            result := this.HasProp("lastMoveToCoordTestResult") ? this.lastMoveToCoordTestResult : ""
            message := "当前选中的步骤不是导航步骤，或导航测试执行失败。"
            if IsObject(result) && result.HasProp("reason") && result.reason != ""
                message := "导航测试失败: " . result.reason
            MsgBox(message, "提示")
        }
    }

    HandleCaptureCoordTemplates(*) {
        if !this.GetBoundHwnd() {
            MsgBox("请先绑定游戏窗口。", "提示")
            return
        }
        if (this.deps.Has("onCaptureCoordTemplates")) {
            callback := this.deps["onCaptureCoordTemplates"]
            if IsObject(callback)
                callback.Call()
        } else {
            MsgBox("模板截取功能未就绪。", "提示")
        }
    }

    HandleReadCoord(*) {
        if !this.GetBoundHwnd() {
            MsgBox("请先绑定游戏窗口。", "提示")
            return
        }
        if (this.deps.Has("onReadCoord")) {
            callback := this.deps["onReadCoord"]
            if IsObject(callback)
                callback.Call()
        } else {
            MsgBox("读坐标功能未就绪。", "提示")
        }
    }

    HandleCalibrateMoveSpeed(*) {
        MsgBox("点击式导航已不再提供跑速标定。", "提示")
    }

    HandleDiagnoseMoveDirection(*) {
        MsgBox("点击式导航已不再提供方向诊断。", "提示")
    }

    HandleApplyMoveDirectionAdvice(*) {
        MsgBox("点击式导航已不再提供方向建议应用。", "提示")
    }

    HandlePickMoveCoordRegion(*) {
        if !this.PickSelectedMoveCoordRegion()
            MsgBox("当前选中的步骤不是导航步骤，或取框工具不可用。", "提示")
    }

    HandlePickMoveCenter(*) {
        if !this.PickSelectedMoveCenter()
            MsgBox("当前选中的步骤不是导航步骤，或取点工具不可用。", "提示")
    }

    PickSelectedMoveCoordRegion() {
        if !(IsObject(this.currentScript) && this.currentScript.steps.Length > 0 && this.deps.Has("manualTools"))
            return false
        step := this.currentScript.steps[this.selectedStepIndex]
        if (step.type != "move_to_coord")
            return false

        info := this.deps["manualTools"].ShowTextOcrDialog(
            "配置导航步骤",
            "",
            step.params.HasProp("coordRegion") ? step.params.coordRegion : "",
            false
        )
        if !info
            return false

        step.params.coordRegion := info.region
        this.RefreshSteps()
        this.SelectStep(this.selectedStepIndex)
        return true
    }

    PickSelectedMoveCenter() {
        if !(IsObject(this.currentScript) && this.currentScript.steps.Length > 0 && this.deps.Has("manualTools"))
            return false
        step := this.currentScript.steps[this.selectedStepIndex]
        if (step.type != "move_to_coord")
            return false

        initialPoint := {
            x: step.params.HasProp("playerCenterX") ? step.params.playerCenterX : 0,
            y: step.params.HasProp("playerCenterY") ? step.params.playerCenterY : 0
        }
        point := this.deps["manualTools"].ShowClientPointDialog("设置玩家中心点", initialPoint, "请点一下角色中心")
        if !IsObject(point)
            return false

        step.params.playerCenterX := point.x
        step.params.playerCenterY := point.y
        this.RefreshSteps()
        this.SelectStep(this.selectedStepIndex)
        return true
    }

    ConfigureSelectedStep() {
        if !(IsObject(this.currentScript) && this.currentScript.steps.Length > 0 && this.deps.Has("manualTools"))
            return false

        step := this.currentScript.steps[this.selectedStepIndex]
        manualTools := this.deps["manualTools"]
        switch step.type {
            case "find_image", "click_image":
                info := manualTools.ShowImageRegionDialog(
                    "配置识别步骤",
                    step.params.HasProp("image") ? step.params.image : "",
                    step.params.HasProp("timeout") ? step.params.timeout : "",
                    step.params.HasProp("region") ? step.params.region : "",
                    true,
                    false,
                    "选择图片并框选搜索区域，用于当前步骤。",
                    true,
                    step.params.HasProp("sim") ? step.params.sim : ""
                )
                if info {
                    step.params.image := info.image
                    step.params.region := info.region
                    if info.HasProp("sim")
                        step.params.sim := info.sim
                    if info.HasProp("timeout")
                        step.params.timeout := info.timeout
                }
            case "ocr_match":
                info := manualTools.ShowTextOcrDialog(
                    "配置 OCR 步骤",
                    step.params.HasProp("targetText") ? step.params.targetText : "",
                    step.params.HasProp("region") ? step.params.region : "",
                    true
                )
                if info {
                    step.params.targetText := info.targetText
                    step.params.region := info.region
                }
            case "move_to_coord":
                info := manualTools.ShowTextOcrDialog(
                    "配置导航步骤",
                    "",
                    step.params.HasProp("coordRegion") ? step.params.coordRegion : "",
                    false
                )
                if info
                    step.params.coordRegion := info.region
            case "branch":
                conditionType := step.params.HasProp("conditionType") ? step.params.conditionType : "ocr_match"
                if (conditionType = "find_image") {
                    info := manualTools.ShowImageRegionDialog(
                        "配置条件分支",
                        step.params.HasProp("image") ? step.params.image : "",
                        step.params.HasProp("timeout") ? step.params.timeout : "",
                        step.params.HasProp("region") ? step.params.region : "",
                        true,
                        false,
                        "设置条件分支的图片识别规则。",
                        true,
                        step.params.HasProp("sim") ? step.params.sim : ""
                    )
                    if info {
                        step.params.image := info.image
                        step.params.region := info.region
                        if info.HasProp("sim")
                            step.params.sim := info.sim
                        if info.HasProp("timeout")
                            step.params.timeout := info.timeout
                    }
                } else {
                    step.params.conditionType := "ocr_match"
                    info := manualTools.ShowTextOcrDialog(
                        "配置条件分支",
                        step.params.HasProp("targetText") ? step.params.targetText : "",
                        step.params.HasProp("region") ? step.params.region : "",
                        true
                    )
                    if info {
                        step.params.targetText := info.targetText
                        step.params.region := info.region
                    }
                }
        }
        this.RefreshSteps()
        this.SelectStep(this.selectedStepIndex)
        return true
    }

    HandleNewFlow(*) {
        if !this.deps.Has("flowRepo")
            return
        ib := InputBox("请输入新流程名称：", "新建流程")
        if (ib.Result = "Cancel" || Trim(ib.Value) = "")
            return
        this.CreateAndPersistFlow(Trim(ib.Value))
    }

    HandleSaveFlow(*) {
        this.SaveCurrentFlow()
    }

    HandleDeleteFlow(*) {
        if !IsObject(this.currentFlow)
            return
        result := MsgBox("确定删除流程「" this.currentFlow.name "」吗？", "删除流程", "YesNo Icon! Default2")
        if (result = "Yes")
            this.DeleteCurrentFlow()
    }

    HandleAddFlowNode(*) {
        if !IsObject(this.currentFlow) {
            MsgBox("请先新建或选择一个流程。", "提示")
            return
        }
        this.AddFlowNode()
    }

    HandleRunFlow(*) {
        if IsObject(this.currentFlow) && (this.deps.Has("flowRunner") || this.deps.Has("runner"))
            this.RunCurrentFlow()
    }

    HandleApplyFlowNode(*) {
        this.ApplyFlowNodeEdits()
    }

    BuildStepEditor(guiObj) {
        this.pnlProps.GetPos(&panelX, &panelY, &panelW, &panelH)
        editorX := panelX + 10
        labelW := 78
        fieldX := editorX + labelW
        fieldW := panelW - labelW - 20
        rowY := panelY + panelH + 12

        this.lblStepType := guiObj.Add("Text", Format("x{} y{} w{} h23 +0x200", editorX, rowY, labelW), "类型")
        this.edtStepType := guiObj.Add("Edit", Format("x{} y{} w{} h23 ReadOnly", fieldX, rowY, fieldW), "")

        rowY += 26
        this.lblStepName := guiObj.Add("Text", Format("x{} y{} w{} h23 +0x200", editorX, rowY, labelW), "名称")
        this.edtStepName := guiObj.Add("Edit", Format("x{} y{} w{} h23", fieldX, rowY, fieldW), "")

        rowY += 26
        this.chkStepEnabled := guiObj.Add("CheckBox", Format("x{} y{} w90 h23", fieldX, rowY), "启用")
        this.btnApplyStep := guiObj.Add("Button", Format("x{} y{} w120 h28", panelX + panelW - 130, rowY - 2), "应用到当前步骤")
        this.btnApplyStep.OnEvent("Click", ObjBindMethod(this, "HandleApplyStep"))

        rowY += 28
        this.lblOnSuccessAction := guiObj.Add("Text", Format("x{} y{} w{} h23 +0x200", editorX, rowY, labelW), "成功")
        this.ddlOnSuccessAction := guiObj.Add("ComboBox", Format("x{} y{} w90 h120", fieldX, rowY), ["next", "jump", "stop"])
        this.lblOnSuccessTarget := guiObj.Add("Text", Format("x{} y{} w36 h23 +0x200", fieldX + 96, rowY, 36), "到")
        this.ddlOnSuccessTarget := guiObj.Add("ComboBox", Format("x{} y{} w{} h120", fieldX + 132, rowY, fieldW - 132), [])

        rowY += 26
        this.lblOnFailureAction := guiObj.Add("Text", Format("x{} y{} w{} h23 +0x200", editorX, rowY, labelW), "失败")
        this.ddlOnFailureAction := guiObj.Add("ComboBox", Format("x{} y{} w90 h120", fieldX, rowY), ["next", "jump", "stop"])
        this.lblOnFailureTarget := guiObj.Add("Text", Format("x{} y{} w36 h23 +0x200", fieldX + 96, rowY, 36), "到")
        this.ddlOnFailureTarget := guiObj.Add("ComboBox", Format("x{} y{} w{} h120", fieldX + 132, rowY, fieldW - 132), [])

        this.paramEditorStartX := editorX
        this.paramEditorLabelW := labelW
        this.paramEditorFieldX := fieldX
        this.paramEditorFieldW := fieldW
        this.paramEditorStartY := rowY + 28
        this.txtStepHint := guiObj.Add("Edit", Format("x{} y{} w{} h56 ReadOnly VScroll", editorX, this.paramEditorStartY, labelW + fieldW), "")
        this.txtStepHint.Visible := false
    }

    BuildFlowEditor(guiObj) {
        this.pnlFlowProps.GetPos(&panelX, &panelY, &panelW, &panelH)
        editorX := panelX + 10
        labelW := 60
        fieldX := editorX + labelW
        fieldW := panelW - labelW - 20
        rowY := panelY + panelH + 12

        this.lblFlowNodeName := guiObj.Add("Text", Format("x{} y{} w{} h23 +0x200", editorX, rowY, labelW), "名称")
        this.edtFlowNodeName := guiObj.Add("Edit", Format("x{} y{} w{} h23", fieldX, rowY, fieldW), "")

        rowY += 30
        this.lblFlowScript := guiObj.Add("Text", Format("x{} y{} w{} h23 +0x200", editorX, rowY, labelW), "脚本")
        this.cmbFlowNodeScript := guiObj.Add("ComboBox", Format("x{} y{} w{} h160", fieldX, rowY, fieldW), [])

        rowY += 30
        this.lblFlowSuccessAction := guiObj.Add("Text", Format("x{} y{} w{} h23 +0x200", editorX, rowY, labelW), "成功")
        this.ddlFlowSuccessAction := guiObj.Add("ComboBox", Format("x{} y{} w90 h120", fieldX, rowY), ["next", "goto", "repeat", "stop"])
        this.lblFlowSuccessTarget := guiObj.Add("Text", Format("x{} y{} w36 h23 +0x200", fieldX + 96, rowY, 36), "到")
        this.cmbFlowSuccessTarget := guiObj.Add("ComboBox", Format("x{} y{} w{} h160", fieldX + 132, rowY, fieldW - 132), [])

        rowY += 30
        this.lblFlowFailureAction := guiObj.Add("Text", Format("x{} y{} w{} h23 +0x200", editorX, rowY, labelW), "失败")
        this.ddlFlowFailureAction := guiObj.Add("ComboBox", Format("x{} y{} w90 h120", fieldX, rowY), ["next", "goto", "repeat", "stop"])
        this.lblFlowFailureTarget := guiObj.Add("Text", Format("x{} y{} w36 h23 +0x200", fieldX + 96, rowY, 36), "到")
        this.cmbFlowFailureTarget := guiObj.Add("ComboBox", Format("x{} y{} w{} h160", fieldX + 132, rowY, fieldW - 132), [])

        rowY += 30
        this.lblFlowMaxLoops := guiObj.Add("Text", Format("x{} y{} w{} h23 +0x200", editorX, rowY, labelW), "循环")
        this.edtFlowNodeMaxLoops := guiObj.Add("Edit", Format("x{} y{} w90 h23", fieldX, rowY), "0")
        this.btnApplyFlowNode := guiObj.Add("Button", Format("x{} y{} w120 h28", panelX + panelW - 130, rowY - 2), "应用节点")
    }

    SetStepEditorEmptyState() {
        if !this.HasProp("edtStepType")
            return

        this.edtStepType.Value := ""
        this.edtStepName.Value := ""
        this.chkStepEnabled.Value := 0
        this.ddlOnSuccessAction.Text := "next"
        this.ddlOnSuccessTarget.Text := ""
        this.ddlOnFailureAction.Text := "stop"
        this.ddlOnFailureTarget.Text := ""
        this.HideParamEditors()
        if this.HasProp("txtStepHint") {
            this.txtStepHint.Value := ""
            this.txtStepHint.Visible := false
        }
        this.SetStepEditorEnabled(false)
        this.UpdateLayout()
    }

    FillStepEditor(step) {
        if !this.HasProp("edtStepType")
            return

        this.SetStepEditorEnabled(true)
        this.edtStepType.Value := step.type
        this.edtStepName.Value := step.name
        this.chkStepEnabled.Value := step.enabled ? 1 : 0
        this.RefreshStepTargetChoices()
        this.ddlOnSuccessAction.Text := step.onSuccess.HasProp("action") ? step.onSuccess.action : "next"
        this.ddlOnSuccessTarget.Text := step.onSuccess.HasProp("targetStepId") ? step.onSuccess.targetStepId : ""
        this.ddlOnFailureAction.Text := step.onFailure.HasProp("action") ? step.onFailure.action : "stop"
        this.ddlOnFailureTarget.Text := step.onFailure.HasProp("targetStepId") ? step.onFailure.targetStepId : ""
        if this.HasProp("btnTestMoveToCoord")
            this.btnTestMoveToCoord.Enabled := (step.type = "move_to_coord")
        if this.HasProp("btnPickMoveCoordRegion")
            this.btnPickMoveCoordRegion.Enabled := (step.type = "move_to_coord") && this.deps.Has("manualTools")
        if this.HasProp("btnPickMoveCenter")
            this.btnPickMoveCenter.Enabled := (step.type = "move_to_coord") && this.deps.Has("manualTools")
        this.RebuildParamEditors(step)
        this.UpdateLayout()
    }

    SetStepEditorEnabled(enabled) {
        controls := ["edtStepType", "edtStepName", "chkStepEnabled", "ddlOnSuccessAction", "ddlOnSuccessTarget", "ddlOnFailureAction", "ddlOnFailureTarget", "btnApplyStep", "btnConfigureStep", "btnTestMoveToCoord", "btnPickMoveCoordRegion", "btnPickMoveCenter"]
        for _, name in controls {
            if this.HasProp(name)
                this.%name%.Enabled := enabled
        }
        for _, ctrl in this.propInputs
            ctrl.Enabled := enabled
    }

    RebuildParamEditors(step) {
        this.HideParamEditors()
        rowY := this.paramEditorStartY
        index := 1
        for _, key in this.OrderedStepParamKeys(step) {
            value := step.params.%key%
            if (index > this.propLabels.Length) {
                label := this.gui.Add("Text", Format("x{} y{} w{} h23 +0x200", this.paramEditorStartX, rowY, this.paramEditorLabelW), "")
                input := this.gui.Add("Edit", Format("x{} y{} w{} h23", this.paramEditorFieldX, rowY, this.paramEditorFieldW), "")
                help := this.gui.Add("Text", Format("x{} y{} w{} h18", this.paramEditorFieldX, rowY + 22, this.paramEditorFieldW), "")
                this.propLabels.Push(label)
                this.propEditors.Push(input)
                this.propHelpTexts.Push(help)
            } else {
                label := this.propLabels[index]
                input := this.propEditors[index]
                help := this.propHelpTexts[index]
            }
            label.Move(this.paramEditorStartX, rowY, this.paramEditorLabelW)
            input.Move(this.paramEditorFieldX, rowY, this.paramEditorFieldW)
            label.Text := this.ParamLabelText(key, step.type)
            label.Visible := true
            input.Value := this.ParamEditorText(value)
            input.Visible := true
            this.propInputs[key] := input
            help.Text := ""
            help.Visible := false
            rowY += (step.type = "move_to_coord") ? 24 : 28
            index += 1
        }
        this.RefreshStepHint(step, rowY)
    }

    OrderedStepParamKeys(step) {
        keys := []
        if !(IsObject(step) && step.HasProp("params"))
            return keys
        if (step.type = "move_to_coord") {
            preferred := ["coordRegion", "targetX", "targetY", "playerCenterX", "playerCenterY", "clickOffsetPx", "ocrEveryClicks", "ocrRetryCount", "ocrRetryIntervalMs", "stuckRounds", "tolerance", "timeoutMs"]
            for _, key in preferred {
                if (step.params.HasProp(key) && this.ShouldShowMoveToCoordParam(key))
                    keys.Push(key)
            }
            for key, _ in step.params.OwnProps() {
                if (!this.HasArrayItem(keys, key) && this.ShouldShowMoveToCoordParam(key))
                    keys.Push(key)
            }
            return keys
        }
        for key, _ in step.params.OwnProps()
            keys.Push(key)
        return keys
    }

    ShouldShowMoveToCoordParam(key) {
        return !(key = "ocrRetryCount" || key = "ocrRetryIntervalMs" || key = "stuckRounds")
    }

    HasArrayItem(items, target) {
        for _, item in items {
            if (item = target)
                return true
        }
        return false
    }

    HideParamEditors() {
        for _, ctrl in this.propLabels
            ctrl.Visible := false
        for _, ctrl in this.propEditors
            ctrl.Visible := false
        for _, ctrl in this.propHelpTexts
            ctrl.Visible := false
        this.propInputs := Map()
    }

    RefreshStepHint(step, topY) {
        if !this.HasProp("txtStepHint")
            return
        hint := this.StepEditorHintText(step)
        this.txtStepHint.Value := hint
        this.txtStepHint.Move(this.paramEditorStartX, topY, this.paramEditorLabelW + this.paramEditorFieldW, 56)
        this.txtStepHint.Visible := (hint != "")
    }

    SetFlowEditorEmptyState() {
        this.edtFlowNodeName.Value := ""
        this.edtFlowNodeName.Enabled := false
        this.cmbFlowNodeScript.Text := ""
        this.cmbFlowNodeScript.Enabled := false
        this.ddlFlowSuccessAction.Text := "next"
        this.ddlFlowSuccessAction.Enabled := false
        this.cmbFlowSuccessTarget.Text := ""
        this.cmbFlowSuccessTarget.Enabled := false
        this.ddlFlowFailureAction.Text := "stop"
        this.ddlFlowFailureAction.Enabled := false
        this.cmbFlowFailureTarget.Text := ""
        this.cmbFlowFailureTarget.Enabled := false
        if this.HasProp("ddlFlowSuccessAction")
            this.ddlFlowSuccessAction.Text := "next"
        if this.HasProp("ddlFlowFailureAction")
            this.ddlFlowFailureAction.Text := "stop"
        if this.HasProp("edtFlowNodeMaxLoops") {
            this.edtFlowNodeMaxLoops.Value := "0"
            this.edtFlowNodeMaxLoops.Enabled := false
        }
        if this.HasProp("btnApplyFlowNode")
            this.btnApplyFlowNode.Enabled := false
        this.UpdateLayout()
    }

    FillFlowNodeEditor(node) {
        controls := [
            "edtFlowNodeName", "cmbFlowNodeScript", "ddlFlowSuccessAction", "cmbFlowSuccessTarget",
            "ddlFlowFailureAction", "cmbFlowFailureTarget", "edtFlowNodeMaxLoops", "btnApplyFlowNode"
        ]
        for _, name in controls
            this.%name%.Enabled := true
        this.RefreshFlowScriptChoices()
        this.RefreshFlowTargetChoices()
        this.edtFlowNodeName.Value := node.name
        this.cmbFlowNodeScript.Text := node.scriptName
        this.ddlFlowSuccessAction.Text := node.onSuccess.HasProp("action") ? node.onSuccess.action : "next"
        this.cmbFlowSuccessTarget.Text := node.onSuccess.HasProp("targetNodeId") ? node.onSuccess.targetNodeId : ""
        this.ddlFlowFailureAction.Text := node.onFailure.HasProp("action") ? node.onFailure.action : "stop"
        this.cmbFlowFailureTarget.Text := node.onFailure.HasProp("targetNodeId") ? node.onFailure.targetNodeId : ""
        this.edtFlowNodeMaxLoops.Value := node.maxLoops ""
        this.UpdateLayout()
    }

    RefreshStepTargetChoices() {
        if !(this.HasProp("ddlOnSuccessTarget") && this.HasProp("ddlOnFailureTarget"))
            return
        targets := []
        if IsObject(this.currentScript) {
            for _, step in this.currentScript.steps
                targets.Push(step.id)
        }
        this.ddlOnSuccessTarget.Delete()
        this.ddlOnFailureTarget.Delete()
        if (targets.Length > 0) {
            this.ddlOnSuccessTarget.Add(targets)
            this.ddlOnFailureTarget.Add(targets)
        }
    }

    RefreshFlowScriptChoices() {
        if !this.HasProp("cmbFlowNodeScript")
            return
        this.cmbFlowNodeScript.Delete()
        if (this.scriptNames.Length > 0)
            this.cmbFlowNodeScript.Add(this.scriptNames)
    }

    RefreshFlowTargetChoices() {
        if !(this.HasProp("cmbFlowSuccessTarget") && this.HasProp("cmbFlowFailureTarget"))
            return
        targets := []
        if IsObject(this.currentFlow) {
            for _, node in this.currentFlow.nodes
                targets.Push(node.id)
        }
        this.cmbFlowSuccessTarget.Delete()
        this.cmbFlowFailureTarget.Delete()
        if (targets.Length > 0) {
            this.cmbFlowSuccessTarget.Add(targets)
            this.cmbFlowFailureTarget.Add(targets)
        }
    }

    CoerceEditorValue(rawValue, currentValue) {
        typeName := Type(currentValue)
        if IsObject(currentValue) {
            parsedRegion := this.TryParseRegionValue(rawValue, currentValue)
            return parsedRegion ? parsedRegion : currentValue
        }
        if (typeName = "Integer") {
            if (Trim(rawValue) = "")
                return 0
            try return Integer(rawValue)
            catch
                return currentValue
        }
        if (typeName = "Float") {
            if (Trim(rawValue) = "")
                return 0.0
            try return Float(rawValue)
            catch
                return currentValue
        }
        return rawValue
    }

    TryParseRegionValue(rawValue, currentValue) {
        if !(currentValue.HasProp("x1") && currentValue.HasProp("y1") && currentValue.HasProp("x2") && currentValue.HasProp("y2"))
            return ""

        text := Trim(rawValue)
        if (text = "")
            return ""

        text := RegExReplace(text, "i)x1\s*:|y1\s*:|x2\s*:|y2\s*:", "")
        numberText := RegExReplace(text, "[^\d-]+", ",")
        numberText := Trim(numberText, ",")
        if (numberText = "")
            return ""
        parts := StrSplit(numberText, ",")
        if (parts.Length < 4)
            return ""
        try {
            return {
                x1: Integer(parts[1]),
                y1: Integer(parts[2]),
                x2: Integer(parts[3]),
                y2: Integer(parts[4])
            }
        } catch {
            return ""
        }
        return ""
    }

    GetDefaultStepName(type) {
        if this.deps.Has("schema")
            return this.deps["schema"].DefaultName(type)
        return type
    }

    ParamLabelText(key, stepType := "") {
        if (stepType = "move_to_coord") {
            switch key {
                case "coordRegion":
                    return "坐标识别区域"
                case "targetX":
                    return "目标X"
                case "targetY":
                    return "目标Y"
                case "playerCenterX":
                    return "中心X"
                case "playerCenterY":
                    return "中心Y"
                case "clickOffsetPx":
                    return "点击偏移"
                case "ocrEveryClicks":
                    return "校验点击数"
                case "ocrRetryCount":
                    return "OCR重试次数"
                case "ocrRetryIntervalMs":
                    return "重试间隔"
                case "stuckRounds":
                    return "卡住轮次"
                case "tolerance":
                    return "到点容差"
                case "timeoutMs":
                    return "超时毫秒"
            }
        }
        return key
    }

    StepParamsSummaryText(step) {
        if !(IsObject(step) && step.HasProp("params"))
            return ""
        text := ""
        if (step.type = "move_to_coord")
            return this.MoveToCoordSummaryText(step.params)
        for key, value in step.params.OwnProps()
            text .= "`n" this.ParamLabelText(key, step.type) ": " this.ParamValueText(value)
        return text
    }

    MoveToCoordSummaryText(params) {
        text := ""
        for key, value in params.OwnProps() {
            if (key = "targetX" || key = "targetY" || key = "playerCenterX" || key = "playerCenterY")
                continue
            if !this.ShouldShowMoveToCoordParam(key)
                continue
            labelText := this.MoveToCoordSummaryLabelText(key)
            text .= "`n" labelText ": " this.ParamValueText(value)
        }
        if (params.HasProp("targetX") || params.HasProp("targetY")) {
            targetX := params.HasProp("targetX") ? params.targetX : 0
            targetY := params.HasProp("targetY") ? params.targetY : 0
            text .= "`n目标坐标: " targetX "," targetY
        }
        if (params.HasProp("playerCenterX") || params.HasProp("playerCenterY")) {
            centerX := params.HasProp("playerCenterX") ? params.playerCenterX : 0
            centerY := params.HasProp("playerCenterY") ? params.playerCenterY : 0
            text .= "`n玩家中心点: " centerX "," centerY
        }
        return text
    }

    MoveToCoordSummaryLabelText(key) {
        switch key {
            case "coordRegion":
                return "坐标识别框"
            case "clickOffsetPx":
                return "点击偏移"
            case "ocrEveryClicks":
                return "校验频率"
            case "ocrRetryCount":
                return "OCR重试"
            case "ocrRetryIntervalMs":
                return "重试间隔"
            case "stuckRounds":
                return "卡住轮次"
        }
        return this.ParamLabelText(key, "move_to_coord")
    }

    ParamHelpText(key, stepType := "") {
        if (stepType = "move_to_coord") {
            switch key {
                case "coordRegion":
                    return "只框住地图坐标数字，尽量不要带地图名。"
                case "playerCenterX", "playerCenterY":
                    return "玩家中心点要尽量落在角色站位附近。"
                case "clickOffsetPx":
                    return "建议先用 200，再按实际游戏点击偏移微调。"
                case "ocrEveryClicks":
                    return "推荐 6-8 次点击做一次 OCR 校验。"
                case "ocrRetryCount":
                    return "OCR 偶发失败时额外再试几次，默认已调稳，一般不用改。"
                case "ocrRetryIntervalMs":
                    return "OCR 重试前的等待毫秒，默认已调稳，一般不用改。"
                case "stuckRounds":
                    return "连续几轮没更接近目标就判定卡住，默认已调稳，一般不用改。"
                case "tolerance":
                    return "建议 1，允许坐标在目标点附近微小偏差。"
            }
        }
        return ""
    }

    StepPropsHintText(step) {
        if !IsObject(step)
            return ""
        switch step.type {
            case "move_to_coord":
                return "提示: 每次右键按 2 格预测移动；当 X 和 Y 都未到位时优先走对角；每批点击后再 OCR 校验当前坐标；默认会自动补读 OCR 并判定卡住。"
        }
        return ""
    }

    StepEditorHintText(step) {
        if !IsObject(step)
            return ""
        switch step.type {
            case "move_to_coord":
                hint := "导航提示`n"
                    . "坐标区域尽量只框住地图坐标数字，避免把地图名一起框进去。`n"
                    . "玩家中心点要尽量落在角色站位附近，右键点击会围绕它计算。`n"
                    . "每次点击默认按 2 格预测移动；当 X 和 Y 都未到位时，优先走对角。`n"
                    . "点击偏移决定鼠标落点离人物中心多远，推荐先用 200。`n"
                    . "校验点击数决定每几次右键后再 OCR 一次，默认 6 次。`n"
                    . "一般不用手动调整 OCR 重试和卡住判定，默认值已按实跑稳定性收紧。`n"
                    . "到点容差建议 1，允许坐标在目标点附近微小误差。"
                return hint
        }
        return ""
    }

    GetMoveDirectionAdviceText(step) {
        advice := this.GetMoveDirectionAdvice(step)
        if !IsObject(advice)
            return ""
        return advice.HasProp("summaryText") ? advice.summaryText : ""
    }

    GetMoveDirectionAdvice(step) {
        if !(IsObject(step) && step.HasProp("id"))
            return ""
        if !this.moveDirectionAdvice.Has(step.id)
            return ""
        advice := this.moveDirectionAdvice[step.id]
        if IsObject(advice)
            return advice
        return {summaryText: advice, suggestedActions: []}
    }
}
