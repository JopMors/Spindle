import SwiftUI

/// Options for what the original's display shows, and how the wheel behaves.
struct ScreenSection: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader("Screen")
            Toggle("Black & white album cover", isOn: $settings.isArtworkMonochrome)
            Text("Desaturates the cover art. The title stays white either way.")
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Show progress & status", isOn: $settings.showsPlaybackDetail)
            Text("""
            The scrubber with elapsed and remaining time, and the status bar \
            carrying queue position, shuffle and repeat.
            """)
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Album art while browsing", isOn: $settings.showsMenuArtwork)
            Text("""
            Shows the cover of the highlighted song behind the menu. Each one is \
            a request to Music, so it waits for the highlight to settle first.
            """)
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Always show a volume bar", isOn: $settings.showsVolumeSlider)
            Text("""
            Keeps a draggable volume bar under the scrubber. Without it the bar \
            only appears while the wheel is turning — which you can still drag.
            """)
                .font(.caption)
                .foregroundStyle(.secondary)

            SectionHeader("Click wheel")
                .padding(.top, 4)
            Toggle("Wheel scrolls volume", isOn: $settings.isWheelScrollEnabled)
            Text("""
            Drag around the wheel, or scroll anywhere on the widget. In a menu \
            the same gesture moves the highlight.
            """)
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Wheel click sound", isOn: $settings.isWheelClickEnabled)
            Text("A short tick, one per step of the wheel.")
                .font(.caption)
                .foregroundStyle(.secondary)
            if settings.isWheelClickEnabled {
                LabeledSlider(
                    title: "Click volume",
                    value: $settings.wheelClickVolume,
                    range: 0...1,
                    format: LabeledSlider.percent
                )
            }

            SectionHeader("Menu playback")
                .padding(.top, 4)
            Toggle("Continue the list after a song", isOn: $settings.queuesRestOfList)
            Text("""
            Picking a song keeps the rest of its own playlist going behind it. \
            Music cannot queue from the middle of a playlist, so the widget \
            keeps the running order itself and plays each track out of your \
            playlist as the one before it ends. Nothing is copied or added to \
            your library. Turn this off and a chosen song plays on its own.
            """)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
