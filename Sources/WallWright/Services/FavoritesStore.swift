import Foundation

struct FavoriteCollection: Identifiable, Codable, Hashable {
    var id: String
    var name: String
    var createdAt: Date
}

struct FavoriteEntry: Identifiable, Codable, Hashable {
    var item: WorkshopItem
    var collectionID: String
    var addedAt: Date

    /// 同一张壁纸只归一个收藏夹，所以直接用作品 ID 当标识
    var id: String { item.id }
}

/// 本地收藏。全部数据存在 `~/Library/Application Support/WallWright/Favorites.json`，
/// 不上传任何服务器。
@MainActor
final class FavoritesStore: ObservableObject {
    static let shared = FavoritesStore()
    static let defaultName = "我的收藏"

    @Published private(set) var collections: [FavoriteCollection] = []
    @Published private(set) var entries: [FavoriteEntry] = []
    @Published var message: String?

    private struct Payload: Codable {
        var collections: [FavoriteCollection]
        var entries: [FavoriteEntry]
    }

    private let fileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("WallWright/Favorites.json", isDirectory: false)
    }()

    private init() {
        load()
    }

    // MARK: - 查询

    func isFavorite(_ id: String) -> Bool {
        entries.contains { $0.id == id }
    }

    func collection(of itemID: String) -> FavoriteCollection? {
        guard let entry = entries.first(where: { $0.id == itemID }) else { return nil }
        return collections.first { $0.id == entry.collectionID }
    }

    /// `nil` 表示"全部"
    func items(in collectionID: String?) -> [FavoriteEntry] {
        guard let collectionID else { return entries.sorted { $0.addedAt > $1.addedAt } }
        return entries.filter { $0.collectionID == collectionID }.sorted { $0.addedAt > $1.addedAt }
    }

    func count(in collectionID: String?) -> Int {
        guard let collectionID else { return entries.count }
        return entries.filter { $0.collectionID == collectionID }.count
    }

    // MARK: - 变更

    /// 点收藏时的入口：没收藏夹就自动建一个「我的收藏」。
    /// 返回 true 表示现在已收藏。
    @discardableResult
    func toggle(_ item: WorkshopItem) -> Bool {
        if isFavorite(item.id) {
            remove(item.id)
            return false
        }
        let target = quickTarget()
        entries.append(FavoriteEntry(item: item, collectionID: target.id, addedAt: Date()))
        save()
        message = "已收藏到「\(target.name)」"
        return true
    }

    func add(_ item: WorkshopItem, to collectionID: String) {
        guard collections.contains(where: { $0.id == collectionID }) else { return }
        entries.removeAll { $0.id == item.id }
        entries.append(FavoriteEntry(item: item, collectionID: collectionID, addedAt: Date()))
        save()
    }

    func remove(_ id: String) {
        entries.removeAll { $0.id == id }
        save()
    }

    func move(_ itemID: String, to collectionID: String) {
        guard let index = entries.firstIndex(where: { $0.id == itemID }) else { return }
        entries[index].collectionID = collectionID
        save()
    }

    @discardableResult
    func createCollection(named raw: String) -> FavoriteCollection? {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            message = "收藏夹名字不能为空"
            return nil
        }
        guard !collections.contains(where: { $0.name == name }) else {
            message = "已经有同名收藏夹了"
            return nil
        }
        let collection = FavoriteCollection(id: UUID().uuidString, name: name, createdAt: Date())
        collections.append(collection)
        save()
        return collection
    }

    func rename(_ id: String, to raw: String) {
        let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !collections.contains(where: { $0.name == name && $0.id != id }),
              let index = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[index].name = name
        save()
    }

    /// 删除收藏夹。`moveItems` 为 true 时把里面的壁纸挪到默认收藏夹，否则一起移除。
    func deleteCollection(_ id: String, moveItems: Bool) {
        guard collections.contains(where: { $0.id == id }) else { return }
        collections.removeAll { $0.id == id }

        if moveItems {
            let target = quickTarget()
            for index in entries.indices where entries[index].collectionID == id {
                entries[index].collectionID = target.id
            }
        } else {
            entries.removeAll { $0.collectionID == id }
        }
        save()
    }

    // MARK: - 导入

    /// 一次性把本机 Steam 客户端的工坊订阅读进来（读不到就返回空）
    func importLocalSubscriptions() async {
        let ids = Self.localSubscribedIDs()
        guard !ids.isEmpty else {
            message = "本机没有读到 Wallpaper Engine 的工坊订阅记录"
            return
        }
        do {
            let fetched = try await SteamAPI.shared.details(ids: ids)
            let target = quickTarget()
            var added = 0
            for item in fetched where !isFavorite(item.id) {
                entries.append(FavoriteEntry(item: item, collectionID: target.id, addedAt: Date()))
                added += 1
            }
            save()
            message = added > 0 ? "已导入 \(added) 张到「\(target.name)」" : "这些壁纸已经在收藏里了"
        } catch {
            message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    var hasLocalSubscriptions: Bool { !Self.localSubscribedIDs().isEmpty }

    // MARK: - 内部

    /// 快速收藏的落点：优先同名默认夹，其次第一个夹，都没有就建一个
    private func quickTarget() -> FavoriteCollection {
        if let existing = collections.first(where: { $0.name == Self.defaultName }) { return existing }
        if let first = collections.first { return first }
        let collection = FavoriteCollection(id: UUID().uuidString, name: Self.defaultName, createdAt: Date())
        collections.append(collection)
        return collection
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let payload = try? JSONDecoder().decode(Payload.self, from: data) else { return }
        collections = payload.collections
        entries = payload.entries
    }

    private func save() {
        let fm = FileManager.default
        try? fm.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        guard let data = try? JSONEncoder().encode(Payload(collections: collections, entries: entries)) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    // MARK: - Steam 本地记录（旧订阅页用过的解析逻辑）

    static func localSubscribedIDs() -> [String] {
        let url = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Steam/steamapps/workshop", isDirectory: true)
            .appendingPathComponent("appworkshop_\(SteamAPI.appID).acf")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        return parseSubscribedIDs(text)
    }

    static func parseSubscribedIDs(_ text: String) -> [String] {
        guard let anchor = text.range(of: "\"WorkshopItemsInstalled\"") else { return [] }
        let chars = Array(text[anchor.upperBound...])
        var depth = 0, started = false
        var ids: [String] = []
        var index = 0
        while index < chars.count {
            let char = chars[index]
            if char == "{" {
                depth += 1
                started = true
            } else if char == "}" {
                depth -= 1
                if started && depth == 0 { break }
            } else if char == "\"" {
                var cursor = index + 1
                var token = ""
                while cursor < chars.count, chars[cursor] != "\"" {
                    token.append(chars[cursor])
                    cursor += 1
                }
                if depth == 1, !token.isEmpty, token.allSatisfy(\.isNumber) { ids.append(token) }
                index = cursor
            }
            index += 1
        }
        return ids
    }
}
