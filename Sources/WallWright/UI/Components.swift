import SwiftUI

// MARK: - 进度环

struct ProgressRing: View {
    var progress: Double
    var lineWidth: CGFloat = 5
    var tint: Color = WW.Palette.accent
    var showLabel: Bool = false
    var size: CGFloat = 34

    var body: some View {
        ZStack {
            Circle()
                .stroke(.primary.opacity(0.12), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.02, min(1, progress)))
                .stroke(
                    AngularGradient(colors: [tint.opacity(0.7), tint, tint.mix(with: WW.Palette.iris, by: 0.4)],
                                    center: .center, startAngle: .degrees(-90), endAngle: .degrees(270)),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.35), value: progress)

            if showLabel {
                Text("\(Int(progress * 100))")
                    .font(WW.Font.rounded(10, .bold))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - 标签

struct TagBadge: View {
    var text: String
    var symbol: String?
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 3) {
            if let symbol {
                Image(systemName: symbol).font(.system(size: 8.5, weight: .bold))
            }
            Text(text)
        }
        .font(WW.Font.rounded(10, .semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background {
            Capsule(style: .continuous)
                .fill(tint.opacity(0.13))
                .overlay { Capsule().strokeBorder(tint.opacity(0.18), lineWidth: 0.6) }
        }
    }
}

// MARK: - 远程图片

struct RemoteImage: View {
    var url: URL?
    var cornerRadius: CGFloat = WW.Radius.card
    @State private var loaded = false

    var body: some View {
        ZStack {
            LinearGradient(colors: [.primary.opacity(0.06), .primary.opacity(0.02)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)

            if let url {
                AsyncImage(url: url, transaction: .init(animation: .easeOut(duration: 0.35))) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .onAppear { loaded = true }
                    case .failure:
                        placeholder(symbol: "photo.badge.exclamationmark")
                    default:
                        shimmer
                    }
                }
            } else {
                placeholder(symbol: "photo")
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var shimmer: some View {
        Rectangle()
            .fill(.primary.opacity(0.05))
            .overlay {
                ProgressView().controlSize(.small).opacity(0.5)
            }
    }

    private func placeholder(symbol: String) -> some View {
        Image(systemName: symbol)
            .font(.system(size: 22, weight: .light))
            .foregroundStyle(.tertiary)
    }
}

// MARK: - 搜索框

struct GlassSearchField: View {
    @Binding var text: String
    var placeholder: String = "搜索创意工坊"
    var onSubmit: () -> Void = {}
    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(focused ? WW.Palette.accent : .secondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(WW.Font.text(13))
                .focused($focused)
                .onSubmit(onSubmit)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 9)
        .background {
            RoundedRectangle(cornerRadius: WW.Radius.field, style: .continuous)
                .fill(.primary.opacity(focused ? 0.06 : 0.045))
                .overlay {
                    RoundedRectangle(cornerRadius: WW.Radius.field, style: .continuous)
                        .strokeBorder(focused ? WW.Palette.accent.opacity(0.45) : .primary.opacity(0.07), lineWidth: 1)
                }
        }
        .animation(.easeOut(duration: 0.18), value: focused)
    }
}

// MARK: - 分区标题

struct SectionTitle: View {
    var title: String
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(WW.Font.rounded(19, .bold))
                .foregroundStyle(.primary)
            if let subtitle {
                Text(subtitle)
                    .font(WW.Font.text(11.5))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - 空状态

struct EmptyStateView: View {
    var symbol: String
    var title: String
    var message: String
    var action: (title: String, run: () -> Void)?

    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle().fill(.primary.opacity(0.05)).frame(width: 62, height: 62)
                Image(systemName: symbol)
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(.secondary)
            }
            VStack(spacing: 5) {
                Text(title).font(WW.Font.rounded(15, .semibold))
                Text(message)
                    .font(WW.Font.text(11.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            if let action {
                Button(action.title, action: action.run)
                    .buttonStyle(CapsuleButtonStyle(kind: .primary))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - 悬停放大

struct HoverLift: ViewModifier {
    @State private var hovering = false
    var scale: CGFloat = 1.012

    func body(content: Content) -> some View {
        content
            .scaleEffect(hovering ? scale : 1)
            .animation(.spring(response: 0.34, dampingFraction: 0.72), value: hovering)
            .onHover { hovering = $0 }
    }
}

extension View {
    func hoverLift(_ scale: CGFloat = 1.012) -> some View {
        modifier(HoverLift(scale: scale))
    }
}
