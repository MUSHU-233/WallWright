# WallWright

一个 macOS 上的 Wallpaper Engine 创意工坊客户端：浏览、搜索、下载工坊壁纸，落到本地库。
界面用 macOS 27 的 Liquid Glass 做的，右下角有个悬浮 HUD 显示下载进度。

---

## 现在能做什么

| 功能 | 状态 | 说明 |
| --- | --- | --- |
| 浏览工坊 | ✅ | 有 API Key 可翻页浏览，没 Key 显示一组精选 |
| 搜索 | ✅ | 关键词 + 排序 + 标签筛选（需 Steam Web API Key） |
| 链接/ID 直接解析 | ✅ | 粘贴 `steamcommunity.com/sharedfiles/filedetails/?id=xxx` 即可 |
| 下载（SteamCMD 通道） | ✅ | 实时进度、速度、Steam Guard 验证码输入 |
| 下载（Steam 客户端通道） | ✅ | 用 `steam://` 唤起 Steam 订阅 |
| 悬浮 HUD | ✅ | 右下角玻璃面板，可拖动，自动弹出 |
| 本地库 | ✅ | 自动扫描 WallWright 与 Steam 客户端的工坊目录 |
| 设为桌面背景 | ⚠️ 仅静态图 | 视频/场景壁纸还设不了，见手册第 8 章 |

> 想真正下到文件，需要一个**拥有 Wallpaper Engine 的 Steam 账号**。这是 Valve 的规则，不是这个 App 的限制。

---

## 三种运行方式

**① 用 Xcode（推荐，日常开发就用这个）**

```bash
open /Users/wu/WallWright/WallWright.xcodeproj
```

然后在 Xcode 里按 `⌘R`。

**② 用命令行打包出可双击的 App**

```bash
cd /Users/wu/WallWright
./scripts/build.sh
open dist/WallWright.app
```

**③ 只编译不打包（改代码时快速查错）**

```bash
cd /Users/wu/WallWright
swift build --disable-sandbox
```

`--disable-sandbox` 不能省，省掉会报 `Invalid manifest`，原因见手册第 7 章。

---

## 目录速览

```
WallWright/
├── WallWright.xcodeproj      Xcode 工程（双击打开）
├── Sources/WallWright/       所有代码
│   ├── WallWrightApp.swift   程序入口：窗口、菜单栏、快捷键
│   ├── Core/                 全局状态、设计系统之外的杂项
│   ├── Models/               数据结构
│   ├── Services/             网络、下载、本地库、偏好设置
│   └── UI/                   所有界面
├── Resources/                Info.plist 和图标
├── scripts/build.sh          一键打包脚本
├── docs/开发手册.md          ★ 完整开发说明，建议先读
└── dist/WallWright.app       打包产物
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

**完整的开发说明、Xcode 界面导览、报错速查都在 [`docs/开发手册.md`](docs/开发手册.md)。**
