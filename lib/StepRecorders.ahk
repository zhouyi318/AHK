#Requires AutoHotkey v2.0

class StepRecorders {
    __New(mouseRecorder := "") {
        this.mouseRecorder := mouseRecorder
        this.pendingRecordedStepCallback := ""
        this.pendingRecordedStepsCallback := ""
        this.rapidClickThresholdMs := 250
    }

    BuildBaseStep(type, name, params) {
        return {
            id: "step_" A_TickCount,
            type: type,
            name: name,
            enabled: true,
            params: params,
            onSuccess: {action: "next"},
            onFailure: {action: "stop"}
        }
    }

    BuildClickStep(x, y, button := "L", delay := 0, repeat := 1, intervalMs := 0) {
        return this.BuildBaseStep("click", "点击", {
            x: x,
            y: y,
            button: button,
            delay: delay,
            repeat: repeat,
            intervalMs: intervalMs
        })
    }

    BuildRepeatClickStep(x, y, button := "L", delay := 0, repeat := 2, intervalMs := 0) {
        return this.BuildClickStep(x, y, button, delay, repeat, intervalMs)
    }

    BuildMouseActionStep(x, y, button := "R", action := "hold", holdMs := 0, delay := 0) {
        return this.BuildBaseStep("mouse_action", "按住", {
            x: x,
            y: y,
            button: button,
            action: action,
            holdMs: holdMs,
            delay: delay
        })
    }

    BuildKeypressStep(keyName, repeat := 1) {
        return this.BuildBaseStep("keypress", "按键", {
            keyName: keyName,
            repeat: repeat
        })
    }

    RecordNextClick(hwnd, onRecorded) {
        if !this.mouseRecorder
            return false
        this.pendingRecordedStepCallback := onRecorded
        this.mouseRecorder.Start(hwnd, ObjBindMethod(this, "OnRawRecordedStep"))
        return true
    }

    RecordMouseSequence(hwnd, onCompleted) {
        if !this.mouseRecorder
            return false
        this.pendingRecordedStepsCallback := onCompleted
        this.mouseRecorder.Start(hwnd, "", ObjBindMethod(this, "OnRawRecordingStopped"))
        return true
    }

    StopMouseSequence() {
        if !this.mouseRecorder
            return false
        if !this.mouseRecorder.recording
            return false
        this.mouseRecorder.Stop()
        return true
    }

    OnRawRecordedStep(rawStep) {
        step := this.NormalizeRecordedStep(rawStep)
        if !step
            return
        this.mouseRecorder.Stop()
        callback := this.pendingRecordedStepCallback
        this.pendingRecordedStepCallback := ""
        if callback
            callback.Call(step)
    }

    NormalizeRecordedStep(rawStep) {
        if !IsObject(rawStep)
            return ""
        if (rawStep.type = "click") {
            repeat := rawStep.HasProp("repeat") ? rawStep.repeat : 1
            intervalMs := rawStep.HasProp("intervalMs") ? rawStep.intervalMs : 0
            return this.BuildClickStep(rawStep.x, rawStep.y, rawStep.button, rawStep.delay, repeat, intervalMs)
        }
        if (rawStep.type = "mouse_action")
            return this.BuildMouseActionStep(rawStep.x, rawStep.y, rawStep.button, rawStep.action, rawStep.holdMs, rawStep.delay)
        return ""
    }

    NormalizeRecordedSteps(rawSteps) {
        normalizedSteps := []
        if !IsObject(rawSteps)
            return normalizedSteps
        for _, rawStep in rawSteps {
            step := this.NormalizeRecordedStep(rawStep)
            if !step
                continue
            if this.TryAggregateRapidClick(normalizedSteps, step)
                continue
            normalizedSteps.Push(step)
        }
        return normalizedSteps
    }

    TryAggregateRapidClick(normalizedSteps, step) {
        if (normalizedSteps.Length = 0)
            return false
        if (step.type != "click")
            return false
        if !step.params.HasProp("button") || (step.params.button != "L")
            return false
        if !step.params.HasProp("delay") || (step.params.delay > this.rapidClickThresholdMs)
            return false

        previous := normalizedSteps[normalizedSteps.Length]
        if (previous.type != "click")
            return false
        if !previous.params.HasProp("button") || (previous.params.button != "L")
            return false
        if (previous.params.x != step.params.x || previous.params.y != step.params.y)
            return false

        previous.params.repeat := previous.params.HasProp("repeat") ? previous.params.repeat + 1 : 2
        previous.params.intervalMs := step.params.delay
        return true
    }

    OnRawRecordingStopped(rawSteps) {
        steps := this.NormalizeRecordedSteps(rawSteps)
        callback := this.pendingRecordedStepsCallback
        this.pendingRecordedStepsCallback := ""
        if callback
            callback.Call(steps)
    }

    PromptKeypressStep() {
        keyInput := InputBox("请输入要录制的按键名称，例如 F8、Space、Enter：", "录制按键")
        if (keyInput.Result = "Cancel")
            return ""
        keyName := Trim(keyInput.Value)
        if (keyName = "")
            return ""

        repeatInput := InputBox("请输入发送次数：", "录制按键", , "1")
        if (repeatInput.Result = "Cancel")
            return ""
        repeatText := Trim(repeatInput.Value)
        repeat := 1
        if (repeatText != "") {
            try repeat := Integer(repeatText)
            catch
                repeat := 1
        }
        if (repeat < 1)
            repeat := 1
        return this.BuildKeypressStep(keyName, repeat)
    }
}
