#Requires AutoHotkey v2.0

#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk
#Include ..\lib\ScriptEditor.ahk

statusPath := A_ScriptDir "\tmp_script_editor_step_edit_status.txt"
if FileExist(statusPath)
    FileDelete(statusPath)

HasVisiblePropLabel(editor, text) {
    for _, label in editor.propLabels {
        if (label.Visible && label.Text = text)
            return true
    }
    return false
}

HasVisiblePropHint(editor, text) {
    if !editor.HasProp("propHelpTexts")
        return false
    for _, hint in editor.propHelpTexts {
        if (hint.Visible && InStr(hint.Text, text))
            return true
    }
    return false
}

HasAnyVisiblePropHint(editor) {
    if !editor.HasProp("propHelpTexts")
        return false
    for _, hint in editor.propHelpTexts {
        if hint.Visible
            return true
    }
    return false
}

GetControlRect(ctrl) {
    ctrl.GetPos(&x, &y, &w, &h)
    return {x: x, y: y, w: w, h: h}
}

try {
    scriptsDir := A_ScriptDir "\tmp_editor_step_edit"
    if DirExist(scriptsDir)
        DirDelete(scriptsDir, 1)

    repo := ScriptRepository(scriptsDir)
    script := repo.CreateScript("步骤编辑测试", "enter_map")
    clickStep := StepSchema.CreateStep("click")
    clickStep.name := "原始点击"
    clickStep.params.x := 237
    clickStep.params.y := 237
    clickStep.params.button := "L"
    clickStep.params.delay := 3688
    waitStep := StepSchema.CreateStep("wait")
    waitStep.id := "step_2"
    waitStep.name := "等待确认"
    waitStep.params.ms := 1000
    clickStep.id := "step_1"
    script.steps.Push(clickStep)
    script.steps.Push(waitStep)
    repo.SaveScript(script)

    editor := ScriptEditor(Map("repo", repo, "schema", StepSchema))
    guiObj := editor.Build()
    editor.ShowPage("脚本编辑")
    editor.LoadScriptByName("步骤编辑测试")
    editor.SelectStep(1)

    if !editor.HasProp("btnApplyStep")
        throw Error("Build should create an apply button for editing the current step")
    if !editor.propInputs.Has("x")
        throw Error("RefreshProps should create an editable field for the x param")
    if !editor.HasProp("ddlOnSuccessAction")
        throw Error("Build should create a success branch action editor")
    if !editor.HasProp("ddlOnSuccessTarget")
        throw Error("Build should create a success branch target editor")
    if !editor.HasProp("ddlOnFailureAction")
        throw Error("Build should create a failure branch action editor")
    if !editor.HasProp("ddlOnFailureTarget")
        throw Error("Build should create a failure branch target editor")

    editor.edtStepName.Value := "点击 Boss"
    editor.chkStepEnabled.Value := 0
    editor.propInputs["x"].Value := "321"
    editor.propInputs["y"].Value := "654"
    editor.propInputs["button"].Value := "R"
    editor.propInputs["delay"].Value := "800"
    editor.ddlOnSuccessAction.Text := "jump"
    editor.ddlOnSuccessTarget.Text := "step_2"
    editor.ddlOnFailureAction.Text := "stop"
    editor.ddlOnFailureTarget.Text := ""

    if !editor.ApplyStepEdits()
        throw Error("ApplyStepEdits should update the selected step from the edit form")
    if (editor.currentScript.steps[1].name != "点击 Boss")
        throw Error("ApplyStepEdits should update the step name")
    if editor.currentScript.steps[1].enabled
        throw Error("ApplyStepEdits should update the enabled flag")
    if (editor.currentScript.steps[1].params.x != 321 || editor.currentScript.steps[1].params.y != 654)
        throw Error("ApplyStepEdits should update numeric click coordinates")
    if (editor.currentScript.steps[1].params.button != "R")
        throw Error("ApplyStepEdits should update string params")
    if (editor.currentScript.steps[1].onSuccess.action != "jump")
        throw Error("ApplyStepEdits should save the success branch action")
    if (editor.currentScript.steps[1].onSuccess.targetStepId != "step_2")
        throw Error("ApplyStepEdits should save the success branch target")
    if (editor.currentScript.steps[1].onFailure.action != "stop")
        throw Error("ApplyStepEdits should save the failure branch action")
    if !InStr(editor.pnlProps.Text, "点击 Boss")
        throw Error("ApplyStepEdits should refresh the properties summary")
    if !InStr(editor.pnlProps.Text, "x: 321")
        throw Error("ApplyStepEdits should show updated params in the summary")
    if !InStr(editor.pnlProps.Text, "成功: jump -> step_2")
        throw Error("ApplyStepEdits should show the updated success branch")

    moveStep := StepSchema.CreateStep("move_to_coord")
    moveStep.id := "step_3"
    moveStep.name := "跑图"
    moveStep.params.coordRegion := {x1: 11, y1: 22, x2: 33, y2: 44}
    moveStep.params.targetX := 100
    moveStep.params.targetY := 200
    moveStep.params.playerCenterX := 300
    moveStep.params.playerCenterY := 400
    moveStep.params.clickOffsetPx := 200
    moveStep.params.ocrEveryClicks := 7
    moveStep.params.ocrRetryCount := 2
    moveStep.params.ocrRetryIntervalMs := 150
    moveStep.params.stuckRounds := 3
    editor.currentScript.steps.Push(moveStep)
    editor.RefreshSteps()
    editor.SelectStep(3)

    if !editor.propInputs.Has("coordRegion")
        throw Error("RefreshProps should create an editable field for move_to_coord region params")
    if !editor.propInputs.Has("targetX")
        throw Error("RefreshProps should create an editable field for move_to_coord targetX")
    if (editor.StepSummary(editor.currentScript.steps[3]) != "导航 100,200")
        throw Error("StepSummary should summarize move_to_coord target coordinates")
    if !InStr(editor.pnlProps.Text, "坐标识别框: { x1: 11, y1: 22, x2: 33, y2: 44 }")
        throw Error("RefreshProps should summarize move_to_coord OCR region with a business-friendly label")
    if !InStr(editor.pnlProps.Text, "目标坐标: 100,200")
        throw Error("RefreshProps should summarize targetX and targetY as a combined target coordinate")
    if !InStr(editor.pnlProps.Text, "玩家中心点: 300,400")
        throw Error("RefreshProps should summarize playerCenterX and playerCenterY as a combined player center point")
    if !InStr(editor.pnlProps.Text, "点击偏移: 200")
        throw Error("RefreshProps should summarize clickOffsetPx with a business-friendly label")
    if !InStr(editor.pnlProps.Text, "校验频率: 7")
        throw Error("RefreshProps should summarize ocrEveryClicks with a business-friendly label")
    if InStr(editor.pnlProps.Text, "OCR重试")
        throw Error("RefreshProps should keep advanced OCR retry params out of the main move_to_coord summary")
    if InStr(editor.pnlProps.Text, "卡住轮次")
        throw Error("RefreshProps should keep advanced stuck params out of the main move_to_coord summary")
    if !InStr(editor.pnlProps.Text, "提示: 每次右键按 2 格预测移动")
        throw Error("RefreshProps should append the click-navigation usage hint for move_to_coord steps")
    if !HasVisiblePropLabel(editor, "坐标识别区域")
        throw Error("RebuildParamEditors should display a Chinese label for coordRegion")
    if !HasVisiblePropLabel(editor, "目标X")
        throw Error("RebuildParamEditors should display a Chinese label for targetX")
    if !HasVisiblePropLabel(editor, "中心X")
        throw Error("RebuildParamEditors should display a player center label for playerCenterX")
    if !HasVisiblePropLabel(editor, "中心Y")
        throw Error("RebuildParamEditors should display a player center label for playerCenterY")
    if !HasVisiblePropLabel(editor, "点击偏移")
        throw Error("RebuildParamEditors should display a click offset label for clickOffsetPx")
    if !HasVisiblePropLabel(editor, "校验点击数")
        throw Error("RebuildParamEditors should display an OCR frequency label for ocrEveryClicks")
    if editor.propInputs.Has("ocrRetryCount")
        throw Error("RebuildParamEditors should hide advanced OCR retry count from the main move_to_coord form")
    if editor.propInputs.Has("ocrRetryIntervalMs")
        throw Error("RebuildParamEditors should hide advanced OCR retry interval from the main move_to_coord form")
    if editor.propInputs.Has("stuckRounds")
        throw Error("RebuildParamEditors should hide advanced stuck detection params from the main move_to_coord form")
    if !editor.HasProp("txtStepHint")
        throw Error("Build should create a step hint text control")
    if !editor.txtStepHint.Visible
        throw Error("FillStepEditor should show the usage hint area for move_to_coord steps")
    if !InStr(editor.txtStepHint.Text, "玩家中心点要尽量落在角色站位附近")
        throw Error("FillStepEditor should explain what the player center point means for move_to_coord steps")
    if !InStr(editor.txtStepHint.Text, "当 X 和 Y 都未到位时，优先走对角")
        throw Error("FillStepEditor should explain the diagonal-first click-navigation rule for move_to_coord steps")
    if !InStr(editor.txtStepHint.Text, "每次点击默认按 2 格预测移动")
        throw Error("FillStepEditor should explain the per-click movement rule for move_to_coord steps")
    if !InStr(editor.txtStepHint.Text, "一般不用手动调整 OCR 重试和卡住判定")
        throw Error("FillStepEditor should explain that advanced stability params usually do not need manual tuning")
    if HasAnyVisiblePropHint(editor)
        throw Error("RebuildParamEditors should move long move_to_coord help text into the dedicated hint panel instead of showing field-level hints")
    targetXRect := GetControlRect(editor.propInputs["targetX"])
    targetYRect := GetControlRect(editor.propInputs["targetY"])
    centerXRect := GetControlRect(editor.propInputs["playerCenterX"])
    centerYRect := GetControlRect(editor.propInputs["playerCenterY"])
    clickOffsetRect := GetControlRect(editor.propInputs["clickOffsetPx"])
    ocrEveryClicksRect := GetControlRect(editor.propInputs["ocrEveryClicks"])
    if (targetYRect.y <= targetXRect.y)
        throw Error("RebuildParamEditors should place targetY on its own row below targetX in single-column mode")
    if (centerXRect.y <= targetYRect.y)
        throw Error("RebuildParamEditors should place playerCenterX below the target coordinate rows")
    if (centerYRect.y <= centerXRect.y)
        throw Error("RebuildParamEditors should place playerCenterY on its own row below playerCenterX")
    if (clickOffsetRect.y <= centerYRect.y)
        throw Error("RebuildParamEditors should place clickOffsetPx below the player center rows")
    if (ocrEveryClicksRect.y <= clickOffsetRect.y)
        throw Error("RebuildParamEditors should place ocrEveryClicks below clickOffsetPx")
    stepHintRect := GetControlRect(editor.txtStepHint)
    timeoutRect := GetControlRect(editor.propInputs["timeoutMs"])
    toleranceRect := GetControlRect(editor.propInputs["tolerance"])
    if (stepHintRect.y <= timeoutRect.y + timeoutRect.h)
        throw Error("FillStepEditor should place the dedicated navigation hint panel below the last param row")
    if (stepHintRect.h < 56)
        throw Error("FillStepEditor should give the dedicated navigation hint panel enough height for multi-line guidance")
    if (toleranceRect.y <= ocrEveryClicksRect.y)
        throw Error("RebuildParamEditors should place tolerance below the click-navigation batch params without overlap")
    pageBottom := editor.shellMetrics.pageY + editor.shellMetrics.pageH
    if (stepHintRect.y + stepHintRect.h > pageBottom - 4)
        throw Error("FillStepEditor should keep the dedicated navigation hint panel inside the visible page area so its scrollbar can be used")

    editor.edtStepName.Value := "跑到补给点"
    editor.propInputs["coordRegion"].Value := "{ x1: 21, y1: 31, x2: 41, y2: 51 }"
    editor.propInputs["targetX"].Value := "123"
    editor.propInputs["targetY"].Value := "456"
    editor.propInputs["playerCenterX"].Value := "654"
    editor.propInputs["playerCenterY"].Value := "321"
    editor.propInputs["clickOffsetPx"].Value := "240"
    editor.propInputs["ocrEveryClicks"].Value := "8"
    editor.propInputs["tolerance"].Value := "1"
    editor.propInputs["timeoutMs"].Value := "9000"

    if !editor.ApplyStepEdits()
        throw Error("ApplyStepEdits should update move_to_coord params from the edit form")
    if (editor.currentScript.steps[3].name != "跑到补给点")
        throw Error("ApplyStepEdits should update the move_to_coord step name")
    if (editor.currentScript.steps[3].params.targetX != 123 || editor.currentScript.steps[3].params.targetY != 456)
        throw Error("ApplyStepEdits should update move_to_coord target coordinates")
    if (editor.currentScript.steps[3].params.playerCenterX != 654 || editor.currentScript.steps[3].params.playerCenterY != 321)
        throw Error("ApplyStepEdits should update move_to_coord player center coordinates")
    if (editor.currentScript.steps[3].params.clickOffsetPx != 240)
        throw Error("ApplyStepEdits should update move_to_coord clickOffsetPx")
    if (editor.currentScript.steps[3].params.ocrEveryClicks != 8)
        throw Error("ApplyStepEdits should update move_to_coord ocrEveryClicks")
    if (editor.currentScript.steps[3].params.tolerance != 1)
        throw Error("ApplyStepEdits should update move_to_coord tolerance")
    if (editor.currentScript.steps[3].params.timeoutMs != 9000)
        throw Error("ApplyStepEdits should update move_to_coord timeoutMs")
    if (editor.currentScript.steps[3].params.ocrRetryCount != 2 || editor.currentScript.steps[3].params.ocrRetryIntervalMs != 150 || editor.currentScript.steps[3].params.stuckRounds != 3)
        throw Error("ApplyStepEdits should preserve hidden advanced stability params when they are not shown in the main form")
    if (editor.currentScript.steps[3].params.coordRegion.x1 != 21 || editor.currentScript.steps[3].params.coordRegion.y2 != 51)
        throw Error("ApplyStepEdits should parse move_to_coord region text back into an object")
    if !InStr(editor.pnlProps.Text, "目标坐标: 123,456")
        throw Error("ApplyStepEdits should refresh move_to_coord params with the combined target coordinate summary")

    guiObj.Destroy()
    FileAppend("PASS", statusPath, "UTF-8")
    ExitApp(0)
} catch as err {
    try guiObj.Destroy()
    FileAppend("FAIL: " . err.Message . " | what=" . err.What . " | file=" . err.File . " | line=" . err.Line, statusPath, "UTF-8")
    ExitApp(1)
}
