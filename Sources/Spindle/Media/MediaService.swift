import Foundation

/// The single seam between the UI and however now-playing data is obtained.
///
/// Views and view models depend only on this, so backends can be swapped or
/// stacked without touching anything above.
protocol MediaService: AnyObject {
    /// Called on the main queue whenever state changes.
    var onUpdate: ((NowPlaying) -> Void)? { get set }
    /// Called on the main queue when the backend cannot provide data.
    var onFailure: ((MediaServiceError) -> Void)? { get set }

    /// Human-readable name of the active backend, for the settings panel.
    var backendDescription: String { get }

    func start()
    func stop()
    func send(_ command: TransportCommand)
    /// Jumps to a point in the current track, in seconds from its start.
    func seek(to seconds: TimeInterval)
}

enum MediaServiceError: Equatable {
    case adapterUnavailable(String)
    case adapterExited(String)

    var message: String {
        switch self {
        case .adapterUnavailable(let detail): return detail
        case .adapterExited(let detail): return detail
        }
    }
}
