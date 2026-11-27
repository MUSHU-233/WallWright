import SwiftUI

struct DiscoverView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var prefs: Preferences
    @EnvironmentObject private var favorites: FavoritesStore
    @State private var keyDraft = ""
    @FocusState private var keyFocused: Bool

    private let columns = [GridItem(.adaptive(minimum: 226, maximum: 300), spacing: 14)]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            if !state.hasAPIKey {
                keyBanner
            }
            if state.results.isEmpty && state.loading {
                gridSkeleton
            } else if state.filtered.isEmpty {
                empty
            } else {
                grid
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .bottom) {
                SectionTitle(
                    title: "发现",
                    subtitle: state.hasAPIKey
                        ? (state.total > 0 ? "创意工坊 \(Self.formatted(state.total)) 件作品" : "Wallpaper Engine 创意工坊")
                        : "Wallpaper Engine 创意工坊"
                )
                Spacer()
                GlassSearchField(text: $state.query, placeholder: "搜索壁纸，或粘贴工坊链接") {
                    Task { await state.submitSearch() }
                }
                .frame(width: 268)

                Button {
                    Task { await state.submitSearch() }
                } label: {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .bold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(CapsuleButtonStyle(kind: .primary))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(SortMode.allCases) { mode in
                        chip(mode.label, active: state.sort == mode) {
                            guard state.sort != mode else { return }
                            state.sort = mode
                            Task { await state.load(reset: true) }
                        }
                    }

                    Rectangle()
                        .fill(.primary.opacity(0.1))
                        .frame(width: 1, height: 16)
                        .padding(.horizontal, 3)

                    ForEach(AppState.filterTags, id: \.self) { tag in
                        chip(tag, active: state.activeTags.contains(tag)) {
                            Task { await state.toggleTag(tag) }
                        }
                    }
                }
                .padding(.vertical, 1)
            }

            filterBar
        }
        .padding(.horizontal, 28)
        .padding(.top, 42)
        .padding(.bottom, 16)
    }

    private var filterBar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 6) {
                Text("分级")
                    .font(WW.Font.text(9.5))
                    .foregroundStyle(.tertiary)
                    .frame(width: 26, alignment: .leading)
                ForEach(AgeRating.selectable) { rating in
                    chip(rating.label, active: state.ageFilter.contains(rating)) {
                        Task { await state.toggleAge(rating) }
                    }
                }
            }

            Rectangle()
                .fill(.primary.opacity(0.1))
                .frame(width: 1, height: 16)

            HStack(spacing: 6) {
                Text("类型")
                    .font(WW.Font.text(9.5))
                    .foregroundStyle(.tertiary)
                    .frame(width: 26, alignment: .leading)
                ForEach(ContentKind.filterable, id: \.self) { kind in
                    chip(kind.filterLabel, active: state.kindFilter.contains(kind)) {
                        Task { await state.toggleKind(kind) }
                    }
                }
            }

            if state.isFiltering {
                Text("\(state.filtered.count) / \(state.results.count)")
                    .font(WW.Font.text(9.5))
                    .foregroundStyle(.tertiary)
                Button("清除") { state.clearFilters() }
                    .buttonStyle(.plain)
                    .font(WW.Font.text(9.5))
                    .foregroundStyle(WW.Palette.accent)
            }

            Spacer()
        }
        .padding(.top, 1)
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
                        Capsule()
                            .fill(.primary.opacity(0.05))
                            .overlay { Capsule().strokeBorder(.primary.opacity(0.07), lineWidth: 0.7) }
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(state.filtered) { item in
                    ItemCard(
                        item: item,
                        onOpen: { state.detail = item },
                        onDownload: { enqueue(item) },
                        isFavorite: favorites.isFavorite(item.id),
                        onFavorite: {
                            let nowSaved = favorites.toggle(item)
                            state.showToast(nowSaved
                                            ? (favorites.collection(of: item.id).map { "已收藏到「\($0.name)」" } ?? "已收藏")
                                            : "已取消收藏")
                        }
                    )
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)

            if state.loadingMore {
                ProgressView().controlSize(.small).padding(.bottom, 22)
            } else if state.total > state.results.count {
                Button("加载更多") {
                    Task { await state.load(reset: false) }
                }
                .buttonStyle(CapsuleButtonStyle(kind: .glass))
                .padding(.bottom, 26)
            }
        }
        .scrollIndicators(.never)
    }

    private func enqueue(_ item: WorkshopItem) {
        if prefs.channel == .steamClient {
            downloads.openInSteam(item)
            state.showToast("已在 Steam 客户端打开，订阅后会自动下载")
        } else {
            downloads.enqueue(item)
            state.showToast("已加入下载队列")
        }
    }

    private var empty: some View {
        Group {
            if state.isFiltering && !state.results.isEmpty {
                EmptyStateView(symbol: "line.3.horizontal.decrease.circle", title: "没有符合筛选的壁纸",
                               message: "当前这批结果里没有符合所选分级 / 类型的条目。换一组，或者先往下多加载一些再筛。",
                               action: ("清除筛选", { state.clearFilters() }))
            } else if let error = state.errorMessage {
                EmptyStateView(symbol: "exclamationmark.triangle", title: "没能取到结果",
                               message: error,
                               action: ("重试", { Task { await state.reload() } }))
            } else {
                EmptyStateView(symbol: "sparkle.magnifyingglass", title: "没有匹配的壁纸",
                               message: "换个关键词，或者粘贴一个工坊链接 / ID 直接解析。",
                               action: ("看看热门", {
                                   state.query = ""
                                   state.activeTags = []
                                   Task { await state.reload() }
                               }))
            }
        }
    }

    private var gridSkeleton: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(0..<9, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 9) {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(.primary.opacity(0.06))
                            .frame(height: 138)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(.primary.opacity(0.05))
                            .frame(width: 120, height: 9)
                    }
                    .padding(9)
                    .glassSurface(radius: WW.Radius.card, shadow: false)
                }
            }
            .padding(.horizontal, 28)
        }
        .scrollIndicators(.never)
        .opacity(state.loading ? 1 : 0)
    }

    private var keyBanner: some View {
        HStack(spacing: 11) {
            ZStack {
                Circle().fill(WW.Palette.amber.opacity(0.16)).frame(width: 30, height: 30)
                Image(systemName: "key.horizontal.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(WW.Palette.amber)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("当前显示精选内容")
                    .font(WW.Font.rounded(11, .semibold))
                Text("填入免费的 Steam Web API Key 后即可搜索全部作品")
                    .font(WW.Font.text(9.5))
                    .foregroundStyle(.tertiary)
            }

            Spacer(minLength: 8)

            TextField("粘贴 API Key", text: $keyDraft)
                .textFieldStyle(.plain)
                .font(.system(size: 10.5, design: .monospaced))
                .focused($keyFocused)
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .frame(width: 210)
                .background {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.primary.opacity(0.06))
                }

            Button("启用") {
                let value = keyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else { return }
                prefs.apiKey = value
                Task { await state.load(reset: true) }
            }
            .buttonStyle(CapsuleButtonStyle(kind: .primary, tint: WW.Palette.amber))

            Button {
                NSWorkspace.shared.open(URL(string: "https://steamcommunity.com/dev/apikey")!)
            } label: {
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Circle().fill(.primary.opacity(0.06)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .glassSurface(radius: 16, tint: WW.Palette.amber, strength: 0.05, shadow: false)
        .padding(.horizontal, 28)
        .padding(.bottom, 14)
    }

    static func formatted(_ value: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }
}
