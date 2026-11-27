import Foundation

enum LoginError: LocalizedError {
    case notInstalled
    case invalidPassword
    case guardFailed
    case rateLimited
    case offline
    case cancelled
    case failed(String)

    var errorDescription: String? {
        switch self {
        case .notInstalled: return "请先在设置里安装 SteamCMD 引擎"
        case .invalidPassword: return "账号或密码不正确"
        case .guardFailed: return "Steam Guard 验证码不正确或已超时"
        case .rateLimited: return "登录尝试过于频繁，请等几分钟再试"
        case .offline: return "连不上 Steam 服务器，请检查网络或代理"
        case .cancelled: return "已取消登录"
        case .failed(let m): return m
        }
    }
}

/// 登录态。凭据只写本机 `credentials.json`（权限 600），全程只与 Steam 服务器交互，
/// 不经过任何第三方服务。
@MainActor
final class AuthStore: ObservableObject {
    static let shared = AuthStore()

    struct GuardPrompt: Identifiable {
        let id = UUID()
        let respond: (String?) -> Void
    }

    @Published private(set) var signingIn = false
    @Published private(set) var steamID64: String?
    @Published private(set) var errorMessage: String?
    @Published var guardPrompt: GuardPrompt?

    var isSignedIn: Bool { steamID64 != nil }
    var username: String { Credentials.get("steamUser") ?? "" }
    var profileURL: URL? {
        steamID64.flatMap { URL(string: "https://steamcommunity.com/profiles/\($0)") }
    }

    private init() {
        if Credentials.get("signedIn") == "1", let id = Credentials.get("steamID64") {
            steamID64 = id
        }
    }

    private var session: SteamLoginSession?

    func cancelSignIn() {
        session?.cancel()
    }

    func clearError() {
        if errorMessage != nil { errorMessage = nil }
    }

    func signIn(user rawUser: String, password: String) async {
        let user = rawUser.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !user.isEmpty, !password.isEmpty else {
            errorMessage = "请填写 Steam 账号和密码"
            return
        }
        guard SteamCMDService.shared.installed else {
            errorMessage = LoginError.notInstalled.errorDescription
            return
        }

        signingIn = true
        errorMessage = nil
        let loginSession = SteamLoginSession()
        session = loginSession
        defer {
            signingIn = false
            session = nil
        }

        do {
            let id = try await loginSession.run(
                user: user,
                password: password,
                guardCodeProvider: { [weak self] in
                    guard let self else { return nil }
                    return self.blockingGuardCode()
                }
            )
            Preferences.shared.applyLogin(user: user, password: password)
            Credentials.set(id, for: "steamID64")
            Credentials.set("1", for: "signedIn")
            steamID64 = id
        } catch {
            Credentials.set("", for: "signedIn")
            Credentials.set("", for: "steamID64")
            steamID64 = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func signOut() {
        Credentials.set("", for: "signedIn")
        Credentials.set("", for: "steamID64")
        steamID64 = nil
        errorMessage = nil
    }

    func submitGuardCode(_ code: String) {
        guardPrompt?.respond(code.trimmingCharacters(in: .whitespacesAndNewlines))
        guardPrompt = nil
    }

    func dismissGuard() {
        guardPrompt?.respond(nil)
        guardPrompt = nil
    }

    /// SteamCMD 的解析线程同步等用户输入，UI 更新切回主线程
    nonisolated private func blockingGuardCode() -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        let box = Box<String?>(nil)
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                self.guardPrompt = GuardPrompt { code in
                    box.value = code
                    semaphore.signal()
                }
            }
        }
        _ = semaphore.wait(timeout: .now() + 240)
        return box.value
    }
}

/// 只做一件事：用 `+login` 验证账号，并从输出里取出 SteamID。
/// 不能复用下载会话——下载会话的完成条件是"拿到文件路径"。
final class SteamLoginSession {
    private let process = Process()
    private let stdinPipe = Pipe()
    private let outputPipe = Pipe()
    private let queue = DispatchQueue(label: "wallwright.steamlogin")
    private let lock = NSLock()

    private var buffer = ""
    private var sentPassword = false
    private var sentCode = false
    private var finished = false
    private var steamID: String?
    private var sawOK = false
    private var recent: [String] = []
    private var watchdog: DispatchSourceTimer?

    private var continuation: CheckedContinuation<String, Error>?
    private var password = ""
    private var guardCodeProvider: (() -> String?)?

