#Requires AutoHotkey v2.0

class StepRunner {
    __New(player, ocr, logger, customExecutor := "", navigator := "") {
        this.player := player
        this.ocr := ocr
        this.log := logger
        this.customExecutor := customExecutor
        this.navigator := navigator
    }

    RunSingleStep(step, hwnd) {
        ok := this.ExecuteStep(step, hwnd)
        if IsObject(this.log)
            this.log.Info("步骤 " step.id " [" step.type "] " (ok ? "成功" : "失败"))
        return {
            ok: ok,
            stepId: step.id,
            nextAction: ok ? step.onSuccess : step.onFailure
        }
    }

    CalibrateMoveToCoordStep(step, hwnd) {
        return {ok: false, reason: "UNSUPPORTED_IN_CLICK_MODE"}
    }

    DiagnoseMoveToCoordDirection(step, hwnd) {
        return {ok: false, reason: "UNSUPPORTED_IN_CLICK_MODE"}
    }

    RunScript(script, hwnd, startIndex := 1) {
        index := startIndex
        lastStepId := ""
        while (index <= script.steps.Length) {
            step := script.steps[index]
            if (step.HasProp("enabled") && !step.enabled) {
                index += 1
                continue
            }

            result := this.RunSingleStep(step, hwnd)
            lastStepId := step.id
            if !result.ok {
                if (result.nextAction.action = "stop") {
                    if IsObject(this.log)
                        this.log.Warn("脚本在步骤 " step.id " [" step.type "] 失败后停止")
                    return {ok: false, failedStepId: step.id, lastStepId: lastStepId}
                }
                index := this.ResolveNextIndex(script.steps, index, result.nextAction)
                continue
            }

            index := this.ResolveNextIndex(script.steps, index, result.nextAction)
        }
        return {ok: true, lastStepId: lastStepId}
    }

    ExecuteStep(step, hwnd) {
        if this.customExecutor
            return this.customExecutor(step, hwnd)
        params := step.HasProp("params") ? step.params : {}
        switch step.type {
            case "wait":
                Sleep(params.HasProp("ms") ? params.ms : 0)
                return true
            case "click":
                ; 游戏忽略后台左键消息，使用物理点击（激活窗口+真实鼠标）
                ; 顺序：移动鼠标到坐标 -> 延迟 delay（录制时与上一步的间隔）-> 点击 repeat 次
                return this.player.DoPhysicalClientClick(hwnd
                    , params.HasProp("x") ? params.x : 0
                    , params.HasProp("y") ? params.y : 0
                    , params.HasProp("button") ? params.button : "L"
                    , params.HasProp("repeat") ? params.repeat : 1
                    , params.HasProp("intervalMs") ? params.intervalMs : 0
                    , params.HasProp("delay") ? params.delay : 0)
            case "mouse_action":
                ; 顺序：移动鼠标到坐标 -> 延迟 delay -> 执行按住动作
                return this.player.DoClientMouseAction(hwnd
                    , params.HasProp("x") ? params.x : 0
                    , params.HasProp("y") ? params.y : 0
                    , params.HasProp("button") ? params.button : "R"
                    , params.HasProp("action") ? params.action : "hold"
                    , params.HasProp("holdMs") ? params.holdMs : 0
                    , params.HasProp("delay") ? params.delay : 0)
            case "find_image":
                return this.player.FindPic(
                    params.HasProp("image") ? params.image : "",
                    hwnd,
                    &outX,
                    &outY,
                    params.HasProp("region") ? params.region : "",
                    "",
                    params.HasProp("sim") ? params.sim : ""
                )
            case "click_image":
                return this.player.ClickPic(
                    params.HasProp("image") ? params.image : "",
                    hwnd,
                    params.HasProp("region") ? params.region : "",
                    ""
                )
            case "ocr_match":
                result := this.ocr.Recognize(
                    hwnd,
                    params.HasProp("region") ? params.region : "",
                    params.HasProp("targetText") ? params.targetText : "",
                    ""
                )
                return result.ok && result.matched
            case "move_to_coord":
                if !this.navigator
                    return false
                result := this.navigator.MoveTo(
                    hwnd,
                    params.HasProp("coordRegion") ? params.coordRegion : "",
                    params.HasProp("targetX") ? params.targetX : 0,
                    params.HasProp("targetY") ? params.targetY : 0,
                    params.HasProp("playerCenterX") ? params.playerCenterX : 0,
                    params.HasProp("playerCenterY") ? params.playerCenterY : 0,
                    params.HasProp("clickOffsetPx") ? params.clickOffsetPx : 200,
                    params.HasProp("ocrEveryClicks") ? params.ocrEveryClicks : 6,
                    params.HasProp("tolerance") ? params.tolerance : 1,
                    params.HasProp("timeoutMs") ? params.timeoutMs : 15000,
                    params.HasProp("ocrRetryCount") ? params.ocrRetryCount : 2,
                    params.HasProp("ocrRetryIntervalMs") ? params.ocrRetryIntervalMs : 150,
                    params.HasProp("stuckRounds") ? params.stuckRounds : 3
                )
                return IsObject(result) && result.ok
            case "branch":
                return this.ExecuteBranchStep(params, hwnd)
            default:
                return false
        }
    }

    ExecuteBranchStep(params, hwnd) {
        conditionType := params.HasProp("conditionType") ? params.conditionType : "ocr_match"
        switch conditionType {
            case "find_image":
                return this.player.FindPic(
                    params.HasProp("image") ? params.image : "",
                    hwnd,
                    &outX,
                    &outY,
                    params.HasProp("region") ? params.region : "",
                    "",
                    params.HasProp("sim") ? params.sim : ""
                )
            case "ocr_match":
                result := this.ocr.Recognize(
                    hwnd,
                    params.HasProp("region") ? params.region : "",
                    params.HasProp("targetText") ? params.targetText : "",
                    ""
                )
                return result.ok && result.matched
            default:
                return false
        }
    }

    ResolveNextIndex(steps, currentIndex, action) {
        if !IsObject(action)
            return currentIndex + 1
        switch action.action {
            case "next":
                return currentIndex + 1
            case "jump":
                targetIndex := this.FindStepIndexById(steps, action.targetStepId)
                return targetIndex = 0 ? steps.Length + 1 : targetIndex
            case "stop":
                return steps.Length + 1
            default:
                return currentIndex + 1
        }
    }

    FindStepIndexById(steps, targetStepId) {
        for index, step in steps {
            if (step.id = targetStepId)
                return index
        }
        return 0
    }
}
