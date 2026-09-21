import SwiftUI

/// Width and corner radius.
struct LayoutSection: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Size & Shape")
            LabeledSlider(
                title: "Width",
                value: $settings.width,
                range: SpindleMetrics.minWidth...SpindleMetrics.maxWidth,
                format: LabeledSlider.points
            )
            // An even ladder. The old set jumped 155 → 329 with nothing usable
            // in between, which is a wide gap on a 14" screen.
            HStack(spacing: 8) {
                WidthPreset(
                    title: "Small",
                    width: SpindleMetrics.smallWidgetWidth,
                    selected: $settings.width
                )
                WidthPreset(
                    title: "Medium",
                    width: SpindleMetrics.mediumWidth,
                    selected: $settings.width
                )
                WidthPreset(
                    title: "Large",
                    width: SpindleMetrics.largeWidth,
                    selected: $settings.width
                )
                WidthPreset(
                    title: "Huge",
                    width: SpindleMetrics.mediumWidgetWidth,
                    selected: $settings.width
                )
            }
            Text("Small and Huge line up with the macOS small and medium widget grid.")
                .font(.caption)
                .foregroundStyle(.secondary)
            LabeledSlider(
                title: "Transparency",
                value: transparencyBinding,
                range: 0...(1 - AppSettings.minOpacity),
                format: LabeledSlider.percent
            )
            // The ceiling moves with the width: a narrow body cannot round its
            // corners past the screen sitting inside it.
            LabeledSlider(
                title: "Corner radius",
                value: $settings.cornerRadius,
                range: AppSettings.minCornerRadius...Double(settings.metrics.maxCornerRadius),
                format: LabeledSlider.points
            )
        }
    }

    /// Presented as transparency, stored as opacity.
    private var transparencyBinding: Binding<Double> {
        Binding(
            get: { 1 - settings.overallOpacity },
            set: { settings.overallOpacity = 1 - $0 }
        )
    }
}
