"""Build the Chrome Web Store package (YouTube removed, no manifest key).

Usage: python scripts/build_store_package.py
Output: dist/chrome-store/ and dist/floating-video-downloader-chrome-store-<version>.zip
"""
import json, re, shutil, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / 'payload' / 'extension'
OUT = ROOT / 'dist' / 'chrome-store'
STORE_NAME = 'Floating Video Downloader'
STORE_DESCRIPTION = '在抖音、B站、小红书、X、Instagram、TikTok 等视频页加一个悬浮下载按钮，交给本机下载组件保存公开视频。'
POPUP_INFO = '支持抖音、B站、小红书、X/Twitter、Instagram、TikTok、新片场和 Liblib。Cookie 只临时传给本机下载组件。'
BLOCKED = re.compile(r'youtu|yt-navigate', re.I)


def sub_once(text, pattern, repl, name):
    new, count = re.subn(pattern, repl, text, flags=re.S)
    if count != 1:
        raise SystemExit(f'{name}: expected 1 match for {pattern!r}, got {count}')
    return new


def build_manifest():
    m = json.loads((SRC / 'manifest.json').read_text(encoding='utf-8'))
    m.pop('key', None)
    m['name'] = STORE_NAME
    m['description'] = STORE_DESCRIPTION
    m['permissions'] = [p for p in m['permissions'] if p != 'tabs']
    keep = lambda patterns: [p for p in patterns if not BLOCKED.search(p)]
    m['host_permissions'] = keep(m['host_permissions'])
    for cs in m['content_scripts']:
        cs['matches'] = keep(cs['matches'])
    return json.dumps(m, ensure_ascii=False, indent=2) + '\n'


def build_content(s):
    s = sub_once(s, r"h==='youtu\.be'\|\|h==='youtube\.com'\|\|h\.endsWith\('\.youtube\.com'\)\?'youtube':", '', 'content site')
    s = sub_once(s, r"if\(site==='youtube'\)\{.*?\?u\.href:null\}(?=if\(site==='xiaohongshu'\))", '', 'content source')
    s = sub_once(s, r"\['youtube',", '[', 'content page list')
    s = sub_once(s, r"document\.addEventListener\('yt-navigate-finish',schedule\);", '', 'content yt event')
    return s


def build_popup_js(s):
    return sub_once(s, r"if\(h==='youtu\.be'\).*?'youtube':null;if\(h==='youtube\.com'.*?'youtube':null;", '', 'popup classify')


def build_popup_html(s):
    s = sub_once(s, r'<h1>[^<]*</h1>', f'<h1>{STORE_NAME}</h1>', 'popup title')
    return sub_once(s, r'<div class="info">[^<]*</div>', f'<div class="info">{POPUP_INFO}</div>', 'popup info')


def build_background(s):
    return sub_once(s, r" youtube: \['\.youtube\.com'\],", '', 'background cookies')


TRANSFORMS = {'content.js': build_content, 'popup.js': build_popup_js,
              'popup.html': build_popup_html, 'background.js': build_background}


def main():
    if OUT.exists():
        shutil.rmtree(OUT)
    OUT.mkdir(parents=True)
    for f in sorted(SRC.iterdir()):
        if f.name == 'manifest.json':
            (OUT / f.name).write_text(build_manifest(), encoding='utf-8')
        elif f.name in TRANSFORMS:
            (OUT / f.name).write_text(TRANSFORMS[f.name](f.read_text(encoding='utf-8')), encoding='utf-8')
        else:
            shutil.copy2(f, OUT / f.name)
    for f in OUT.iterdir():
        if f.suffix in ('.js', '.json', '.html') and BLOCKED.search(f.read_text(encoding='utf-8')):
            raise SystemExit(f'YouTube reference left in {f.name}')
    version = json.loads((OUT / 'manifest.json').read_text(encoding='utf-8'))['version']
    zip_path = ROOT / 'dist' / f'floating-video-downloader-chrome-store-{version}.zip'
    with zipfile.ZipFile(zip_path, 'w', zipfile.ZIP_DEFLATED) as z:
        for f in sorted(OUT.iterdir()):
            z.write(f, f.name)
    print(zip_path)


if __name__ == '__main__':
    main()
