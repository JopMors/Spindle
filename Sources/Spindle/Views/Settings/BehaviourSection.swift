import SwiftUI

/// Placement, position lock and light/dark treatment.
struct BehaviourSection: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader("Behaviour")
            Picker("Placement", selection: $settings.placement) {
                ForEach(AppSettings.Placement.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)
            Text(settings.placement.detail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Toggle("Lock position", isOn: $settings.isPositionLocked)
            Text(lockDetail)
                .font(.caption)
                .foregroundStyle(.secondary)

            Picker("Appearance", selection: $settings.appearance) {
                ForEach(AppSettings.Appearance.allCases) { option in
                    Text(option.label).tag(option)
                }
            }
            .pickerStyle(.segmented)

            Toggle("Launch at login", isOn: $settings.launchesAtLogin)
            Text(launchDetail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var launchDetail: String {
        LaunchAtLogin.needsApproval
            ? "Approve Spindle in System Settings → General → Login Items."
            : "Starts the widget when you log in. Revocable from Login Items."
    }

    private var lockDetail: String {
        settings.isPositionLocked
            ? "Dragging is off, so it cannot be nudged by accident. ⌘-drag still moves it."
            : "Drag it anywhere to move it. Lock it once it is where you want it."
    }
}
