import Foundation

struct LibraryEntry: Identifiable, Codable, Hashable {
    var id: String
    var title: String
    var kind: ContentKind
    var size: Int64
    var path: String
    var added: Date
    var preview: String?
    var source: String

    var url: URL { URL(fileURLWithPath: path) }
    var previewURL: URL? { preview.flatMap(URL.init(string:)) }
}

@MainActor
final class LibraryStore: ObservableObject {
    static let shared = LibraryStore()

    @Published private(set) var entries: [LibraryEntry] = []
    @Published private(set) var scanning = false
    @Published var lastMessage: String?

    let directory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("WallWright/Library", isDirectory: true)
    }()

    private var steamClientDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Steam/steamapps/workshop/content/\(SteamAPI.appID)", isDirectory: true)
    }

    private var metaFile: URL { directory.appendingPathComponent("index.json") }

    private init() {
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: metaFile),
              let decoded = try? JSONDecoder().decode([LibraryEntry].self, from: data) else { return }
        entries = decoded.sorted { $0.added > $1.added }
    }

    private func persist() {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        if let data = try? JSONEncoder().encode(entries) {
            try? data.write(to: metaFile, options: .atomic)
        }
    }

    @discardableResult
    func register(id: String, at url: URL, item: WorkshopItem?) -> LibraryEntry {
        let kind = ContentKind.detect(in: url)
        let entry = LibraryEntry(
            id: id,
            title: item?.title ?? "工坊物品 \(id)",
            kind: kind,
            size: Self.directorySize(url),
            path: url.path,
            added: Date(),
            preview: item?.previewURL?.absoluteString,
            source: url.path.contains("/WallWright/") ? "WallWright" : "Steam"
        )
        entries.removeAll { $0.id == id }
        entries.insert(entry, at: 0)
        persist()
        return entry
    }

    func remove(id: String, deleteFiles: Bool) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return }
        let entry = entries[index]
        if deleteFiles, entry.path.contains("/WallWright/") || entry.path.contains("/Steam/") {
            try? FileManager.default.removeItem(at: entry.url)
        }
        entries.remove(at: index)
        persist()
    }

    func reveal(_ entry: LibraryEntry) {
        NSWorkspace.shared.activateFileViewerSelecting([entry.url])
    }

    func openWithDefault(_ entry: LibraryEntry) {
        NSWorkspace.shared.open(entry.url)
    }

    /// 扫描 WallWright 库目录与 Steam 客户端本地工坊目录，补齐元数据
    func scan() async {
        scanning = true
        defer { scanning = false }

        var found: [String: URL] = [:]
        for root in [directory, steamClientDirectory] where FileManager.default.fileExists(atPath: root.path) {
            let children = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey])) ?? []
            for child in children where (try? child.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
                let id = child.lastPathComponent
                if id.allSatisfy(\.isNumber) { found[id] = child }
            }
        }

        let known = Set(entries.map(\.id))
        let missing = found.keys.filter { !known.contains($0) }
        var items: [String: WorkshopItem] = [:]
        if !missing.isEmpty {
            if let fetched = try? await SteamAPI.shared.details(ids: missing) {
                for item in fetched { items[item.id] = item }
            }
        }

        for (id, url) in found {
            let changed = entries.first { $0.id == id }?.path != url.path
            if known.contains(id) && !changed { continue }
            register(id: id, at: url, item: items[id])
        }

        entries.removeAll { !FileManager.default.fileExists(atPath: $0.path) }
        entries.sort { $0.added > $1.added }
        persist()
        lastMessage = entries.isEmpty ? "库里还没有壁纸，去发现页下载一个吧" : "已同步 \(entries.count) 个本地壁纸"
    }

    func setWallpaper(for entry: LibraryEntry) {
        guard let image = Self.coverImage(in: entry.url, kind: entry.kind) else {
            lastMessage = "这个壁纸没有可直接设为桌面的静态画面"
            return
        }
        do {
            try NSWorkspace.shared.setDesktopImageURL(image, for: NSScreen.main ?? NSScreen.screens[0], options: [:])
            lastMessage = "已设为桌面背景"
        } catch {
            lastMessage = "设置桌面失败：\(error.localizedDescription)"
        }
    }

    static func coverImage(in url: URL, kind: ContentKind) -> URL? {
        let names = (try? FileManager.default.contentsOfDirectory(atPath: url.path)) ?? []
        let preferred = ["preview.jpg", "preview.png", "preview.gif", "cover.jpg"]
        if let hit = preferred.first(where: { names.contains($0) }) {
            return url.appendingPathComponent(hit)
        }
        if let image = names.first(where: { ["jpg", "jpeg", "png", "heic"].contains(($0 as NSString).pathExtension.lowercased()) }) {
            return url.appendingPathComponent(image)
        }
        return nil
    }

    static func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) else { return 0 }
        var total: Int64 = 0
        for case let file as URL in enumerator {
            total += Int64((try? file.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        }
        return total
    }
}
