# AHKV2 挂机脚本

一个基于 **AutoHotkey v2** 的传奇私服挂机脚本项目，带可视化 GUI、录制回放、窗口绑定、OCR 识别和回归测试。

项目当前采用“**脚本 + 自带 OCR 运行时**”的方式运行：
- 主程序入口是 `Main.ahk`
- OCR 依赖已随仓库提供在 `tools/rapidocr/`
- 新电脑仍需安装 **AutoHotkey v2**

仓库根目录已附带安装包：
- `AutoHotkey_2.0.26_setup.exe`

## 功能概览

- GUI 界面管理挂机流程
- 绑定目标窗口并基于客户区坐标执行操作
- 支持脚本录制与回放
- 优先使用 **RapidOCR** 做文字识别，失败时可回退到 WinRT OCR
- 提供自动化回归测试和环境校验脚本

## 目录结构

```text
Main.ahk                    主程序入口
config/config.ini           主配置文件
assets/                     模板图资源
lib/                        AHK 模块与 OCR 辅助脚本
scripts/                    录制得到的步骤脚本
tests/                      回归测试
tools/setup_rapidocr_runtime.ps1
                            初始化/修复 OCR 运行时
tools/validate_setup.ps1    新机器环境校验
tools/rapidocr/             自带 Python、模型与 OCR 依赖
```

## 运行要求

1. Windows
2. AutoHotkey v2
3. 首次准备 OCR 运行时时建议联网

## 首次使用

1. 安装 AutoHotkey v2  
   可直接运行仓库里的 `AutoHotkey_2.0.26_setup.exe`

2. 初始化 OCR 运行时

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\setup_rapidocr_runtime.ps1
```

3. 启动主程序

```powershell
& "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe" .\Main.ahk
```

4. 在 GUI 中完成这些设置
- 绑定目标窗口
- 检查或调整 `config\config.ini`
- 准备 `assets\` 中需要的模板图
- 录制或选择挂机脚本

## 新电脑部署

推荐在新机器上按这个顺序操作：

1. 克隆或拷贝整个仓库
2. 安装 AutoHotkey v2
3. 运行 OCR 初始化脚本
4. 运行环境校验脚本
5. 检查配置和素材图是否齐全
6. 启动 `Main.ahk`

环境校验命令：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\validate_setup.ps1
```

这个脚本会检查：
- AutoHotkey v2 是否存在
- bundled Python 与 RapidOCR 是否可用
- OCR smoke test 和 runner regression
- 全部 AHK 回归测试
- `config\config.ini` 中引用的素材图是否存在

## 配置说明

主配置文件：`config/config.ini`

重点配置项：
- `[Window]` 绑定窗口信息
- `[Images]` 模板图文件名
- `[ImageRegions]` 找图区域
- `[Hotkey]` 热键，默认：
  - `F8` 启动/暂停
  - `F12` 急停
- `[Paths]` 资源、日志、脚本目录

## OCR 说明

项目默认优先使用 `tools/rapidocr/` 下的自带 OCR 运行时：
- 自带 Python
- `rapidocr-onnxruntime`
- OCR 模型

如果 OCR 运行时缺失或不可用，会尝试回退到 WinRT OCR。

当前实现已处理这些问题：
- OCR 调用时隐藏控制台窗口，不再弹出一闪而过的 `cmd`
- 从库路径自动解析项目根目录，避免在 `tests/` 下运行时找错路径

## 测试

运行 OCR smoke test：

```powershell
.\tools\rapidocr\python\python.exe .\tests\rapidocr_runtime_smoke.py
```

运行 OCR runner regression：

```powershell
.\tools\rapidocr\python\python.exe .\tests\rapidocr_runner_regression.py
```

批量运行 AHK 回归：

```powershell
$ahk = "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe"
Get-ChildItem .\tests\*regression*.ahk | Sort-Object Name | ForEach-Object { & $ahk /ErrorStdOut $_.FullName }
```

## 已知注意事项

- 当前仓库已经包含 OCR 运行时，因此体积较大
- `config\config.ini` 里引用的部分模板图，可能需要你在新机器上重新截取或改配置
- OCR 对纯文字识别优于找图，文字类目标优先走 OCR

## 常见问题

### 1. 新电脑能不能直接运行？

当前还不能做到“完全免安装”，因为 `Main.ahk` 仍需要 AutoHotkey v2 解释器。  
不过 OCR 相关依赖已经随仓库提供，不需要另装 Python。

### 2. 运行时提示找不到 AutoHotkey

先确认 AutoHotkey v2 已安装，或安装路径是否为：

```text
C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe
```

### 3. OCR 不工作怎么办？

依次执行：

```powershell
powershell -ExecutionPolicy Bypass -File .\tools\setup_rapidocr_runtime.ps1
powershell -ExecutionPolicy Bypass -File .\tools\validate_setup.ps1
```

### 4. 日志在哪里看？

默认在 `logs/` 目录。

## 后续建议

- 补充更完整的 `assets/` 示例资源
- 增加一键启动脚本
- 进一步改造成“免安装运行”版本，例如附带本地 AHK 可执行文件或直接编译为 EXE
