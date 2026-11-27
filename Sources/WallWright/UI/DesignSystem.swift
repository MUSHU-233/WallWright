import SwiftUI

enum WW {
    enum Radius {
        static let hud: CGFloat = 30
        static let panel: CGFloat = 26
        static let card: CGFloat = 22
        static let chip: CGFloat = 13
        static let field: CGFloat = 16
    }

    enum Palette {
        static let accent = Color(red: 0.36, green: 0.53, blue: 1.00)
        static let iris = Color(red: 0.60, green: 0.42, blue: 0.98)
        static let mint = Color(red: 0.28, green: 0.82, blue: 0.72)
        static let coral = Color(red: 0.99, green: 0.55, blue: 0.46)
        static let amber = Color(red: 1.00, green: 0.75, blue: 0.36)

        static var accentGradient: LinearGradient {
            LinearGradient(colors: [accent, iris], startPoint: .topLeading, endPoint: .bottomTrailing)
        }

        static func tint(for kind: ContentKind) -> Color {
            switch kind {
            case .video: return coral
            case .scene: return iris
            case .web: return mint
            case .image: return accent
            case .application: return amber
            case .unknown: return .gray
            }
        }
    }

    enum Font {
        static func rounded(_ size: CGFloat, _ weight: SwiftUI.Font.Weight = .semibold) -> SwiftUI.Font {
            .system(size: size, weight: weight, design: .rounded)
        }
        static func text(_ size: CGFloat, _ weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            .system(size: size, weight: weight)
        }
    }
}

// MARK: - 极光背景

struct AuroraBackground: View {
    @Environment(\.colorScheme) private var scheme
    @State private var drift: CGFloat = 0

    var intensity: Double = 1

    var body: some View {
        ZStack {
            base

            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                ZStack {
                    blob(WW.Palette.accent, size: w * 0.75)
                        .offset(x: -w * 0.28 + drift * 24, y: -h * 0.34 + drift * 18)
                    blob(WW.Palette.iris, size: w * 0.65)
                        .offset(x: w * 0.36 - drift * 18, y: h * 0.12 + drift * 26)
                    blob(WW.Palette.mint, size: w * 0.5)
                        .offset(x: -w * 0.1, y: h * 0.44 - drift * 20)
                    blob(WW.Palette.coral, size: w * 0.36)
                        .offset(x: w * 0.3, y: -h * 0.3 + drift * 12)
                }
                .blur(radius: 90)
                .opacity(scheme == .dark ? 0.55 : 0.42)
            }

            LinearGradient(
                colors: scheme == .dark
                    ? [Color.black.opacity(0.15), Color.black.opacity(0.55)]
                    : [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                startPoint: .top, endPoint: .bottom
            )
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 26).repeatForever(autoreverses: true)) {
                drift = 1
            }
        }
    }

    private var base: some View {
        Rectangle().fill(
            scheme == .dark
                ? Color(red: 0.055, green: 0.06, blue: 0.085)
                : Color(red: 0.965, green: 0.968, blue: 0.985)
        )
    }

    private func blob(_ color: Color, size: CGFloat) -> some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .blur(radius: 40)
            .opacity(intensity)
    }
}

// MARK: - 玻璃面

struct GlassSurface: ViewModifier {
    var radius: CGFloat = WW.Radius.card
    var tint: Color = .clear
    var strength: Double = 0
    var interactive: Bool = false
    var shadow: Bool = true

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        content
            .glassEffect(
                interactive
                    ? .regular.tint(tint.opacity(strength)).interactive()
                    : .regular.tint(tint.opacity(strength)),
                in: .rect(cornerRadius: radius)
            )
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.55), .white.opacity(0.12), .white.opacity(0.02)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .blendMode(.plusLighter)
                .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(shadow ? 0.16 : 0), radius: 26, x: 0, y: 12)
    }
}

extension View {
    func glassSurface(radius: CGFloat = WW.Radius.card,
                      tint: Color = .clear,
                      strength: Double = 0,
                      interactive: Bool = false,
                      shadow: Bool = true) -> some View {
        modifier(GlassSurface(radius: radius, tint: tint, strength: strength, interactive: interactive, shadow: shadow))
    }
}

// MARK: - 胶囊按钮

struct CapsuleButtonStyle: ButtonStyle {
    enum Kind { case primary, glass, ghost }
    var kind: Kind = .glass
    var tint: Color = WW.Palette.accent

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(WW.Font.rounded(12.5, .semibold))
            .foregroundStyle(foreground)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background {
                switch kind {
                case .primary:
                    Capsule(style: .continuous)
                        .fill(LinearGradient(colors: [tint, tint.mix(with: WW.Palette.iris, by: 0.45)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay {
                            Capsule().strokeBorder(.white.opacity(0.35), lineWidth: 0.8)
                        }
                case .glass:
                    Color.clear
                        .glassEffect(.regular.interactive(), in: .capsule)
                case .ghost:
                    Color.clear
                }
            }
            .scaleEffect(configuration.isPressed ? 0.965 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }

    private var foreground: Color {
        kind == .primary ? .white : .primary
    }
}

extension Color {
    func mix(with other: Color, by ratio: Double) -> Color {
        let a = NSColor(self).usingColorSpace(.sRGB) ?? .black
        let b = NSColor(other).usingColorSpace(.sRGB) ?? .black
        return Color(
            .sRGB,
            red: Double(a.redComponent) * (1 - ratio) + Double(b.redComponent) * ratio,
            green: Double(a.greenComponent) * (1 - ratio) + Double(b.greenComponent) * ratio,
            blue: Double(a.blueComponent) * (1 - ratio) + Double(b.blueComponent) * ratio,
            opacity: 1
        )
    }
}
