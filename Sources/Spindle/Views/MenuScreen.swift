import SwiftUI

/// The original's menu: a title bar and a list of rows with one highlighted.
///
/// The list is windowed rather than scrolled — the real device moved a fixed
/// highlight through a fixed number of lines, and a scroll view would both look
/// wrong and fight the wheel for the gesture.
struct MenuScreen: View {
    @ObservedObject var model: MenuViewModel
    let theme: Theme
    let metrics: SpindleMetrics
    /// Clicking a row does what scrolling to it and pressing centre does.
    var onSelectRow: (String) -> Void = { _ in }

    var body: some View {
        ZStack {
            artworkBackdrop
            list
        }
    }

    /// The highlighted track's cover, blurred and held well back so the rows
    /// stay the thing you are reading.
    @ViewBuilder
    private var artworkBackdrop: some View {
        if let artwork = model.previewArtwork {
            Image(nsImage: artwork)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: metrics.screenWidth, height: metrics.screenHeight)
                .clipped()
                .blur(radius: 7)
                .opacity(0.34)
                .allowsHitTesting(false)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: artwork)
        }
    }

    private var list: some View {
        VStack(spacing: 0) {
            ScreenStatusBar(
                title: model.level.title,
                isPlaying: false,
                showsPlaybackGlyph: false,
                shuffle: .off,
                repeatMode: .off,
                theme: theme,
                metrics: metrics
            )
            .background(theme.screenText.color.opacity(0.12))

            content
        }
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage = model.errorMessage {
            centred {
                Text(errorMessage)
                    .font(.system(size: metrics.statusFontSize))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 8)
            }
        } else if model.isLoading {
            centred {
                ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.7)
            }
        } else if model.rows.isEmpty {
            centred {
                Text("Empty")
                    .font(.system(size: metrics.statusFontSize))
            }
        } else {
            rowList
        }
    }

    private func centred<V: View>(@ViewBuilder _ inner: () -> V) -> some View {
        VStack {
            Spacer(minLength: 0)
            inner()
                .foregroundStyle(theme.screenSecondaryText.color)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity)
    }

    private var rowList: some View {
        VStack(spacing: 0) {
            ForEach(visibleRows) { row in
                MenuRowView(
                    row: row,
                    isSelected: row.id == selectedID,
                    theme: theme,
                    metrics: metrics
                )
                .contentShape(Rectangle())
                .onTapGesture { onSelectRow(row.id) }
            }
            Spacer(minLength: 0)
        }
    }

    private var selectedID: String? {
        guard model.selection < model.rows.count else { return nil }
        return model.rows[model.selection].id
    }

    /// The slice of rows around the highlight that fits on the screen.
    private var visibleRows: [MenuRow] {
        let capacity = metrics.menuVisibleRows
        guard model.rows.count > capacity else { return model.rows }
        let half = capacity / 2
        let start = min(max(model.selection - half, 0), model.rows.count - capacity)
        return Array(model.rows[start..<(start + capacity)])
    }
}

/// One line of the menu. Selected rows invert, as they did on the device.
private struct MenuRowView: View {
    let row: MenuRow
    let isSelected: Bool
    let theme: Theme
    let metrics: SpindleMetrics

    var body: some View {
        HStack(spacing: 3) {
            Text(row.title)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 2)
            accessory
        }
        .font(.system(size: metrics.statusFontSize * 1.1, weight: isSelected ? .semibold : .regular))
        .foregroundStyle(isSelected ? selectedForeground : theme.screenText.color)
        .padding(.horizontal, metrics.screenTextInset)
        .frame(height: metrics.menuRowHeight)
        .frame(maxWidth: .infinity)
        .background(isSelected ? highlight : .clear)
    }

    /// The highlight bar is drawn from the screen's text colour, so it is
    /// always the strongest contrast the skin has against its own background.
    private var highlight: Color {
        theme.screenText.opaqueColor.opacity(0.92)
    }

    /// Inverted against the *bar*, not the screen background. A skin can set
    /// the screen background to anything — transparent, or the same tone as
    /// the text — and reading the label off it would make the selected row
    /// invisible. Deriving it from the bar cannot.
    private var selectedForeground: Color {
        theme.screenText.brightness > 0.55 ? .black : .white
    }

    @ViewBuilder
    private var accessory: some View {
        switch row.accessory {
        case .chevron:
            Image(systemName: "chevron.right")
                .font(.system(size: metrics.statusFontSize * 0.8, weight: .semibold))
                .opacity(0.7)
        case .value(let text):
            Text(text)
                .lineLimit(1)
                .opacity(0.7)
        case .none:
            EmptyView()
        }
    }
}
