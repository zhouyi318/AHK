# Script Workflow Upgrade Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 升级统一脚本编辑器，补齐图片/OCR步骤新增入口、条件分支编辑，以及多个脚本的流程调度与循环执行。

**Architecture:** 保留现有 `script.steps` 作为单脚本步骤层，扩展 `StepSchema / ScriptEditor / StepRunner` 让识别步骤和分支跳转可编辑、可执行。在其上新增独立的流程仓储与调度执行器，用 `flow.json` 保存脚本节点关系，运行时由 `FlowRunner` 驱动多个脚本串联、循环和失败回退。

**Tech Stack:** AutoHotkey v2、现有 GUI 控件、JSON 文件持久化、RapidOCR/WinRT OCR、现有回归测试脚本。

---

### Task 1: 扩展步骤模型与编辑器新增入口

**Files:**
- Modify: `lib\StepSchema.ahk`
- Modify: `lib\ScriptEditor.ahk`
- Test: `tests\step_schema_regression.ahk`
- Test: `tests\script_editor_actions_regression.ahk`

**Step 1: 写失败测试，要求编辑器暴露图片/OCR/分支新增入口**

```ahk
if !editor.HasProp("btnAddFindImage")
    throw Error("Build should expose a button for adding find_image steps")
if !editor.HasProp("btnAddClickImage")
    throw Error("Build should expose a button for adding click_image steps")
if !editor.HasProp("btnAddOcrMatch")
    throw Error("Build should expose a button for adding ocr_match steps")
if !editor.HasProp("btnAddBranch")
    throw Error("Build should expose a button for adding branch steps")
```

**Step 2: 运行测试确认失败**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\script_editor_actions_regression.ahk"
```

Expected: FAIL，提示编辑器缺少新增步骤入口。

**Step 3: 写最小实现**

```ahk
this.btnAddFindImage := guiObj.Add("Button", "xm y+10 w100 h28", "+ 找图")
this.btnAddClickImage := guiObj.Add("Button", "x+8 yp w100 h28", "+ 图点")
this.btnAddOcrMatch := guiObj.Add("Button", "x+8 yp w100 h28", "+ OCR")
this.btnAddBranch := guiObj.Add("Button", "x+8 yp w100 h28", "+ 分支")
```

**Step 4: 跑测试确认通过**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\script_editor_actions_regression.ahk"
```

Expected: PASS。

**Step 5: 提交**

```bash
git add lib/StepSchema.ahk lib/ScriptEditor.ahk tests/script_editor_actions_regression.ahk
git commit -m "feat: add workflow step creation actions"
```

### Task 2: 扩展步骤属性编辑与分支流转

**Files:**
- Modify: `lib\ScriptEditor.ahk`
- Modify: `lib\StepRunner.ahk`
- Test: `tests\script_editor_step_edit_regression.ahk`
- Test: `tests\step_runner_builtin_regression.ahk`

**Step 1: 写失败测试，要求编辑器能编辑 onSuccess/onFailure 跳转**

```ahk
editor.ddlOnSuccessAction.Text := "jump"
editor.ddlOnSuccessTarget.Text := "step_2"
editor.ddlOnFailureAction.Text := "stop"
if !editor.ApplyStepEdits()
    throw Error("ApplyStepEdits should persist branch settings")
if (editor.currentScript.steps[1].onSuccess.action != "jump")
    throw Error("ApplyStepEdits should save success branch action")
```

**Step 2: 运行测试确认失败**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\script_editor_step_edit_regression.ahk"
```

Expected: FAIL，提示编辑器没有分支编辑控件或未保存分支配置。

**Step 3: 写最小实现**

```ahk
step.onSuccess := this.ReadBranchConfig(this.ddlOnSuccessAction, this.ddlOnSuccessTarget)
step.onFailure := this.ReadBranchConfig(this.ddlOnFailureAction, this.ddlOnFailureTarget)
```

**Step 4: 跑测试确认通过**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\script_editor_step_edit_regression.ahk"
AutoHotkey64.exe "f:\code\AHKV2\tests\step_runner_builtin_regression.ahk"
```

Expected: PASS，分支步骤和识别步骤都能继续执行。

**Step 5: 提交**

```bash
git add lib/ScriptEditor.ahk lib/StepRunner.ahk tests/script_editor_step_edit_regression.ahk tests/step_runner_builtin_regression.ahk
git commit -m "feat: add branch editing for workflow steps"
```

### Task 3: 新增流程仓储与调度执行器

