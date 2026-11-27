import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var auth: AuthStore
    @EnvironmentObject private var steamcmd: SteamCMDService
    @EnvironmentObject private var prefs: Preferences

    @State private var user = ""
    @State private var password = ""
    @State private var guardCode = ""
    @FocusState private var focus: Field?

    private enum Field { case user, password }

    private var locked: Bool { auth.signingIn }

    private var canSubmit: Bool {
        !locked && !user.trimmingCharacters(in: .whitespaces).isEmpty && !password.isEmpty
    }

    var body: some View {
        ZStack {
            AuroraBackground()

            VStack(spacing: 22) {
                header
                card
                footnote
            }
            .frame(maxWidth: 420)
            .padding(.horizontal, 32)
        }
        .ignoresSafeArea(.container, edges: .top)
        .onAppear {
            user = prefs.rememberAccount ? prefs.steamUser : ""
            password = prefs.rememberPassword ? prefs.steamPassword : ""
        }
        .sheet(item: $auth.guardPrompt) { prompt in
            guardSheet(prompt)
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            LogoMark(size: 52)
            VStack(spacing: 5) {
                Text("登录 Steam")
                    .font(WW.Font.rounded(19, .bold))
                Text("WallWright 需要你的 Steam 账号才能下载创意工坊内容")
                    .font(WW.Font.text(11.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 46)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 14) {
            field("账号", symbol: "person") {
                TextField("Steam 用户名", text: $user)
                    .textFieldStyle(.plain)
                    .font(WW.Font.text(12.5))
                    .focused($focus, equals: .user)
                    .disabled(locked)
                    .onSubmit { focus = .password }
                    .onChange(of: user) { _, _ in auth.clearError() }
            }
            .opacity(locked ? 0.55 : 1)

            field("密码", symbol: "lock") {
                SecureField("密码", text: $password)
                    .textFieldStyle(.plain)
                    .font(WW.Font.text(12.5))
                    .focused($focus, equals: .password)
                    .disabled(locked)
                    .onSubmit { submit() }
                    .onChange(of: password) { _, _ in auth.clearError() }
            }
            .opacity(locked ? 0.55 : 1)

            HStack(spacing: 16) {
                toggleRow("记住账号", isOn: $prefs.rememberAccount)
                toggleRow("记住密码", isOn: $prefs.rememberPassword)
                Spacer()
            }

            if let error = auth.errorMessage {
                HStack(alignment: .top, spacing: 5) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 9))
                    Text(error).font(WW.Font.text(10.5))
                }
                .foregroundStyle(WW.Palette.coral)
                .fixedSize(horizontal: false, vertical: true)
            }

            if !steamcmd.installed {
                engineSetup
            }

            HStack(spacing: 8) {
                if locked {
                    Button("取消") { auth.cancelSignIn() }
                        .buttonStyle(CapsuleButtonStyle(kind: .ghost))
                }
                Button(action: submit) {
                    HStack(spacing: 7) {
                        if locked {
                            ProgressView().controlSize(.small)
                        }
                        Text(locked ? "正在登录…" : "登录")
                            .frame(maxWidth: .infinity)
                    }
                    .frame(height: 20)
                }
                .buttonStyle(CapsuleButtonStyle(kind: .primary))
                .disabled(!canSubmit || !steamcmd.installed)
                .opacity(canSubmit && steamcmd.installed ? 1 : 0.5)
            }
        }
        .padding(20)
        .glassSurface(radius: 22, strength: 0.08)
    }

    private var engineSetup: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("还需要下载下载引擎（约 12 MB）")
                .font(WW.Font.rounded(11, .semibold))
            Text("Valve 官方的 SteamCMD，用来执行登录与下载。装在本机 `~/.wallwright/`，不会写入系统目录。")
                .font(WW.Font.text(10))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if steamcmd.installing {
                ProgressView(value: steamcmd.installProgress).frame(width: 160)
            } else {
                Button("安装 SteamCMD") {
                    Task { await steamcmd.install() }
                }
                .buttonStyle(CapsuleButtonStyle(kind: .glass, tint: WW.Palette.mint))
            }
            if let err = steamcmd.lastError {
                Text(err).font(WW.Font.text(10)).foregroundStyle(WW.Palette.coral)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(WW.Palette.mint.opacity(0.08))
        }
    }

    private var footnote: some View {
        VStack(spacing: 5) {
            HStack(spacing: 5) {
                Image(systemName: "lock.shield").font(.system(size: 9))
                Text("账号密码只保存在本机 credentials.json（权限 600）")
            }
            Text("不经过任何第三方服务器，只与 Steam 官方通信")
        }
        .font(WW.Font.text(9.5))
        .foregroundStyle(.tertiary)
        .multilineTextAlignment(.center)
        .padding(.bottom, 26)
    }

    private func guardSheet(_ prompt: AuthStore.GuardPrompt) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("需要 Steam Guard 验证码")
                    .font(WW.Font.rounded(15, .bold))
                Text("检查你的邮箱，或打开手机 Steam 令牌，输入 5 位验证码。")
                    .font(WW.Font.text(11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            TextField("验证码", text: $guardCode)
                .textFieldStyle(.plain)
                .font(WW.Font.rounded(16, .semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(.primary.opacity(0.06))
                        .overlay {
                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
                        }
                }

            HStack(spacing: 8) {
                Button("取消") {
                    auth.dismissGuard()
                    guardCode = ""
                }
                .buttonStyle(CapsuleButtonStyle(kind: .ghost))

                Button("提交") {
                    auth.submitGuardCode(guardCode)
                    guardCode = ""
                }
                .buttonStyle(CapsuleButtonStyle(kind: .primary))
                .disabled(guardCode.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(20)
        .frame(width: 320)
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            HStack(spacing: 5) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.system(size: 11))
                    .foregroundStyle(isOn.wrappedValue ? WW.Palette.accent : Color.secondary.opacity(0.55))
                Text(title)
                    .font(WW.Font.text(10.5))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(locked)
        .opacity(locked ? 0.55 : 1)
    }

    private func field<Content: View>(_ label: String, symbol: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(WW.Font.text(10)).foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Image(systemName: symbol)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(width: 13)
                content()
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 9)
            .background {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(.primary.opacity(locked ? 0.03 : 0.06))
                    .overlay {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .strokeBorder(.primary.opacity(0.08), lineWidth: 1)
                    }
            }
        }
    }

    private func submit() {
        guard canSubmit, steamcmd.installed else { return }
        focus = nil
        Task { await auth.signIn(user: user, password: password) }
    }
}
