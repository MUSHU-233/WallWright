import SwiftUI

struct ItemDetailView: View {
    var item: WorkshopItem
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var prefs: Preferences

    private var accent: Color { WW.Palette.tint(for: item.kind) }
    private var inLibrary: Bool { LibraryStore.shared.entries.contains { $0.id == item.id } }

    var body: some View {
        ZStack {
            AuroraBackground(intensity: 0.9)

            HStack(spacing: 0) {
                preview
                info
            }
            .padding(18)
        }
        .frame(width: 860, height: 540)
        .overlay(alignment: .topTrailing) {
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 26, height: 26)
                    .background(Circle().fill(.primary.opacity(0.07)))
            }
            .buttonStyle(.plain)
            .padding(26)
        }
    }

    private var preview: some View {
        RemoteImage(url: item.previewURL, cornerRadius: 20)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 1)
            }
            .overlay(alignment: .bottomLeading) {
                HStack(spacing: 6) {
                    TagBadge(text: item.kind.label, symbol: item.kind.symbol, tint: .white.opacity(0.95))
                    if let resolution = item.resolution {
                        TagBadge(text: resolution, tint: .white.opacity(0.8))
                    }
                }
                .padding(14)
            }
            .shadow(color: accent.opacity(0.3), radius: 34, y: 14)
            .padding(.trailing, 18)
    }

    private var info: some View {
        VStack(alignment: .leading, spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text(item.title)
                        .font(WW.Font.rounded(22, .bold))
                        .lineSpacing(1)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 14) {
                        stat("person.2.fill", item.subsText, "订阅")
                        stat("internaldrive.fill", item.sizeText, "大小")
                        stat("eye.fill", "\(item.views)", "浏览")
                    }

                    if !item.displayTags.isEmpty {
                        FlowTags(tags: item.displayTags, accent: accent)
                    }

                    if !item.summary.isEmpty {
                        Text(item.summary)
                            .font(WW.Font.text(11.5))
                            .foregroundStyle(.secondary)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollIndicators(.never)

            Spacer(minLength: 16)

            actions
        }
        .frame(width: 300)
        .padding(20)
        .glassSurface(radius: WW.Radius.panel, shadow: false)
    }

    private func stat(_ symbol: String, _ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: symbol).font(.system(size: 8.5))
                Text(value).font(WW.Font.rounded(12, .semibold))
            }
            .foregroundStyle(.primary)
            Text(label)
                .font(WW.Font.text(9))
                .foregroundStyle(.tertiary)
        }
    }

    private var actions: some View {
        VStack(spacing: 8) {
            Button {
                if prefs.channel == .steamClient {
                    downloads.openInSteam(item)
                    dismiss()
                } else {
                    downloads.enqueue(item)
                    state.showToast("已加入下载队列")
                    dismiss()
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: inLibrary ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                    Text(inLibrary ? "已在库中，重新下载" : (prefs.channel == .steamClient ? "在 Steam 中打开" : "下载到本地"))
                        .font(WW.Font.rounded(12, .semibold))
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(CapsuleButtonStyle(kind: .primary, tint: accent))

            HStack(spacing: 8) {
                Button {
                    downloads.openInSteam(item)
                } label: {
                    Text("Steam 页面").frame(maxWidth: .infinity)
                }
                .buttonStyle(CapsuleButtonStyle(kind: .glass))

                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.id, forType: .string)
                    state.showToast("已复制工坊 ID")
                } label: {
                    Text("复制 ID").frame(maxWidth: .infinity)
                }
                .buttonStyle(CapsuleButtonStyle(kind: .glass))
            }
        }
    }
}

struct FlowTags: View {
    var tags: [String]
    var accent: Color

    var body: some View {
        HStack(spacing: 5) {
            ForEach(tags, id: \.self) { tag in
                TagBadge(text: tag, tint: accent)
            }
        }
    }
}
