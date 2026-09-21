import AppKit
import Combine

/// Bridges a `MediaService` to the SwiftUI views. Owns no AppKit windows and
/// knows nothing about which backend is supplying data.
@MainActor
final class NowPlayingViewModel: ObservableObject {

    @Published private(set) var nowPlaying: NowPlaying = .idle
    @Published private(set) var artwork: NSImage?
    /// Set when the backend cannot supply data; surfaced on the widget's screen.
    @Published private(set) var errorMessage: String?

    /// Bumped on every track change so the view can animate artwork swaps.
    @Published private(set) var artworkGeneration = 0

    private let service: MediaService

    var backendDescription: String { service.backendDescription }

    init(service: MediaService) {
        self.service = service
        configure()
    }

    private func configure() {
        service.onUpdate = { [weak self] state in
            self?.apply(state)
        }
        service.onFailure = { [weak self] error in
            self?.errorMessage = error.message
        }
    }

    func start() { service.start() }
    func stop() { service.stop() }

    private func apply(_ state: NowPlaying) {
        let artworkChanged = state.artworkData != nowPlaying.artworkData
        errorMessage = nil
        nowPlaying = state
        Diagnostics.log(state, artworkChanged: artworkChanged)

        guard artworkChanged else { return }
        artwork = state.artworkData.flatMap(NSImage.init(data:))
        artworkGeneration += 1
    }

    // MARK: - Transport

    func send(_ command: TransportCommand) {
        service.send(command)
    }

    func seek(to seconds: TimeInterval) {
        service.seek(to: seconds)
    }
}
