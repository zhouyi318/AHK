# 统一脚本编辑器 Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 将现有按业务拆分的 GUI 重构为统一脚本编辑器，支持统一脚本模型、步骤编辑、简单判断、整段运行、从当前步骤运行和单步执行当前步骤，同时兼容旧脚本与现有存仓配置。

**Architecture:** 入口 `Main.ahk` 变薄，只做依赖初始化与主界面启动。新增 `ScriptRepository / StepSchema / StepRunner / StepRecorders / ScriptEditor` 五个模块，分别负责脚本存储、步骤模型、步骤执行、录制采集和 GUI 工作台；`Recorder / Player / TextRecognizer / Bot` 继续复用底层能力并逐步收口到新模块。

**Tech Stack:** AutoHotkey v2、现有 GUI 控件、JSON 文件持久化、RapidOCR/WinRT OCR、现有回归测试脚本。

---

### Task 1: 建立新脚本模型与兼容仓储

**Files:**
- Create: `lib\ScriptRepository.ahk`
- Modify: `lib\ScriptStore.ahk`
- Test: `tests\script_repository_regression.ahk`

**Step 1: 写兼容加载失败测试**

```ahk
#Requires AutoHotkey v2.0
#Include ..\lib\ScriptRepository.ahk

repo := ScriptRepository(A_ScriptDir "\tmp_scripts")
legacy := {name: "demo", targetMapImage: "map.bmp", steps: [{type: "wait", ms: 1000}]}
repo.SaveLegacyFixture("legacy_demo", legacy)

script := repo.LoadScript("legacy_demo")
if (script.type != "enter_map")
    throw Error("Legacy script should map to enter_map")
if (script.steps[1].onFailure.action != "stop")
    throw Error("Legacy steps should default to stop on failure")
ExitApp(0)
```

**Step 2: 运行测试确认失败**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\script_repository_regression.ahk"
```

Expected: FAIL，提示 `ScriptRepository` 未定义或旧脚本无法映射到新模型。

**Step 3: 写最小实现**

```ahk
class ScriptRepository extends ScriptStore {
    LoadScript(name) {
        raw := super.LoadScript(name)
        if !raw
            return ""
        return this.NormalizeScript(raw)
    }

    NormalizeScript(raw) {
        if raw.HasProp("type")
            return raw
        return {
            id: "script_" raw.name,
            name: raw.name,
            type: "enter_map",
            enabled: true,
            metadata: {
                targetMapImage: raw.HasProp("targetMapImage") ? raw.targetMapImage : "",
                targetMapRegion: raw.HasProp("targetMapRegion") ? raw.targetMapRegion : "",
                notes: ""
            },
            steps: this.NormalizeLegacySteps(raw.steps)
        }
    }
}
```

**Step 4: 跑测试确认通过**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\script_repository_regression.ahk"
```

Expected: PASS，无输出且退出码为 0。

**Step 5: 提交**

```bash
git add lib/ScriptRepository.ahk lib/ScriptStore.ahk tests/script_repository_regression.ahk
git commit -m "feat: add unified script repository"
```

### Task 2: 建立步骤类型定义与校验器

**Files:**
- Create: `lib\StepSchema.ahk`
- Test: `tests\step_schema_regression.ahk`

**Step 1: 写默认步骤和跳转校验失败测试**

```ahk
#Requires AutoHotkey v2.0
#Include ..\lib\StepSchema.ahk

step := StepSchema.CreateStep("ocr_match")
if (step.type != "ocr_match")
    throw Error("CreateStep should keep requested type")
if (step.onSuccess.action != "next")
    throw Error("CreateStep should default success to next")

invalid := {steps: [step]}
step.onFailure := {action: "jump", targetStepId: "missing"}
err := StepSchema.ValidateJumpTargets(invalid)
if (err = "")
    throw Error("ValidateJumpTargets should reject missing target step")
ExitApp(0)
```

**Step 2: 运行测试确认失败**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\step_schema_regression.ahk"
```

Expected: FAIL，提示 `StepSchema` 未定义或返回值不符合预期。

**Step 3: 写最小实现**

```ahk
class StepSchema {
    static CreateStep(type) {
        return {
            id: "step_" A_TickCount,
            type: type,
            name: this.DefaultName(type),
            enabled: true,
            params: this.DefaultParams(type),
            onSuccess: {action: "next"},
            onFailure: {action: "stop"}
        }
    }

