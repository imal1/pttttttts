param(
    [Parameter(Mandatory = $true)]
    [string]$InputFolder,

    [Parameter(Mandatory = $true)]
    [string]$OutputFolder,

    [ValidateRange(1, 100)]
    [int]$Quality = 78,

    [ValidateRange(0, 30000)]
    [int]$MaxSide = 2560
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $InputFolder -PathType Container)) {
    throw "Input folder not found: $InputFolder"
}

New-Item -ItemType Directory -Force -Path $OutputFolder | Out-Null

Add-Type -AssemblyName System.Drawing

function Get-JpegCodec {
    return [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() |
        Where-Object { $_.MimeType -eq "image/jpeg" } |
        Select-Object -First 1
}

function Save-AsJpeg {
    param(
        [Parameter(Mandatory = $true)]
        [System.Drawing.Bitmap]$Bitmap,

        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [int]$JpegQuality,

        [Parameter(Mandatory = $true)]
        [System.Drawing.Imaging.ImageCodecInfo]$Codec
    )

    $encoder = [System.Drawing.Imaging.Encoder]::Quality
    $encParams = New-Object System.Drawing.Imaging.EncoderParameters(1)
    $encParams.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter($encoder, [int64]$JpegQuality)
    try {
        $Bitmap.Save($Path, $Codec, $encParams)
    }
    finally {
        $encParams.Dispose()
    }
}

$jpegCodec = Get-JpegCodec
if (-not $jpegCodec) {
    throw "JPEG codec not found on this machine."
}

$exts = @(".jpg", ".jpeg", ".png")
$files = Get-ChildItem -LiteralPath $InputFolder -Recurse -File |
    Where-Object { $exts -contains $_.Extension.ToLowerInvariant() }

if (-not $files -or $files.Count -eq 0) {
    Write-Output "No supported image files found."
    exit 0
}

[int64]$totalIn = 0
[int64]$totalOut = 0
[int]$ok = 0
[int]$failed = 0

foreach ($f in $files) {
    $relative = $f.FullName.Substring($InputFolder.Length).TrimStart('\\')
    $targetRelative = [System.IO.Path]::ChangeExtension($relative, ".jpg")
    $destPath = Join-Path $OutputFolder $targetRelative
    $destDir = Split-Path -Path $destPath -Parent
    New-Item -ItemType Directory -Force -Path $destDir | Out-Null

    try {
        $image = [System.Drawing.Image]::FromFile($f.FullName)
        try {
            $newW = $image.Width
            $newH = $image.Height

            if ($MaxSide -gt 0) {
                $longSide = [Math]::Max($image.Width, $image.Height)
                if ($longSide -gt $MaxSide) {
                    $scale = [double]$MaxSide / [double]$longSide
                    $newW = [Math]::Max(1, [int][Math]::Round($image.Width * $scale))
                    $newH = [Math]::Max(1, [int][Math]::Round($image.Height * $scale))
                }
            }

            $bitmap = New-Object System.Drawing.Bitmap($newW, $newH)
            try {
                $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
                try {
                    $graphics.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
                    $graphics.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
                    $graphics.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
                    $graphics.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
                    $graphics.DrawImage($image, 0, 0, $newW, $newH)
                }
                finally {
                    $graphics.Dispose()
                }

                Save-AsJpeg -Bitmap $bitmap -Path $destPath -JpegQuality $Quality -Codec $jpegCodec
            }
            finally {
                $bitmap.Dispose()
            }
        }
        finally {
            $image.Dispose()
        }

        $totalIn += $f.Length
        $outInfo = Get-Item -LiteralPath $destPath
        $totalOut += $outInfo.Length
        $ok++
    }
    catch {
        $failed++
        Write-Warning ("Failed: " + $f.FullName + " | " + $_.Exception.Message)
    }
}

$inMb = [Math]::Round($totalIn / 1MB, 2)
$outMb = [Math]::Round($totalOut / 1MB, 2)
$ratio = if ($totalIn -gt 0) { [Math]::Round((1 - ($totalOut / [double]$totalIn)) * 100, 2) } else { 0 }

Write-Output "Done. Success: $ok, Failed: $failed"
Write-Output "Original total: $inMb MB"
Write-Output "Compressed total: $outMb MB"
Write-Output "Reduction: $ratio%"
