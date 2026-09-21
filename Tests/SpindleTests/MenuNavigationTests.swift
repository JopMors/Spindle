import Foundation
import Testing
@testable import Spindle

/// Covers the levels that are built in code. Anything sourced from Music.app
/// needs the app itself, so it is left to manual checking.
@Suite("Menu navigation")
@MainActor
struct MenuNavigationTests {

    private func makeModel() -> MenuViewModel {
        MenuViewModel(library: MusicLibrary())
    }

    @Test("Opens on the main menu")
    func startsAtMain() {
        let model = makeModel()

        #expect(model.level == .main)
        #expect(model.canGoBack == false)
        #expect(model.rows.map(\.id) == [
            MenuRowID.music, MenuRowID.shuffle, MenuRowID.repeatMode,
            MenuRowID.settings, MenuRowID.nowPlaying
        ])
    }

    @Test("Selecting Music descends a level and resets the highlight")
    func pushesIntoMusic() {
        let model = makeModel()
        model.moveSelection(by: 0)

        #expect(model.activateSelection() == nil)
        #expect(model.level == .music)
        #expect(model.canGoBack)
        #expect(model.selection == 0)
        #expect(model.rows.map(\.id) == [
            MenuRowID.playlists, MenuRowID.artists, MenuRowID.albums, MenuRowID.songs
        ])
    }

    @Test("Going back restores the highlight it was left on")
    func restoresSelectionOnPop() {
        let model = makeModel()
        // Move to Music, remember position 0, descend, then come back.
        _ = model.activateSelection()
        model.moveSelection(by: 2)
        #expect(model.selection == 2)

        #expect(model.goBack())
        #expect(model.level == .main)
        #expect(model.selection == 0)
    }

    @Test("Back from the top level is refused, so the caller can leave the menu")
    func refusesToPopPastMain() {
        let model = makeModel()

        #expect(model.goBack() == false)
        #expect(model.level == .main)
    }

    @Test("Selection cannot run off either end of the list")
    func clampsSelection() {
        let model = makeModel()

        model.moveSelection(by: -5)
        #expect(model.selection == 0)

        model.moveSelection(by: 99)
        #expect(model.selection == model.rows.count - 1)
    }

    @Test("Shuffle, Repeat and Settings rows return actions instead of navigating")
    func returnsActionsForLeafRows() {
        let model = makeModel()

        model.moveSelection(by: 1)
        #expect(model.activateSelection() == .cycleShuffle)
        #expect(model.level == .main)

        model.moveSelection(by: 1)
        #expect(model.activateSelection() == .cycleRepeat)

        model.moveSelection(by: 1)
        #expect(model.activateSelection() == .openSettings)

        model.moveSelection(by: 1)
        #expect(model.activateSelection() == .showNowPlaying)
    }

    @Test("Mode rows show their current value")
    func showsModeValues() {
        let model = makeModel()
        model.shuffleLabel = ShuffleMode.songs.label
        model.repeatLabel = RepeatMode.all.label
        model.refreshModeLabels()

        #expect(model.rows[1].accessory == .value("Songs"))
        #expect(model.rows[2].accessory == .value("All"))
    }

    @Test("Levels sourced from the library are marked as such")
    func flagsLibraryLevels() {
        #expect(MenuLevel.main.needsLibrary == false)
        #expect(MenuLevel.music.needsLibrary == false)
        #expect(MenuLevel.playlists.needsLibrary)
        #expect(MenuLevel.songs.needsLibrary)
        #expect(MenuLevel.playlist(index: 3, name: "Top 2000").title == "Top 2000")
    }
}