    static ValidateJumpTargets(script) {
        ids := Map()
        for _, step in script.steps
            ids[step.id] := true
        for _, step in script.steps {
            for _, branch in [step.onSuccess, step.onFailure] {
                if (branch.action = "jump" && !ids.Has(branch.targetStepId))
                    return "Missing jump target: " branch.targetStepId
            }
        }
        return ""
    }
}
```

**Step 4: 跑测试确认通过**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\step_schema_regression.ahk"
```

Expected: PASS。

**Step 5: 提交**

```bash
git add lib/StepSchema.ahk tests/step_schema_regression.ahk
git commit -m "feat: add step schema definitions"
```

### Task 3: 建立统一执行器并覆盖单步执行

**Files:**
- Create: `lib\StepRunner.ahk`
- Modify: `lib\Player.ahk`
- Test: `tests\step_runner_regression.ahk`

**Step 1: 写顺序执行、失败停止、失败跳转、单步执行测试**

```ahk
#Requires AutoHotkey v2.0
#Include ..\lib\StepRunner.ahk

class FakeOps {
    __New() {
        this.calls := []
    }
    RunStep(step, hwnd) {
        this.calls.Push(step.id)
        return step.params.ok
    }
}

ops := FakeOps()
runner := StepRunner("", "", "", ops.RunStep.Bind(ops))
script := {
    steps: [
        {id: "s1", type: "wait", enabled: true, params: {ok: true}, onSuccess: {action: "next"}, onFailure: {action: "stop"}},
        {id: "s2", type: "wait", enabled: true, params: {ok: false}, onSuccess: {action: "next"}, onFailure: {action: "jump", targetStepId: "s3"}},
        {id: "s3", type: "wait", enabled: true, params: {ok: true}, onSuccess: {action: "next"}, onFailure: {action: "stop"}}
    ]
}

result := runner.RunScript(script, 0)
if !result.ok
    throw Error("RunScript should recover through jump branch")
if (ops.calls.Length != 3)
    throw Error("RunScript should visit s1, s2, s3")

single := runner.RunSingleStep(script.steps[2], 0)
if single.stepId != "s2"
    throw Error("RunSingleStep should report current step id")
ExitApp(0)
```

**Step 2: 运行测试确认失败**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\step_runner_regression.ahk"
```

Expected: FAIL，提示 `StepRunner` 未定义。

**Step 3: 写最小实现**

```ahk
class StepRunner {
    __New(player, ocr, logger, customExecutor := "") {
        this.player := player
        this.ocr := ocr
        this.log := logger
        this.customExecutor := customExecutor
    }

    RunSingleStep(step, hwnd) {
        ok := this.ExecuteStep(step, hwnd)
        return {ok: ok, stepId: step.id, nextAction: ok ? step.onSuccess : step.onFailure}
    }

    RunScript(script, hwnd, startIndex := 1) {
        index := startIndex
        while (index <= script.steps.Length) {
            step := script.steps[index]
            if !step.enabled {
                index += 1
                continue
            }
            result := this.RunSingleStep(step, hwnd)
            if (!result.ok && result.nextAction.action = "stop")
                return {ok: false, failedStepId: step.id}
            index := this.ResolveNextIndex(script.steps, index, result.nextAction)
        }
        return {ok: true}
    }
}
```

**Step 4: 跑测试确认通过**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\step_runner_regression.ahk"
```

Expected: PASS。

**Step 5: 提交**

```bash
git add lib/StepRunner.ahk lib/Player.ahk tests/step_runner_regression.ahk
git commit -m "feat: add unified step runner"
```

### Task 4: 提取录制入口并支持按键录制

**Files:**
- Create: `lib\StepRecorders.ahk`
- Modify: `lib\Recorder.ahk`
- Test: `tests\step_recorders_regression.ahk`

**Step 1: 写录制点击、录制按键转标准步骤的失败测试**

