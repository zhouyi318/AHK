#Requires AutoHotkey v2.0

#Include ..\lib\Recorder.ahk

statusPath := A_ScriptDir "\tmp_recorder_result.txt"
if FileExist(statusPath)
    FileDelete(statusPath)

class RecorderSink {
    __New() {
        this.rawSteps := []
        this.completedSteps := []
    }

    OnRawStep(step) {
        this.rawSteps.Push(step)
    }

    OnCompleted(steps) {
        this.completedSteps := steps
    }
}

class TestRecorder extends Recorder {
    __New() {
        super.__New()
        this.fakeTick := 0
        this.mouseEvents := []
        this.registerCount := 0
        this.unregisterCount := 0
    }

    QueueMouseEvent(hwnd, clientX, clientY, isInside := true) {
        this.mouseEvents.Push({
            hwnd: hwnd,
            clientX: clientX,
            clientY: clientY,
            isInside: isInside
        })
    }

    SetTick(tickCount) {
        this.fakeTick := tickCount
    }

    Now() {
        return this.fakeTick
    }

    RegisterHooks() {
        this.registerCount += 1
    }

    UnregisterHooks() {
        this.unregisterCount += 1
    }

    ReadMouseContext(&hoveredHwnd, &clientX, &clientY) {
        if (this.mouseEvents.Length = 0)
            return false
        event := this.mouseEvents.RemoveAt(1)
        hoveredHwnd := event.hwnd
        clientX := event.clientX
        clientY := event.clientY
        return event.isInside
    }
}

try {
    sink := RecorderSink()
    recorder := TestRecorder()

    recorder.SetTick(1000)
    recorder.Start(123, ObjBindMethod(sink, "OnRawStep"), ObjBindMethod(sink, "OnCompleted"))
    if !recorder.recording
        throw Error("Start should enter recording mode")
    if (recorder.registerCount != 1)
        throw Error("Start should register hooks once")

    recorder.SetTick(1100)
    recorder.QueueMouseEvent(999, 10, 20)
    recorder.HandleLeftButtonDown()
    if (recorder.steps.Length != 0)
        throw Error("Recorder should ignore clicks outside the bound window")

    recorder.SetTick(1120)
    recorder.QueueMouseEvent(123, 50, 60)
    recorder.HandleLeftButtonDown()
    if (recorder.steps.Length != 1)
        throw Error("Left button down should append a raw click event")
    if (recorder.steps[1].delay != 120)
        throw Error("Left button delay should be measured from Start")

    recorder.SetTick(1200)
    recorder.QueueMouseEvent(123, 50, 60)
    recorder.HandleLeftButtonDown()
    if !recorder.recording
        throw Error("Recorder should keep running after multiple left clicks")
    if (recorder.steps.Length != 2)
        throw Error("Recorder should keep collecting raw left-click events")
    if (recorder.steps[2].delay != 80)
        throw Error("Recorder should preserve the delay between rapid left clicks")

    recorder.SetTick(1500)
    recorder.QueueMouseEvent(123, 80, 90)
    recorder.HandleRightButtonDown()

    recorder.SetTick(1900)
    recorder.HandleRightButtonUp()
    if (recorder.steps.Length != 3)
        throw Error("Right button up should emit one raw mouse_action event")
    if (recorder.steps[3].type != "mouse_action")
        throw Error("Right button hold should be recorded as a raw mouse_action event")
    if (recorder.steps[3].holdMs != 400)
        throw Error("Right button hold should preserve hold duration")
    if (recorder.steps[3].delay != 300)
        throw Error("Right button hold delay should be measured from button-down time")

    recorder.SetTick(2200)
    recorder.HandleEscape()
    if recorder.recording
        throw Error("ESC should stop the recorder")
    if (recorder.unregisterCount != 1)
        throw Error("Stopping should unregister hooks once")
    if (sink.completedSteps.Length != 3)
        throw Error("Stopping should flush the full recorded step sequence")
    if (sink.rawSteps.Length != 3)
        throw Error("Recorder should still stream each raw event while recording")

    FileAppend("PASS", statusPath, "UTF-8")
    ExitApp(0)
} catch as err {
    FileAppend("FAIL: " err.Message, statusPath, "UTF-8")
    ExitApp(1)
}
