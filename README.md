# WallWright

一个 macOS 上的 Wallpaper Engine 创意工坊客户端：浏览、搜索、下载工坊壁纸，落到本地库。
界面用 macOS 27 的 Liquid Glass 做的，右下角有个悬浮 HUD 显示下载进度。

---

## 现在能做什么

| 功能 | 状态 | 说明 |
| --- | --- | --- |
| **Steam 登录（必须）** | ✅ | 启动即登录，未登录进不了主界面。凭据只存本机（600 权限），不上传任何服务器 |
| 浏览工坊 | ✅ | 有 API Key 可翻页浏览，没 Key 显示一组精选 |
| 搜索 | ✅ | 关键词 + 排序 + 标签筛选（需 Steam Web API Key） |
| **分类筛选** | ✅ | 分级（全年龄 / PG13 / R18）+ 类型（场景 / 视频 / 网页），多选即在组内取并集，全选等于不筛 |
| **我的收藏** | ✅ | 发现页点爱心收藏，可自建多个收藏夹分类；数据只存本机 `Favorites.json` |
| 链接/ID 直接解析 | ✅ | 粘贴 `steamcommunity.com/sharedfiles/filedetails/?id=xxx` 即可 |
| 下载（SteamCMD 通道） | ✅ | 实时进度、速度、Steam Guard 验证码输入 |
| 下载（Steam 客户端通道） | ✅ | 用 `steam://` 唤起 Steam 订阅 |
| 悬浮 HUD | ✅ | 右下角玻璃面板，可拖动，自动弹出 |
| 本地库 | ✅ | 自动扫描 WallWright 与 Steam 客户端的工坊目录；卡片悬停可「移到废纸篓」或仅移除记录 |
| 设为桌面背景 | ⚠️ 仅静态图 | 视频/场景壁纸还设不了，见手册第 8 章 |
| **关于 / 检查更新** | ✅ | 版本号取自 Info.plist；设置页可一键对比 GitHub Releases 检查新版 |

> 需要**拥有 Wallpaper Engine 的 Steam 账号**。这是 Valve 的规则，不是这个 App 的限制。

---

## 三种运行方式

**① 用 Xcode（推荐，日常开发就用这个）**

```bash
open WallWright.xcodeproj
```

然后在 Xcode 里按 `⌘R`。

**② 用命令行打包出可双击的 App**

```bash
./scripts/build.sh
open dist/WallWright.app
```

**③ 只编译不打包（改代码时快速查错）**

```bash
swift build --disable-sandbox
```

`--disable-sandbox` 不能省，省掉会报 `Invalid manifest`，原因见手册第 7 章。

**④ 做成双击安装的 `.dmg`**

```bash
./scripts/make_dmg.sh
```

产出 `dist/WallWright-1.0.dmg`：双击挂载 → 把图标拖进 Applications → 完成。
格式说明、签名、公证、为什么别人下载会报"已损坏"，全部见 [`docs/打包与分发.md`](docs/打包与分发.md)。

---

## 目录速览

```
WallWright/
├── WallWright.xcodeproj      Xcode 工程（双击打开）
├── Sources/WallWright/       所有代码
│   ├── WallWrightApp.swift   程序入口：窗口、菜单栏、快捷键
│   ├── Core/                 全局状态、路由
│   ├── Models/               数据结构
│   ├── Services/             网络、登录、下载、收藏、本地库、凭据
│   └── UI/                   所有界面（含 LoginView 登录门禁）
├── Resources/                Info.plist 和图标
├── scripts/build.sh          一键打包成 .app
├── scripts/make_dmg.sh       一键打包成 .dmg 安装包
├── docs/学习路线.md          ★ 从零学 Apple 开发的 10 周路线 + 资源
├── docs/开发手册.md          ★ 完整开发说明，建议先读
├── docs/打包与分发.md        ★ 怎么做出安装包、签名、公证
├── LICENSE                   MIT
└── dist/                     打包产物
```

---

## 想改点什么，去哪找

| 想改的东西 | 打开这个文件 | 找什么 |
| --- | --- | --- |
| 主题色 | `UI/DesignSystem.swift` | `WW.Palette.accent` |
| 所有圆角 | `UI/DesignSystem.swift` | `WW.Radius` |
| 背景那团彩色光晕 | `UI/DesignSystem.swift` | `AuroraBackground` |
| HUD 大小和位置 | `UI/HUD/HUDView.swift` + `HUDController.swift` | `.frame(width:)` 和 `width: 400` |
| 窗口默认大小 | `WallWrightApp.swift` | `.defaultSize` |
| 加一个新页面 | `Core/AppState.swift` + `UI/Main/RootView.swift` | `Route` 和 `switch state.route` |

---

## 文档

| 文档 | 内容 |
| --- | --- |
| [docs/学习路线.md](docs/学习路线.md) | 从零学 macOS / Apple 生态开发的 10 周路线、视频资源、GitHub 开源流程、简历写法 |
| [docs/开发手册.md](docs/开发手册.md) | Xcode 界面导览、代码地图、下载配置、报错速查 |
| [docs/打包与分发.md](docs/打包与分发.md) | DMG 制作、代码签名、公证、Gatekeeper |

---

## 系统要求

- macOS 26 或更高（界面用到 Liquid Glass）
- Apple Silicon 或 Intel 均可；SteamCMD 是 x86_64 程序，靠 Rosetta 2 运行
- 一个**拥有 Wallpaper Engine 的 Steam 账号**
- 搜索功能需要 [Steam Web API Key](https://steamcommunity.com/dev/apikey)（免费）

## 免责声明

本项目是第三方的个人工具，**与 Valve、Wallpaper Engine 官方没有任何关系**。

它调用的是 Valve 官方的 SteamCMD 命令行客户端，用你自己的账号登录、下载你自己有权访问的内容。
使用前请自行确认这符合 [Steam 用户协议](https://store.steampowered.com/subscriber_agreement/)；
因使用本工具产生的任何后果由使用者自行承担。

请**不要**把打包好的 `.app` 转发给别人——它需要输入 Steam 账号密码，转发会让人以为你在钓鱼。
要分享就发这个仓库的源码。

---

MIT License · 详见 [LICENSE](LICENSE)