```ahk
#Requires AutoHotkey v2.0
#Include ..\lib\StepRecorders.ahk

mgr := StepRecorders()
click := mgr.BuildClickStep(100, 200, "L", 300)
if (click.type != "click")
    throw Error("BuildClickStep should create click step")

key := mgr.BuildKeypressStep("F8", 2)
if (key.params.keyName != "F8")
    throw Error("BuildKeypressStep should preserve key name")
ExitApp(0)
```

**Step 2: 运行测试确认失败**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\step_recorders_regression.ahk"
```

Expected: FAIL。

**Step 3: 写最小实现**

```ahk
class StepRecorders {
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
}
```

**Step 4: 跑测试确认通过**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\step_recorders_regression.ahk"
```

Expected: PASS。

**Step 5: 提交**

```bash
git add lib/StepRecorders.ahk lib/Recorder.ahk tests/step_recorders_regression.ahk
git commit -m "feat: add step recorder helpers"
```

### Task 5: 落统一脚本编辑器 GUI 骨架

**Files:**
- Create: `lib\ScriptEditor.ahk`
- Modify: `Main.ahk`
- Test: `tests\script_editor_smoke_regression.ahk`

**Step 1: 写 GUI 骨架烟雾测试**

```ahk
#Requires AutoHotkey v2.0
#Include ..\lib\ScriptEditor.ahk

editor := ScriptEditor({repo: "", runner: "", recorders: "", cfg: "", logger: ""})
guiObj := editor.Build()

if !guiObj
    throw Error("ScriptEditor should build a GUI instance")
if (editor.lvSteps = "")
    throw Error("ScriptEditor should expose steps list view")
if (editor.lstScripts = "")
    throw Error("ScriptEditor should expose script list")

guiObj.Destroy()
ExitApp(0)
```

**Step 2: 运行测试确认失败**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\script_editor_smoke_regression.ahk"
```

Expected: FAIL。

**Step 3: 写最小实现**

```ahk
class ScriptEditor {
    __New(deps) {
        this.deps := deps
    }

    Build() {
        guiObj := Gui(, "统一脚本编辑器")
        this.toolbar := guiObj.Add("Text", "xm ym w900", "脚本编辑器")
        this.lstScripts := guiObj.Add("ListBox", "xm y+10 w180 h360", [])
        this.lvSteps := guiObj.Add("ListView", "x+10 yp w360 h360", ["序号", "启用", "类型", "摘要"])
        this.pnlProps := guiObj.Add("Text", "x+10 yp w280 h360 Border", "步骤属性")
        return this.gui := guiObj
    }
}
```

**Step 4: 跑测试确认通过**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\script_editor_smoke_regression.ahk"
```

Expected: PASS。

**Step 5: 提交**

```bash
git add lib/ScriptEditor.ahk Main.ahk tests/script_editor_smoke_regression.ahk
git commit -m "feat: add script editor workbench shell"
```

### Task 6: 接通编辑器与仓储、步骤模型

**Files:**
- Modify: `lib\ScriptEditor.ahk`
- Modify: `lib\ScriptRepository.ahk`
- Modify: `lib\StepSchema.ahk`
- Test: `tests\script_editor_load_save_regression.ahk`

**Step 1: 写新建脚本、添加步骤、保存后重载测试**

```ahk
#Requires AutoHotkey v2.0
#Include ..\lib\ScriptEditor.ahk
#Include ..\lib\ScriptRepository.ahk
#Include ..\lib\StepSchema.ahk

repo := ScriptRepository(A_ScriptDir "\tmp_scripts")
editor := ScriptEditor({repo: repo, schema: StepSchema})
editor.NewScript("测试脚本", "enter_map")
editor.AddStep("wait")
editor.currentScript.steps[1].params.ms := 500
editor.SaveCurrentScript()

loaded := repo.LoadScript("测试脚本")
if (loaded.steps[1].params.ms != 500)
    throw Error("SaveCurrentScript should persist edited params")
ExitApp(0)
```

**Step 2: 运行测试确认失败**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\script_editor_load_save_regression.ahk"
```

Expected: FAIL。

**Step 3: 写最小实现**

```ahk
NewScript(name, type := "enter_map") {
    this.currentScript := this.deps.repo.CreateScript(name, type)
    this.RefreshScriptList()
    this.RefreshSteps()
}

