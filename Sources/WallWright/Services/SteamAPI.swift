import Foundation

enum SteamAPIError: LocalizedError {
    case missingKey
    case http(Int)
    case api(String)
    case empty
    case offline

    var errorDescription: String? {
        switch self {
        case .missingKey: return "需要 Steam Web API Key 才能搜索创意工坊"
        case .http(let code): return "网络请求失败（HTTP \(code)）"
        case .api(let message): return message
        case .empty: return "没有找到结果"
        case .offline: return "连不上 Steam 服务器，请检查网络或代理后重试"
        }
    }
}

enum SortMode: String, CaseIterable, Identifiable {
    case trend, newest, popular, topRated
    var id: String { rawValue }

    var label: String {
        switch self {
        case .trend: return "热门趋势"
        case .newest: return "最新"
        case .popular: return "最多订阅"
        case .topRated: return "最高评分"
        }
    }

    var queryType: Int {
        switch self {
        case .trend: return 3
        case .newest: return 1
        case .popular: return 0
        case .topRated: return 8
        }
    }
}

struct SearchPage: Sendable {
    var items: [WorkshopItem]
    var total: Int
    var nextCursor: String?
}

actor SteamAPI {
    static let shared = SteamAPI()
    static let appID = 431960

    private let base = URL(string: "https://api.steampowered.com")!
    private let session: URLSession

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 40
        config.waitsForConnectivity = false
        config.httpAdditionalHeaders = ["User-Agent": "WallWright/1.0 (macOS)"]
        session = URLSession(configuration: config)
    }

    /// api.steampowered.com 在部分网络下会间歇性连不上（同一秒内可能 000/200 交替），
    /// 所以网络层错误一律重试，HTTP 错误直接抛出。
    private func send(_ request: URLRequest, attempts: Int = 4) async throws -> Data {
        var networkFailure = false
        for attempt in 0..<attempts {
            do {
                let (data, response) = try await session.data(for: request)
                if let http = response as? HTTPURLResponse, http.statusCode != 200 {
                    throw SteamAPIError.http(http.statusCode)
                }
                return data
            } catch let error as SteamAPIError {
                throw error
            } catch {
                networkFailure = true
                if attempt < attempts - 1 {
                    try? await Task.sleep(for: .milliseconds(500 * (attempt + 1)))
                }
            }
        }
        throw networkFailure ? SteamAPIError.offline : SteamAPIError.api("请求失败")
    }

    func details(ids: [String]) async throws -> [WorkshopItem] {
        let unique = Array(NSOrderedSet(array: ids)) as? [String] ?? ids
        guard !unique.isEmpty else { return [] }
        var collected: [WorkshopItem] = []

        for chunk in stride(from: 0, to: unique.count, by: 50).map({ Array(unique[$0..<min($0 + 50, unique.count)]) }) {
            var body = "itemcount=\(chunk.count)"
            for (index, id) in chunk.enumerated() {
                body += "&publishedfileids[\(index)]=\(id)"
            }
            var request = URLRequest(url: base.appendingPathComponent("ISteamRemoteStorage/GetPublishedFileDetails/v1/"))
            request.httpMethod = "POST"
            request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
            request.httpBody = body.data(using: .utf8)

            let data = try await send(request)
            guard
                let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                let payload = root["response"] as? [String: Any],
                let list = payload["publishedfiledetails"] as? [[String: Any]]
            else { throw SteamAPIError.api("元数据解析失败") }

            for raw in list {
                if let item = Self.parse(raw) { collected.append(item) }
            }
        }
        return collected
    }

    func search(key: String, text: String, sort: SortMode, cursor: String?, tags: [String] = []) async throws -> SearchPage {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw SteamAPIError.missingKey }

        var components = URLComponents(url: base.appendingPathComponent("IPublishedFileService/QueryFiles/v1/"), resolvingAgainstBaseURL: false)!
        var query: [URLQueryItem] = [
            .init(name: "key", value: trimmed),
            .init(name: "appid", value: String(Self.appID)),
            .init(name: "numperpage", value: "30"),
            .init(name: "query_type", value: String(sort.queryType)),
            .init(name: "return_short_description", value: "true"),
            .init(name: "return_vote_data", value: "true"),
            .init(name: "return_tags", value: "true"),
            .init(name: "return_previews", value: "true"),
            .init(name: "strip_description_bbcode", value: "true")
        ]
        if let cursor { query.append(.init(name: "cursor", value: cursor)) }
        if !text.isEmpty { query.append(.init(name: "search_text", value: text)) }
        for (index, tag) in tags.enumerated() {
            query.append(.init(name: "requiredtags[\(index)]", value: tag))
        }
        components.queryItems = query

        let data = try await send(URLRequest(url: components.url!))
        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let payload = root["response"] as? [String: Any]
        else { throw SteamAPIError.api("搜索失败，请检查 API Key 是否有效") }

        let list = payload["publishedfiledetails"] as? [[String: Any]] ?? []
        let items = list.compactMap { Self.parse($0) }
        let total = (payload["total"] as? NSNumber)?.intValue ?? items.count
        var next: String?
        if let raw = payload["next_cursor"] as? String, raw != cursor, !raw.isEmpty { next = raw }
        return SearchPage(items: items, total: total, nextCursor: next)
    }

    func trending(key: String) async throws -> [WorkshopItem] {
        try await search(key: key, text: "", sort: .trend, cursor: nil).items
    }

    private static func parse(_ raw: [String: Any]) -> WorkshopItem? {
        guard let id = raw["publishedfileid"] as? String, !id.isEmpty else { return nil }
        if let result = raw["result"] as? Int, result != 1 { return nil }

        let tags = (raw["tags"] as? [[String: Any]])?.compactMap { $0["tag"] as? String } ?? []
        let preview = (raw["preview_url"] as? String).flatMap(URL.init(string:))

        return WorkshopItem(
            id: id,
            title: (raw["title"] as? String)?.nilIfBlank ?? "未命名壁纸",
            summary: (raw["short_description"] as? String) ?? (raw["file_description"] as? String) ?? "",
            previewURL: preview,
            fileSize: (raw["file_size"] as? NSNumber)?.int64Value ?? 0,
            subscriptions: (raw["subscriptions"] as? NSNumber)?.intValue
                ?? (raw["lifetime_subscriptions"] as? NSNumber)?.intValue ?? 0,
            views: (raw["views"] as? NSNumber)?.intValue ?? 0,
            tags: tags,
            created: (raw["time_created"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) },
            updated: (raw["time_updated"] as? NSNumber).map { Date(timeIntervalSince1970: $0.doubleValue) },
            kind: ContentKind.from(tags: tags)
        )
    }
}

extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
