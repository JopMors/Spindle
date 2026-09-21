import Foundation

/// The primary backend: streams now-playing state out of MediaRemote by
/// running the bundled adapter dylib inside `/usr/bin/perl`.
///
/// Reading MediaRemote directly returns an empty dictionary on macOS 15.4+;
/// perl is an Apple platform binary and is still permitted. Transport commands
/// do not need this detour and go through `MediaRemoteCommands`.
final class MediaRemoteAdapterService: MediaService {

    var onUpdate: ((NowPlaying) -> Void)?
    var onFailure: ((MediaServiceError) -> Void)?

    var backendDescription: String {
        commands.isAvailable
            ? "MediaRemote via perl adapter"
            : "MediaRemote via perl adapter (AppleScript control)"
    }

    private let commands = MediaRemoteCommands()
    private let ioQueue = DispatchQueue(label: "nl.jopmors.spindle.adapter-io")

    private var process: Process?
    private var buffer = Data()
    private var current = NowPlaying.idle
    private var isStopping = false
    private var restartAttempts = 0

    private static let maxRestartAttempts = 3
    private static let restartDelay: TimeInterval = 2.0
    private static let maxBufferBytes = 8 * 1024 * 1024

    // MARK: - Lifecycle

    func start() {
        isStopping = false
        launch()
    }

    func stop() {
        isStopping = true
        ioQueue.sync {
            process?.terminationHandler = nil
            process?.terminate()
            process = nil
            buffer.removeAll()
        }
    }

    private func launch() {
        let payload: AdapterLocator.Payload
        do {
            payload = try AdapterLocator.locate()
        } catch {
            report(.adapterUnavailable(error.localizedDescription))
            return
        }

        let task = Process()
        task.executableURL = payload.perl
        task.arguments = [payload.script.path, payload.dylib.path]

        let output = Pipe()
        task.standardOutput = output
        task.standardError = FileHandle.nullDevice

        output.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let chunk = handle.availableData
            guard !chunk.isEmpty else { return }
            self?.ioQueue.async { self?.consume(chunk) }
        }

        task.terminationHandler = { [weak self] _ in
            self?.handleTermination()
        }

        do {
            try task.run()
            process = task
        } catch {
            report(.adapterUnavailable("Could not start the adapter: \(error.localizedDescription)"))
        }
    }

    private func handleTermination() {
        guard !isStopping else { return }
        guard restartAttempts < Self.maxRestartAttempts else {
            report(.adapterExited("The now-playing adapter stopped and could not be restarted."))
            return
        }
        restartAttempts += 1
        ioQueue.asyncAfter(deadline: .now() + Self.restartDelay) { [weak self] in
            guard let self, !self.isStopping else { return }
            self.launch()
        }
    }

    // MARK: - Stream decoding

    /// Accumulates bytes and dispatches whole lines. Called on `ioQueue`.
    private func consume(_ chunk: Data) {
        buffer.append(chunk)

        // A wedged adapter must not grow the buffer without bound.
        if buffer.count > Self.maxBufferBytes { buffer.removeAll() }

        while let newline = buffer.firstIndex(of: UInt8(ascii: "\n")) {
            let lineData = buffer[buffer.startIndex..<newline]
            buffer.removeSubrange(buffer.startIndex...newline)
            guard let line = String(data: lineData, encoding: .utf8) else { continue }
            handle(line: line)
        }
    }

    private func handle(line: String) {
        guard let message = NowPlayingParser.parse(line: line) else { return }

        switch message {
        case .failure(let detail):
            report(.adapterUnavailable(detail))
        case .nowPlaying(let snapshot):
            // A successful frame means the adapter is healthy again.
            restartAttempts = 0
            let merged = NowPlayingParser.merge(previous: current, snapshot: snapshot)
            guard merged != current else { return }
            current = merged
            DispatchQueue.main.async { [weak self] in
                self?.onUpdate?(merged)
            }
        }
    }

    private func report(_ error: MediaServiceError) {
        DispatchQueue.main.async { [weak self] in
            self?.onFailure?(error)
        }
    }

    // MARK: - Transport

    func send(_ command: TransportCommand) {
        // MediaRemote reaches every app; AppleScript only covers Music/Spotify.
        if commands.send(command) { return }
        AppleScriptController.send(command)
    }

    func seek(to seconds: TimeInterval) {
        if commands.seek(to: seconds) { return }
        AppleScriptController.seek(to: seconds)
    }
}
