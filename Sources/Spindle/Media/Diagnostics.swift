import Foundation

/// Opt-in stderr logging of now-playing updates.
///
/// Enable by launching the binary with `IPODWIDGET_DEBUG=1`, which is the
/// quickest way to confirm the perl adapter is feeding the UI:
///
///     IPODWIDGET_DEBUG=1 "dist/Spindle.app/Contents/MacOS/Spindle"
enum Diagnostics {

    static let isEnabled = ProcessInfo.processInfo.environment["IPODWIDGET_DEBUG"] == "1"

    /// Free-form trace line, used for window geometry.
    static func log(_ message: String) {
        guard isEnabled else { return }
        FileHandle.standardError.write(Data(("[widget] " + message + "\n").utf8))
    }

    static func log(_ state: NowPlaying, artworkChanged: Bool) {
        guard isEnabled else { return }
        let artwork = state.artworkData.map { "\($0.count) bytes" } ?? "none"
        let line = """
        [now-playing] \(state.isPlaying ? "▶" : "❚❚") \
        "\(state.title ?? "-")" — \(state.artist ?? "-") \
        | album: \(state.album ?? "-") \
        | artwork: \(artwork)\(artworkChanged ? " (new)" : "")
        """
        FileHandle.standardError.write(Data((line + "\n").utf8))
    }
}
