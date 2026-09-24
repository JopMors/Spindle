import SwiftUI

/// Three-way toggle for the note button, shown as logos rather than words.
///
/// The logos are drawn rather than lifted from the installed apps, so the
/// picker looks the same whether or not Spotify is on this Mac.
struct WheelTargetPicker: View {
    @Binding var selection: WheelSourceTarget

    private static let tileSize: CGFloat = 30
    private static let logoSize: CGFloat = 20

    var body: some View {
        HStack(spacing: 4) {
            ForEach(WheelSourceTarget.allCases) { target in
                tile(for: target)
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 9).fill(.quaternary))
    }

    private func tile(for target: WheelSourceTarget) -> some View {
        let isSelected = selection == target
        return Button { selection = target } label: {
            WheelTargetLogo(target: target)
                .frame(width: Self.logoSize, height: Self.logoSize)
                .frame(width: Self.tileSize, height: Self.tileSize)
                .background(
                    RoundedRectangle(cornerRadius: 7)
                        .fill(isSelected ? Color(nsColor: .controlBackgroundColor) : .clear)
                        .shadow(color: .black.opacity(isSelected ? 0.18 : 0), radius: 1, y: 0.5)
                )
                .opacity(isSelected ? 1 : 0.55)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(target.label)
        .accessibilityLabel(target.label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The mark for each target: Apple Music's tile, Spotify's circle, and a
/// display with a play button for everything else.
struct WheelTargetLogo: View {
    let target: WheelSourceTarget

    var body: some View {
        switch target {
        case .appleMusic: AppleMusicLogo()
        case .spotify: SpotifyLogo()
        case .media: MediaLogo()
        }
    }
}

private struct AppleMusicLogo: View {
    private static let top = Color(red: 0.98, green: 0.36, blue: 0.45)
    private static let bottom = Color(red: 0.98, green: 0.14, blue: 0.23)

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            RoundedRectangle(cornerRadius: side * 0.23, style: .continuous)
                .fill(LinearGradient(colors: [Self.top, Self.bottom], startPoint: .top, endPoint: .bottom))
                .overlay(
                    Image(systemName: "music.note")
                        .font(.system(size: side * 0.58, weight: .semibold))
                        .foregroundStyle(.white)
                )
                .frame(width: side, height: side)
        }
    }
}

private struct SpotifyLogo: View {
    private static let green = Color(red: 0.12, green: 0.84, blue: 0.38)
    /// Clockwise lean of the three arcs, as in the real mark.
    private static let tilt: Double = 8

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                Circle().fill(Self.green)
                SpotifyWaves()
                    .frame(width: side, height: side)
                    .rotationEffect(.degrees(Self.tilt))
            }
            .frame(width: side, height: side)
        }
    }
}

/// The three arcs, widest and heaviest on top.
private struct SpotifyWaves: View {
    /// Vertical position, half-width and stroke of each arc, as fractions of
    /// the logo's side.
    private static let arcs: [(y: CGFloat, halfWidth: CGFloat, stroke: CGFloat)] = [
        (0.36, 0.29, 0.085),
        (0.52, 0.25, 0.07),
        (0.66, 0.2, 0.06),
    ]

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            ZStack {
                ForEach(Self.arcs.indices, id: \.self) { index in
                    let arc = Self.arcs[index]
                    wave(y: arc.y, halfWidth: arc.halfWidth, side: side)
                        .stroke(.black, style: StrokeStyle(lineWidth: side * arc.stroke, lineCap: .round))
                }
            }
        }
    }

    private func wave(y: CGFloat, halfWidth: CGFloat, side: CGFloat) -> Path {
        let midX = side * 0.52
        let baseY = side * y
        // A slight tilt, as in the real mark: the left end sits a touch lower.
        let start = CGPoint(x: midX - side * halfWidth, y: baseY + side * 0.03)
        let end = CGPoint(x: midX + side * halfWidth, y: baseY + side * 0.045)
        let control = CGPoint(x: midX - side * 0.02, y: baseY - side * 0.09)
        var path = Path()
        path.move(to: start)
        path.addQuadCurve(to: end, control: control)
        return path
    }
}

private struct MediaLogo: View {
    var body: some View {
        GeometryReader { proxy in
            Image(systemName: "play.display")
                .resizable()
                .scaledToFit()
                .fontWeight(.medium)
                .foregroundStyle(.primary)
                .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}
