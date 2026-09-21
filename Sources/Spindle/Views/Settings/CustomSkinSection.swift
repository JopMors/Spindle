import SwiftUI

/// Sliders and colour wells for the user-editable skin.
///
/// Editing anything here switches the active skin to Custom, so a slider always
/// has a visible effect rather than silently changing an unselected skin.
struct CustomSkinSection: View {
    @ObservedObject var settings: AppSettings

    @State private var editingTarget: ColorTarget = .body

    /// Brightness the wheel snaps to when the edited colour or the appearance
    /// changes, so the slider never jumps to a stale derived value.
    private static let defaultBrightness = 0.5

    /// Which colour the wheel is currently editing.
    enum ColorTarget: String, CaseIterable, Identifiable {
        case body
        case border

        var id: String { rawValue }

        var label: String {
            switch self {
            case .body: return "Body colour"
            case .border: return "Border colour"
            }
        }

        var keyPath: WritableKeyPath<CustomSkin, HexColor> {
            switch self {
            case .body: return \.tint
            case .border: return \.borderColor
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            colorRow
            LabeledSlider(
                title: "Body opacity",
                value: binding(\.bodyOpacity),
                range: 0...1,
                format: LabeledSlider.percent
            )
            LabeledSlider(
                title: "Border opacity",
                value: binding(\.borderOpacity),
                range: 0...1,
                format: LabeledSlider.percent
            )
            LabeledSlider(
                title: "Border width",
                value: binding(\.borderWidth),
                range: 0...6,
                format: { String(format: "%.1f pt", $0) }
            )
            LabeledSlider(
                title: "Click wheel opacity",
                value: binding(\.wheelOpacity),
                range: 0...1,
                format: LabeledSlider.percent
            )
            LabeledSlider(
                title: "Screen dim",
                value: binding(\.screenOpacity),
                range: 0...1,
                format: LabeledSlider.percent
            )
            LabeledSlider(
                title: "Title scrim",
                value: binding(\.textScrimOpacity),
                range: 0...1,
                format: LabeledSlider.percent
            )
            Toggle("Blur wallpaper behind widget", isOn: binding(\.isGlass))
            resetButton
        }
    }

    private var header: some View {
        HStack {
            SectionHeader("Custom Skin")
            Spacer()
            if !settings.isCustomSkinSelected {
                Text("Editing selects Custom")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private var colorRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            Picker("", selection: $editingTarget) {
                ForEach(ColorTarget.allCases) { target in
                    Text(target.label).tag(target)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            ColorWheelPicker(color: hexBinding(editingTarget.keyPath))
        }
        .onChange(of: editingTarget) { resetBrightness(of: editingTarget) }
        .onChange(of: settings.appearance) { resetBrightness(of: editingTarget) }
    }

    /// Snaps the edited colour to the default brightness, keeping its hue.
    /// Writes the skin directly so an appearance switch doesn't select Custom.
    private func resetBrightness(of target: ColorTarget) {
        let keyPath = target.keyPath
        var skin = settings.customSkin
        skin[keyPath: keyPath] = skin[keyPath: keyPath].withBrightness(Self.defaultBrightness)
        settings.customSkin = skin
    }

    private var resetButton: some View {
        Button("Reset Custom Skin") {
            settings.customSkin = CustomSkin()
            settings.selectedThemeID = CustomSkin.themeID
        }
        .controlSize(.small)
    }

    // MARK: - Bindings

    /// Writes through to the custom skin and makes it the active selection.
    private func binding<T>(_ keyPath: WritableKeyPath<CustomSkin, T>) -> Binding<T> {
        Binding(
            get: { settings.customSkin[keyPath: keyPath] },
            set: { newValue in
                settings.customSkin[keyPath: keyPath] = newValue
                settings.selectedThemeID = CustomSkin.themeID
            }
        )
    }

    private func hexBinding(_ keyPath: WritableKeyPath<CustomSkin, HexColor>) -> Binding<HexColor> {
        Binding(
            get: { settings.customSkin[keyPath: keyPath] },
            set: { newValue in
                settings.customSkin[keyPath: keyPath] = newValue
                settings.selectedThemeID = CustomSkin.themeID
            }
        )
    }
}
