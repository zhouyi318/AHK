# Move To Coord Click Navigation Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 把 `move_to_coord` 从轴映射长按导航重构为八方向点击导航，并同步精简参数与编辑器 UI。

**Architecture:** 导航内核改为“预测坐标驱动的八方向离散右键点击 + 每批点击后 OCR 校正”。步骤参数改成最小集合，编辑器只保留取点、取框、试跑三个工具入口，移除轴映射、跑速标定和方向诊断相关能力。

**Tech Stack:** AutoHotkey v2、现有 `ScriptEditor` / `StepRunner` / `CoordinateNavigator` 回归测试

---

### Task 1: 点击式导航回归

**Files:**
- Modify: `d:\code\AHK\tests\coordinate_navigator_regression.ahk`
- Modify: `d:\code\AHK\tests\step_runner_builtin_regression.ahk`

**Step 1: Write the failing test**
- 改成验证 `MoveTo()` 使用右键点击而不是物理长按。
- 增加“对角优先”“每批点击后 OCR 校正”“±1 容差到点”的断言。

**Step 2: Run test to verify it fails**
- 运行导航回归，预期因旧实现仍为长按/轴映射而失败。

**Step 3: Write minimal implementation**
- 在 `CoordinateNavigator.ahk` / `StepRunner.ahk` 中改成点击式参数签名与执行流。

**Step 4: Run test to verify it passes**
- 重新运行导航相关回归，确认通过。

### Task 2: move_to_coord 参数精简

**Files:**
- Modify: `d:\code\AHK\lib\StepSchema.ahk`
- Modify: `d:\code\AHK\tests\step_schema_regression.ahk`

**Step 1: Write the failing test**
- 把 `move_to_coord` 默认参数断言改为新集合：
  `coordRegion`、`targetX`、`targetY`、`playerCenterX`、`playerCenterY`、`clickOffsetPx`、`ocrEveryClicks`、`tolerance`、`timeoutMs`。

**Step 2: Run test to verify it fails**
- 运行 schema 回归，预期因旧参数仍存在而失败。

**Step 3: Write minimal implementation**
- 更新 `StepSchema.DefaultParams("move_to_coord")`。

**Step 4: Run test to verify it passes**
- 重新运行 schema 回归。

### Task 3: 编辑器极简导航 UI

**Files:**
- Modify: `d:\code\AHK\lib\ScriptEditor.ahk`
- Modify: `d:\code\AHK\tests\script_editor_actions_regression.ahk`
- Modify: `d:\code\AHK\tests\script_editor_step_edit_regression.ahk`
- Modify: `d:\code\AHK\tests\script_editor_layout_regression.ahk`

**Step 1: Write the failing test**
- 断言只保留 `取中心`、`取坐标框`、`试跑` 三个导航工具按钮。
- 断言旧按钮不再存在。
- 断言参数编辑和摘要文案改为点击式字段。

**Step 2: Run test to verify it fails**
- 运行脚本编辑器相关回归。

**Step 3: Write minimal implementation**
- 移除旧按钮与旧按钮逻辑。
- 新增 `取坐标框` 按钮及事件绑定。
- 更新参数标签、摘要和提示文案。

**Step 4: Run test to verify it passes**
- 重新运行脚本编辑器相关回归。

### Task 4: 清理旧导航辅助回归

**Files:**
- Modify: `d:\code\AHK\tests\script_editor_move_preset_regression.ahk`
- Modify: `d:\code\AHK\tests\script_editor_move_speed_calibration_regression.ahk`
- Modify: `d:\code\AHK\tests\script_editor_move_quick_adjust_regression.ahk`
- Modify: `d:\code\AHK\tests\script_editor_move_direction_diagnosis_regression.ahk`

**Step 1: Write the failing test**
- 把旧能力回归替换为新导航工具存在性/禁用性断言，或删除无价值断言。

**Step 2: Run test to verify it fails**
- 运行这些测试，确认旧预期不再成立。

**Step 3: Write minimal implementation**
- 同步代码或测试，确保只覆盖新模型。

**Step 4: Run test to verify it passes**
- 运行相关旧回归替代项。

### Task 5: 全量验证

**Files:**
- Verify: `d:\code\AHK\lib\CoordinateNavigator.ahk`
- Verify: `d:\code\AHK\lib\StepRunner.ahk`
- Verify: `d:\code\AHK\lib\StepSchema.ahk`
- Verify: `d:\code\AHK\lib\ScriptEditor.ahk`

**Step 1: Run focused regressions**
- 导航、schema、编辑器相关回归。

**Step 2: Check diagnostics**
- 检查最近修改文件无新诊断。

**Step 3: Commit**
- 由用户决定是否提交。
