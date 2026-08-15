#Requires AutoHotkey v2.0

class StepRecorders {
    __New(mouseRecorder := "") {
        this.mouseRecorder := mouseRecorder
        this.pendingRecordedStepCallback := ""
    }

    BuildClickStep(x, y, button := "L", delay := 0) {
        return {
            id: "step_" A_TickCount,
            type: "click",
            name: "点击",
            enabled: true,
            params: {x: x, y: y, button: button, delay: delay},
            onSuccess: {action: "next"},
            onFailure: {action: "stop"}
        }
    }

    BuildKeypressStep(keyName, repeat := 1) {
        return {
            id: "step_" A_TickCount,
            type: "keypress",
            name: "按键",
            enabled: true,
            params: {keyName: keyName, repeat: repeat},
            onSuccess: {action: "next"},
            onFailure: {action: "stop"}
        }
    }

    RecordNextClick(hwnd, onRecorded) {
        if !this.mouseRecorder
            return false
        this.pendingRecordedStepCallback := onRecorded
        this.mouseRecorder.Start(hwnd, ObjBindMethod(this, "OnRawRecordedStep"))
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
        if (rawStep.type = "click")
            return this.BuildClickStep(rawStep.x, rawStep.y, rawStep.button, rawStep.delay)
        return ""
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
