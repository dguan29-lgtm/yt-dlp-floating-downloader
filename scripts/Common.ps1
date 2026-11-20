$script:ProductName = 'yt-dlp Floating Downloader'
$script:ProductVersion = '3.6.0'
$script:ProductGuid = '8a4ad44c-988f-4a67-bfa4-9e604c644e0d'
$script:NativeHostName = 'com.cherry.ytdlp'
$script:ExpectedExtensionId = 'okbefieikffjgofllaokdgohmmbclfop'
$script:DefaultInstallRoot = Join-Path $env:LOCALAPPDATA 'CherryYtDlp'

function Get-PackageRoot { Split-Path $PSScriptRoot -Parent }
function Write-Utf8NoBom([string]$Path, [string]$Content) { [IO.File]::WriteAllText($Path, $Content, (New-Object Text.UTF8Encoding($false))) }
function Get-ChromePath {
    $candidates = @((Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe' -ErrorAction SilentlyContinue).'(default)', (Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\App Paths\chrome.exe' -ErrorAction SilentlyContinue).'(default)', "$env:ProgramFiles\Google\Chrome\Application\chrome.exe", "${env:ProgramFiles(x86)}\Google\Chrome\Application\chrome.exe", "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe")
    foreach ($candidate in $candidates) { if ($candidate -and (Test-Path -LiteralPath $candidate)) { return $candidate } }
    return $null
}
function Get-DefaultDownloadDirectory {
    $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
    $value = (Get-ItemProperty -Path $key -Name '{374DE290-123F-4565-9164-39C4925E467B}' -ErrorAction SilentlyContinue).'{374DE290-123F-4565-9164-39C4925E467B}'
    if ($value) { return (Join-Path ([Environment]::ExpandEnvironmentVariables($value)) 'yt-dlp') }
    return (Join-Path (Join-Path $HOME 'Downloads') 'yt-dlp')
}
function Test-SafeInstallRoot([string]$Path) {
    if (-not $Path -or -not [IO.Path]::IsPathRooted($Path)) { return $false }
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    foreach ($forbidden in @([IO.Path]::GetPathRoot($full).TrimEnd('\'), $HOME.TrimEnd('\'), $env:LOCALAPPDATA.TrimEnd('\'))) { if ($full -ieq $forbidden) { return $false } }
    return $true
}
