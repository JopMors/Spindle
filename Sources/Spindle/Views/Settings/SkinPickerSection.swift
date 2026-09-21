import SwiftUI

/// Grid of skin swatches, including the live custom skin.
struct SkinPickerSection: View {
    @ObservedObject var settings: AppSettings

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 4)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader("Skin")
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(settings.availableThemes) { theme in
                    ThemeSwatch(
                        theme: theme,
                        isSelected: theme.id == settings.selectedThemeID,
                        action: { settings.selectedThemeID = theme.id }
                    )
                }
            }
        }
    }
}