AddStep(type) {
    step := this.deps.schema.CreateStep(type)
    this.currentScript.steps.Push(step)
    this.RefreshSteps()
}

SaveCurrentScript() {
    this.deps.repo.SaveScript(this.currentScript)
}
```

**Step 4: 跑测试确认通过**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\script_editor_load_save_regression.ahk"
```

Expected: PASS。

**Step 5: 提交**

```bash
git add lib/ScriptEditor.ahk lib/ScriptRepository.ahk lib/StepSchema.ahk tests/script_editor_load_save_regression.ahk
git commit -m "feat: connect editor to script repository"
```

### Task 7: 接入整段运行、从当前步骤运行和单步执行

**Files:**
- Modify: `lib\ScriptEditor.ahk`
- Modify: `lib\StepRunner.ahk`
- Test: `tests\script_editor_execution_regression.ahk`

**Step 1: 写运行入口测试**

```ahk
#Requires AutoHotkey v2.0
#Include ..\lib\ScriptEditor.ahk

class FakeRunner {
    __New() {
        this.calls := []
    }
    RunScript(script, hwnd, startIndex := 1) {
        this.calls.Push("run:" startIndex)
        return {ok: true}
    }
    RunSingleStep(step, hwnd) {
        this.calls.Push("single:" step.id)
        return {ok: true, stepId: step.id}
    }
}

runner := FakeRunner()
editor := ScriptEditor({runner: runner})
editor.currentScript := {steps: [{id: "s1"}, {id: "s2"}]}
editor.selectedStepIndex := 2

editor.RunCurrentScript()
editor.RunFromCurrentStep()
editor.RunCurrentStep()

if (runner.calls[1] != "run:1")
    throw Error("RunCurrentScript should start from first step")
if (runner.calls[2] != "run:2")
    throw Error("RunFromCurrentStep should start from selected step")
if (runner.calls[3] != "single:s2")
    throw Error("RunCurrentStep should execute selected step only")
ExitApp(0)
```

**Step 2: 运行测试确认失败**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\script_editor_execution_regression.ahk"
```

Expected: FAIL。

**Step 3: 写最小实现**

```ahk
RunCurrentScript() {
    return this.deps.runner.RunScript(this.currentScript, this.GetBoundHwnd(), 1)
}

RunFromCurrentStep() {
    return this.deps.runner.RunScript(this.currentScript, this.GetBoundHwnd(), this.selectedStepIndex)
}

RunCurrentStep() {
    step := this.currentScript.steps[this.selectedStepIndex]
    return this.deps.runner.RunSingleStep(step, this.GetBoundHwnd())
}
```

**Step 4: 跑测试确认通过**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\script_editor_execution_regression.ahk"
```

Expected: PASS。

**Step 5: 提交**

```bash
git add lib/ScriptEditor.ahk lib/StepRunner.ahk tests/script_editor_execution_regression.ahk
git commit -m "feat: add script execution controls"
```

### Task 8: 迁移 Bot 到统一脚本与存仓流程脚本

**Files:**
- Modify: `lib\Bot.ahk`
- Modify: `lib\Config.ahk`
- Modify: `lib\ScriptRepository.ahk`
- Test: `tests\bot_store_flow_regression.ahk`

**Step 1: 写存仓流程脚本优先执行测试**

```ahk
#Requires AutoHotkey v2.0
#Include ..\lib\Bot.ahk

class FakeStore {
    ListScriptsByType(type) {
        return (type = "enter_map") ? ["进图1"] : ["存仓1"]
    }
    LoadScript(name) {
        if (name = "存仓1")
            return {name: name, type: "store_flow", steps: [{id: "s1"}]}
        return {name: name, type: "enter_map", steps: [{id: "s1"}]}
    }
    LoadStoreConfig() {
        return {intervalMinutes: 60, itemNames: ["裁决"], flowScriptName: "存仓1"}
    }
}

class FakeRunner {
    __New() {
        this.calls := []
    }
    RunScript(script, hwnd, startIndex := 1) {
        this.calls.Push(script.type ":" script.name)
        return {ok: true}
    }
}

bot := Bot({Window: {Hwnd: 1}, Bot: {StoreIntervalMin: 60}}, "", FakeRunner(), FakeStore())
```

