param([string]$InstallRoot = (Join-Path $env:LOCALAPPDATA 'CherryYtDlp'))

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'Common.ps1')
try {
    if (-not (Test-SafeInstallRoot $InstallRoot)) { throw "Unsafe uninstall path: $InstallRoot" }
    $markerPath = Join-Path $InstallRoot '.product-marker.json'
    if (Test-Path $markerPath) {
        $marker = Get-Content $markerPath -Raw -Encoding UTF8 | ConvertFrom-Json
        if ($marker.productGuid -ne $ProductGuid) { throw 'Product marker does not match.' }
    } elseif (-not (Test-Path $InstallRoot)) {
        Write-Host 'Product is already uninstalled.' -ForegroundColor Green
        exit 0
    } else { throw 'Product marker is missing; refusing recursive removal.' }

    $nativeManifest = Join-Path $InstallRoot 'native\com.cherry.ytdlp.json'
    $regPath = "HKCU:\Software\Google\Chrome\NativeMessagingHosts\$NativeHostName"
    if (Test-Path $regPath) {
        $current = (Get-Item $regPath).GetValue('')
        if ($current -ieq $nativeManifest) { Remove-Item $regPath -Recurse -Force }
    }
    Remove-Item -LiteralPath $InstallRoot -Recurse -Force
    $chrome = Get-ChromePath
    if ($chrome) { Start-Process $chrome 'chrome://extensions/' }
    Add-Type -AssemblyName System.Windows.Forms
    [Windows.Forms.MessageBox]::Show("Local components were removed.`r`nDownloaded videos were kept.`r`n`r`nIn Chrome, remove extension ID:`r`n$ExpectedExtensionId", $ProductName, 0, 64) | Out-Null
    Write-Host 'Uninstalled successfully. Downloaded videos were preserved.' -ForegroundColor Green
} catch {
    Write-Host ('Uninstall failed: ' + $_.Exception.Message) -ForegroundColor Red
    exit 1
}
