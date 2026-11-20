# yt-dlp Floating Downloader

在视频详情页右下角注入一个悬浮「下载」按钮，一键把公开视频保存到本地。底层是 [yt-dlp](https://github.com/yt-dlp/yt-dlp)，通过 Chrome 扩展 + Native Messaging + 本地 PowerShell worker 驱动。

A Chrome extension that adds a floating download button on supported video pages and saves public videos locally via yt-dlp, ffmpeg and a native messaging host. Windows only.

## 支持站点

抖音、B 站、YouTube、小红书、X/Twitter、Instagram、TikTok、新片场，以及 Liblib 页面中公开播放的 MP4。

## 功能特性

- 视频详情页右下角悬浮下载按钮，所见即所得
- 自动复用浏览器登录 Cookie（抖音 / X / Instagram 等需要登录态的站点）
- 境外站点自动跟随 Windows 系统代理，也可在配置里写死代理
- 自动合并最佳画质音视频为 MP4（yt-dlp + ffmpeg）
- 弹窗内可修改保存目录、自检本地组件
- 只下载公开内容：不绕过 DRM、付费墙、私有项目或任何访问控制

## 快速安装（推荐）

1. 到 **Releases** 下载最新的 `yt-dlp-floating-downloader-*-win64.zip`，完整解压。
2. 双击 `安装.cmd`。
3. Chrome 扩展页开启「开发者模式」→「加载已解压的扩展程序」→ 选择安装器提示的 `extension` 目录。
4. 扩展 ID 应为 `okbefieikffjgofllaokdgohmmbclfop`。
5. 点击扩展图标 →「检测本地组件」，全部打勾即完成。

卸载：双击 `卸载.cmd`。

## 从源码安装

```powershell
git clone https://github.com/dguan29-lgtm/yt-dlp-floating-downloader.git
cd yt-dlp-floating-downloader
powershell -NoProfile -ExecutionPolicy Bypass -File .\scripts\Fetch-Tools.ps1
.\安装.cmd
```

`payload\tools\` 下的 yt-dlp / ffmpeg / deno 二进制（约 255 MB）不随仓库分发，`Fetch-Tools.ps1` 会从官方来源拉取并把哈希写回 `integrity\SHA256SUMS.txt`。

## 架构

```
content.js (悬浮按钮) → background.js (service worker)
        ⇅ Chrome Native Messaging
yt-dlp-native-host.exe (C#, 请求校验 + 拉起 worker)
        ⇅ 生成 request-*.json
yt-dlp-worker.ps1 (PowerShell, 站点/URL 二次校验)
        ⇅
yt-dlp.exe + ffmpeg.exe (+ deno.exe 用于 YouTube JS 运行时)
```

| 目录 | 内容 |
| --- | --- |
| `payload/extension/` | MV3 扩展（content/background/popup） |
| `payload/native/` | Native host（C# 源 + 编译产物）与下载 worker |
| `payload/tools/` | 第三方二进制（仓库不含，Fetch-Tools.ps1 拉取） |
| `scripts/` | 安装/卸载/自检/工具拉取脚本 |
| `integrity/` | 发布包 SHA256 校验清单 |

## 使用限制

仅下载本人拥有权利、已获授权或平台明确允许保存的内容。本工具不绕过 DRM、付费墙、私有项目、订阅访问控制、地区限制或账户权限。请遵守各平台服务条款。

## 站点备注

- **Instagram / TikTok / X / YouTube**：需要代理。默认读系统代理；在 `config\settings.json` 加 `"proxy":"http://127.0.0.1:7892"` 可固定。
- **新片场**：仅作品详情页 `https://www.xinpianchang.com/a数字ID`。
- **Liblib**：仅页面中公开播放的视频；私有/付费/DRM 不显示按钮。

## 日志与排查

日志：`%LOCALAPPDATA%\CherryYtDlp\runtime\logs`（`worker.log` / `native-host.log` / `last-run.log`）。
下载失败时 PowerShell 窗口会保留 30 秒显示错误。

## License

MIT（见 [LICENSE](LICENSE)）。第三方组件各自保留其许可证：yt-dlp（Unlicense）、ffmpeg（LGPL/GPL）、Deno（MIT）——文本见 `licenses/`。
