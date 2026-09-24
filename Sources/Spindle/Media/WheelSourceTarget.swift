import Foundation

/// What the note at the bottom of the wheel opens.
///
/// Media follows whatever is playing — a browser tab with YouTube in it
/// included — which is what the button has always done. The other two pin it
/// to one app regardless of who owns the audio.
enum WheelSourceTarget: String, CaseIterable, Identifiable {
    case appleMusic
    case spotify
    case media

    static let appleMusicBundleIdentifier = "com.apple.Music"
    static let spotifyBundleIdentifier = "com.spotify.client"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .appleMusic: return "Apple Music"
        case .spotify: return "Spotify"
        case .media: return "Media"
        }
    }

    var detail: String {
        switch self {
        case .appleMusic: return "The note always opens Apple Music."
        case .spotify: return "The note always opens Spotify."
        case .media: return "The note opens whatever is playing, browsers included."
        }
    }

    /// The app to bring forward. `nil` leaves the choice to
    /// `SourceAppLauncher`'s fallback.
    func bundleIdentifier(nowPlaying: String?) -> String? {
        switch self {
        case .appleMusic: return Self.appleMusicBundleIdentifier
        case .spotify: return Self.spotifyBundleIdentifier
        case .media: return nowPlaying
        }
    }
}
