import Foundation

/// 凭据存储。
///
/// 为什么不用钥匙串：App 目前是 ad-hoc 签名，每次重新编译签名哈希都会变。
/// 钥匙串会把条目绑定到"创建它的那个二进制身份"上，于是新版本读自己上次写的
/// 密码时会被判定为陌生 App —— 轻则弹授权框，重则直接读不到，表现为"密码老是丢"。
///
/// 代价：密码以 0600 权限明文存放在 `~/Library/Application Support/WallWright/credentials.json`。
/// 这对本地个人工具可以接受，但不适合分发给别人。等有了 Developer ID 证书、
/// 签名身份固定下来之后，应该改回 Keychain（`kSecClassGenericPassword`）。
enum Credentials {
    private static let file: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("WallWright/credentials.json", isDirectory: false)
    }()

    private static func loadAll() -> [String: String] {
        guard let data = try? Data(contentsOf: file),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else { return [:] }
        return map
    }

    static func get(_ key: String) -> String? {
        loadAll()[key]
    }

    static func set(_ value: String, for key: String) {
        var map = loadAll()
        if value.isEmpty {
            map.removeValue(forKey: key)
        } else {
            map[key] = value
        }
        guard let data = try? JSONEncoder().encode(map) else { return }
        let fm = FileManager.default
        try? fm.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: file, options: .atomic)
        try? fm.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
    }

    static func remove(_ key: String) {
        set("", for: key)
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
        didSet { Credentials.set(apiKey, for: "steamAPIKey") }
    }
    @Published var steamUser: String {
        didSet {
            if rememberAccount {
                defaults.set(steamUser, forKey: "steamUser")
            } else {
                defaults.removeObject(forKey: "steamUser")
            }
        }
    }
    @Published var autoShowHUD: Bool {
        didSet { defaults.set(autoShowHUD, forKey: "autoShowHUD") }
    }
    @Published var rememberAccount: Bool {
        didSet {
            defaults.set(rememberAccount, forKey: "rememberAccount")
            if rememberAccount {
                defaults.set(steamUser, forKey: "steamUser")
            } else {
                defaults.removeObject(forKey: "steamUser")
            }
        }
    }
    @Published var rememberPassword: Bool {
        didSet {
            defaults.set(rememberPassword, forKey: "rememberPassword")
            if rememberPassword, let memoryPassword {
                Credentials.set(memoryPassword, for: "steamPassword")
            } else if !rememberPassword {
                Credentials.set("", for: "steamPassword")
            }
        }
    }
    @Published var steamGuardCode: String = ""

    /// 不勾"记住密码"时，密码只留在内存里——本次运行能用来下载，退出即消失
    private var memoryPassword: String?
    /// 同理，账号也可能不进 UserDefaults，但本次运行内下载仍要用
    private var memoryUser: String?

    var steamPassword: String {
        get { memoryPassword ?? Credentials.get("steamPassword") ?? "" }
        set {
            memoryPassword = newValue
            if rememberPassword {
                Credentials.set(newValue, for: "steamPassword")
            } else {
                Credentials.set("", for: "steamPassword")
            }
        }
    }

    /// 当前会话实际使用的账号（优先内存，其次持久化的）
    var loginUser: String { memoryUser ?? steamUser }

    var hasCredentials: Bool {
        !loginUser.isEmpty && !steamPassword.isEmpty
    }

    /// 登录成功后按用户的勾选决定落盘哪些
    func applyLogin(user: String, password: String) {
        memoryUser = user
        steamUser = rememberAccount ? user : ""
        steamPassword = password
    }

    private init() {
        channel = DownloadChannel(rawValue: defaults.string(forKey: "channel") ?? "") ?? .steamcmd
        apiKey = Credentials.get("steamAPIKey") ?? ""
        rememberAccount = defaults.object(forKey: "rememberAccount") as? Bool ?? true
        rememberPassword = defaults.object(forKey: "rememberPassword") as? Bool ?? true
        // 两个开关要先就位，steamUser 的 didSet 才能正确决定存不存
        steamUser = defaults.string(forKey: "steamUser") ?? ""
        autoShowHUD = defaults.object(forKey: "autoShowHUD") as? Bool ?? true
    }
}
