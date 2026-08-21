#Requires AutoHotkey v2.0

#Include ..\lib\StepRunner.ahk

WriteStatus(exitCode) {
    if (A_Args.Length < 1)
        return
    statusPath := A_Args[1]
    try {
        if FileExist(statusPath)
            FileDelete(statusPath)
    }
    FileAppend("EXIT=" exitCode, statusPath, "UTF-8")
}

class FakeExecutor {
    __New() {
        this.calls := []
    }

    Call(step, hwnd) {
        this.calls.Push(step.id)
        return step.params.ok
    }
}

InvokeFakeExecutor(executor, owner, step, hwnd) {
    return executor.Call(step, hwnd)
}

try {
    executor := FakeExecutor()
    runner := StepRunner("", "", "", InvokeFakeExecutor.Bind(executor))

    script := {
        steps: [
            {id: "step_1", type: "wait", name: "第一步", enabled: true, params: {ok: true}, onSuccess: {action: "next"}, onFailure: {action: "stop"}},
            {id: "step_2", type: "wait", name: "第二步", enabled: true, params: {ok: false}, onSuccess: {action: "next"}, onFailure: {action: "jump", targetStepId: "step_3"}},
            {id: "step_3", type: "wait", name: "第三步", enabled: true, params: {ok: true}, onSuccess: {action: "next"}, onFailure: {action: "stop"}}
        ]
    }

    result := runner.RunScript(script, 123)
    if !result.ok
        throw Error("RunScript should follow failure jump and still succeed")
    if (result.lastStepId != "step_3")
        throw Error("RunScript should finish on the jumped target step")
    if (executor.calls.Length != 3)
        throw Error("RunScript should execute all reachable steps in order")

    stopScript := {
        steps: [
            {id: "step_a", type: "wait", name: "A", enabled: true, params: {ok: false}, onSuccess: {action: "next"}, onFailure: {action: "stop"}}
        ]
    }
    stopResult := runner.RunScript(stopScript, 123)
    if stopResult.ok
        throw Error("RunScript should stop with failure when onFailure is stop")
    if (stopResult.failedStepId != "step_a")
        throw Error("RunScript should report the failed step id")

    singleResult := runner.RunSingleStep(script.steps[2], 123)
    if singleResult.ok
        throw Error("RunSingleStep should surface executor failure for the current step")
    if (singleResult.stepId != "step_2")
        throw Error("RunSingleStep should report the current step id")
    if (singleResult.nextAction.action != "jump")
        throw Error("RunSingleStep should return the selected branch")

    WriteStatus(0)
    ExitApp(0)
} catch {
    WriteStatus(1)
    ExitApp(1)
}
