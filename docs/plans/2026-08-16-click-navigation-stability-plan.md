# Click Navigation Stability Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 提升点击式 `move_to_coord` 在 OCR 波动和实跑偏差下的稳定性，减少误停、过冲和 OCR 瞬时失败导致的中断。

**Architecture:** 保持现有“八方向点击 + 批次 OCR 校正”主模型不变，只增强容错层。导航器新增 OCR 重试、批次后进度评估和更稳的卡住判定；不重新引入轴映射、长按、跑速标定等复杂模型。

**Tech Stack:** AutoHotkey v2、`CoordinateNavigator`、`StepRunner`、现有 AHK 回归测试

---

### Task 1: OCR 容错回归

**Files:**
- Modify: `d:\code\AHK\tests\coordinate_navigator_regression.ahk`

**Step 1: Write the failing test**
- 增加“首轮 OCR 失败后短暂重试可恢复”的用例。
- 增加“连续 OCR 失败达到阈值后返回 OCR_FAILED”的用例。

**Step 2: Run test to verify it fails**
- 运行 `coordinate_navigator_regression.ahk`
- 预期：旧实现会直接失败，不会重试。

**Step 3: Write minimal implementation**
- 在 `CoordinateNavigator.ahk` 中封装带重试的坐标读取。

**Step 4: Run test to verify it passes**
- 重新运行 `coordinate_navigator_regression.ahk`

### Task 2: 批次后进度评估

**Files:**
- Modify: `d:\code\AHK\tests\coordinate_navigator_regression.ahk`
- Modify: `d:\code\AHK\lib\CoordinateNavigator.ahk`

**Step 1: Write the failing test**
- 增加“批次 OCR 回来后若离目标更近则继续，不按预测误判卡住”的用例。
- 增加“批次 OCR 完全无进展时，累计数次后判定 STUCK”的用例。

**Step 2: Run test to verify it fails**
- 运行导航回归，预期因旧实现 stuck 判定过于粗糙而失败。

**Step 3: Write minimal implementation**
- 把 stuck 计数从“相同坐标次数”升级为“连续无进展 OCR 轮次”。
- 以到目标的切比雪夫距离评估是否有前进。

**Step 4: Run test to verify it passes**
- 重新运行导航回归。

### Task 3: 参数最小增强

**Files:**
- Modify: `d:\code\AHK\lib\StepSchema.ahk`
- Modify: `d:\code\AHK\lib\StepRunner.ahk`
- Modify: `d:\code\AHK\tests\step_schema_regression.ahk`
- Modify: `d:\code\AHK\tests\step_runner_builtin_regression.ahk`

**Step 1: Write the failing test**
- 增加最小稳定性参数断言：
  - `ocrRetryCount`
  - `ocrRetryIntervalMs`
  - `stuckRounds`

**Step 2: Run test to verify it fails**
- 运行 schema / runner 回归。

**Step 3: Write minimal implementation**
- 在 schema 中补默认值。
- 在 runner 中透传给 navigator。

**Step 4: Run test to verify it passes**
- 重新运行 schema / runner 回归。

### Task 4: 重点回归验证

**Files:**
- Verify: `d:\code\AHK\lib\CoordinateNavigator.ahk`
- Verify: `d:\code\AHK\lib\StepSchema.ahk`
- Verify: `d:\code\AHK\lib\StepRunner.ahk`

**Step 1: Run focused regressions**
- `coordinate_navigator_regression.ahk`
- `step_runner_builtin_regression.ahk`
- `step_schema_regression.ahk`

**Step 2: Check diagnostics**
- 确认最近修改文件无新增诊断。

**Step 3: Commit**
- 由用户决定是否提交。
