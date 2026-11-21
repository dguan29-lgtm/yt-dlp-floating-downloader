# Chrome 应用商店上架资料（复制粘贴用）

## 商品详情 Store listing

**名称**：Floating Video Downloader（构建脚本自动写入 manifest）

**摘要**（manifest description，≤132 字符，自动写入）：
在抖音、B站、小红书、X、Instagram、TikTok 等视频页加一个悬浮下载按钮，交给本机下载组件保存公开视频。

**类别**：工具（Tools）　**语言**：中文（简体）

**详细说明**（中文，粘贴到“说明”）：

```
在视频详情页加一个悬浮的“下载”按钮，一键把公开视频保存到你自己的电脑。

支持站点：抖音、B站、小红书、X/Twitter、Instagram、TikTok、新片场，以及 Liblib 页面中公开播放的 MP4。

功能
• 鼠标移到视频上就出现下载按钮，所见即所得
• 自动使用浏览器里的登录状态，下载你有权观看的公开内容
• 自动合并最佳画质的音视频为 MP4
• 弹窗里可以修改保存目录、检测本地组件

使用前须知
本扩展只是按钮和桥接，真正的下载由你电脑上的本地组件完成（仅支持 Windows）。
首次使用请到 GitHub 下载安装包并运行“安装.cmd”：
https://github.com/dguan29-lgtm/yt-dlp-floating-downloader/releases

使用限制
只下载你本人拥有权利、已获授权或平台明确允许保存的内容。不绕过 DRM、付费墙、私有内容或任何访问控制。请遵守各平台服务条款。

隐私
不收集、不上传任何数据。Cookie 只临时交给本机下载组件，不离开你的电脑。
```

**English description**（可选，加英文语言时用）：

```
Adds a floating "Download" button to video pages so you can save public videos to your own computer.

Supported sites: Douyin, Bilibili, Xiaohongshu, X/Twitter, Instagram, TikTok, Xinpianchang, and public MP4s on Liblib.

The extension is only the button and bridge. Downloads are done by a local Windows component; install it once from:
https://github.com/dguan29-lgtm/yt-dlp-floating-downloader/releases

Only download content you own, are authorized to save, or the platform explicitly allows. Does not bypass DRM, paywalls, private content or any access control.

Privacy: no data is collected or uploaded. Cookies are passed only to the local component and never leave your computer.
```

**图片**
- 商店图标 128×128：`payload/extension/icon128.png`
- 屏幕截图 1280×800：`store/screenshot-1-button.png`、`store/screenshot-2-popup.png`
- 小型宣传图块 440×280：`store/promo-440x280.png`

## 隐私权 Privacy practices

**单一用途说明**：
```
在受支持的视频网站页面上显示一个下载按钮，把当前视频交给用户电脑上的本地下载组件保存。
```

**权限理由**：

| 权限 | 理由（粘贴） |
| --- | --- |
| cookies | 用户点击下载时，读取当前站点的登录 Cookie 并只交给本机下载组件，用于下载用户已登录、有权观看的公开视频。Cookie 不上传到任何服务器。 |
| nativeMessaging | 扩展本身不能下载和合并视频，需要通过 Native Messaging 把下载任务交给用户自己安装的本地下载组件。 |
| 主机权限 | 只在列出的视频网站（抖音、B站、小红书、X、Instagram、TikTok、新片场、Liblib）注入下载按钮，并读取这些站点的 Cookie；不访问其他网站。 |
| 远程代码 | 选“否，我不使用远程代码”。所有 JS 都在扩展包内。 |

**数据使用**：
- 勾选“身份验证信息”（Cookie）和“网站内容”（视频页地址、标题）。
- 勾选三项声明：不出售给第三方、不用于与单一用途无关的目的、不用于信用评估。

**隐私权政策网址**：
```
https://github.com/dguan29-lgtm/yt-dlp-floating-downloader/blob/main/PRIVACY.md
```

## 分发 Distribution
- 公开范围：先选“不公开（Unlisted）”。拿到链接的人才能安装，审核通常更顺利，之后可以改成公开。
- 地区：所有地区。
