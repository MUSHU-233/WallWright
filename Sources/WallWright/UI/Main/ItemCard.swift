import SwiftUI

struct ItemCard: View {
    var item: WorkshopItem
    var onOpen: () -> Void
    var onDownload: () -> Void
    @State private var hover = false

    private var accent: Color { WW.Palette.tint(for: item.kind) }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            cover
            meta
        }
        .padding(9)
        .glassSurface(radius: WW.Radius.card, tint: accent, strength: hover ? 0.10 : 0.03, interactive: true)
        .hoverLift(1.018)
        .onHover { hover = $0 }
        .contentShape(RoundedRectangle(cornerRadius: WW.Radius.card, style: .continuous))
        .onTapGesture(perform: onOpen)
    }

    private var cover: some View {
        ZStack(alignment: .bottomLeading) {
            RemoteImage(url: item.previewURL, cornerRadius: 15)
                .frame(height: 138)
                .overlay {
                    LinearGradient(colors: [.clear, .black.opacity(0.62)],
                                   startPoint: .center, endPoint: .bottom)
                        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(WW.Font.rounded(12.5, .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .shadow(color: .black.opacity(0.35), radius: 4, y: 1)
                if let resolution = item.resolution {
                    Text(resolution)
                        .font(WW.Font.rounded(9, .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 10)
            .padding(.bottom, 9)

            HStack {
                TagBadge(text: item.kind.label, symbol: item.kind.symbol, tint: .white.opacity(0.92))
                Spacer()
            }
            .padding(8)
            .frame(maxHeight: .infinity, alignment: .top)

            if hover {
                HStack {
                    Spacer()
                    Button(action: onDownload) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 26)
                            .background(Circle().fill(accent.gradient))
                            .overlay { Circle().strokeBorder(.white.opacity(0.4), lineWidth: 0.8) }
                            .shadow(color: accent.opacity(0.5), radius: 8, y: 3)
                    }
                    .buttonStyle(.plain)
                    .padding(8)
                    .frame(maxHeight: .infinity, alignment: .center)
                }
                .transition(.opacity)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(.white.opacity(0.14), lineWidth: 0.8)
        }
        .animation(.easeOut(duration: 0.18), value: hover)
    }

    private var meta: some View {
        HStack(spacing: 8) {
            HStack(spacing: 3) {
                Image(systemName: "person.2.fill").font(.system(size: 8))
                Text(item.subsText)
            }
            .font(WW.Font.rounded(9.5, .medium))
            .foregroundStyle(.secondary)

            Text("·").foregroundStyle(.quaternary).font(.system(size: 8))

            Text(item.sizeText)
                .font(WW.Font.rounded(9.5, .medium))
                .foregroundStyle(.secondary)

            Spacer()

            if item.isAudioResponsive {
                Image(systemName: "waveform")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(WW.Palette.mint)
            }
        }
        .padding(.horizontal, 3)
        .padding(.bottom, 1)
    }
}

extension Color {
    var gradient: LinearGradient {
        LinearGradient(colors: [self, self.mix(with: WW.Palette.iris, by: 0.5)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
