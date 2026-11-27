import SwiftUI

struct LibraryView: View {
    @EnvironmentObject private var library: LibraryStore
    @EnvironmentObject private var state: AppState
    @State private var filter: ContentKind?

    private let columns = [GridItem(.adaptive(minimum: 226, maximum: 300), spacing: 14)]

    private var filtered: [LibraryEntry] {
        guard let filter else { return library.entries }
        return library.entries.filter { $0.kind == filter }
    }

    private var totalSize: Int64 {
        library.entries.reduce(0) { $0 + $1.size }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if library.entries.isEmpty {
                EmptyStateView(symbol: "square.stack.3d.up.slash",
                               title: "本地库还是空的",
                               message: "下载完成的壁纸会自动出现在这里。已经用 Steam 客户端订阅过的作品也会被自动扫描到。",
                               action: ("去发现页看看", { state.route = .discover }))
                    .padding(.bottom, 60)
            } else {
                grid
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .bottom) {
                SectionTitle(title: "我的库",
                             subtitle: "\(library.entries.count) 个壁纸 · 占用 \(ByteCountFormatter.string(fromByteCount: totalSize, countStyle: .file))")
                Spacer()
                Button {
                    Task { await library.scan() }
                } label: {
                    HStack(spacing: 5) {
                        if library.scanning {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath").font(.system(size: 9.5, weight: .bold))
                        }
                        Text("同步 Steam")
                    }
                }
                .buttonStyle(CapsuleButtonStyle(kind: .glass))
            }

            HStack(spacing: 6) {
                chip("全部", active: filter == nil) { filter = nil }
                ForEach(ContentKind.allCases.filter { $0 != .unknown }, id: \.self) { kind in
                    if library.entries.contains(where: { $0.kind == kind }) {
                        chip(kind.label, active: filter == kind) { filter = kind }
                    }
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 42)
        .padding(.bottom, 16)
    }

    private func chip(_ label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(WW.Font.rounded(10.5, .semibold))
                .foregroundStyle(active ? .white : .secondary)
                .padding(.horizontal, 11)
                .padding(.vertical, 5.5)
                .background {
                    if active {
                        Capsule().fill(WW.Palette.accentGradient)
                    } else {
                        Capsule().fill(.primary.opacity(0.05))
                            .overlay { Capsule().strokeBorder(.primary.opacity(0.07), lineWidth: 0.7) }
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(filtered) { entry in
                    LibraryCard(entry: entry)
                        .contextMenu {
                            Button("在 Finder 中显示") { library.reveal(entry) }
                            Button("设为桌面背景") { library.setWallpaper(for: entry) }
                            Button("打开文件夹") { library.openWithDefault(entry) }
                            Divider()
                            Button("从库中移除", role: .destructive) { library.remove(id: entry.id, deleteFiles: false) }
                        }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.never)
    }
}

struct LibraryCard: View {
    var entry: LibraryEntry
    @EnvironmentObject private var library: LibraryStore
    @State private var hover = false

    private var accent: Color { WW.Palette.tint(for: entry.kind) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            ZStack(alignment: .topLeading) {
                RemoteImage(url: entry.previewURL, cornerRadius: 15)
                    .frame(height: 138)
                    .overlay {
                        LinearGradient(colors: [.clear, .black.opacity(0.55)],
                                       startPoint: .center, endPoint: .bottom)
                            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                    }

                TagBadge(text: entry.kind.label, symbol: entry.kind.symbol, tint: .white.opacity(0.92))
                    .padding(8)

                if hover {
                    HStack(spacing: 6) {
                        Spacer()
                        iconButton("folder") { library.reveal(entry) }
                        iconButton("display") { library.setWallpaper(for: entry) }
                    }
                    .padding(8)
                    .transition(.opacity)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Spacer()
                    Text(entry.title)
                        .font(WW.Font.rounded(12, .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 9)
            }
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(.white.opacity(0.14), lineWidth: 0.8)
            }

            HStack(spacing: 6) {
                Text(ByteCountFormatter.string(fromByteCount: entry.size, countStyle: .file))
                Text("·")
                Text(entry.source)
                Spacer()
            }
            .font(WW.Font.rounded(9.5, .medium))
            .foregroundStyle(.tertiary)
            .padding(.horizontal, 3)
        }
        .padding(9)
        .glassSurface(radius: WW.Radius.card, tint: accent, strength: hover ? 0.10 : 0.03, interactive: true)
        .hoverLift(1.018)
        .onHover { hover = $0 }
        .animation(.easeOut(duration: 0.16), value: hover)
    }

    private func iconButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 9.5, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(.black.opacity(0.32)))
                .overlay { Circle().strokeBorder(.white.opacity(0.28), lineWidth: 0.7) }
        }
        .buttonStyle(.plain)
    }
}
