import Foundation

enum SteamCMDError: LocalizedError {
    case notInstalled
    case installFailed(String)
    case launchFailed(String)
    case loginFailed(String)
    case downloadFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .notInstalled: return "SteamCMD 尚未安装"
        case .installFailed(let m): return "SteamCMD 安装失败：\(m)"
        case .launchFailed(let m): return "无法启动 SteamCMD：\(m)"
        case .loginFailed(let m): return "Steam 登录失败：\(m)"
        case .downloadFailed(let m): return "下载失败：\(m)"
        case .cancelled: return "已取消"
        }
    }
}

@MainActor
final class SteamCMDService: ObservableObject {
    static let shared = SteamCMDService()

    @Published private(set) var installed: Bool
    @Published private(set) var installing = false
    @Published private(set) var installProgress: Double = 0
    @Published private(set) var lastError: String?

    private var runningSession: SteamCMDSession?

    nonisolated static let root: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("WallWright/steamcmd", isDirectory: true)
    }()

    nonisolated static var executable: URL { root.appendingPathComponent("steamcmd.sh") }

    nonisolated static var workshopRoot: URL {
        root.appendingPathComponent("steamapps/workshop/content/\(SteamAPI.appID)", isDirectory: true)
    }

    init() {
        installed = FileManager.default.isExecutableFile(atPath: Self.executable.path)
    }

    func refresh() {
        installed = FileManager.default.isExecutableFile(atPath: Self.executable.path)
    }

    func install() async {
        installing = true
        installProgress = 0
        lastError = nil
        defer { installing = false }

        do {
            try FileManager.default.createDirectory(at: Self.root, withIntermediateDirectories: true)
            let source = URL(string: "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_osx.tar.gz")!
            let (temp, response) = try await URLSession.shared.download(from: source)
            guard (response as? HTTPURLResponse)?.statusCode == 200 else {
                throw SteamCMDError.installFailed("下载安装包失败")
            }
            installProgress = 0.6
            let archive = Self.root.appendingPathComponent("steamcmd_osx.tar.gz")
            try? FileManager.default.removeItem(at: archive)
            try FileManager.default.moveItem(at: temp, to: archive)

            let tar = Process()
            tar.executableURL = URL(fileURLWithPath: "/usr/bin/tar")
            tar.arguments = ["-xzf", archive.path, "-C", Self.root.path]
            try tar.run()
            tar.waitUntilExit()
            try? FileManager.default.removeItem(at: archive)
            guard tar.terminationStatus == 0 else {
                throw SteamCMDError.installFailed("解压失败（tar \(tar.terminationStatus)）")
            }

            try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: Self.executable.path)
            installProgress = 1
            refresh()
        } catch {
            lastError = error.localizedDescription
            refresh()
        }
    }

    func cancelCurrent() {
        runningSession?.cancel()
    }

    func download(
        item: WorkshopItem,
        user: String,
        password: String,
        guardCodeProvider: @escaping () -> String?,
        onProgress: @escaping (Double, Int64, Int64) -> Void,
        onLine: @escaping (String) -> Void
    ) async throws -> URL {
        guard installed else { throw SteamCMDError.notInstalled }

        let session = SteamCMDSession()
        runningSession = session
        defer { runningSession = nil }

        let contentDir = try await session.run(
            user: user,
            password: password,
            itemID: item.id,
            guardCodeProvider: guardCodeProvider,
            onProgress: onProgress,
            onLine: onLine
        )

        let fm = FileManager.default
        let destination = LibraryStore.shared.directory.appendingPathComponent(item.id, isDirectory: true)
        try? fm.removeItem(at: destination)
        try fm.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            try fm.moveItem(at: contentDir, to: destination)
        } catch {
            try fm.copyItem(at: contentDir, to: destination)
            try? fm.removeItem(at: contentDir)
        }
        return destination
    }
}

final class SteamCMDSession {
    private let process = Process()
    private let stdinPipe = Pipe()
    private let outputPipe = Pipe()
    private let queue = DispatchQueue(label: "wallwright.steamcmd")
    private let lock = NSLock()

    private var buffer = ""
    private var sentPassword = false
    private var sentCode = false
    private var finished = false
    private var resolvedPath: URL?
    private var lastProgress: Double = 0
    private var silenceTimer: DispatchSourceTimer?

    private var continuation: CheckedContinuation<URL, Error>?
    private var password = ""
    private var guardCodeProvider: (() -> String?)?
    private var onProgress: ((Double, Int64, Int64) -> Void)?
    private var onLine: ((String) -> Void)?

