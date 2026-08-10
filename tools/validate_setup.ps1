$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$rootDir = Split-Path -Parent $PSScriptRoot
$configPath = Join-Path $rootDir "config\config.ini"
$assetsDir = Join-Path $rootDir "assets"
$rapidSetupScript = Join-Path $rootDir "tools\setup_rapidocr_runtime.ps1"
$rapidSmokeTest = Join-Path $rootDir "tests\rapidocr_runtime_smoke.py"
$runnerRegression = Join-Path $rootDir "tests\rapidocr_runner_regression.py"

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

function Get-MissingConfiguredAssets([string]$IniPath, [string]$AssetsRoot) {
    if (!(Test-Path $IniPath)) {
        return @("config\config.ini")
    }

    $missing = New-Object System.Collections.Generic.List[string]
    $currentSection = ""

    foreach ($line in Get-Content $IniPath) {
        $trimmed = $line.Trim()
        if ($trimmed -eq "" -or $trimmed.StartsWith(";")) {
            continue
        }

        if ($trimmed -match '^\[(.+)\]$') {
            $currentSection = $Matches[1]
            continue
        }

        if ($currentSection -ne "Images") {
            continue
        }

        $pair = $trimmed -split "=", 2
        if ($pair.Count -ne 2) {
            continue
        }

        $value = $pair[1].Trim()
        if ($value -eq "") {
            continue
        }

        $assetPath = Join-Path $AssetsRoot $value
        if (!(Test-Path $assetPath)) {
            $missing.Add($value)
        }
    }

    return $missing
}

function Invoke-Step([string]$Label, [scriptblock]$Action) {
    Write-Host "[STEP] $Label"
    & $Action
    Write-Host "[OK]   $Label"
}

$ahkExe = Resolve-AutoHotkey
$pythonExe = Join-Path $rootDir "tools\rapidocr\python\python.exe"

Invoke-Step "Prepare bundled RapidOCR runtime" {
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $rapidSetupScript
}

if (!(Test-Path $pythonExe)) {
    throw "Bundled Python not found after OCR runtime setup: $pythonExe"
}

Invoke-Step "Run RapidOCR runtime smoke test" {
    & $pythonExe $rapidSmokeTest
}

Invoke-Step "Run RapidOCR runner regression" {
    & $pythonExe $runnerRegression
}

Invoke-Step "Run all AutoHotkey regressions" {
    $failed = @()
    foreach ($file in Get-ChildItem (Join-Path $rootDir "tests") -Filter "*regression*.ahk" | Sort-Object Name) {
        & $ahkExe /ErrorStdOut $file.FullName
        if (!$?) {
            $failed += $file.Name
        }
    }

    if ($failed.Count -gt 0) {
        throw ("AHK regressions failed: " + ($failed -join ", "))
    }
}

$missingAssets = Get-MissingConfiguredAssets -IniPath $configPath -AssetsRoot $assetsDir
if ($missingAssets.Count -gt 0) {
    Write-Warning ("Configured assets are missing: " + ($missingAssets -join ", "))
    Write-Warning "On a new machine, re-capture these images in assets\ or update config\config.ini."
} else {
    Write-Host "[OK]   Configured asset files exist"
}

Write-Host ""
Write-Host "Environment validation completed."
Write-Host "AutoHotkey: $ahkExe"
Write-Host "Bundled Python: $pythonExe"
