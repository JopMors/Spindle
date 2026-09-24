import AppKit
import Foundation

/// Fetches cover art for the highlighted menu row.
///
/// Every preview is an AppleScript round trip to Music, and the highlight moves
/// a step at a time under the wheel, so this waits for the selection to settle
/// before asking and remembers what it has already seen. Without both, scrolling
/// a long playlist would fire one query per row.
@MainActor
final class MenuArtworkPreview {

    /// How long the highlight has to sit still before a query goes out. Long
    /// enough to skip everything you scroll past, short enough not to feel lazy.
    static let defaultSettleDelay: Duration = .milliseconds(280)
    /// Covers are full-size JPEGs — 1200x1200 on a real track — so the cache is
    /// held to a size that cannot quietly become tens of megabytes.
    private static let cacheLimit = 24

    private let library: MusicLibraryProviding
    private let settleDelay: Duration
    private var task: Task<Void, Never>?
    private var cache: [String: NSImage?] = [:]
    private var order: [String] = []
    /// What the highlight is on right now, so a slow answer for a row we have
    /// since scrolled past is discarded rather than shown.
    private var currentKey: String?

    init(
        library: MusicLibraryProviding,
        settleDelay: Duration = MenuArtworkPreview.defaultSettleDelay
    ) {
        self.library = library
        self.settleDelay = settleDelay
    }

    /// A track came under the highlight. `onImage` is called on the main actor,
    /// possibly more than once: immediately from cache, or later from Music.
    func request(
        playlistIndex: Int?,
        trackIndex: Int,
        onImage: @escaping (NSImage?) -> Void
    ) {
        let key = Self.key(playlistIndex: playlistIndex, trackIndex: trackIndex)
        task?.cancel()
        currentKey = key

        if let cached = cache[key] {
            onImage(cached)
            return
        }

        task = Task { [weak self] in
            try? await Task.sleep(for: self?.settleDelay ?? Self.defaultSettleDelay)
            guard !Task.isCancelled, let self else { return }
            self.library.artwork(playlistIndex: playlistIndex, trackIndex: trackIndex) { data in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let image = data.flatMap(NSImage.init(data:))
                    self.store(image, for: key)
                    guard self.currentKey == key else { return }
                    onImage(image)
                }
            }
        }
    }

    /// The highlight is on something that is not a track, or previews are off.
    func cancel() {
        task?.cancel()
        task = nil
        currentKey = nil
    }

    /// The library changed underneath: positions now mean other tracks.
    func clearCache() {
        cancel()
        cache = [:]
        order = []
    }

    private func store(_ image: NSImage?, for key: String) {
        if cache[key] == nil { order.append(key) }
        cache[key] = image
        while order.count > Self.cacheLimit {
            cache.removeValue(forKey: order.removeFirst())
        }
    }

    private static func key(playlistIndex: Int?, trackIndex: Int) -> String {
        "\(playlistIndex.map(String.init) ?? "library"):\(trackIndex)"
    }
}
