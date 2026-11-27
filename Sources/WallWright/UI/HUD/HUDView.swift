import SwiftUI

private struct HUDSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

struct HUDView: View {
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var state: AppState
    @State private var code: String = ""
    @State private var appeared = false

    private var visibleJobs: [DownloadJob] {
        let active = downloads.jobs.filter { $0.state.isActive }
        let finished = downloads.jobs.filter { !$0.state.isActive }.prefix(2)
        return active + finished
    }

    var body: some View {
        card
            .padding(26)
            .background {
                GeometryReader { proxy in
                    Color.clear.preference(key: HUDSizeKey.self, value: proxy.size)
                }
            }
            .onPreferenceChange(HUDSizeKey.self) { size in
                HUDController.shared.resize(to: size)
            }
            .scaleEffect(appeared ? 1 : 0.96, anchor: .bottomTrailing)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) { appeared = true }
            }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            if downloads.codeRequest != nil {
                codeSection
            }
            if visibleJobs.isEmpty {
                emptyState
            } else {
                VStack(spacing: 10) {
                    ForEach(visibleJobs) { job in
                        HUDJobRow(job: job) { downloads.cancel(job.id) }
                        if job.id != visibleJobs.last?.id {
                            Rectangle()
                                .fill(.primary.opacity(0.06))
                                .frame(height: 0.8)
                                .padding(.leading, 58)
                        }
                    }
                }
            }
            if downloads.hasActive {
                footer
            }
        }
        .padding(16)
        .frame(width: 348, alignment: .leading)
        .glassSurface(radius: WW.Radius.hud, tint: WW.Palette.accent, strength: 0.07)
    }

    private var header: some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(WW.Palette.accentGradient)
                    .frame(width: 18, height: 18)
                    .blur(radius: 5)
                    .opacity(0.75)
                Circle()
                    .fill(WW.Palette.accentGradient)
                    .frame(width: 8, height: 8)
            }

            Text("下载队列")
                .font(WW.Font.rounded(12.5, .bold))
                .foregroundStyle(.primary)

            if downloads.hasActive {
                Text("\(downloads.activeJobs.count)")
                    .font(WW.Font.rounded(9.5, .bold))
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(WW.Palette.accent.opacity(0.9)))
            }

            Spacer()

            Button {
                HUDController.shared.hide()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, height: 20)
                    .background(Circle().fill(.primary.opacity(0.07)))
            }
            .buttonStyle(.plain)
        }
    }

    private var emptyState: some View {
        HStack(spacing: 10) {
            Image(systemName: "moon.stars")
                .font(.system(size: 17, weight: .light))
                .foregroundStyle(.tertiary)
            VStack(alignment: .leading, spacing: 2) {
                Text("队列空闲").font(WW.Font.rounded(12, .semibold))
                Text("去发现页挑一张壁纸，下载会在这里显示")
                    .font(WW.Font.text(10.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 10)
    }

    private var codeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(WW.Palette.amber)
                Text("Steam Guard 需要验证码")
                    .font(WW.Font.rounded(11, .semibold))
            }
            HStack(spacing: 8) {
                TextField("邮箱里的 5 位字母", text: $code)
                    .textFieldStyle(.plain)
                    .font(WW.Font.text(12))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(.primary.opacity(0.07))
                    }
                    .onSubmit { submit() }
                Button("验证") { submit() }
                    .buttonStyle(CapsuleButtonStyle(kind: .primary, tint: WW.Palette.amber))
            }
        }
        .padding(11)
        .background {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(WW.Palette.amber.opacity(0.10))
        }
    }

    private func submit() {
        guard !code.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        downloads.submitCode(code)
        code = ""
    }

    private var footer: some View {
        HStack(spacing: 10) {
            let speed = downloads.activeJobs.reduce(0) { $0 + $1.speed }
            HStack(spacing: 4) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 8.5, weight: .bold))
                Text(speed > 0 ? ByteCountFormatter.string(fromByteCount: Int64(speed), countStyle: .file) + "/s" : "连接中")
                    .font(WW.Font.rounded(10, .semibold))
                    .monospacedDigit()
            }
            .foregroundStyle(.secondary)

            Spacer()

            Button("打开下载页") {
                state.route = .downloads
                NSApp.activate(ignoringOtherApps: true)
                for window in NSApp.windows where window.canBecomeMain && window.isVisible {
                    window.makeKeyAndOrderFront(nil)
                    break
                }
                HUDController.shared.hide()
            }
            .buttonStyle(CapsuleButtonStyle(kind: .glass))
        }
    }
}

struct HUDJobRow: View {
    var job: DownloadJob
    var onCancel: () -> Void
    @State private var hovering = false

    var body: some View {
        HStack(spacing: 10) {
            RemoteImage(url: job.item.previewURL, cornerRadius: 11)
                .frame(width: 46, height: 46)
                .overlay {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 0.7)
                }

            VStack(alignment: .leading, spacing: 5) {
                Text(job.item.title)
                    .font(WW.Font.rounded(11.5, .semibold))
                    .lineLimit(1)
                    .truncationMode(.middle)

                if case .failed(let message) = job.state {
                    Text(message)
                        .font(WW.Font.text(9.5))
                        .foregroundStyle(WW.Palette.coral)
                        .lineLimit(1)
                } else if case .done = job.state {
                    Text("已保存到本地库")
                        .font(WW.Font.text(9.5))
                        .foregroundStyle(WW.Palette.mint)
                } else {
                    progressBar
                    HStack(spacing: 6) {
                        Text(job.bytesText)
                        if !job.speedText.isEmpty {
                            Text("·")
                            Text(job.speedText)
                        }
                    }
                    .font(WW.Font.rounded(9, .medium))
                    .monospacedDigit()
                    .foregroundStyle(.tertiary)
                }
            }

            Spacer(minLength: 4)

            trailing
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
        .onHover { hovering = $0 }
        .overlay(alignment: .topTrailing) {
            if hovering && job.state.isActive {
                Button(action: onCancel) {
                    Image(systemName: "xmark")
                        .font(.system(size: 7.5, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 14, height: 14)
                        .background(Circle().fill(.primary.opacity(0.09)))
                }
                .buttonStyle(.plain)
                .offset(x: 2, y: -2)
            }
        }
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(.primary.opacity(0.09))
                Capsule()
                    .fill(LinearGradient(colors: [WW.Palette.accent, WW.Palette.iris],
                                         startPoint: .leading, endPoint: .trailing))
                    .frame(width: max(3, proxy.size.width * job.progress))
            }
        }
        .frame(height: 3.5)
        .animation(.easeOut(duration: 0.35), value: job.progress)
    }

    @ViewBuilder
    private var trailing: some View {
        switch job.state {
        case .running, .awaitingCode, .queued:
            ProgressRing(progress: job.progress, lineWidth: 3.4, showLabel: true, size: 28)
        case .done:
            Image(systemName: "checkmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(WW.Palette.mint))
        case .failed:
            Image(systemName: "exclamationmark")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Circle().fill(WW.Palette.coral))
        case .cancelled:
            Image(systemName: "minus")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.secondary)
        }
    }
}
