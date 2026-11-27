import Foundation

/// 关于页展示的信息。**要改作者 / 仓库地址，只改这个文件就够了。**
enum AppInfo {
    /// 作者署名（占位，之后替换成你自己的名字 / 昵称）
    static let author = "MUSHU-233"

    /// GitHub 仓库，格式 `"owner/repo"`。
    /// 留空时：关于页的仓库链接显示"未配置"，检查更新提示未配置。
    static let repoSlug = "MUSHU-233/Wallwright"

    static let displayName = "WallWright"
    static let tagline = "工坊壁纸工作站"
    static let blurb = "在 macOS 上浏览、下载、管理 Wallpaper Engine 创意工坊壁纸。"

    static var repoURL: URL? {
        repoSlug.isEmpty ? nil : URL(string: "https://github.com/\(repoSlug)")
    }

    static var version: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    static var build: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    static var versionText: String { "\(version) (build \(build))" }
}
