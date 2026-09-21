import SwiftUI

/// Single-line text that gently scrolls back and forth, but only when it is
/// too long to fit. Short titles stay centred and still.
struct MarqueeText: View {
    let text: String
    let font: Font
    let color: Color
    let width: CGFloat

    @State private var textWidth: CGFloat = 0
    @State private var offset: CGFloat = 0

    /// Points travelled per second while scrolling. Deliberately a slow crawl:
    /// the widget sits on the desktop all day, so drifting text should never
    /// pull the eye away from what you are actually doing.
    private static let speed: CGFloat = 5
    /// Held still at each end before creeping back.
    private static let pauseDuration: TimeInterval = 3.0

    private var overflow: CGFloat { max(0, textWidth - width) }
    private var isScrolling: Bool { overflow > 1 }

    var body: some View {
        Text(text)
            .font(font)
            .foregroundStyle(color)
            .lineLimit(1)
            .fixedSize()
            .background(widthReader)
            .offset(x: isScrolling ? offset : 0)
            .frame(width: width, alignment: isScrolling ? .leading : .center)
            .clipped()
            .onChange(of: text) { restart() }
            .onChange(of: textWidth) { restart() }
            .onAppear { restart() }
    }

    private var widthReader: some View {
        GeometryReader { proxy in
            Color.clear
                .task(id: proxy.size.width) { textWidth = proxy.size.width }
        }
    }

    private func restart() {
        offset = 0
        guard isScrolling else { return }
        let duration = TimeInterval(overflow / Self.speed)
        withAnimation(
            .easeInOut(duration: duration)
            .delay(Self.pauseDuration)
            .repeatForever(autoreverses: true)
        ) {
            offset = -overflow
        }
    }
}
