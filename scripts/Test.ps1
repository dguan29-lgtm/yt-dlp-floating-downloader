param([string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'CherryYtDlp'))

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')

$manifestPath = Join-Path $InstallRoot 'native\com.cherry.ytdlp.json'
$hostPath = Join-Path $InstallRoot 'native\yt-dlp-native-host.exe'
if (-not (Test-Path -LiteralPath $manifestPath)) { throw 'Native host manifest is missing.' }
if (-not (Test-Path -LiteralPath $hostPath)) { throw 'Native host executable is missing.' }

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
if (@($manifest.allowed_origins) -notcontains "chrome-extension://$ExpectedExtensionId/") { throw 'Native host extension ID mismatch.' }

$json = '{"action":"ping"}'
$payload = [Text.Encoding]::UTF8.GetBytes($json)
$prefix = [BitConverter]::GetBytes($payload.Length)
$inputFile = Join-Path $env:TEMP ('cherry-ytdlp-ping-' + [Guid]::NewGuid().ToString('N') + '.bin')
$outputFile = "$inputFile.out"
try {
    $stream = [IO.File]::Open($inputFile, [IO.FileMode]::CreateNew)
    $stream.Write($prefix, 0, 4)
    $stream.Write($payload, 0, $payload.Length)
    $stream.Dispose()
    cmd.exe /d /c "type `"$inputFile`" | `"$hostPath`" > `"$outputFile`""
    $raw = [IO.File]::ReadAllBytes($outputFile)
    if ($raw.Length -lt 4) { throw 'Native host returned no response.' }
    $length = [BitConverter]::ToInt32($raw, 0)
    $response = [Text.Encoding]::UTF8.GetString($raw, 4, $length) | ConvertFrom-Json
    if (-not $response.ok) { throw ($response.error | Out-String) }
    $response | Format-List
    Write-Host 'Native host self-test passed.' -ForegroundColor Green
} finally {
    Remove-Item -LiteralPath $inputFile -Force -ErrorAction SilentlyContinue
    Remove-Item -LiteralPath $outputFile -Force -ErrorAction SilentlyContinue
}
