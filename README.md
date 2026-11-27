# WallWright

一个 macOS 上的 Wallpaper Engine 创意工坊客户端。浏览、搜索、下载工坊壁纸，收进本地库，还能收藏分类。

界面用 macOS 26 的 Liquid Glass 做的，右下角有个悬浮 HUD 显示下载进度。

---

## 功能

| 功能 | 说明 |
| --- | --- |
| Steam 登录 | 启动即登录，凭据只存本机，不上传任何服务器 |
| 浏览工坊 | 按热门 / 最新 / 最多订阅 / 最高评分排序 |
| 搜索 | 关键词搜索，也可以直接粘贴工坊链接或 ID |
| 分类筛选 | 分级（全年龄 / PG13 / R18）+ 类型（场景 / 视频 / 网页），默认只显示全年龄 |
| 我的收藏 | 一键收藏，可自建收藏夹分类 |
| 下载 | 实时进度、速度显示，支持 Steam Guard 验证码 |
| 我的库 | 自动扫描已下载的壁纸，可设为桌面背景、删除到废纸篓 |
| 悬浮 HUD | 右下角常驻进度面板，可拖动 |

---

## 下载安装

去 [Releases](https://github.com/MUSHU-233/Wallwright/releases) 下载最新的 `WallWright-x.x.dmg`。

1. 双击打开 `.dmg`
2. 把 WallWright 图标拖进「应用程序」文件夹
3. 从「应用程序」里启动

**首次打开被系统拦下怎么办**

这个 App 没有 Apple 开发者签名，macOS 会提示"无法验证开发者"或"已损坏"。两种处理方式：

- 在「应用程序」里**右键点图标 → 打开**，弹窗里再点"打开"（只需一次）
- 在「隐私与安全」里最下面找到**Open Anyway**即可打开
- 或者打开终端执行：

```bash
xattr -dr com.apple.quarantine /Applications/WallWright.app
```

---

## 第一次使用

**1. 登录 Steam**

启动后第一屏是登录页。输入你的 Steam 账号和密码，账号如果开了 Steam Guard，会弹出验证码输入框。

> 这个账号**必须拥有 Wallpaper Engine**。这是 Valve 的规则：SteamCMD 只允许拥有该游戏的账号下载它的工坊内容。

账号密码只会保存在本机 `~/Library/Application Support/WallWright/credentials.json`（权限 600，只有你自己能读）。也可以取消勾选"记住密码"，让它只在本次运行有效。

**2. 填 Steam Web API Key（可选）**

搜索功能需要它，免费申请：<https://steamcommunity.com/dev/apikey>，域名随便填 `localhost`。

不填也能用：发现页会显示一批精选壁纸，也可以粘贴工坊链接直接解析、下载和收藏。

**3. 开始浏览**

- **发现**：翻页浏览、搜索、按分级和类型筛选
- **我的收藏**：鼠标移到壁纸上点右上角爱心，收藏到收藏夹
- **下载**：点卡片上的下载按钮，HUD 会显示进度
- **我的库**：下载完成的壁纸都在这里

---

## 常见问题

**下载一直不动 / 卡在"正在登录"**
先检查网络能否连上 Steam。国内访问 `api.steampowered.com` 时通时断，App 会自动重试 4 次。

**提示"Steam 拒绝下载"**
说明这个账号没有 Wallpaper Engine，或者该游戏的工坊权限受限。

**下载的壁纸存在哪**
`~/Library/Application Support/WallWright/Library/<工坊ID>/`

**视频壁纸为什么不能设为桌面背景**
macOS 系统接口只支持静态图片做壁纸。动态壁纸需要额外的渲染层，目前还没做。

**"我的收藏"和 Steam 的订阅是一回事吗**
不是。收藏是本地的，只存元数据（标题、预览图地址），不占硬盘空间，也不影响你的 Steam 账号。

**会不会把账号信息传出去**
不会。账号相关请求只发往 Steam；检查更新会访问 GitHub API，不带任何账号信息。


---

## 系统要求

- macOS 26 或更高
- Apple Silicon 或 Intel 均可（SteamCMD 是 x86_64 程序，需要 Rosetta 2，首次运行系统会提示安装）
- 一个拥有 Wallpaper Engine 的 Steam 账号

---

## 免责声明

本项目是个人开发的第三方工具，**与 Valve、Wallpaper Engine 官方没有任何关系**。

它调用的是 Valve 官方的 SteamCMD 命令行客户端，用你自己的账号登录、下载你自己有权访问的内容。使用前请确认这符合 [Steam 用户协议](https://store.steampowered.com/subscriber_agreement/)，因使用本工具产生的后果由使用者自行承担。

请**不要**把打包好的 `.app` 单独转发给别人——它会索要 Steam 账号密码，容易被误认为钓鱼程序。要分享就发这个仓库的链接。

**注意**，此软件是开源软件，完全免费，如果您通过付费渠道获得了此软件，请联系商家进行退款。

---

MIT License · 详见 [LICENSE](LICENSE)
