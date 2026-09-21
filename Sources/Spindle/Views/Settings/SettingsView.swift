import SwiftUI

/// Customisation panel, opened from the menu bar or the wheel's MENU button.
///
/// Every control writes straight through to `UserDefaults`, so whatever is set
/// here is what the widget uses on the next launch.
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    let backendDescription: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SkinPickerSection(settings: settings)
                Divider()
                CustomSkinSection(settings: settings)
                Divider()
                LayoutSection(settings: settings)
                Divider()
                ScreenSection(settings: settings)
                Divider()
                BehaviourSection(settings: settings)
                Divider()
                footer
            }
            .padding(20)
        }
        .frame(width: 400, height: 620)
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Media source")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(backendDescription)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("""
            MENU on the click wheel reopens this window; \
            the music note opens Apple Music.
            """)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }
}
