"""Exercise yt-dlp-worker.ps1 site guards without performing a download.

Each case stops at the validation stage (settings.json is absent from the source tree),
so yt-dlp is never launched and no PowerShell window wait occurs.
"""
import json, os, subprocess, tempfile

WORKER = r'D:\yt-dlp-floating-downloader-3.4.0-release\payload\native\yt-dlp-worker.ps1'
PS = r'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'

CASES = [
    ('instagram ok',   'instagram', 'https://www.instagram.com/p/Cabcdef1234/'),
    ('instagram reel', 'instagram', 'https://www.instagram.com/reel/Cabcdef1234/'),
    ('instagram bad',  'instagram', 'https://evil.example.com/p/Cabcdef1234/'),
    ('tiktok ok',      'tiktok',    'https://www.tiktok.com/@user/video/7123456789012345678'),
    ('tiktok bad',     'tiktok',    'https://www.tiktok.com/@user/photo/7123456789012345678'),
    ('twitter ok',     'twitter',   'https://x.com/user/status/1234567890123456789'),
    ('twitter bad',    'twitter',   'https://x.com/user/'),
    ('douyin ok',      'douyin',    'https://www.douyin.com/video/7123456789012345678'),
    ('unknown host',   'douyin',    'https://evil.example.com/video/1'),
]

tmp = tempfile.mkdtemp(prefix='ytdlp-guard-')
for label, site, url in CASES:
    req = os.path.join(tmp, 'req.json')
    with open(req, 'w', encoding='utf-8') as fh:
        json.dump({'protocolVersion': 2, 'site': site, 'mode': 'extractor',
                   'sourcePageUrl': url, 'mediaUrl': '', 'title': 't', 'cookies': []}, fh)
    p = subprocess.run([PS, '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', WORKER,
                        '-RequestFile', req], capture_output=True, text=True, timeout=60)
    out = ' '.join((p.stdout or '').split())
    # a validation throw prints "Download startup failed: <msg>"
    if 'Download startup failed' in out:
        msg = out.split('Download startup failed:', 1)[1].split('Log:')[0].strip()
        verdict = 'REJECT'
    else:
        msg = out[:80]
        verdict = 'PASS  '
    print(f'{label:16} {verdict}  {msg[:95]}')
