import Foundation
import Security

enum Keychain {
    private static let service = "com.wallwright.credentials"

    static func set(_ value: String, for key: String) {
        let data = Data(value.utf8)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    static func get(_ key: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func remove(_ key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        SecItemDelete(query as CFDictionary)
    }
}

enum DownloadChannel: String, CaseIterable, Identifiable {
    case steamcmd, steamClient
    var id: String { rawValue }

    var label: String {
        switch self {
        case .steamcmd: return "SteamCMD 直连"
        case .steamClient: return "Steam 客户端"
        }
    }

    var detail: String {
        switch self {
        case .steamcmd: return "用你的 Steam 账号登录，直接下载工坊原始文件，带实时进度"
        case .steamClient: return "用 steam:// 唤起 Steam 客户端订阅下载，App 负责浏览与本地库管理"
        }
    }
}

@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    @Published var channel: DownloadChannel {
        didSet { defaults.set(channel.rawValue, forKey: "channel") }
    }
    @Published var apiKey: String {
        didSet { Keychain.set(apiKey, for: "steamAPIKey") }
    }
    @Published var steamUser: String {
        didSet { defaults.set(steamUser, forKey: "steamUser") }
    }
    @Published var autoShowHUD: Bool {
        didSet { defaults.set(autoShowHUD, forKey: "autoShowHUD") }
    }
    @Published var steamGuardCode: String = ""

    var steamPassword: String {
        get { Keychain.get("steamPassword") ?? "" }
        set { Keychain.set(newValue, for: "steamPassword") }
    }

    var hasCredentials: Bool {
        !steamUser.isEmpty && !steamPassword.isEmpty
    }

    private init() {
        channel = DownloadChannel(rawValue: defaults.string(forKey: "channel") ?? "") ?? .steamcmd
        apiKey = Keychain.get("steamAPIKey") ?? ""
        steamUser = defaults.string(forKey: "steamUser") ?? ""
        autoShowHUD = defaults.object(forKey: "autoShowHUD") as? Bool ?? true
    }
}
