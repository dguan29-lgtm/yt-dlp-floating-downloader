yt-dlp Floating Downloader 3.7.0
================================

支持：抖音、快手、B站、YouTube、小红书、X/Twitter、Instagram、TikTok、新片场，
以及 Liblib 页面中公开播放的 MP4。

快速安装
--------
1. 解压整个 ZIP。
2. 双击“安装.cmd”。
3. 在 Chrome 扩展页开启开发者模式，加载安装器提示的 extension 文件夹。
4. 固定扩展 ID：okbefieikffjgofllaokdgohmmbclfop。
5. 打开扩展 popup，可检测组件并修改视频保存目录。

Instagram
---------
支持作品详情页与 Reels：https://www.instagram.com/p/短码/ 或 /reel/短码/。
Instagram 对未登录访问限制很严，多数视频需要先在浏览器登录 Instagram，
扩展会自动把登录 Cookie 交给 yt-dlp。未登录时报 “empty media response” 属正常限制，
请登录后再试。快拍（Story）与个人主页暂不支持。

TikTok
------
支持作品详情页：https://www.tiktok.com/@用户名/video/数字ID
TikTok 会封禁大量代理/机房 IP，报 “Your IP address is blocked” 时请换一个出口节点，
或在浏览器登录 TikTok 后重试。个人主页与合辑暂不支持。

X/Twitter
---------
支持推文详情页：https://x.com/用户名/status/数字ID
下载失败时请先确认已登录 X，并打开的是具体某条推文（不是首页或搜索页）。
失败原因会写入日志文件，见下方“日志”。

代理
----
Instagram / TikTok / X / YouTube 需要代理。默认自动读取 Windows 系统代理设置
（设置 → 网络和 Internet → 代理），跟随 Clash 等工具的端口，无需额外配置。
若要固定使用某个代理，可在 config\settings.json 中增加 "proxy" 字段，例如：
{"schemaVersion":1,"downloadDirectory":"D:\\Downloads\\yt-dlp","proxy":"http://127.0.0.1:7892"}
填了 proxy 之后，所有站点都会显式走该代理；留空或不填则只对境外站点用系统代理。

新片场
------
仅支持作品详情页：https://www.xinpianchang.com/a数字ID
推荐页只用于浏览；请点击具体作品进入详情页再下载。站点可能要求登录，403 或访问受限时请使用平台提供的正式渠道。

Liblib
-----
支持 liblib.tv 作品详情页（https://www.liblib.tv/detail/作品ID）中公开播放的视频。
LibTV 现已改用 HLS 播放，扩展会自动定位真实源文件并下载：优先原始 MP4 直链，
其次 MOV/WEBM 原始文件，最后回退到 m3u8 高清流（由 yt-dlp 合并为 MP4）。
对于私有、付费、DRM 或未公开的内容，不显示下载按钮，也不会尝试绕过限制。

使用限制
--------
仅下载本人拥有权利、已获授权或平台明确允许保存的内容。扩展不支持 DRM、付费墙、私有项目、订阅访问控制、地区限制或账户权限规避。

保存目录
--------
popup 中选择“选择文件夹”即可通过 Windows 目录选择器修改路径。修改只影响新下载，不移动已有文件。恢复默认会使用 Windows“下载\yt-dlp”。

日志
----
%LOCALAPPDATA%\CherryYtDlp\runtime\logs
