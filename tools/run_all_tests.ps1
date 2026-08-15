$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$rootDir = Split-Path -Parent $PSScriptRoot
$testsDir = Join-Path $rootDir "tests"
$ahkRunnerScript = Join-Path $rootDir "tools\ahk_test_runner.ahk"
$directStatusTests = @(
    "step_runner_regression.ahk",
    "text_recognizer_regression.ahk",
    "window_bound_coordinate_regression.ahk",
    "window_handle_click_regression.ahk",
    "window_picker_enter_confirm_regression.ahk",
    "window_picker_polling_confirm_regression.ahk",
    "window_picker_restart_regression.ahk"
)
$pythonExe = Join-Path $rootDir "tools\rapidocr\python\python.exe"
$pythonTests = @(
    "rapidocr_runtime_smoke.py",
    "rapidocr_runner_regression.py"
)

function Resolve-AutoHotkey {
    $candidates = @(
        "C:\Program Files\AutoHotkey\v2\AutoHotkey64.exe",
        "C:\Program Files\AutoHotkey\v2\AutoHotkey.exe"
    )

    foreach ($candidate in $candidates) {
        if (Test-Path $candidate) {
            return $candidate
        }
    }

    $whereOutput = (& where.exe AutoHotkey64.exe AutoHotkey.exe 2>$null)
    if ($LASTEXITCODE -eq 0 -and $whereOutput) {
        return ($whereOutput | Select-Object -First 1)
    }

    throw "AutoHotkey v2 executable not found. Install AutoHotkey v2 first."
}

function Invoke-AhkRegressions([string]$AutoHotkeyExe, [string]$RunnerScript, [string]$Directory) {
    $failed = New-Object System.Collections.Generic.List[string]
    $files = Get-ChildItem $Directory -Filter "*regression*.ahk" | Sort-Object Name

    if ($files.Count -eq 0) {
        throw "No AHK regression tests were found in $Directory"
    }
    if (!(Test-Path $RunnerScript)) {
        throw "AHK regression wrapper not found: $RunnerScript"
    }

    foreach ($file in $files) {
        Write-Host "[AHK] $($file.Name)"
        if ($file.Name -in $directStatusTests) {
            $statusPath = Join-Path $env:TEMP ("ahk_test_status_" + [guid]::NewGuid().ToString("N") + ".txt")
            try {
                Start-Process -FilePath $AutoHotkeyExe `
                    -ArgumentList @('/ErrorStdOut', $RunnerScript, $file.FullName, $statusPath, '120000') `
                    -Wait `
                    -PassThru | Out-Null
                if (!(Test-Path $statusPath)) {
                    throw "AHK runner did not write a status file for $($file.Name)"
                }
                $status = (Get-Content -Raw $statusPath).Trim()
                if ($status -notmatch '^EXIT=(-?\d+)$') {
                    throw "AHK runner wrote an invalid status for $($file.Name): $status"
                }
                if ([int]$Matches[1] -ne 0) {
                    $failed.Add($file.Name)
                }
            } finally {
                Remove-Item $statusPath -ErrorAction SilentlyContinue
            }
            continue
        }

        $process = Start-Process -FilePath $AutoHotkeyExe `
            -ArgumentList @('/ErrorStdOut', $file.FullName) `
            -Wait `
            -PassThru
        if ($process.ExitCode -ne 0) {
            $failed.Add($file.Name)
        }
    }

    if ($failed.Count -gt 0) {
        throw ("AHK regressions failed: " + ($failed -join ", "))
    }
}

function Invoke-PythonRegressions([string]$PythonExe, [string]$Directory, [string[]]$Names) {
    if (!(Test-Path $PythonExe)) {
        throw "Bundled Python not found: $PythonExe"
    }

    foreach ($name in $Names) {
        $path = Join-Path $Directory $name
        if (!(Test-Path $path)) {
            throw "Python regression test not found: $path"
        }

        Write-Host "[PY ] $name"
        & $PythonExe $path
        if ($LASTEXITCODE -ne 0) {
            throw "Python regression failed: $name"
        }
    }
}

$ahkExe = Resolve-AutoHotkey

Write-Host "== Running AutoHotkey regressions =="
Invoke-AhkRegressions -AutoHotkeyExe $ahkExe -RunnerScript $ahkRunnerScript -Directory $testsDir

Write-Host ""
Write-Host "== Running Python OCR regressions =="
Invoke-PythonRegressions -PythonExe $pythonExe -Directory $testsDir -Names $pythonTests

Write-Host ""
Write-Host "All regression tests passed."
