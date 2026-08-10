$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$rootDir = Split-Path -Parent $PSScriptRoot
$rapidDir = Join-Path $rootDir "tools\rapidocr"
$pythonDir = Join-Path $rapidDir "python"
$downloadsDir = Join-Path $rapidDir "downloads"
$modelsDir = Join-Path $rapidDir "models"
$pythonZip = Join-Path $downloadsDir "python-3.11.9-embed-amd64.zip"
$getPipPath = Join-Path $downloadsDir "get-pip.py"
$modelsZip = Join-Path $downloadsDir "required_for_whl_v1.1.0.zip"
$pythonExe = Join-Path $pythonDir "python.exe"
$onnxruntimeVersion = "1.19.2"

function Download-File([string]$Url, [string]$Destination) {
    & curl.exe -L --fail --retry 5 --retry-all-errors -C - --output $Destination $Url
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to download: $Url"
    }
}

New-Item -ItemType Directory -Path $downloadsDir -Force | Out-Null
New-Item -ItemType Directory -Path $modelsDir -Force | Out-Null

if (!(Test-Path $pythonExe)) {
    Download-File "https://www.python.org/ftp/python/3.11.9/python-3.11.9-embed-amd64.zip" $pythonZip
    if (Test-Path $pythonDir) {
        Remove-Item $pythonDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $pythonDir -Force | Out-Null
    Expand-Archive -Path $pythonZip -DestinationPath $pythonDir -Force

    $pthFile = Get-ChildItem $pythonDir -Filter "python*._pth" | Select-Object -First 1
    if ($null -ne $pthFile) {
        Remove-Item $pthFile.FullName -Force
    }
}

if (!(Test-Path (Join-Path $pythonDir "Scripts\pip.exe"))) {
    Download-File "https://bootstrap.pypa.io/get-pip.py" $getPipPath
    & $pythonExe $getPipPath
}

& $pythonExe -m pip install --upgrade pip
# onnxruntime 1.28 fails DLL initialization on this workstation; 1.19.2
# works with the bundled Python 3.11 runtime and numpy 2.x.
& $pythonExe -m pip install rapidocr-onnxruntime pillow numpy "onnxruntime==$onnxruntimeVersion"

$requiredDir = Join-Path $modelsDir "required_for_whl_v1.1.0"
if (!(Test-Path (Join-Path $requiredDir "config.yaml"))) {
    Download-File "https://github.com/RapidAI/RapidOCR/releases/download/v1.1.0/required_for_whl_v1.1.0.zip" $modelsZip
    if (Test-Path $requiredDir) {
        Remove-Item $requiredDir -Recurse -Force
    }
    Expand-Archive -Path $modelsZip -DestinationPath $modelsDir -Force
}

Write-Output "RapidOCR runtime is ready at $rapidDir"