    func run(
        user: String,
        password: String,
        itemID: String,
        guardCodeProvider: @escaping () -> String?,
        onProgress: @escaping (Double, Int64, Int64) -> Void,
        onLine: @escaping (String) -> Void
    ) async throws -> URL {
        self.password = password
        self.guardCodeProvider = guardCodeProvider
        self.onProgress = onProgress
        self.onLine = onLine

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation

            let script = SteamCMDService.executable.path
            process.executableURL = URL(fileURLWithPath: "/usr/bin/script")
            process.arguments = [
                "-q", "/dev/null", script,
                "+@ShutdownOnFailedCommand", "1",
                "+@NoPromptForPassword", "0",
                "+login", user,
                "+workshop_download_item", String(SteamAPI.appID), itemID,
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
                self?.finishProcess(status: proc.terminationStatus)
            }

            do {
                try process.run()
                startSilenceWatchdog()
            } catch {
                self.fail(.launchFailed(error.localizedDescription))
            }
        }
    }

    func cancel() {
        fail(.cancelled)
        if process.isRunning { process.terminate() }
    }

    private func startSilenceWatchdog() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 120)
        timer.setEventHandler { [weak self] in
            guard let self, !self.finished else { return }
            self.append("—— 超过 120 秒没有任何输出，判定连接失败")
            self.fail(.loginFailed("超时，可能是网络无法连接 Steam 服务器"))
        }
        timer.resume()
        silenceTimer = timer
    }

    private func resetSilence() {
        silenceTimer?.cancel()
        silenceTimer = nil
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 120)
        timer.setEventHandler { [weak self] in
            guard let self, !self.finished else { return }
            self.fail(.loginFailed("超时，可能是网络无法连接 Steam 服务器"))
        }
        timer.resume()
        silenceTimer = timer
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
        }
    }

    private func append(_ line: String) {
        DispatchQueue.main.async { self.onLine?(line) }
    }

    private func handle(line raw: String) {
        let line = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !line.isEmpty else { return }
        resetSilence()
        append(line)
        let lower = line.lowercased()

        if !sentPassword, lower.hasPrefix("password") || lower.contains("password:") {
            sentPassword = true
            send(password)
            return
        }

        if !sentCode, lower.contains("steam guard") || lower.contains("two-factor") || lower.contains("two factor") {
            sentCode = true
            let code = guardCodeProvider?() ?? ""
            send(code)
            return
        }

        if let numbers = Self.parseProgress(line) {
            let (done, total) = numbers
            let fraction = total > 0 ? min(1, Double(done) / Double(total)) : 0
            if fraction >= lastProgress - 0.0001 || total > 0 {
                lastProgress = fraction
                DispatchQueue.main.async { self.onProgress?(fraction, done, total) }
            }
            return
        }

        if lower.contains("success. downloaded item") || lower.contains("success. downloaded") {
            if let path = Self.parseQuotedPath(line) {
                resolvedPath = URL(fileURLWithPath: path)
            }
            return
        }

        if lower.contains("invalid password") {
            fail(.loginFailed("账号或密码不正确"))
            return
        }
        if lower.contains("rate limit exceeded") {
            fail(.loginFailed("Steam 登录频率限制，请稍后再试"))
            return
        }
        if lower.contains("failed to download item") || lower.contains("failure") && lower.contains("download") {
            fail(.downloadFailed("Steam 拒绝下载。请确认该账号已拥有 Wallpaper Engine"))
            return
        }
        if lower.contains("account logon denied") || lower.contains("logged in elsewhere") {
            fail(.loginFailed("该账号已在其他地方登录"))
            return
        }
    }

    private func send(_ value: String) {
        let line = value + "\n"
        if let data = line.data(using: .utf8) {
            try? stdinPipe.fileHandleForWriting.write(contentsOf: data)
        }
    }

    private func finishProcess(status: Int32) {
        outputPipe.fileHandleForReading.readabilityHandler = nil
        if finished { return }
        if let path = resolvedPath, FileManager.default.fileExists(atPath: path.path) {
            succeed(path)
        } else if status == 0 {
            fail(.downloadFailed("SteamCMD 已退出但没有报告下载成功，请查看日志"))
        } else {
            fail(.downloadFailed("SteamCMD 退出码 \(status)，请查看日志"))
        }
    }

    private func succeed(_ url: URL) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        lock.unlock()
        silenceTimer?.cancel()
        append("✓ 已下载到 \(url.path)")
        DispatchQueue.main.async { self.onProgress?(1, 0, 0) }
        continuation?.resume(returning: url)
        continuation = nil
    }

    private func fail(_ error: SteamCMDError) {
        lock.lock()
        guard !finished else { lock.unlock(); return }
        finished = true
        lock.unlock()
        silenceTimer?.cancel()
        append("✗ \(error.localizedDescription)")
        continuation?.resume(throwing: error)
        continuation = nil
        if process.isRunning { process.terminate() }
    }

    private static func parseProgress(_ line: String) -> (Int64, Int64)? {
        guard line.contains("progress:"), let open = line.lastIndex(of: "("), let close = line.lastIndex(of: ")") else { return nil }
        let inner = line[line.index(after: open)..<close]
        let parts = inner.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let done = Int64(parts[0]), let total = Int64(parts[1]), total > 0 else { return nil }
        return (done, total)
    }

    private static func parseQuotedPath(_ line: String) -> String? {
        guard let first = line.firstIndex(of: "\""), let last = line.lastIndex(of: "\""), first < last else { return nil }
        return String(line[line.index(after: first)..<last])
    }
}
