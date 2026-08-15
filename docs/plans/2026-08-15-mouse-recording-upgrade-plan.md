# Mouse Recording Upgrade Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** 为 AHK 脚本编辑器增加连续鼠标录制能力，支持 `ESC` 停止录制、左键连续点击合并、右键按住时长记录与回放。

**Architecture:** 保留现有“绑定窗口客户区坐标”体系，在 `Recorder` 中把原始鼠标事件升级为一段连续录制流，再由 `StepRecorders` 归一化为脚本步骤。左键连续点击在同一区域短时间内合并为单个 `click` 步骤，右键按住使用单个“鼠标动作”步骤保存按住时长，`StepRunner` 与 `Player` 增加对应回放能力。

**Tech Stack:** AutoHotkey v2, 现有 `ScriptEditor` GUI, `Recorder`/`StepRecorders`/`StepRunner`/`Player` 流程, AHK 回归测试脚本。

---

### Task 1: 扩展步骤模型

**Files:**
- Modify: `d:\code\AHK\lib\StepSchema.ahk`
- Modify: `d:\code\AHK\lib\StepRecorders.ahk`
- Test: `d:\code\AHK\tests\step_recorders_regression.ahk`

**Step 1: 写失败用例**

- 为左键连续点击增加归一化预期：
  - 同坐标、短间隔的多次左键点击应合并成单个 `click` 步骤。
  - `params` 至少包含 `x`、`y`、`button`、`delay`、`repeat`、`intervalMs`。
- 为右键按住增加归一化预期：
  - 应生成单个新步骤类型，例如 `mouse_action`。
  - `params` 至少包含 `x`、`y`、`button`、`action`、`holdMs`、`delay`。

**Step 2: 运行测试确认失败**

- 运行相关 AHK 回归脚本。
- 预期：现有实现不认识 `repeat` / `holdMs` / `mouse_action`，测试失败。

**Step 3: 最小实现**

- 在 `StepSchema.DefaultName()` 与 `DefaultParams()` 中加入新步骤类型。
- 在 `StepRecorders` 中加入：
  - 构建“可重复点击”步骤的方法。
  - 构建“按住动作”步骤的方法。
  - 归一化原始录制事件的方法。

**Step 4: 运行测试确认通过**

- 确认新的步骤结构可以被创建且字段完整。

**Step 5: 提交**

- 提交步骤模型变更与对应测试。

### Task 2: 升级连续录制器

**Files:**
- Modify: `d:\code\AHK\lib\Recorder.ahk`
- Test: `d:\code\AHK\tests\recorder_regression.ahk` 或新增 `d:\code\AHK\tests\mouse_recording_regression.ahk`

**Step 1: 写失败用例**

- 用测试子类或可注入时钟/坐标方法验证：
  - 开始录制后，按 `ESC` 可停止录制。
  - 左键多次点击被收集为连续流，而不是首个点击后立即结束。
  - 右键按下与抬起能计算出按住时长。
  - 鼠标事件只在绑定窗口内记录。

**Step 2: 运行测试确认失败**

- 预期：当前 `Recorder` 只有 `~*LButton` / `~*RButton` 单点记录，没有 `ESC` 停止，也没有 down/up 区分。

**Step 3: 最小实现**

- 为 `Recorder` 增加：
  - `escFn`、`rbUpFn`、必要时 `lbUpFn`。
  - 连续录制状态，不在录到一步后自动结束。
  - `ESC` 停止录制并触发结束回调。
  - 右键 down/up 的时间戳记录，生成带 `holdMs` 的原始事件。
  - 左键点击流缓存，为后续合并提供事件粒度。
- 保持现有“基于绑定窗口客户区坐标”逻辑不变。

**Step 4: 运行测试确认通过**

- 验证连续录制的开始、停止、事件采集、按住时长都正确。

**Step 5: 提交**

- 提交录制器升级与测试。

### Task 3: 连接脚本编辑器录制入口

**Files:**
- Modify: `d:\code\AHK\lib\ScriptEditor.ahk`
- Modify: `d:\code\AHK\lib\StepRecorders.ahk`
- Test: `d:\code\AHK\tests\script_editor_recording_regression.ahk`

**Step 1: 写失败用例**

- 验证点击“录制点击”后：
  - 不再只录一次，而是进入连续录制状态。
  - `ESC` 停止后一次性把录到的鼠标动作追加到当前脚本。
  - 若未绑定窗口，仍提示用户先绑定窗口。

**Step 2: 运行测试确认失败**

- 预期：当前 `RecordNextClickStep()` 在首个动作录到后就停止。

**Step 3: 最小实现**

- 将现有“录一个 click step”入口改为“开始连续鼠标录制”。
- 在 `StepRecorders` 中新增批量回调，例如：
  - 开始录制。
  - 结束后返回一组标准化步骤。
- 在 `ScriptEditor` 中把这组步骤批量追加到当前脚本，并刷新步骤列表。
- 录制期间给出明确提示：`ESC` 停止录制鼠标事件。

**Step 4: 运行测试确认通过**

- 验证 GUI 入口行为与脚本追加行为正确。

**Step 5: 提交**

- 提交 GUI 录制入口变更与测试。

### Task 4: 增强回放执行器

**Files:**
- Modify: `d:\code\AHK\lib\Player.ahk`
- Modify: `d:\code\AHK\lib\StepRunner.ahk`
- Test: `d:\code\AHK\tests\step_runner_regression.ahk`
- Test: `d:\code\AHK\tests\window_handle_click_regression.ahk`

**Step 1: 写失败用例**

- 为左键连点增加回放预期：
  - `repeat > 1` 时，应按指定次数和间隔执行。
- 为右键按住增加回放预期：
  - 执行按下、等待 `holdMs`、抬起。

**Step 2: 运行测试确认失败**

- 预期：当前 `Player.DoClientClick()` 只支持单击。

**Step 3: 最小实现**

- 在 `Player` 中增加更通用的鼠标执行能力，例如：
  - `DoClientClick(hwnd, x, y, button, repeat := 1, intervalMs := 0)`
  - `DoClientMouseAction(hwnd, x, y, button, action, holdMs := 0)`
- 在 `StepRunner.ExecuteStep()` 中识别新的参数和步骤类型。
- 保持旧脚本兼容：历史 `click` 步骤默认仍按单击执行。

**Step 4: 运行测试确认通过**

- 验证老脚本不回归，新录制步骤可正确回放。

**Step 5: 提交**

- 提交执行器增强与测试。

### Task 5: 收尾与回归

**Files:**
- Test: `d:\code\AHK\tests\window_picker_enter_confirm_regression.ahk`
- Test: `d:\code\AHK\tests\window_picker_polling_confirm_regression.ahk`
- Test: `d:\code\AHK\tests\script_editor_actions_regression.ahk`
- Test: `d:\code\AHK\tests\script_editor_recording_regression.ahk`

**Step 1: 跑目标回归**

- 录制相关回归。
- 执行器相关回归。
- 选窗相关回归，确保没有误伤窗口绑定逻辑。

**Step 2: 手动冒烟**

- 绑定一个普通窗口。
- 进入脚本编辑页。
- 点击“录制点击”开始连续录制。
- 连续左键点击几次。
- 执行一次右键按住。
- 按 `ESC` 停止。
- 检查步骤列表是否正确生成。

**Step 3: 清理与提交**

- 清理临时测试文件。
- 提交最终实现。
