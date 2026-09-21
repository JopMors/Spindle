import SwiftUI

/// A miniature widget used to pick a skin.
struct ThemeSwatch: View {
    let theme: Theme
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    // Glass skins are mostly transparent, so they need a
                    // stand-in backdrop to be legible as a swatch.
                    .fill(theme.isGlass ? AnyShapeStyle(swatchBackdrop) : AnyShapeStyle(Color.clear))
                    .overlay(RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(theme.bodyGradient))
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(theme.bodyBorder.color, lineWidth: theme.borderWidth)
                    )
                    .overlay(swatchDetail)
                    .frame(height: 52)
                    .overlay(selectionRing)
                Text(theme.name)
                    .font(.system(size: 9))
                    .foregroundStyle(isSelected ? .primary : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
        .help(theme.name)
    }

    /// Stands in for the wallpaper behind the translucent glass skins.
    private var swatchBackdrop: LinearGradient {
        LinearGradient(
            colors: [Color(nsColor: .systemIndigo), Color(nsColor: .systemTeal)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Miniature screen and wheel so each swatch reads as the device.
    private var swatchDetail: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(theme.screenBackground.color)
                .frame(width: 22, height: 15)
            Circle()
                .fill(theme.wheelGradient)
                .overlay(Circle().strokeBorder(theme.wheelBorder.color, lineWidth: 0.5))
                .frame(width: 17, height: 17)
        }
    }

    @ViewBuilder
    private var selectionRing: some View {
        if isSelected {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(Color.accentColor, lineWidth: 2)
                .padding(-2)
        }
    }
}
