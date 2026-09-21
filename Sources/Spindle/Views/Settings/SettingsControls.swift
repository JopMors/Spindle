import SwiftUI

/// Small shared controls used across the settings sections.

struct SectionHeader: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        Text(title)
            .font(.headline)
    }
}

struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                Text(format(value))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .font(.callout)
            Slider(value: $value, in: range)
        }
    }
}

/// Formats a 0...1 value as a percentage.
extension LabeledSlider {
    static func percent(_ value: Double) -> String {
        String(format: "%.0f%%", value * 100)
    }

    static func points(_ value: Double) -> String {
        String(format: "%.0f pt", value)
    }
}

/// One-tap preset for the standard macOS widget widths.
struct WidthPreset: View {
    let title: String
    let width: Double
    @Binding var selected: Double

    private var isActive: Bool { abs(selected - width) < 0.5 }

    var body: some View {
        Button(title) { selected = width }
            .buttonStyle(.bordered)
            .tint(isActive ? .accentColor : nil)
            .controlSize(.small)
    }
}
