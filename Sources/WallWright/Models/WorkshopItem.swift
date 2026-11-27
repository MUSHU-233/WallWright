import Foundation

enum ContentKind: String, Codable, CaseIterable, Sendable {
    case video, scene, web, image, application, unknown

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
