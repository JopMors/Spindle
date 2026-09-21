import AppKit
import Foundation
import Testing
@testable import Spindle

@Suite("Album art while browsing")
@MainActor
struct MenuArtworkTests {

    /// Short enough that the tests do not sit waiting on the real one, long
    /// enough that the moves below still land inside a single settle window.
    private static let settleDelay: Duration = .milliseconds(30)

    /// Walks the menu down a path of row titles, selecting each in turn.
    private func descend(_ model: MenuViewModel, through titles: [String]) {
        for title in titles {
            guard let index = model.rows.firstIndex(where: { $0.title == title }) else {
                Issue.record("no row titled \(title) in \(model.rows.map(\.title))")
                return
            }
            model.moveSelection(by: index - model.selection)
            _ = model.activateSelection()
        }
    }

    /// Polls rather than sleeping a fixed span: a fixed wait races the test
    /// runner's own scheduling and fails intermittently on a busy machine.
    private func waitForRequests(_ library: StubLibrary) async throws {
        for _ in 0..<200 where library.artworkRequests.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    /// The request going out and the cover landing in the cache are separate
    /// hops. Waiting for the image itself is what proves the cache is warm.
    private func waitForImage(_ model: MenuViewModel) async throws {
        for _ in 0..<200 where model.previewArtwork == nil {
            try await Task.sleep(for: .milliseconds(10))
        }
    }

    /// A real image, so `NSImage` decodes it and `previewArtwork` becomes
    /// non-nil — a byte of nonsense would cache as "no cover".
    private static func swatchPNG() -> Data {
        let image = NSImage(size: NSSize(width: 2, height: 2))
        image.lockFocus()
        NSColor.red.drawSwatch(in: NSRect(x: 0, y: 0, width: 2, height: 2))
        image.unlockFocus()
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return Data() }
        return png
    }

    @Test("Scrolling past rows does not ask Music for every cover")
    func artworkPreviewIsDebounced() async throws {
        let library = StubLibrary()
        library.artworkResult = Data([0x00])
        let model = MenuViewModel(library: library, artworkSettleDelay: Self.settleDelay)
        descend(model, through: ["Music", "Playlists", "Top 2000"])

        // Straight past two track rows and onto a third.
        model.moveSelection(by: 1)
        model.moveSelection(by: 1)
        model.moveSelection(by: 1)
        #expect(library.artworkRequests.isEmpty, "nothing goes out while the highlight moves")

        try await waitForRequests(library)

        // Only the row it came to rest on.
        #expect(library.artworkRequests == [.init(playlist: 1, track: 3)])
    }

    @Test("Rows that are not tracks have no cover to show")
    func artworkPreviewClearsOnNonTrackRows() async throws {
        let library = StubLibrary()
        let model = MenuViewModel(library: library, artworkSettleDelay: Self.settleDelay)

        // The main menu is Music, Shuffle, Repeat, Settings, Now Playing.
        model.moveSelection(by: 1)
        try await Task.sleep(for: .milliseconds(120))

        #expect(library.artworkRequests.isEmpty)
        #expect(model.previewArtwork == nil)
    }

    @Test("A cover already seen is shown without asking again")
    func cachesCovers() async throws {
        let library = StubLibrary()
        library.artworkResult = Self.swatchPNG()
        let model = MenuViewModel(library: library, artworkSettleDelay: Self.settleDelay)
        descend(model, through: ["Music", "Playlists", "Top 2000"])

        model.moveSelection(by: 1)
        try await waitForImage(model)
        #expect(library.artworkRequests == [.init(playlist: 1, track: 1)])

        // Away and back again: the second visit comes out of the cache.
        model.moveSelection(by: 1)
        model.moveSelection(by: -1)
        try await Task.sleep(for: .milliseconds(120))

        #expect(library.artworkRequests.filter { $0.track == 1 }.count == 1)
        #expect(model.previewArtwork != nil)
    }
}
