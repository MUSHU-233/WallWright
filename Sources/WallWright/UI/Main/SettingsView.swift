import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var prefs: Preferences
    @EnvironmentObject private var steamcmd: SteamCMDService

    @State private var password: String = ""
    @State private var key: String = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                SectionTitle(title: "设置", subtitle: "下载通道、账号与本地库")
                    .padding(.top, 6)

                channelCard
                accountCard
                engineCard
                apiCard
                miscCard
            }
            .padding(.horizontal, 28)
            .padding(.top, 42)
            .padding(.bottom, 30)
            .frame(maxWidth: 720, alignment: .leading)
        }
        .scrollIndicators(.never)
        .onAppear {
            password = prefs.steamPassword
            key = prefs.apiKey
            steamcmd.refresh()
        }
    }

    private var channelCard: some View {
        SettingsCard(title: "下载通道", symbol: "arrow.down.forward.circle", tint: WW.Palette.accent) {
            VStack(spacing: 8) {
                ForEach(DownloadChannel.allCases) { channel in
                    ChannelRow(channel: channel, selected: prefs.channel == channel) {
                        prefs.channel = channel
                    }
                }
            }
        }
    }

    private var accountCard: some View {
        SettingsCard(title: "Steam 账号", symbol: "person.crop.circle", tint: WW.Palette.iris) {
            VStack(spacing: 10) {
                field("账号", placeholder: "Steam 用户名") {
                    TextField("Steam 用户名", text: $prefs.steamUser)
                        .textFieldStyle(.plain)
                        .font(WW.Font.text(12))
                }

                field("密码", placeholder: "密码") {
                    SecureField("密码", text: $password)
                        .textFieldStyle(.plain)
                        .font(WW.Font.text(12))
                        .onSubmit { prefs.steamPassword = password }
                }

                HStack(spacing: 6) {
                    Image(systemName: "lock.fill").font(.system(size: 8))
                    Text("凭据保存在系统钥匙串，只用于本地调用 SteamCMD。首次登录需要在悬浮 HUD 里输入 Steam Guard 验证码。")
                        .font(WW.Font.text(9.5))
                }
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .onChange(of: password) { _, new in prefs.steamPassword = new }
        }
    }

    private var engineCard: some View {
        SettingsCard(title: "SteamCMD 引擎", symbol: "shippingbox", tint: WW.Palette.mint) {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(statusColor.opacity(0.14)).frame(width: 34, height: 34)
                    Image(systemName: steamcmd.installed ? "checkmark" : "arrow.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(statusColor)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(steamcmd.installed ? "引擎已就绪" : (steamcmd.installing ? "正在安装…" : "尚未安装"))
                        .font(WW.Font.rounded(12, .semibold))
                    Text(steamcmd.installed
                         ? "Valve 官方命令行客户端，下载内容写入本地库"
                         : "需要下载约 12 MB 的官方客户端，首次运行会自更新")
                        .font(WW.Font.text(10))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if steamcmd.installing {
                    ProgressView(value: steamcmd.installProgress)
                        .frame(width: 80)
                } else {
                    Button(steamcmd.installed ? "重新安装" : "安装 SteamCMD") {
                        Task { await steamcmd.install() }
                    }
                    .buttonStyle(CapsuleButtonStyle(kind: steamcmd.installed ? .glass : .primary, tint: WW.Palette.mint))
                }
            }

            if let error = steamcmd.lastError {
                Text(error).font(WW.Font.text(10)).foregroundStyle(WW.Palette.coral)
            }

            HStack(spacing: 8) {
                Button("在 Finder 中显示") {
                    let dir = SteamCMDService.root
                    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    NSWorkspace.shared.activateFileViewerSelecting([dir])
                }
                .buttonStyle(CapsuleButtonStyle(kind: .ghost))
                Spacer()
            }
        }
    }

    private var statusColor: Color {
        if steamcmd.installed { return WW.Palette.mint }
        return steamcmd.installing ? WW.Palette.amber : WW.Palette.coral
    }

    private var apiCard: some View {
        SettingsCard(title: "Steam Web API", symbol: "key.horizontal", tint: WW.Palette.amber) {
            VStack(spacing: 9) {
                field("API Key", placeholder: "32 位十六进制密钥") {
                    TextField("粘贴 API Key", text: $key)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, design: .monospaced))
                        .onSubmit { prefs.apiKey = key }
                }
                HStack(spacing: 8) {
                    Button("保存") { prefs.apiKey = key }
                        .buttonStyle(CapsuleButtonStyle(kind: .primary, tint: WW.Palette.amber))
                    Button("打开申请页") {
                        NSWorkspace.shared.open(URL(string: "https://steamcommunity.com/dev/apikey")!)
                    }
                    .buttonStyle(CapsuleButtonStyle(kind: .ghost))
                    Spacer()
                    Text("只用于搜索与元数据，不涉及下载")
                        .font(WW.Font.text(9))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private var miscCard: some View {
        SettingsCard(title: "库与 HUD", symbol: "rectangle.on.rectangle", tint: WW.Palette.coral) {
            VStack(spacing: 12) {
                Toggle(isOn: $prefs.autoShowHUD) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("开始下载时自动弹出 HUD").font(WW.Font.rounded(11.5, .semibold))
                        Text("右下角显示实时进度、速度与验证码输入").font(WW.Font.text(9.5)).foregroundStyle(.tertiary)
                    }
                }
                .toggleStyle(.switch)
                .controlSize(.small)

                HStack(spacing: 8) {
                    Text(LibraryStore.shared.directory.path)
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button("打开库目录") {
                        NSWorkspace.shared.open(LibraryStore.shared.directory)
                    }
                    .buttonStyle(CapsuleButtonStyle(kind: .ghost))
                }
            }
        }
    }

    private func field<Content: View>(_ label: String, placeholder: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(WW.Font.rounded(11, .medium))
                .foregroundStyle(.secondary)
                .frame(width: 62, alignment: .leading)
            content()
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.primary.opacity(0.05))
                        .overlay {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(.primary.opacity(0.07), lineWidth: 1)
                        }
                }
        }
    }
}

struct ChannelRow: View {
    var channel: DownloadChannel
    var selected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 13))
                    .foregroundStyle(selected ? WW.Palette.accent : Color.secondary.opacity(0.5))
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text(channel.label)
                        .font(WW.Font.rounded(12, .semibold))
                        .foregroundStyle(.primary)
                    Text(channel.detail)
                        .font(WW.Font.text(10.5))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(11)
            .background {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(selected ? WW.Palette.accent.opacity(0.08) : Color.primary.opacity(0.03))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .strokeBorder(selected ? WW.Palette.accent.opacity(0.25) : Color.primary.opacity(0.06), lineWidth: 1)
                    }
            }
        }
        .buttonStyle(.plain)
    }
}

struct SettingsCard<Content: View>: View {
    var title: String
    var symbol: String
    var tint: Color
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(tint)
                Text(title)
                    .font(WW.Font.rounded(12.5, .bold))
                Spacer()
            }
            content
        }
        .padding(15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(radius: WW.Radius.panel, tint: tint, strength: 0.04, shadow: false)
    }
}
