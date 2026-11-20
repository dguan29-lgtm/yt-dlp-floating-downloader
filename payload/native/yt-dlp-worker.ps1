param([Parameter(Mandatory = $true)][string]$RequestFile)

$ErrorActionPreference = 'Stop'
$exitCode = 1
$nativeDir = $PSScriptRoot
$installRoot = Split-Path $nativeDir -Parent
$toolsDir = Join-Path $installRoot 'tools'
$configDir = Join-Path $installRoot 'config'
$runtimeDir = Join-Path $installRoot 'runtime'
$logDir = Join-Path $runtimeDir 'logs'
$cookieDir = Join-Path $runtimeDir 'cookies'
$logFile = Join-Path $logDir 'worker.log'
$ytdlpPath = Join-Path $toolsDir 'yt-dlp.exe'
$ffmpegPath = Join-Path $toolsDir 'ffmpeg.exe'
$denoPath = Join-Path $toolsDir 'deno.exe'
$settingsPath = Join-Path $configDir 'settings.json'
$cookieFile = $null
$directTitle = $null

function Write-SafeLog([string]$Message) {
    try {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        Add-Content -LiteralPath $logFile -Value ((Get-Date -Format 's') + ' ' + $Message) -Encoding UTF8
    } catch {}
}

function Resolve-SafeDownloadDirectory([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path) -or $Path.StartsWith('\\') -or $Path.StartsWith('\\?\') -or $Path.StartsWith('\\.\')) { throw 'Download directory must be a local absolute path' }
    $full = [IO.Path]::GetFullPath($Path).TrimEnd('\')
    $root = [IO.Path]::GetPathRoot($full).TrimEnd('\')
    if ($full -eq $root -or $full.Length -gt 220) { throw 'Download directory cannot be a drive root or an overly long path' }
    $forbidden = @($installRoot, $env:WINDIR, $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData) | Where-Object { $_ }
    foreach ($item in $forbidden) { $base = [IO.Path]::GetFullPath($item).TrimEnd('\'); if ($full -ieq $base -or $full.StartsWith($base + '\', [StringComparison]::OrdinalIgnoreCase)) { throw 'Download directory cannot be inside a system or application directory' } }
    if ($full -ieq $HOME.TrimEnd('\') -or $full -ieq $env:LOCALAPPDATA.TrimEnd('\')) { throw 'Download directory cannot be a profile root' }
    New-Item -ItemType Directory -Path $full -Force | Out-Null
    $probe = Join-Path $full ('.write-test-' + [Guid]::NewGuid().ToString('N'))
    try { [IO.File]::WriteAllText($probe, 'ok') } finally { Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue }
    return $full
}

function New-NetscapeCookieFile($Cookies) {
    if (-not $Cookies -or $Cookies.Count -eq 0) { return $null }
    New-Item -ItemType Directory -Path $cookieDir -Force | Out-Null
    $path = Join-Path $cookieDir ('cookies-' + [Guid]::NewGuid().ToString('N') + '.txt')
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# Netscape HTTP Cookie File')
    foreach ($cookie in $Cookies) {
        $domain = ([string]$cookie.domain) -replace '[\r\n\t]', ''
        $name = ([string]$cookie.name) -replace '[\r\n\t]', ''
        $value = ([string]$cookie.value) -replace '[\r\n\t]', ''
        if (-not $domain -or -not $name) { continue }
        $includeSubdomains = if ($domain.StartsWith('.')) { 'TRUE' } else { 'FALSE' }
        $pathValue = if ($cookie.path) { ([string]$cookie.path) -replace '[\r\n\t]', '' } else { '/' }
        $secure = if ($cookie.secure) { 'TRUE' } else { 'FALSE' }
        $expires = if ($cookie.expirationDate) { [int64][math]::Floor([double]$cookie.expirationDate) } else { 0 }
        $lines.Add((@($domain, $includeSubdomains, $pathValue, $secure, $expires, $name, $value) -join "`t"))
    }
    [IO.File]::WriteAllLines($path, $lines, (New-Object Text.UTF8Encoding($false)))
    return $path
}

function Test-HttpOk([string]$Url) {
    try {
        $req = [Net.HttpWebRequest]::Create($Url)
        $req.Method = 'HEAD'
        $req.Timeout = 15000
        $req.ReadWriteTimeout = 15000
        $req.AllowAutoRedirect = $false
        $req.UserAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'
        $resp = $null
        try { $resp = $req.GetResponse() } catch [Net.WebException] { $resp = $_.Exception.Response }
        if ($null -eq $resp) { return $false }
        $code = [int]$resp.StatusCode
        $resp.Close()
        return ($code -ge 200 -and $code -lt 400)
    } catch { return $false }
}

function Get-SystemProxy {
    try {
        $key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
        $p = Get-ItemProperty -Path $key -ErrorAction SilentlyContinue
        if (-not $p -or $p.ProxyEnable -ne 1 -or -not $p.ProxyServer) { return $null }
        $server = ([string]$p.ProxyServer).Split(';')[0] -replace '^\s*https?=', ''
        $server = $server.Trim()
        if (-not $server) { return $null }
        if ($server -notmatch '^https?://') { $server = 'http://' + $server }
        return $server
    } catch { return $null }
}

function Resolve-LiblibMedia([string]$Mp4Url) {
    if ($Mp4Url -notmatch '^https://libtv-res\.liblib\.art/upload-images/[a-f0-9]{8,64}/[a-f0-9]{8,64}\.mp4$') { return $Mp4Url }
    if (Test-HttpOk $Mp4Url) { return $Mp4Url }
    $base = $Mp4Url -replace '\.mp4$',''
    foreach ($candidate in @(($base + '.mov'), ($base + '.webm'), ($base + '/master.m3u8'))) {
        if (Test-HttpOk $candidate) { return $candidate }
    }
    return $Mp4Url
}

try {
    if (-not (Test-Path -LiteralPath $RequestFile)) { throw "Request file not found" }
    $request = Get-Content -LiteralPath $RequestFile -Raw -Encoding UTF8 | ConvertFrom-Json
    Remove-Item -LiteralPath $RequestFile -Force -ErrorAction SilentlyContinue
    $site = [string]$request.site
    $mode = [string]$request.mode
    $sourceUrl = [string]$request.sourcePageUrl
    $mediaUrl = [string]$request.mediaUrl
    if ($site -eq 'xinpianchang') {
        if ($mode -ne 'extractor' -or $sourceUrl -notmatch '^https://www\.xinpianchang\.com/a\d+$' -or $mediaUrl) { throw 'Xinpianchang requires a work detail page' }
        foreach ($cookie in @($request.cookies)) { $cookieDomain = [string]$cookie.domain; if (($cookieDomain -ne 'xinpianchang.com') -and ($cookieDomain -ne '.xinpianchang.com')) { throw 'Invalid Xinpianchang cookie domain' } }
        $downloadUrl = $sourceUrl
    } elseif ($site -eq 'liblib') {
        $sourceUri = $null; $mediaUri = $null
        if ($mode -ne 'direct-public-mp4' -or -not [Uri]::TryCreate($sourceUrl, [UriKind]::Absolute, [ref]$sourceUri) -or -not [Uri]::TryCreate($mediaUrl, [UriKind]::Absolute, [ref]$mediaUri)) { throw 'Liblib request is invalid' }
        if ($sourceUri.Scheme -ne 'https' -or ($sourceUri.Host -ne 'www.liblib.tv' -and -not $sourceUri.Host.EndsWith('.liblib.tv')) -or $mediaUri.Scheme -ne 'https' -or $mediaUri.Host -ne 'libtv-res.liblib.art' -or $mediaUri.UserInfo -or -not $mediaUri.IsDefaultPort -or $mediaUri.AbsolutePath.EndsWith('/') -or @($request.cookies).Count -ne 0) { throw 'Liblib supports public videos only' }
        $downloadUrl = Resolve-LiblibMedia $mediaUri
        $t = ([string]$request.title) -replace '[\\/:\*?"<>\|\r\n\t]', ' '
        $t = $t.Trim()
        if ($t) { if ($t.Length -gt 100) { $t = $t.Substring(0, 100).Trim() }; if ($t) { $directTitle = $t -replace '%', '%%' } }
    } elseif ($site -eq 'douyin' -and $mode -eq 'extractor' -and -not [string]::IsNullOrWhiteSpace($mediaUrl)) {
        $uri = $null; $mediaUri = $null
        if (-not [Uri]::TryCreate($sourceUrl, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https' -or $uri.Host -ne 'www.douyin.com' -or $uri.AbsolutePath -notmatch '^/video/\d+$') { throw 'Invalid douyin source page' }
        if (-not [Uri]::TryCreate($mediaUrl, [UriKind]::Absolute, [ref]$mediaUri) -or $mediaUri.Scheme -ne 'https' -or $mediaUri.UserInfo -or -not $mediaUri.IsDefaultPort -or $mediaUri.Host -notmatch '(^|\.)(douyin|365yg|douyinvod|amemv|zjcdn|bytedance|ibytedtos)\.com$') { throw 'Invalid douyin media URL' }
        $downloadUrl = $mediaUrl
        $t = ([string]$request.title) -replace '[\\/:\*?"<>\|\r\n\t]', ' '
        $t = $t.Trim()
        if ($t) { if ($t.Length -gt 100) { $t = $t.Substring(0, 100).Trim() }; if ($t) { $directTitle = $t -replace '%', '%%' } }
    } elseif ($site -eq 'instagram') {
        $uri = $null
        if ($mode -ne 'extractor' -or -not [Uri]::TryCreate($sourceUrl, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') { throw 'Instagram request is invalid' }
        if ($uri.Host -notmatch '(^|\.)instagram\.com$' -or $uri.AbsolutePath -notmatch '^/(?:p|reel|reels|tv)/[A-Za-z0-9_-]{5,}') { throw 'Please open a specific Instagram post or reel page' }
        $downloadUrl = $sourceUrl
    } elseif ($site -eq 'tiktok') {
        $uri = $null
        if ($mode -ne 'extractor' -or -not [Uri]::TryCreate($sourceUrl, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') { throw 'TikTok request is invalid' }
        if ($uri.Host -notmatch '(^|\.)tiktok\.com$' -or $uri.AbsolutePath -notmatch '^/@[A-Za-z0-9._-]+/video/\d+') { throw 'Please open a specific TikTok video page' }
        $downloadUrl = $sourceUrl
    } else {
        $uri = $null
        if ($mode -ne 'extractor' -or -not [Uri]::TryCreate($sourceUrl, [UriKind]::Absolute, [ref]$uri) -or $uri.Scheme -ne 'https') { throw 'Only HTTPS video URLs are allowed' }
        $allowedHost = $uri.Host -match '(^|\.)(douyin|bilibili|youtube|xiaohongshu|xhslink|twitter)\.com$' -or $uri.Host -ieq 'youtu.be' -or $uri.Host -match '(^|\.)x\.com$'
        if (-not $allowedHost) { throw 'Only supported video-site URLs are allowed' }
        if (($uri.Host -match '(^|\.)(x|twitter)\.com$') -and $uri.AbsolutePath -notmatch '^/(?:[^/]+|i)/status/\d+') { throw 'Please open a specific X/Twitter status page' }
        $downloadUrl = $sourceUrl
    }
    if (-not (Test-Path -LiteralPath $ytdlpPath)) { throw 'yt-dlp.exe is missing' }
    if (-not (Test-Path -LiteralPath $ffmpegPath)) { throw 'ffmpeg.exe is missing' }
    if ($request.site -eq 'youtube' -and -not (Test-Path -LiteralPath $denoPath)) { throw 'deno.exe is missing for YouTube extraction' }
    if (-not (Test-Path -LiteralPath $settingsPath)) { throw 'settings.json is missing' }
    $settings = Get-Content -LiteralPath $settingsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([int]$settings.schemaVersion -ne 1) { throw 'Unsupported settings schema' }
    $downloadDir = Resolve-SafeDownloadDirectory ([string]$settings.downloadDirectory)

    Write-SafeLog ('download-start site=' + $site + ' mode=' + $mode)
    if ($site -ne 'liblib') { $cookieFile = New-NetscapeCookieFile $request.cookies }
    $outputTemplate = '%(title)s.%(ext)s'
    if ($directTitle) { $outputTemplate = $directTitle + '.%(ext)s' }
    $arguments = @('--ignore-config', '--ffmpeg-location', $ffmpegPath, '--format', 'bestvideo[ext=mp4]+bestaudio[ext=m4a]/bestvideo+bestaudio/best', '--merge-output-format', 'mp4', '--output', (Join-Path $downloadDir $outputTemplate), '--windows-filenames', '--no-playlist', '--progress')
    if ($site -eq 'youtube') { $arguments += @('--js-runtimes', ('deno:' + $denoPath)) }
    if ($site -eq 'liblib') { $arguments += @('--referer', $sourceUrl) }
    if ($site -eq 'douyin') { $arguments += @('--referer', 'https://www.douyin.com/') }
    $proxyUrl = $null
    if (($settings.PSObject.Properties.Name -contains 'proxy') -and -not [string]::IsNullOrWhiteSpace([string]$settings.proxy)) {
        $proxyUrl = ([string]$settings.proxy).Trim()
    } elseif (@('twitter','instagram','tiktok','youtube') -contains $site) {
        $proxyUrl = Get-SystemProxy
    }
    if ($proxyUrl) { $arguments += @('--proxy', $proxyUrl); Write-SafeLog ('using-proxy ' + $proxyUrl) }
    if ($cookieFile) { $arguments += @('--cookies', $cookieFile) }
    $arguments += $downloadUrl
    $runLog = Join-Path $logDir 'last-run.log'
    $prevEap = $ErrorActionPreference
    try {
        $ErrorActionPreference = 'Continue'
        & $ytdlpPath @arguments 2>&1 | ForEach-Object { "$_" } | Tee-Object -FilePath $runLog
    } finally {
        $ErrorActionPreference = $prevEap
    }
    $exitCode = $LASTEXITCODE
    Write-SafeLog ('download-exit code=' + $exitCode)
    if ($exitCode -ne 0 -and (Test-Path -LiteralPath $runLog)) {
        $errorLines = @(Get-Content -LiteralPath $runLog -Encoding UTF8 | Where-Object { $_ -match 'ERROR' } | Select-Object -First 5)
        foreach ($line in $errorLines) { Write-SafeLog ('ytdlp-error ' + $line) }
    }
    if ($exitCode -eq 0) {
        Write-Host 'Download complete. Closing in 3 seconds.' -ForegroundColor Green
        Start-Sleep 3
        Start-Process explorer.exe -ArgumentList $downloadDir
    } else {
        Write-Host ('Download failed. Exit code: ' + $exitCode) -ForegroundColor Red
        Write-Host ('Log: ' + $logFile) -ForegroundColor Yellow
        Start-Sleep 30
    }
} catch {
    Write-SafeLog ('worker-error ' + $_.Exception.Message)
    Write-Host ('Download startup failed: ' + $_.Exception.Message) -ForegroundColor Red
    Write-Host ('Log: ' + $logFile) -ForegroundColor Yellow
    Start-Sleep 30
} finally {
    if ($cookieFile -and (Test-Path -LiteralPath $cookieFile)) { Remove-Item -LiteralPath $cookieFile -Force -ErrorAction SilentlyContinue }
    if ($RequestFile -and (Test-Path -LiteralPath $RequestFile)) { Remove-Item -LiteralPath $RequestFile -Force -ErrorAction SilentlyContinue }
}
exit $exitCode
