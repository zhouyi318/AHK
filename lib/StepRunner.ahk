#Requires AutoHotkey v2.0

class StepRunner {
    __New(player, ocr, logger, customExecutor := "") {
        this.player := player
        this.ocr := ocr
        this.log := logger
        this.customExecutor := customExecutor
    }

    RunSingleStep(step, hwnd) {
        ok := this.ExecuteStep(step, hwnd)
        return {
            ok: ok,
            stepId: step.id,
            nextAction: ok ? step.onSuccess : step.onFailure
        }
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
                if (result.nextAction.action = "stop")
                    return {ok: false, failedStepId: step.id, lastStepId: lastStepId}
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
                return this.player.DoClientClick(hwnd
                    , params.HasProp("x") ? params.x : 0
                    , params.HasProp("y") ? params.y : 0
                    , params.HasProp("button") ? params.button : "L"
                    , params.HasProp("repeat") ? params.repeat : 1
                    , params.HasProp("intervalMs") ? params.intervalMs : 0)
            case "mouse_action":
                return this.player.DoClientMouseAction(hwnd
                    , params.HasProp("x") ? params.x : 0
                    , params.HasProp("y") ? params.y : 0
                    , params.HasProp("button") ? params.button : "R"
                    , params.HasProp("action") ? params.action : "hold"
                    , params.HasProp("holdMs") ? params.holdMs : 0)
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
