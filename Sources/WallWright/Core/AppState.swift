import SwiftUI

enum Route: String, CaseIterable, Identifiable {
    case discover, favorites, library, downloads, settings
    var id: String { rawValue }

    var title: String {
        switch self {
        case .discover: return "发现"
        case .favorites: return "我的收藏"
        case .library: return "我的库"
        case .downloads: return "下载"
        case .settings: return "设置"
        }
    }

    var symbol: String {
        switch self {
        case .discover: return "sparkles.rectangle.stack"
        case .favorites: return "heart"
        case .library: return "square.stack.3d.up"
        case .downloads: return "arrow.down.circle"
        case .settings: return "gearshape"
        }
    }
}

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    @Published var route: Route = .discover
    @Published var query = ""
    @Published var sort: SortMode = .trend
    @Published var activeTags: [String] = []
    @Published var ageFilter: Set<AgeRating> = [.everyone]
    @Published var kindFilter: Set<ContentKind> = []
    @Published var results: [WorkshopItem] = []
    @Published var total = 0
    @Published var loading = false
    @Published var loadingMore = false
    @Published var errorMessage: String?
    @Published var detail: WorkshopItem?
    @Published var didInitialLoad = false
    @Published var toast: String?

    private var cursor: String?
    private var lastKey = ""

    static let filterTags = ["3840 x 2160", "2560 x 1440", "Anime", "Abstract", "Audio responsive"]

    /// 筛选后的结果。空选或全选都等于"不筛"，符合"勾了就显示、全勾就全显示"。
    var filtered: [WorkshopItem] {
        var items = results
        if !kindFilter.isEmpty, kindFilter.count < ContentKind.filterable.count {
            items = items.filter { kindFilter.contains($0.kind) }
        }
        if !ageFilter.isEmpty, ageFilter.count < AgeRating.selectable.count {
            items = items.filter { ageFilter.contains($0.ageRating) }
        }
        return items
    }

    var isFiltering: Bool {
        !kindFilter.isEmpty && kindFilter.count < ContentKind.filterable.count
            || !ageFilter.isEmpty && ageFilter.count < AgeRating.selectable.count
    }

    /// 每组只选中一个时，可以把标签交给服务端做精确筛选（AND 语义成立）；
    /// 多选时服务端表达不了"组内或"，退回本地筛选。
    private var serverTags: [String] {
        var tags = activeTags
        if ageFilter.count == 1, let tag = ageFilter.first?.tag { tags.append(tag) }
        if kindFilter.count == 1, let tag = kindFilter.first?.filterTag { tags.append(tag) }
        return tags
    }

    static let curatedIDs = [
        "3006959414", "2999533184", "3001191986", "3000034175",
        "2998257947", "2997695957", "3005447220", "3003969186",
        "3008926967", "3005031143", "3007983717", "1170756031"
    ]

    var hasAPIKey: Bool { !Preferences.shared.apiKey.isEmpty }

    func bootstrap() async {
        if !didInitialLoad {
            didInitialLoad = true
            if hasAPIKey {
                await load(reset: true)
            } else {
                await loadCurated()
            }
        }
        await LibraryStore.shared.scan()
    }

    /// 有 Key 走搜索，没 Key 回落到精选列表
    func reload() async {
        if hasAPIKey { await load(reset: true) } else { await loadCurated() }
    }

    func loadCurated() async {
        loading = true
        defer { loading = false }
        do {
            results = try await SteamAPI.shared.details(ids: Self.curatedIDs)
            total = results.count
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func submitSearch() async {
        detail = nil
        let input = query.trimmingCharacters(in: .whitespacesAndNewlines)

        if let id = Self.extractID(from: input) {
            loading = true
            defer { loading = false }
            do {
                let items = try await SteamAPI.shared.details(ids: [id])
                guard let item = items.first else {
                    errorMessage = "没有找到 ID 为 \(id) 的工坊物品"
                    return
                }
                results = [item]
                total = 1
                cursor = nil
                detail = item
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
            return
        }

        await load(reset: true)
    }

    func load(reset: Bool) async {
        let key = Preferences.shared.apiKey
        guard !key.isEmpty else {
            errorMessage = SteamAPIError.missingKey.localizedDescription
            return
        }
        if !reset && cursor == nil { return }

        if reset {
            loading = true
            cursor = nil
        } else {
            loadingMore = true
        }
        defer {
            loading = false
            loadingMore = false
        }

        do {
            let page = try await SteamAPI.shared.search(
                key: key,
                text: query.trimmingCharacters(in: .whitespacesAndNewlines),
                sort: sort,
                cursor: cursor,
                tags: serverTags
            )
            if reset {
                results = page.items
            } else {
                let existing = Set(results.map(\.id))
                results.append(contentsOf: page.items.filter { !existing.contains($0.id) })
            }
            total = page.total
            cursor = page.nextCursor
            errorMessage = nil
            lastKey = key
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleTag(_ tag: String) async {
        if activeTags.contains(tag) {
            activeTags.removeAll { $0 == tag }
        } else {
            activeTags.append(tag)
        }
        if hasAPIKey { await load(reset: true) }
    }

    func toggleAge(_ rating: AgeRating) async {
        if ageFilter.contains(rating) { ageFilter.remove(rating) } else { ageFilter.insert(rating) }
        if hasAPIKey { await load(reset: true) }
    }

    func toggleKind(_ kind: ContentKind) async {
        if kindFilter.contains(kind) { kindFilter.remove(kind) } else { kindFilter.insert(kind) }
        if hasAPIKey { await load(reset: true) }
    }

    func clearFilters() {
        ageFilter.removeAll()
        kindFilter.removeAll()
        activeTags.removeAll()
        Task { await reload() }
    }

    func showToast(_ text: String) {
        toast = text
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if toast == text { toast = nil }
        }
    }

    static func extractID(from text: String) -> String? {
        guard !text.isEmpty else { return nil }
        if text.allSatisfy(\.isNumber), text.count >= 6 { return text }
        if let range = text.range(of: "id=") {
            let digits = text[range.upperBound...].prefix { $0.isNumber }
            if digits.count >= 6 { return String(digits) }
        }
        let digits = text.filter(\.isNumber)
        if digits.count >= 8 && digits.count <= 12 && !text.contains(" ") { return digits }
        return nil
    }
}
