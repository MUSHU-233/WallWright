import SwiftUI

struct MenuBarPanel: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var prefs: Preferences
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.openWindow) private var openWindow
    @State private var text = ""
    @State private var localResults: [WorkshopItem] = []
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            header

            GlassSearchField(text: $text, placeholder: "搜索 / 粘贴工坊链接") {
                Task { await search() }
            }

            if downloads.hasActive {
                activeSection
            }

            if busy {
                HStack { Spacer(); ProgressView().controlSize(.small); Spacer() }
                    .frame(height: 50)
            } else if !localResults.isEmpty {
                results
            } else {
                hint
            }

            footer
        }
        .padding(14)
        .frame(width: 344)
        .background {
            AuroraBackground(intensity: 0.55).opacity(0.55)
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            LogoMark(size: 20)
            Text("WallWright").font(WW.Font.rounded(12, .bold))
            Spacer()
            Button {
                state.route = .downloads
                HUDController.shared.toggle()
            } label: {
                Image(systemName: "rectangle.on.rectangle")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(downloads.hasActive ? WW.Palette.accent : .secondary)
            }
            .buttonStyle(.plain)

            Button {
                openMain()
            } label: {
                Image(systemName: "macwindow")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var activeSection: some View {
        VStack(spacing: 7) {
            ForEach(downloads.activeJobs.prefix(2)) { job in
                HStack(spacing: 8) {
                    ProgressRing(progress: job.progress, lineWidth: 3, size: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(job.item.title)
                            .font(WW.Font.rounded(10.5, .semibold))
                            .lineLimit(1)
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.primary.opacity(0.09))
                                Capsule()
                                    .fill(WW.Palette.accentGradient)
                                    .frame(width: max(2, proxy.size.width * job.progress))
                            }
                        }
                        .frame(height: 3)
                    }
                    Text("\(Int(job.progress * 100))%")
                        .font(WW.Font.rounded(9, .bold))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(9)
        .background {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(.primary.opacity(0.045))
        }
    }

    private var results: some View {
        VStack(spacing: 2) {
            ForEach(localResults.prefix(5)) { item in
                Button {
                    state.detail = item
                    state.results = localResults
                    openMain()
                } label: {
                    HStack(spacing: 8) {
                        RemoteImage(url: item.previewURL, cornerRadius: 7)
                            .frame(width: 38, height: 30)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.title)
                                .font(WW.Font.rounded(10.5, .medium))
                                .lineLimit(1)
                            Text("\(item.kind.label) · \(item.sizeText)")
                                .font(WW.Font.text(8.5))
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Button {
                            if prefs.channel == .steamClient {
                                downloads.openInSteam(item)
                            } else {
                                downloads.enqueue(item)
                                HUDController.shared.show()
                            }
                        } label: {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 18, height: 18)
                                .background(Circle().fill(WW.Palette.accent))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var hint: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(prefs.apiKey.isEmpty ? "还没有配置 API Key" : "试试搜「Aurora」或「Cyberpunk」")
                .font(WW.Font.rounded(10.5, .semibold))
                .foregroundStyle(.secondary)
            Text(prefs.apiKey.isEmpty
                 ? "打开主窗口 → 设置里填入 Key，或用链接直接解析"
                 : "结果会显示在这里，点击可进详情")
                .font(WW.Font.text(9.5))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Text("\(library.entries.count) 个本地壁纸")
                .font(WW.Font.rounded(9.5, .medium))
                .foregroundStyle(.tertiary)
            Spacer()
            Button("主窗口") { openMain() }
                .buttonStyle(CapsuleButtonStyle(kind: .glass))
        }
    }

    private func openMain() {
        openWindow(id: "main")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func search() async {
        let query = text
        guard !query.isEmpty else { return }
        if let id = AppState.extractID(from: query) {
            busy = true
            defer { busy = false }
            localResults = (try? await SteamAPI.shared.details(ids: [id])) ?? []
            return
        }
        guard !prefs.apiKey.isEmpty else {
            openMain()
            return
        }
        busy = true
        defer { busy = false }
        let page = try? await SteamAPI.shared.search(key: prefs.apiKey, text: query, sort: .trend, cursor: nil)
        localResults = page?.items ?? []
    }
}
