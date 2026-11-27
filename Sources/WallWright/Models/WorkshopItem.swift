import Foundation

/// 工坊分级。标签实测分布：Everyone 270 万 / Questionable 19 万 / Mature 38 万
enum AgeRating: String, CaseIterable, Identifiable, Sendable {
    case everyone, pg13, r18, unrated

    var id: String { rawValue }

    var label: String {
        switch self {
        case .everyone: return "全年龄"
        case .pg13: return "PG13"
        case .r18: return "R18"
        case .unrated: return "未标注"
        }
    }

    /// 对应的工坊标签，`unrated` 没有标签
    var tag: String? {
        switch self {
        case .everyone: return "Everyone"
        case .pg13: return "Questionable"
        case .r18: return "Mature"
        case .unrated: return nil
        }
    }

    /// 界面只给用户三个选项，"未标注"不进筛选栏（实际几乎不存在）
    static var selectable: [AgeRating] { [.everyone, .pg13, .r18] }
}

/// 内容类型。Wallpaper Engine 的条目通常同时带 `Wallpaper` 大类和
/// `Scene`/`Video`/`Web` 之一，所以筛选只看后者。
enum ContentKind: String, Codable, CaseIterable, Sendable {
    case video, scene, web, image, application, unknown

    /// 可筛选的类型（`Application` 全站仅 1 个条目，不列入）
    static var filterable: [ContentKind] { [.scene, .video, .web] }

    var filterLabel: String {
        switch self {
        case .scene: return "场景"
        case .video: return "视频"
        case .web: return "网页"
        default: return label
        }
    }

    /// 对应的工坊标签
    var filterTag: String? {
        switch self {
        case .scene: return "Scene"
        case .video: return "Video"
        case .web: return "Web"
        default: return nil
        }
    }

    var label: String {
        switch self {
        case .video: return "视频"
        case .scene: return "场景"
        case .web: return "网页"
        case .image: return "图片"
        case .application: return "程序"
        case .unknown: return "未知"
        }
    }

    var symbol: String {
        switch self {
        case .video: return "play.rectangle.fill"
        case .scene: return "cube.transparent.fill"
        case .web: return "safari.fill"
        case .image: return "photo.fill"
        case .application: return "app.badge.fill"
        case .unknown: return "questionmark.square.dashed"
        }
    }

    static func from(tags: [String]) -> ContentKind {
        if tags.contains("Video") { return .video }
        if tags.contains("Scene") { return .scene }
        if tags.contains("Web") { return .web }
        if tags.contains("Application") { return .application }
        if tags.contains("Wallpaper") { return .image }
        return .unknown
    }

    static func detect(in directory: URL) -> ContentKind {
        let fm = FileManager.default
        guard let names = try? fm.contentsOfDirectory(atPath: directory.path) else { return .unknown }
        let lower = names.map { $0.lowercased() }
        if lower.contains("scene.pkg") { return .scene }
        if lower.contains(where: { $0.hasSuffix(".mp4") || $0.hasSuffix(".webm") }) { return .video }
        if lower.contains("index.html") || lower.contains("project.json") { return .web }
        if lower.contains(where: { $0.hasSuffix(".exe") }) { return .application }
        if lower.contains(where: { $0.hasSuffix(".jpg") || $0.hasSuffix(".png") || $0.hasSuffix(".jpeg") }) { return .image }
        return .unknown
    }
}

struct WorkshopItem: Identifiable, Hashable, Codable, Sendable {
    let id: String
    var title: String
    var summary: String
    var previewURL: URL?
    var fileSize: Int64
    var subscriptions: Int
    var views: Int
    var tags: [String]
    var created: Date?
    var updated: Date?
    var kind: ContentKind

    var resolution: String? {
        tags.first { $0.contains(" x ") }
    }

    var isAudioResponsive: Bool {
        tags.contains("Audio responsive")
    }

    /// Wallpaper Engine 工坊用 Everyone / Questionable / Mature 三个标签标分级，
    /// 实测三者加起来几乎覆盖全部条目（270 万 / 19 万 / 38 万）。
    var ageRating: AgeRating {
        if tags.contains("Mature") { return .r18 }
        if tags.contains("Questionable") { return .pg13 }
        if tags.contains("Everyone") { return .everyone }
        return .unrated
    }

    var displayTags: [String] {
        tags.filter { $0 != "Wallpaper" && $0 != "Everyone" && !$0.contains(" x ") }.prefix(3).map { $0 }
    }

    var sizeText: String {
        guard fileSize > 0 else { return "未知" }
        return ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }

    var subsText: String {
        subscriptions >= 10000
            ? String(format: "%.1f 万", Double(subscriptions) / 10000)
            : "\(subscriptions)"
    }

    static func placeholder(id: String) -> WorkshopItem {
        WorkshopItem(id: id, title: "工坊物品 \(id)", summary: "", previewURL: nil, fileSize: 0,
                     subscriptions: 0, views: 0, tags: [], created: nil, updated: nil, kind: .unknown)
    }
}
