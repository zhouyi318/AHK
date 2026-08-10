param(
    [Parameter(Mandatory = $true)]
    [int]$X,

    [Parameter(Mandatory = $true)]
    [int]$Y,

    [Parameter(Mandatory = $true)]
    [int]$Width,

    [Parameter(Mandatory = $true)]
    [int]$Height,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$Languages = "zh-Hans-CN,en-US,zh-CN"
)

$ErrorActionPreference = "Stop"

function Await-WinRt($AsyncTask, [Type]$ResultType) {
    $awaiter = [WindowsRuntimeSystemExtensions].GetMember('GetAwaiter').
        Where({ $PSItem.GetParameters()[0].ParameterType.Name -eq 'IAsyncOperation`1' }, 'First')[0]
    $awaiter.MakeGenericMethod($ResultType).Invoke($null, @($AsyncTask)).GetResult()
}

function Write-Result([string]$Status, [string]$Text, [string]$ErrorText = "") {
    $lines = @("STATUS=$Status")
    if ($ErrorText) {
        $lines += "ERROR=$ErrorText"
    }
    $lines += "TEXT_BEGIN"
    if ($Text) {
        $lines += $Text -split "`r?`n"
    }
    $lines += "TEXT_END"
    $payload = ($lines -join [Environment]::NewLine)
    Set-Content -LiteralPath $OutputPath -Value $payload -Encoding UTF8
    Write-Output $payload
}

try {
    Add-Type -AssemblyName System.Runtime.WindowsRuntime
    Add-Type -AssemblyName System.Drawing

    [Windows.Storage.StorageFile, Windows.Storage, ContentType = WindowsRuntime] | Out-Null
    [Windows.Media.Ocr.OcrEngine, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null
    [Windows.Graphics.Imaging.BitmapDecoder, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null
    [Windows.Graphics.Imaging.SoftwareBitmap, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null
    [Windows.Globalization.Language, Windows.Foundation, ContentType = WindowsRuntime] | Out-Null

    if ($Width -le 0 -or $Height -le 0) {
        throw "Width/Height must be positive."
    }

    $tempImage = Join-Path ([System.IO.Path]::GetTempPath()) ("ahkv2_ocr_{0}.png" -f ([guid]::NewGuid()))
    try {
        $bitmap = New-Object System.Drawing.Bitmap($Width, $Height)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $graphics.CopyFromScreen($X, $Y, 0, 0, $bitmap.Size)
        $bitmap.Save($tempImage, [System.Drawing.Imaging.ImageFormat]::Png)
        $graphics.Dispose()
        $bitmap.Dispose()

        $languageTags = @()
        foreach ($tag in ($Languages -split ",")) {
            $trimmed = $tag.Trim()
            if ($trimmed) {
                $languageTags += $trimmed
            }
        }

        $engine = $null
        foreach ($languageTag in $languageTags) {
            try {
                $lang = [Windows.Globalization.Language]::new($languageTag)
                $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromLanguage($lang)
                if ($null -ne $engine) {
                    break
                }
            } catch {
            }
        }
        if ($null -eq $engine) {
            $engine = [Windows.Media.Ocr.OcrEngine]::TryCreateFromUserProfileLanguages()
        }
        if ($null -eq $engine) {
            throw "No OCR engine available."
        }

        $file = Await-WinRt ([Windows.Storage.StorageFile]::GetFileFromPathAsync($tempImage)) ([Windows.Storage.StorageFile])
        $stream = Await-WinRt ($file.OpenAsync([Windows.Storage.FileAccessMode]::Read)) ([Windows.Storage.Streams.IRandomAccessStream])
        $decoder = Await-WinRt ([Windows.Graphics.Imaging.BitmapDecoder]::CreateAsync($stream)) ([Windows.Graphics.Imaging.BitmapDecoder])
        $softwareBitmap = Await-WinRt ($decoder.GetSoftwareBitmapAsync()) ([Windows.Graphics.Imaging.SoftwareBitmap])
        $ocrResult = Await-WinRt ($engine.RecognizeAsync($softwareBitmap)) ([Windows.Media.Ocr.OcrResult])

        Write-Result -Status "OK" -Text ($ocrResult.Text.Trim())
    } finally {
        if (Test-Path -LiteralPath $tempImage) {
            Remove-Item -LiteralPath $tempImage -Force
        }
    }
} catch {
    Write-Result -Status "ERROR" -Text "" -ErrorText $_.Exception.Message
    exit 1
}
