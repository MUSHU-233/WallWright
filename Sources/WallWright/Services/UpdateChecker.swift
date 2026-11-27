import Foundation

/// 检查 GitHub Releases 上有没有新版本。
/// 没有配置 `AppInfo.repoSlug` 时直接返回 `.notConfigured`，不会偷偷发请求。
@MainActor
final class UpdateChecker: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(version: String, url: URL?)
        case notConfigured
        case failed(String)
    }

    @Published private(set) var state: State = .idle

    func check() async {
        guard !AppInfo.repoSlug.isEmpty else {
            state = .notConfigured
            return
        }
        guard let url = URL(string: "https://api.github.com/repos/\(AppInfo.repoSlug)/releases/latest") else {
            state = .failed("仓库地址格式不对")
            return
        }

        state = .checking

        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("WallWright/\(AppInfo.version)", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                state = .failed("响应异常")
                return
            }
            switch http.statusCode {
            case 200:
                break
            case 404:
                state = .failed("仓库不存在，或者还没有发布过 Release")
                return
            case 403:
                state = .failed("GitHub 拒绝了请求（可能是网络或频率限制）")
                return
            default:
                state = .failed("GitHub 返回 \(http.statusCode)")
                return
            }

            struct Release: Decodable {
                let tag_name: String
                let html_url: String
            }
            let release = try JSONDecoder().decode(Release.self, from: data)
            if Self.isNewer(release.tag_name, than: AppInfo.version) {
                state = .available(version: release.tag_name, url: URL(string: release.html_url))
            } else {
                state = .upToDate
            }
        } catch {
            state = .failed("检查失败：\(error.localizedDescription)")
        }
    }

    /// 逐段比较数字，`v1.2.10` > `v1.2.9`（字符串比较会判错，所以不能直接比字符串）
    static func isNewer(_ latest: String, than current: String) -> Bool {
        func parts(_ raw: String) -> [Int] {
            raw.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
                .split(separator: ".")
                .map { Int($0.prefix { $0.isNumber }) ?? 0 }
        }
        let lhs = parts(latest)
        let rhs = parts(current)
        for index in 0..<max(lhs.count, rhs.count) {
            let a = index < lhs.count ? lhs[index] : 0
            let b = index < rhs.count ? rhs[index] : 0
            if a != b { return a > b }
        }
        return false
    }
}