**Files:**
- Create: `lib\FlowRepository.ahk`
- Create: `lib\FlowRunner.ahk`
- Test: `tests\flow_repository_regression.ahk`
- Test: `tests\flow_runner_regression.ahk`

**Step 1: 写失败测试，要求流程仓储能保存入口节点和节点跳转**

```ahk
repo := FlowRepository(A_ScriptDir "\tmp_flows")
flow := repo.CreateFlow("主循环")
flow.entryNodeId := "node_1"
flow.nodes.Push({id: "node_1", name: "补给", scriptName: "补给脚本", onSuccess: {action: "next", targetNodeId: "node_2"}, onFailure: {action: "repeat"}})
repo.SaveFlow(flow)
loaded := repo.LoadFlow("主循环")
if (loaded.entryNodeId != "node_1")
    throw Error("LoadFlow should preserve entry node id")
```

**Step 2: 运行测试确认失败**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\flow_repository_regression.ahk"
```

Expected: FAIL，提示 `FlowRepository` 未定义。

**Step 3: 写最小实现**

```ahk
class FlowRepository extends ScriptStore {
    CreateFlow(name) {
        return {id: "flow_" name, name: name, entryNodeId: "", nodes: []}
    }
}
```

**Step 4: 跑测试确认通过**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\flow_repository_regression.ahk"
AutoHotkey64.exe "f:\code\AHKV2\tests\flow_runner_regression.ahk"
```

Expected: PASS，流程可按成功/失败分支循环节点。

**Step 5: 提交**

```bash
git add lib/FlowRepository.ahk lib/FlowRunner.ahk tests/flow_repository_regression.ahk tests/flow_runner_regression.ahk
git commit -m "feat: add script flow orchestration"
```

### Task 4: 在编辑器中接入流程页签

**Files:**
- Modify: `lib\ScriptEditor.ahk`
- Test: `tests\script_editor_flow_regression.ahk`

**Step 1: 写失败测试，要求编辑器能切换到流程页并新增流程节点**

```ahk
if !editor.HasProp("lvFlowNodes")
    throw Error("Build should expose a flow node list")
editor.NewFlow("主循环")
editor.AddFlowNode("进入地图")
if (editor.currentFlow.nodes.Length != 1)
    throw Error("AddFlowNode should append flow nodes")
```

**Step 2: 运行测试确认失败**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\script_editor_flow_regression.ahk"
```

Expected: FAIL，提示编辑器没有流程视图。

**Step 3: 写最小实现**

```ahk
this.tabs := guiObj.Add("Tab3", "xm y+14 w930 h520", ["步骤编辑", "流程调度"])
this.lvFlowNodes := guiObj.Add("ListView", "xm y+40 w700 h320", ["节点", "脚本", "成功后", "失败后"])
```

**Step 4: 跑测试确认通过**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\script_editor_flow_regression.ahk"
```

Expected: PASS。

**Step 5: 提交**

```bash
git add lib/ScriptEditor.ahk tests/script_editor_flow_regression.ahk
git commit -m "feat: add flow scheduler workspace"
```

### Task 5: 接入主界面与流程运行按钮

**Files:**
- Modify: `Main.ahk`
- Modify: `lib\Bot.ahk`
- Test: `tests\main_editor_mode_regression.ahk`
- Test: `tests\script_editor_execution_regression.ahk`

**Step 1: 写失败测试，要求主界面初始化流程依赖并暴露运行流程入口**

```ahk
if !editor.HasProp("btnRunFlow")
    throw Error("Build should expose a run flow button")
```

**Step 2: 运行测试确认失败**

Run:

```powershell
AutoHotkey64.exe "f:\code\AHKV2\tests\script_editor_execution_regression.ahk"
```

Expected: FAIL，提示没有运行流程入口。

**Step 3: 写最小实现**

```ahk
global flowRepo := FlowRepository(A_ScriptDir "\flows")
global flowRunner := FlowRunner(stepRunnerService, store, appLogger)
```

**Step 4: 跑核心回归确认通过**

Run:

```powershell
powershell -ExecutionPolicy Bypass -File "f:\code\AHKV2\tools\run_all_tests.ps1"
```

Expected: 核心非交互回归 PASS。

**Step 5: 提交**

```bash
git add Main.ahk lib/Bot.ahk lib/ScriptEditor.ahk lib/FlowRepository.ahk lib/FlowRunner.ahk tests docs/plans/2026-08-14-script-workflow-upgrade-implementation-plan.md
git commit -m "feat: add workflow editor and flow runner"
```
