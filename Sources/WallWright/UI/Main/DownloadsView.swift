import SwiftUI

struct DownloadsView: View {
    @EnvironmentObject private var downloads: DownloadManager
    @State private var expanded: String?

    private var totalSpeed: Double {
        downloads.activeJobs.reduce(0) { $0 + $1.speed }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if downloads.jobs.isEmpty {
                EmptyStateView(symbol: "arrow.down.circle.dotted",
                               title: "没有下载任务",
                               message: "在发现页点卡片上的下载按钮，任务会出现在这里，并同步显示在右下角的悬浮 HUD。")
                    .padding(.bottom, 60)
            } else {
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(downloads.jobs) { job in
                            DownloadRow(job: job, expanded: $expanded)
                        }
                    }
                    .padding(.horizontal, 28)
                    .padding(.bottom, 26)
                }
                .scrollIndicators(.never)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .bottom) {
            SectionTitle(title: "下载",
                         subtitle: downloads.hasActive
                            ? "\(downloads.activeJobs.count) 个任务进行中 · \(ByteCountFormatter.string(fromByteCount: Int64(totalSpeed), countStyle: .file))/s"
                            : "队列空闲")
            Spacer()
            Button {
                HUDController.shared.show()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "rectangle.on.rectangle").font(.system(size: 9.5, weight: .bold))
                    Text("显示 HUD")
                }
            }
            .buttonStyle(CapsuleButtonStyle(kind: .glass))

            Button("清理已完成") { downloads.removeFinished() }
                .buttonStyle(CapsuleButtonStyle(kind: .ghost))
                .disabled(downloads.jobs.allSatisfy { $0.state.isActive })
        }
        .padding(.horizontal, 28)
        .padding(.top, 42)
        .padding(.bottom, 18)
    }
}

struct DownloadRow: View {
    var job: DownloadJob
    @Binding var expanded: String?
    @EnvironmentObject private var downloads: DownloadManager
    @State private var hover = false

    private var accent: Color { WW.Palette.tint(for: job.item.kind) }
    private var isExpanded: Bool { expanded == job.id }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 13) {
                RemoteImage(url: job.item.previewURL, cornerRadius: 12)
                    .frame(width: 66, height: 50)
                    .overlay {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(.white.opacity(0.14), lineWidth: 0.8)
                    }

                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(job.item.title)
                            .font(WW.Font.rounded(12.5, .semibold))
                            .lineLimit(1)
                        Text(job.state.label)
                            .font(WW.Font.rounded(9, .bold))
                            .foregroundStyle(stateColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(stateColor.opacity(0.12)))
                    }

                    if case .failed(let message) = job.state {
                        Text(message).font(WW.Font.text(10)).foregroundStyle(WW.Palette.coral).lineLimit(2)
                    } else {
                        progressBar
                        HStack(spacing: 6) {
                            Text(job.bytesText)
                            if !job.speedText.isEmpty {
                                Text("·")
                                Text(job.speedText)
                            }
                        }
                        .font(WW.Font.rounded(9.5, .medium))
                        .monospacedDigit()
                        .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: 8)

                if job.state.isActive {
                    ProgressRing(progress: job.progress, lineWidth: 4, showLabel: true, size: 38)
                }

                rowActions
            }
            .padding(12)

            if isExpanded && !job.log.isEmpty {
                logView
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .glassSurface(radius: 18, tint: accent, strength: 0.05, shadow: false)
        .onHover { hover = $0 }
        .animation(.spring(response: 0.3, dampingFraction: 0.85), value: isExpanded)
    }

    private var stateColor: Color {
        switch job.state {
        case .done: return WW.Palette.mint
        case .failed: return WW.Palette.coral
        case .awaitingCode: return WW.Palette.amber
        case .cancelled: return .secondary
        default: return WW.Palette.accent
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.08))
                Capsule()
                    .fill(LinearGradient(colors: [accent, WW.Palette.iris], startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(2, proxy.size.width * job.progress))
            }
        }
        .frame(height: 4)
        .animation(.easeOut(duration: 0.3), value: job.progress)
    }

    private var rowActions: some View {
        HStack(spacing: 6) {
            if job.state.isActive {
                small("xmark") { downloads.cancel(job.id) }
            }
            if case .failed = job.state {
                small("arrow.clockwise") { downloads.retry(job.id) }
            }
            if case .done = job.state, let entry = LibraryStore.shared.entries.first(where: { $0.id == job.id }) {
                small("folder") { LibraryStore.shared.reveal(entry) }
            }
            if !job.log.isEmpty {
                small(isExpanded ? "chevron.up" : "terminal") {
                    expanded = isExpanded ? nil : job.id
                }
            }
        }
        .opacity(hover || isExpanded ? 1 : 0.55)
    }

    private func small(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
                .background(Circle().fill(.primary.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    private var logView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 1) {
                ForEach(Array(job.log.suffix(40).enumerated()), id: \.offset) { _, line in
                    Text(line)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(line.hasPrefix("✓") ? WW.Palette.mint
                                         : line.hasPrefix("✗") ? WW.Palette.coral : .secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(10)
        }
        .frame(height: 116)
        .background {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.black.opacity(0.22))
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
    }
}