**Step 2: 运行测试确认失败**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\bot_store_flow_regression.ahk"
```

Expected: FAIL，当前 `Bot` 仍然只会执行老的 `player.Play` 和硬编码存仓逻辑。

**Step 3: 写最小实现**

```ahk
HandleRunEnterScript() {
    scripts := this.store.ListScriptsByType("enter_map")
    ; ...
    this.runner.RunScript(script, this.hwnd, 1)
}

HandleStoreItems() {
    storeCfg := this.store.LoadStoreConfig()
    if (storeCfg.HasProp("flowScriptName") && storeCfg.flowScriptName != "") {
        flow := this.store.LoadScript(storeCfg.flowScriptName)
        if flow
            this.runner.RunScript(flow, this.hwnd, 1)
    }
}
```

**Step 4: 跑测试确认通过**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\bot_store_flow_regression.ahk"
```

Expected: PASS。

**Step 5: 提交**

```bash
git add lib/Bot.ahk lib/Config.ahk lib/ScriptRepository.ahk tests/bot_store_flow_regression.ahk
git commit -m "feat: run store flow scripts through unified runner"
```

### Task 9: 清理入口并补最终回归

**Files:**
- Modify: `Main.ahk`
- Modify: `tests\gui_show_regression.ahk`
- Modify: `tests\script_store_save_regression.ahk`
- Modify: `tests\text_recognizer_regression.ahk`

**Step 1: 写最终启动回归检查**

```ahk
#Requires AutoHotkey v2.0
RunWait 'AutoHotkey64.exe "f:\code\AHKV2\Main.ahk"', , "Hide"
ExitApp(0)
```

**Step 2: 运行核心回归集**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\script_repository_regression.ahk"
AutoHotkey64.exe "f:\code\AHKV2\tests\step_schema_regression.ahk"
AutoHotkey64.exe "f:\code\AHKV2\tests\step_runner_regression.ahk"
AutoHotkey64.exe "f:\code\AHKV2\tests\step_recorders_regression.ahk"
AutoHotkey64.exe "f:\code\AHKV2\tests\script_editor_smoke_regression.ahk"
AutoHotkey64.exe "f:\code\AHKV2\tests\script_editor_load_save_regression.ahk"
AutoHotkey64.exe "f:\code\AHKV2\tests\script_editor_execution_regression.ahk"
AutoHotkey64.exe "f:\code\AHKV2\tests\bot_store_flow_regression.ahk"
AutoHotkey64.exe "f:\code\AHKV2\tests\text_recognizer_regression.ahk"
```

Expected: 全部 PASS。

**Step 3: 收口入口实现**

```ahk
#Include lib\ScriptRepository.ahk
#Include lib\StepSchema.ahk
#Include lib\StepRunner.ahk
#Include lib\StepRecorders.ahk
#Include lib\ScriptEditor.ahk

repo := ScriptRepository(A_ScriptDir "\" cfg.Paths.ScriptsDir)
runner := StepRunner(playback, ocrRecognizer, appLogger)
recorders := StepRecorders(rec, regionTool)
editor := ScriptEditor({cfg: cfg, logger: appLogger, repo: repo, runner: runner, schema: StepSchema, recorders: recorders})
g.gui := editor.Build()
```

**Step 4: 运行总回归确认通过**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\gui_show_regression.ahk"
AutoHotkey64.exe "f:\code\AHKV2\tests\text_recognizer_regression.ahk"
AutoHotkey64.exe "f:\code\AHKV2\tests\window_handle_click_regression.ahk"
```

Expected: PASS。

**Step 5: 提交**

```bash
git add Main.ahk lib tests docs/plans/2026-08-13-unified-script-editor-implementation-plan.md
git commit -m "feat: ship unified script editor"
```

## 执行提醒

- 开工前先创建独立 worktree，避免当前工作区被重构中间态污染。
- 严格按 TDD 执行，每个任务先写失败测试，再做最小实现。
- GUI 回归测试里，点击后至少保留 250ms 等待时间。
- OCR 坐标断言继续用动态映射函数生成，不要硬编码屏幕坐标。
- 第一版不要引入循环节点、可视化连线或多窗口并行，避免计划膨胀。
