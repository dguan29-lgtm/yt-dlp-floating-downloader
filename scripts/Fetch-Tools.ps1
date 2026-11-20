param([string]$PackageRoot = '')

$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

if (-not $PackageRoot) { $PackageRoot = Split-Path $PSScriptRoot -Parent }
$toolsDir = Join-Path $PackageRoot 'payload\tools'
$manifestPath = Join-Path $PackageRoot 'integrity\SHA256SUMS.txt'
New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null

function Get-File([string]$Url, [string]$OutFile) {
    Write-Host ('Downloading ' + $Url)
    Invoke-WebRequest -Uri $Url -OutFile $OutFile -UseBasicParsing
}

$tmp = Join-Path $env:TEMP ('ytdlp-tools-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null
try {
    Get-File 'https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp.exe' (Join-Path $toolsDir 'yt-dlp.exe')

    $denoZip = Join-Path $tmp 'deno.zip'
    Get-File 'https://github.com/denoland/deno/releases/latest/download/deno-x86_64-pc-windows-msvc.zip' $denoZip
    Expand-Archive -LiteralPath $denoZip -DestinationPath (Join-Path $tmp 'deno') -Force
    Copy-Item -LiteralPath (Join-Path $tmp 'deno\deno.exe') -Destination (Join-Path $toolsDir 'deno.exe') -Force

    $ffmpegZip = Join-Path $tmp 'ffmpeg.zip'
    Get-File 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip' $ffmpegZip
    Expand-Archive -LiteralPath $ffmpegZip -DestinationPath (Join-Path $tmp 'ffmpeg') -Force
    $ffmpegExe = Get-ChildItem -LiteralPath (Join-Path $tmp 'ffmpeg') -Recurse -Filter 'ffmpeg.exe' | Select-Object -First 1
    if (-not $ffmpegExe) { throw 'ffmpeg.exe not found in downloaded archive' }
    Copy-Item -LiteralPath $ffmpegExe.FullName -Destination (Join-Path $toolsDir 'ffmpeg.exe') -Force
} finally {
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

if (Test-Path -LiteralPath $manifestPath) {
    $lines = Get-Content -LiteralPath $manifestPath -Encoding UTF8
    foreach ($tool in @('yt-dlp.exe', 'ffmpeg.exe', 'deno.exe')) {
        $hash = (Get-FileHash -LiteralPath (Join-Path $toolsDir $tool) -Algorithm SHA256).Hash.ToLowerInvariant()
        $lines = $lines -replace ('^[0-9a-f]{64}  payload/tools/' + [regex]::Escape($tool) + '$'), ($hash + '  payload/tools/' + $tool)
    }
    [IO.File]::WriteAllLines($manifestPath, $lines, (New-Object Text.UTF8Encoding($false)))
}

Write-Host ('Tools ready in ' + $toolsDir) -ForegroundColor Green
