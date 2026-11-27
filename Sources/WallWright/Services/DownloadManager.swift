import Foundation

enum JobState: Equatable {
    case queued
    case running
    case awaitingCode
    case done
    case failed(String)
    case cancelled

    var isActive: Bool {
        switch self {
        case .queued, .running, .awaitingCode: return true
        default: return false
        }
    }

    var label: String {
        switch self {
        case .queued: return "排队中"
        case .running: return "下载中"
        case .awaitingCode: return "等待令牌"
        case .done: return "已完成"
        case .failed: return "失败"
        case .cancelled: return "已取消"
        }
    }
}

struct DownloadJob: Identifiable, Equatable {
    let id: String
    var item: WorkshopItem
    var state: JobState
    var progress: Double
    var received: Int64
    var total: Int64
    var speed: Double
    var added: Date
    var log: [String]

    var bytesText: String {
        guard total > 0 else { return "" }
        return "\(ByteCountFormatter.string(fromByteCount: received, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: total, countStyle: .file))"
    }

    var speedText: String {
        guard speed > 0 else { return "" }
        return ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file) + "/s"
    }
}

struct CodeRequest: Identifiable {
    let id = UUID()
    var itemTitle: String
    var respond: (String?) -> Void
}

@MainActor
final class DownloadManager: ObservableObject {
    static let shared = DownloadManager()

    @Published private(set) var jobs: [DownloadJob] = []
    @Published var codeRequest: CodeRequest?
    @Published var onJobStarted: ((DownloadJob) -> Void)?

    private var worker: Task<Void, Never>?
    private var cancelRequested = false
    private var lastSample: (date: Date, bytes: Int64)?

    var activeJobs: [DownloadJob] { jobs.filter { $0.state.isActive } }
    var hasActive: Bool { !activeJobs.isEmpty }

    func enqueue(_ item: WorkshopItem) {
        guard !jobs.contains(where: { $0.id == item.id && $0.state.isActive }) else { return }
        let job = DownloadJob(id: item.id, item: item, state: .queued, progress: 0,
                              received: 0, total: item.fileSize, speed: 0, added: Date(), log: [])
        jobs.insert(job, at: 0)
        onJobStarted?(job)
        startWorker()
    }

    func openInSteam(_ item: WorkshopItem) {
        guard let url = URL(string: "steam://url/CommunityFilePage/\(item.id)") else { return }
        NSWorkspace.shared.open(url)
    }

    func cancel(_ id: String) {
        cancelRequested = true
        dismissCode()
        SteamCMDService.shared.cancelCurrent()
        update(id) { job in
            job.state = .cancelled
            job.speed = 0
        }
    }

    func retry(_ id: String) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].state = .queued
        jobs[index].progress = 0
        jobs[index].log = []
        startWorker()
    }

    func removeFinished() {
        jobs.removeAll { !$0.state.isActive }
    }

    func submitCode(_ code: String) {
        codeRequest?.respond(code.trimmingCharacters(in: .whitespacesAndNewlines))
        codeRequest = nil
    }

    func dismissCode() {
        codeRequest?.respond(nil)
        codeRequest = nil
    }

    private func startWorker() {
        guard worker == nil || worker?.isCancelled == true else { return }
        worker = Task { [weak self] in
            await self?.drain()
            self?.worker = nil
        }
    }

    private func drain() async {
        while let next = jobs.last(where: { $0.state == .queued }) {
            if Task.isCancelled { return }
            await runJob(next.id)
        }
    }

    private func runJob(_ id: String) async {
        guard let item = jobs.first(where: { $0.id == id })?.item else { return }
        cancelRequested = false
        lastSample = nil
        update(id) { job in
            job.state = .running
            job.progress = 0
            job.speed = 0
            job.log = []
        }

        let prefs = Preferences.shared
        guard SteamCMDService.shared.installed else {
            update(id) { job in
                job.state = .failed("SteamCMD 未安装，请到设置里点「安装 SteamCMD」")
            }
            return
        }
        guard prefs.hasCredentials else {
            update(id) { job in
                job.state = .failed("请先在设置里填写 Steam 账号与密码")
            }
            return
        }

        do {
            let url = try await SteamCMDService.shared.download(
                item: item,
                user: prefs.loginUser,
                password: prefs.steamPassword,
                guardCodeProvider: { [weak self] in
                    guard let self else { return nil }
                    return self.blockingGuardCode(jobID: id, title: item.title)
                },
                onProgress: { [weak self] fraction, done, total in
                    Task { @MainActor in
                        self?.applyProgress(id, fraction: fraction, received: done, total: total)
                    }
                },
                onLine: { [weak self] line in
                    Task { @MainActor in self?.appendLog(id, line) }
                }
            )
            LibraryStore.shared.register(id: item.id, at: url, item: item)
            update(id) { job in
                job.state = .done
                job.progress = 1
                job.speed = 0
            }
        } catch {
            let message = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            update(id) { job in
                if job.state != .cancelled {
                    job.state = .failed(message)
                }
                job.speed = 0
            }
        }
    }

    /// 从 SteamCMD 的解析线程同步等待用户输入。
    /// 本函数运行在后台队列，所有 UI 状态改动切回主线程执行。
    nonisolated private func blockingGuardCode(jobID: String, title: String) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        let box = Box<String?>(nil)
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                self.codeRequest = CodeRequest(itemTitle: title) { code in
                    box.value = code
                    semaphore.signal()
                }
                if let index = self.jobs.firstIndex(where: { $0.id == jobID }) {
                    self.jobs[index].state = .awaitingCode
                }
            }
        }
        _ = semaphore.wait(timeout: .now() + 300)
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                if let index = self.jobs.firstIndex(where: { $0.id == jobID }),
                   self.jobs[index].state == .awaitingCode {
                    self.jobs[index].state = .running
                }
            }
        }
        return box.value
    }

    private func applyProgress(_ id: String, fraction: Double, received: Int64, total: Int64) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].progress = max(jobs[index].progress, fraction)
        if received > 0 { jobs[index].received = received }
        if total > 0 { jobs[index].total = total }

        let now = Date()
        if let sample = lastSample, now.timeIntervalSince(sample.date) > 0.4 {
            let delta = Double(received - sample.bytes)
            let rate = delta / now.timeIntervalSince(sample.date)
            if rate >= 0 { jobs[index].speed = rate }
            lastSample = (now, received)
        } else if lastSample == nil {
            lastSample = (now, received)
        }
    }

    private func appendLog(_ id: String, _ line: String) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        jobs[index].log.append(line)
        if jobs[index].log.count > 200 { jobs[index].log.removeFirst(60) }
    }

    private func update(_ id: String, _ mutate: (inout DownloadJob) -> Void) {
        guard let index = jobs.firstIndex(where: { $0.id == id }) else { return }
        mutate(&jobs[index])
    }
}

final class Box<T> {
    var value: T
    init(_ value: T) { self.value = value }
}
