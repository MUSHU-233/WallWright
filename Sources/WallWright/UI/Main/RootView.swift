import SwiftUI

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var prefs: Preferences

    var body: some View {
        ZStack {
            AuroraBackground()

            HStack(spacing: 0) {
                Sidebar()
                    .frame(width: 214)
                Rectangle()
                    .fill(.primary.opacity(0.06))
                    .frame(width: 1)
                    .padding(.vertical, 18)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(item: $state.detail) { item in
            ItemDetailView(item: item)
                .environmentObject(state)
                .environmentObject(downloads)
                .environmentObject(prefs)
        }
        .overlay(alignment: .bottom) {
            if let toast = state.toast {
                Text(toast)
                    .font(WW.Font.rounded(11.5, .semibold))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 9)
                    .glassSurface(radius: 999, tint: WW.Palette.mint, strength: 0.12)
                    .padding(.bottom, 26)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: state.toast)
        .ignoresSafeArea(.container, edges: .top)
        .task { await state.bootstrap() }
    }

    @ViewBuilder
    private var content: some View {
        switch state.route {
        case .discover: DiscoverView()
        case .favorites: FavoritesView()
        case .library: LibraryView()
        case .downloads: DownloadsView()
        case .settings: SettingsView()
        }
    }
}

struct Sidebar: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var downloads: DownloadManager
    @EnvironmentObject private var prefs: Preferences
    @State private var hovered: Route?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            brand
                .padding(.top, 40)
                .padding(.horizontal, 20)
                .padding(.bottom, 22)

            VStack(spacing: 3) {
                ForEach(Route.allCases) { route in
                    navItem(route)
                }
            }
            .padding(.horizontal, 12)

            Spacer(minLength: 12)

            statusCard
                .padding(.horizontal, 12)
                .padding(.bottom, 14)
        }
    }

    private var brand: some View {
        HStack(spacing: 10) {
            LogoMark(size: 26)
            VStack(alignment: .leading, spacing: 0) {
                Text("WallWright")
                    .font(WW.Font.rounded(14, .bold))
                    .foregroundStyle(.primary)
                Text("工坊壁纸工作站")
                    .font(WW.Font.text(9.5))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func navItem(_ route: Route) -> some View {
        let selected = state.route == route
        return Button {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                state.route = route
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: route.symbol)
                    .font(.system(size: 12.5, weight: selected ? .semibold : .regular))
                    .frame(width: 18)
                    .foregroundStyle(selected ? WW.Palette.accent : .secondary)
                Text(route.title)
                    .font(WW.Font.rounded(12.5, selected ? .semibold : .medium))
                    .foregroundStyle(selected ? .primary : .secondary)
                Spacer()
                if route == .downloads, downloads.hasActive {
                    Text("\(downloads.activeJobs.count)")
                        .font(WW.Font.rounded(9.5, .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5.5)
                        .padding(.vertical, 1.5)
                        .background(Capsule().fill(WW.Palette.accent))
                }
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 8.5)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.primary.opacity(0.07))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white.opacity(0.25), lineWidth: 0.7)
                        }
                } else if hovered == route {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.primary.opacity(0.035))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 ? route : nil }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Circle()
                    .fill(prefs.channel == .steamcmd
                          ? (SteamCMDService.shared.installed ? WW.Palette.mint : WW.Palette.amber)
                          : WW.Palette.accent)
                    .frame(width: 6, height: 6)
                Text(prefs.channel.label)
                    .font(WW.Font.rounded(10, .semibold))
                Spacer()
            }
            Text(prefs.channel == .steamcmd
                 ? (SteamCMDService.shared.installed ? "引擎就绪" : "尚未安装引擎")
                 : "通过 Steam 客户端订阅")
                .font(WW.Font.text(9.5))
                .foregroundStyle(.tertiary)
        }
        .padding(11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: 14, shadow: false)
    }
}

struct LogoMark: View {
    var size: CGFloat = 24

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.32, style: .continuous)
                .fill(WW.Palette.accentGradient)
            Image(systemName: "square.stack.3d.up.fill")
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white.opacity(0.95))
        }
        .frame(width: size, height: size)
        .shadow(color: WW.Palette.accent.opacity(0.4), radius: size * 0.28, y: size * 0.12)
    }
}
