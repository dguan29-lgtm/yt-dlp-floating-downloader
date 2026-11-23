const NATIVE_HOST = 'com.cherry.ytdlp';
const CONFIG_ACTIONS = new Set(['getConfig', 'chooseDownloadDirectory', 'resetDownloadDirectory']);

function cookieDomains(site) {
  const domains = {
    douyin: ['.douyin.com'], bilibili: ['.bilibili.com'], youtube: ['.youtube.com'],
    xiaohongshu: ['.xiaohongshu.com'], twitter: ['.x.com', '.twitter.com'],
    instagram: ['.instagram.com'], tiktok: ['.tiktok.com'],
    xinpianchang: ['.xinpianchang.com']
  };
  return domains[site] || [];
}

function sendNative(message) {
  return new Promise((resolve, reject) => {
    chrome.runtime.sendNativeMessage(NATIVE_HOST, message, (response) => {
      const error = chrome.runtime.lastError;
      if (error) reject(new Error(error.message));
      else if (!response) reject(new Error('本地下载程序没有返回结果'));
      else resolve(response);
    });
  });
}

async function getCookies(site) {
  const groups = await Promise.all(cookieDomains(site).map((domain) => new Promise((resolve, reject) => {
    chrome.cookies.getAll({ domain }, (items) => {
      const error = chrome.runtime.lastError;
      if (error) reject(new Error(error.message));
      else resolve(items || []);
    });
  })));
  const deduped = new Map();
  for (const cookie of groups.flat()) {
    if (!cookie?.name || !cookie?.domain || cookie.name.length > 256 || String(cookie.value || '').length > 8192) continue;
    deduped.set(`${cookie.domain}\n${cookie.path || '/'}\n${cookie.name}`, cookie);
  }
  return [...deduped.values()].slice(0, 500);
}

function isPopup(sender) {
  return sender.id === chrome.runtime.id && sender.url === chrome.runtime.getURL('popup.html') && !sender.tab;
}
function validXpc(url) {
  try { const u = new URL(url); return u.protocol === 'https:' && u.hostname === 'www.xinpianchang.com' && /^\/a\d+$/.test(u.pathname); } catch { return false; }
}
function validLibPage(url) {
  try { const u = new URL(url); return u.protocol === 'https:' && (u.hostname === 'www.liblib.tv' || u.hostname.endsWith('.liblib.tv')); } catch { return false; }
}
function validLibMedia(url) {
  try { const u = new URL(url); return u.protocol === 'https:' && u.hostname === 'libtv-res.liblib.art' && !u.username && !u.password && !u.port && /\.mp4$/i.test(u.pathname); } catch { return false; }
}
function validKsPage(url) {
  try { const u = new URL(url); return u.protocol === 'https:' && (u.hostname === 'kuaishou.com' || u.hostname.endsWith('.kuaishou.com')); } catch { return false; }
}
function validKsMedia(url) {
  try { const u = new URL(url); return u.protocol === 'https:' && !u.username && !u.password && !u.port
    && /(^|\.)(ndcimgs|kwaivideo|yximgs|kwimgs|gifshow)\.com$/i.test(u.hostname) && /\.mp4$/i.test(u.pathname); } catch { return false; }
}
function validDouyinMedia(url) {
  try { const u = new URL(url); return u.protocol === 'https:' && !u.username && !u.password && !u.port
    && /(^|\.)(douyin|365yg|douyinvod|amemv|zjcdn|bytedance|ibytedtos)\.com$/i.test(u.hostname); } catch { return false; }
}

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  if (CONFIG_ACTIONS.has(request.action)) {
    if (!isPopup(sender)) { sendResponse({ ok: false, error: '未授权的配置请求' }); return false; }
    sendNative({ action: request.action }).then(sendResponse).catch((error) => sendResponse({ ok: false, error: error.message }));
    return true;
  }
  if (request.action === 'ping') {
    sendNative({ action: 'ping' }).then(sendResponse).catch((error) => sendResponse({ ok: false, error: error.message }));
    return true;
  }
  if (request.action !== 'download') return false;

  (async () => {
    try {
      const site = request.site || '';
      const page = request.sourcePageUrl || request.pageUrl || sender.tab?.url || '';
      const url = request.url || page;
      const task = { protocolVersion: 2, action: 'download', site, title: request.title || sender.tab?.title || '' };
      if (site === 'xinpianchang') {
        if (!validXpc(url) || !validXpc(page)) throw new Error('新片场仅支持作品详情页');
        task.mode = 'extractor'; task.sourcePageUrl = url; task.mediaUrl = null; task.cookies = await getCookies(site);
      } else if (site === 'liblib') {
        if (!validLibPage(page) || !validLibMedia(request.mediaUrl)) throw new Error('当前作品未提供可下载的公开 MP4');
        task.mode = 'direct-public-mp4'; task.sourcePageUrl = page; task.mediaUrl = request.mediaUrl; task.url = request.mediaUrl; task.cookies = [];
      } else if (site === 'kuaishou') {
        if (!validKsPage(page) || !validKsMedia(request.mediaUrl)) throw new Error('当前视频未提供可下载的公开 MP4');
        task.mode = 'direct-public-mp4'; task.sourcePageUrl = page; task.mediaUrl = request.mediaUrl; task.url = request.mediaUrl; task.cookies = [];
      } else {
        if (!url || !cookieDomains(site).length) throw new Error('没有识别到受支持的视频链接');
        let mediaUrl = site === 'douyin' && request.mediaUrl && validDouyinMedia(request.mediaUrl) ? request.mediaUrl : null;
        let sourceUrl = url;
        if (site === 'douyin' && !mediaUrl) {
          const tabId = sender.tab?.id ?? request.tabId;
          if (tabId != null) {
            try {
              const res = await chrome.tabs.sendMessage(tabId, { action: 'resolve-douyin-direct', url });
              if (res?.ok && validDouyinMedia(res.mediaUrl)) {
                mediaUrl = res.mediaUrl;
                if (res.videoUrl) sourceUrl = res.videoUrl;
                if (res.title) task.title = res.title;
              }
            } catch {}
          }
        }
        task.mode = 'extractor'; task.sourcePageUrl = sourceUrl; task.mediaUrl = mediaUrl; task.cookies = await getCookies(site);
      }
      const response = await sendNative(task);
      if (!response.ok) throw new Error(response.error || '本地下载任务启动失败');
      sendResponse({ ok: true, message: response.message || '本地下载窗口已启动' });
    } catch (error) { sendResponse({ ok: false, error: error.message }); }
  })();
  return true;
});