    func run(
        user: String,
        password: String,
        guardCodeProvider: @escaping () -> String?
    ) async throws -> String {
        self.password = password
        self.guardCodeProvider = guardCodeProvider

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
            process.arguments = [
                "-q", "/dev/null", SteamCMDService.executable.path,
                "+@ShutdownOnFailedCommand", "1",
                "+@NoPromptForPassword", "0",
                "+login", user,
                "+quit"
            ]
            process.standardInput = stdinPipe
            process.standardOutput = outputPipe
            process.standardError = outputPipe

            outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
                self?.consume(text)
            }

            process.terminationHandler = { [weak self] proc in
                self?.finish(status: proc.terminationStatus)
            }

            do {
                try process.run()
                armWatchdog()
            } catch {
                self.fail(.failed("无法启动 SteamCMD：\(error.localizedDescription)"))
            }
        }
    }

    func cancel() {
        fail(.cancelled)
    }

    private func armWatchdog() {
        watchdog?.cancel()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 120)
        timer.setEventHandler { [weak self] in
            guard let self, !self.finished else { return }
            self.fail(.offline)
        }
        timer.resume()
        watchdog = timer
    }

    private func consume(_ chunk: String) {
        queue.async { [weak self] in
            guard let self else { return }
            self.buffer += chunk.replacingOccurrences(of: "\r", with: "\n")
            while let range = self.buffer.range(of: "\n") {
                let line = String(self.buffer[self.buffer.startIndex..<range.lowerBound])
                self.buffer.removeSubrange(self.buffer.startIndex..<range.upperBound)
                self.handle(line: line)
            }
            self.handlePendingPrompt()
        }
    }

    /// `password: ` 这类提示不带换行，必须单独检查缓冲区尾部
    private func handlePendingPrompt() {
        switch SteamPrompt.detect(in: buffer) {
        case .password where !sentPassword:
            sentPassword = true
            send(password)
        case .guardCode where !sentCode:
            sentCode = true
            send(guardCodeProvider?() ?? "")
        default:
            break
        }
    }

    private func handle(line raw: String) {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return }
        armWatchdog()
        if recent.count >= 12 { recent.removeFirst(4) }
        recent.append(line)
        let lower = line.lowercased()

        // 登录成功后输出形如：Logging in user 'x' [U:1:123456] to Steam Public...OK
        if let range = line.range(of: #"\[U:1:(\d+)\]"#, options: .regularExpression) {
            let digits = String(line[range]).filter(\.isNumber)
            if let account = UInt64(digits), account > 0 {
                steamID = String(76561197960265728 + account)
            }
        }
        if lower.contains("to steam public...ok") || lower.contains("logged in ok") {
            sawOK = true
        }

        if !sentPassword, lower.hasPrefix("password") {
            sentPassword = true
            send(password)
            return
        }
        if !sentCode, lower.contains("steam guard") || lower.contains("two-factor") || lower.contains("two factor") {
            sentCode = true
            send(guardCodeProvider?() ?? "")
            return
        }

        if lower.contains("invalid password") {
            fail(.invalidPassword)
            return
        }
        if lower.contains("rate limit") {
            fail(.rateLimited)
            return
        }
        if lower.contains("invalid login auth code") || lower.contains("two-factor code incorrect")
            || lower.contains("steam guard code is incorrect") {
            fail(.guardFailed)
            return
        }
        if lower.contains("account logon denied") || lower.contains("logged in elsewhere") {
            fail(.failed("该账号已在其他地方登录，请先在别处退出"))
            return
        }
    }

    private func send(_ value: String) {
        guard let data = (value + "\n").data(using: .utf8) else { return }
        try? stdinPipe.fileHandleForWriting.write(contentsOf: data)
    }

    private func finish(status: Int32) {
        outputPipe.fileHandleForReading.readabilityHandler = nil
        lock.lock(); let done = finished; lock.unlock()
        guard !done else { return }

        if let steamID, sawOK {
            succeed(steamID)
        } else if sawOK {
            fail(.failed("登录成功但没能解析出 SteamID，请重试"))
        } else {
            let last = recent.last { !$0.isEmpty } ?? ""
            fail(.failed("登录没有完成（SteamCMD 退出码 \(status)）" + (last.isEmpty ? "" : "\n最后一行：\(last)")))
        }
    }

    private func succeed(_ id: String) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        lock.unlock()
        watchdog?.cancel()
        continuation?.resume(returning: id)
        continuation = nil
    }

    private func fail(_ error: LoginError) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        lock.unlock()
        watchdog?.cancel()
        continuation?.resume(throwing: error)
        continuation = nil
        if process.isRunning { process.terminate() }
    }
}
