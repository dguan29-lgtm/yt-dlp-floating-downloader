param(
    [string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'CherryYtDlp'),
    [string]$DownloadDirectory = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
$packageRoot = Get-PackageRoot
$payload = Join-Path $packageRoot 'payload'
$markerPath = Join-Path $InstallRoot '.product-marker.json'

try {
    if (-not [Environment]::Is64BitOperatingSystem) { throw 'Only 64-bit Windows is supported.' }
    if (-not (Test-SafeInstallRoot $InstallRoot)) { throw "Unsafe install path: $InstallRoot" }

    $hashManifest = Join-Path $packageRoot 'integrity\SHA256SUMS.txt'
    if (-not (Test-Path -LiteralPath $hashManifest)) { throw 'SHA256SUMS.txt is missing.' }
    foreach ($line in Get-Content -LiteralPath $hashManifest -Encoding UTF8) {
        if ($line -notmatch '^([0-9a-f]{64})  (.+)$') { throw "Invalid checksum line: $line" }
        $expectedHash = $matches[1]
        $relativePath = $matches[2].Replace('/', '\')
        $filePath = Join-Path $packageRoot $relativePath
        if (-not (Test-Path -LiteralPath $filePath)) { throw "Package file missing: $relativePath" }
        $actualHash = (Get-FileHash -LiteralPath $filePath -Algorithm SHA256).Hash.ToLowerInvariant()
        if ($actualHash -ne $expectedHash) { throw "Package checksum mismatch: $relativePath" }
    }

    $manifest = Get-Content (Join-Path $payload 'extension\manifest.json') -Raw -Encoding UTF8 | ConvertFrom-Json
    if ($manifest.version -ne $ProductVersion -or -not $manifest.key) { throw 'Extension manifest identity is invalid.' }
    $publicKey = [Convert]::FromBase64String([string]$manifest.key)
    $publicHash = [Security.Cryptography.SHA256]::Create().ComputeHash($publicKey)
    $alphabet = 'abcdefghijklmnop'
    $derivedExtensionId = ''
    foreach ($byte in $publicHash[0..15]) { $derivedExtensionId += $alphabet[$byte -shr 4]; $derivedExtensionId += $alphabet[$byte -band 15] }
    if ($derivedExtensionId -ne $ExpectedExtensionId) { throw 'Extension key does not match the expected extension ID.' }
    foreach ($required in @('extension\background.js','extension\content.js','native\yt-dlp-native-host.exe','native\yt-dlp-worker.ps1','tools\yt-dlp.exe','tools\ffmpeg.exe','tools\deno.exe')) {
        if (-not (Test-Path -LiteralPath (Join-Path $payload $required))) { throw "Package file missing: $required" }
    }

    $existingSettings = Join-Path $InstallRoot 'config\settings.json'
    if (-not $DownloadDirectory -and (Test-Path $existingSettings)) {
        try { $DownloadDirectory = [string](Get-Content $existingSettings -Raw -Encoding UTF8 | ConvertFrom-Json).downloadDirectory } catch {}
    }
    if (-not $DownloadDirectory) { $DownloadDirectory = Get-DefaultDownloadDirectory }
    if (-not [IO.Path]::IsPathRooted($DownloadDirectory)) { throw 'Download directory must be absolute.' }
    New-Item -ItemType Directory -Path $DownloadDirectory -Force | Out-Null
    $probe = Join-Path $DownloadDirectory ('.write-test-' + [Guid]::NewGuid().ToString('N'))
    [IO.File]::WriteAllText($probe, 'ok'); Remove-Item $probe -Force

    New-Item -ItemType Directory -Path $InstallRoot -Force | Out-Null
    foreach ($dir in @('extension','native','tools','licenses','config','runtime\requests','runtime\cookies','runtime\logs','uninstall')) { New-Item -ItemType Directory -Path (Join-Path $InstallRoot $dir) -Force | Out-Null }
    Copy-Item (Join-Path $payload 'extension\*') (Join-Path $InstallRoot 'extension') -Recurse -Force
    Copy-Item (Join-Path $payload 'native\*') (Join-Path $InstallRoot 'native') -Recurse -Force
    Copy-Item (Join-Path $payload 'tools\*') (Join-Path $InstallRoot 'tools') -Recurse -Force
    if (Test-Path (Join-Path $packageRoot 'licenses')) { Copy-Item (Join-Path $packageRoot 'licenses\*') (Join-Path $InstallRoot 'licenses') -Recurse -Force }

    $settings = [ordered]@{ schemaVersion = 1; downloadDirectory = $DownloadDirectory }
    Write-Utf8NoBom (Join-Path $InstallRoot 'config\settings.json') ($settings | ConvertTo-Json)
    $nativeManifest = [ordered]@{ name=$NativeHostName; description='Local yt-dlp download bridge'; path=(Join-Path $InstallRoot 'native\yt-dlp-native-host.exe'); type='stdio'; allowed_origins=@(Get-AllowedOrigins) }
    $nativeManifestPath = Join-Path $InstallRoot 'native\com.cherry.ytdlp.json'
    Write-Utf8NoBom $nativeManifestPath ($nativeManifest | ConvertTo-Json -Depth 4)

    $regPath = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$NativeHostName"
    New-Item -Path $regPath -Force | Out-Null
    Set-Item -Path $regPath -Value $nativeManifestPath
    $marker = [ordered]@{ productGuid=$ProductGuid; productName=$ProductName; version=$ProductVersion; extensionId=$ExpectedExtensionId; installRoot=$InstallRoot; installedAt=(Get-Date).ToString('s') }
    Write-Utf8NoBom $markerPath ($marker | ConvertTo-Json)

    Copy-Item (Join-Path $packageRoot 'scripts\Uninstall.ps1') (Join-Path $InstallRoot 'uninstall\Uninstall.ps1') -Force
    Copy-Item (Join-Path $packageRoot 'scripts\Common.ps1') (Join-Path $InstallRoot 'uninstall\Common.ps1') -Force
    $uninstallCmd = "@echo off`r`npowershell.exe -NoProfile -ExecutionPolicy Bypass -File `"%~dp0Uninstall.ps1`"`r`npause`r`n"
    [IO.File]::WriteAllText((Join-Path $InstallRoot 'uninstall\Uninstall.cmd'), $uninstallCmd, [Text.Encoding]::ASCII)

    Set-Clipboard -Value (Join-Path $InstallRoot 'extension')
    $chrome = Get-ChromePath
    if ($chrome) { Start-Process $chrome 'chrome://extensions/' }
    Add-Type -AssemblyName System.Windows.Forms
    [Windows.Forms.MessageBox]::Show("Installation complete.`r`n`r`nIMPORTANT LEGACY MIGRATION:`r`n1. In chrome://extensions remove old extension ID:`r`nelpphapffoicanjmlgjmjenkacllljob`r`n2. Enable Developer mode and click Load unpacked.`r`n3. Select:`r`n$(Join-Path $InstallRoot 'extension')`r`n4. Confirm new ID:`r`n$ExpectedExtensionId`r`n5. Refresh already-open video pages.", $ProductName, 0, 64) | Out-Null
    Write-Host "Installed successfully to $InstallRoot" -ForegroundColor Green
    Write-Host "Downloads: $DownloadDirectory"
} catch {
    Write-Host ('Installation failed: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
