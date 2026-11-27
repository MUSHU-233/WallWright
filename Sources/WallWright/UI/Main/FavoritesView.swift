import SwiftUI

struct FavoritesView: View {
    @EnvironmentObject private var favorites: FavoritesStore
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var downloads: DownloadManager

    @State private var selected: String?
    @State private var nameSheet: NameSheet?
    @State private var draftName = ""
    @State private var pendingDelete: FavoriteCollection?
    @State private var sheetError: String?

    private let columns = [GridItem(.adaptive(minimum: 226, maximum: 300), spacing: 14)]

    private enum NameSheet: Identifiable {
        case create
        case rename(FavoriteCollection)

        var id: String {
            switch self {
            case .create: return "create"
            case .rename(let collection): return collection.id
            }
        }
    }

    private var shown: [FavoriteEntry] { favorites.items(in: selected) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if favorites.entries.isEmpty {
                emptyAll
            } else if shown.isEmpty {
                emptyCollection
            } else {
                grid
            }
        }
        .sheet(item: $nameSheet) { sheet in
            nameSheetView(sheet)
        }
        .confirmationDialog(
            "删除收藏夹「\(pendingDelete?.name ?? "")」？",
            isPresented: Binding(get: { pendingDelete != nil },
                                 set: { if !$0 { pendingDelete = nil } }),
            presenting: pendingDelete
        ) { collection in
            Button("把壁纸移到「我的收藏」") {
                favorites.deleteCollection(collection.id, moveItems: true)
                if selected == collection.id { selected = nil }
                pendingDelete = nil
            }
            Button("连壁纸一起移除", role: .destructive) {
                favorites.deleteCollection(collection.id, moveItems: false)
                if selected == collection.id { selected = nil }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) { pendingDelete = nil }
        } message: { _ in
            Text("删除收藏夹不会动磁盘上的文件，只影响这里的分组。")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .bottom) {
                SectionTitle(title: "我的收藏",
                             subtitle: "\(favorites.entries.count) 张 · \(favorites.collections.count) 个收藏夹")
                Spacer()
                Button {
                    draftName = ""
                    sheetError = nil
                    nameSheet = .create
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "folder.badge.plus").font(.system(size: 10, weight: .bold))
                        Text("新建收藏夹")
                    }
                }
                .buttonStyle(CapsuleButtonStyle(kind: .glass))
            }

            if let message = favorites.message {
                Text(message).font(WW.Font.text(10)).foregroundStyle(.tertiary)
            }

            if !favorites.collections.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        chip("全部", count: favorites.entries.count, active: selected == nil) {
                            selected = nil
                        }
                        ForEach(favorites.collections) { collection in
                            chip(collection.name, count: favorites.count(in: collection.id),
                                 active: selected == collection.id) {
                                selected = collection.id
                            }
                            .contextMenu {
                                Button("重命名…") {
                                    draftName = collection.name
                                    sheetError = nil
                                    nameSheet = .rename(collection)
                                }
                                Button("删除收藏夹…", role: .destructive) {
                                    pendingDelete = collection
                                }
                            }
                        }
                    }
                    .padding(.vertical, 1)
                }
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 42)
        .padding(.bottom, 16)
    }

    private func chip(_ label: String, count: Int, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 5) {
                Text(label)
                Text("\(count)")
                    .font(WW.Font.rounded(9, .bold))
                    .opacity(active ? 0.85 : 0.5)
            }
            .font(WW.Font.rounded(10.5, .semibold))
            .foregroundStyle(active ? .white : .secondary)
            .padding(.horizontal, 11)
            .padding(.vertical, 5.5)
            .background {
                if active {
                    Capsule().fill(WW.Palette.coral)
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
                ForEach(shown) { entry in
                    ItemCard(
                        item: entry.item,
                        onOpen: { state.detail = entry.item },
                        onDownload: { downloads.enqueue(entry.item) },
                        onRemove: {
                            favorites.remove(entry.id)
                            state.showToast("已从收藏中移除")
                        }
                    )
                    .contextMenu {
                        Button("取消收藏", role: .destructive) { favorites.remove(entry.id) }
                        if favorites.collections.count > 1 {
                            Menu("移动到收藏夹") {
                                ForEach(favorites.collections) { collection in
                                    Button(collection.name) {
                                        favorites.move(entry.id, to: collection.id)
                                    }
                                }
                            }
                        }
                        Divider()
                        Button("在 Steam 中打开") { downloads.openInSteam(entry.item) }
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .scrollIndicators(.never)
    }

    private var emptyAll: some View {
        VStack(spacing: 16) {
            EmptyStateView(symbol: "heart",
                           title: "还没有收藏",
                           message: "在发现页把鼠标移到喜欢的壁纸上，点右上角的爱心就会收藏到这里。第一次收藏会自动建一个叫「我的收藏」的收藏夹。",
                           action: ("去发现页看看", { state.route = .discover }))
                .fixedSize(horizontal: false, vertical: true)

            if favorites.hasLocalSubscriptions {
                Button("导入本机 Steam 订阅") {
                    Task { await favorites.importLocalSubscriptions() }
                }
                .buttonStyle(CapsuleButtonStyle(kind: .glass))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.bottom, 50)
    }

    private var emptyCollection: some View {
        EmptyStateView(symbol: "folder",
                       title: "这个收藏夹还是空的",
                       message: "在发现页收藏壁纸时，默认会进「我的收藏」。想归到别的夹子，可以在卡片右键菜单里「移动到收藏夹」。",
                       action: ("看全部收藏", { selected = nil }))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.bottom, 50)
    }

    private func nameSheetView(_ sheet: NameSheet) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(sheetTitle(sheet))
                .font(WW.Font.rounded(15, .bold))

            TextField("收藏夹名字", text: $draftName)
                .textFieldStyle(.plain)
                .font(WW.Font.text(12.5))
                .padding(.horizontal, 11)
                .padding(.vertical, 9)
                .background {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(.primary.opacity(0.06))
                        .overlay {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
                        }
                }

            if let sheetError {
                Text(sheetError).font(WW.Font.text(10)).foregroundStyle(WW.Palette.coral)
            }

            HStack(spacing: 8) {
                Spacer()
                Button("取消") { nameSheet = nil }
                    .buttonStyle(CapsuleButtonStyle(kind: .ghost))
                Button("确定") { commit(sheet) }
                    .buttonStyle(CapsuleButtonStyle(kind: .primary))
                    .disabled(draftName.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 340)
    }

    private func sheetTitle(_ sheet: NameSheet) -> String {
        switch sheet {
        case .create: return "新建收藏夹"
        case .rename: return "重命名收藏夹"
        }
    }

    private func commit(_ sheet: NameSheet) {
        let name = draftName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            sheetError = "名字不能为空"
            return
        }
        if favorites.collections.contains(where: { $0.name == name }) {
            sheetError = "已经有同名收藏夹了"
            return
        }
        switch sheet {
        case .create:
            if let created = favorites.createCollection(named: name) {
                selected = created.id
                sheetError = nil
                nameSheet = nil
            }
        case .rename(let collection):
            favorites.rename(collection.id, to: name)
            sheetError = nil
            nameSheet = nil
        }
    }
}
