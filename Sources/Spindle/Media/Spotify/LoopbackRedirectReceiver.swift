import Foundation
import Network

/// Catches the browser's redirect back from Spotify's sign-in page.
///
/// Spotify only accepts HTTPS or a loopback IP literal as a redirect, and an
/// app has no HTTPS endpoint of its own, so this listens on 127.0.0.1 for the
/// one request and answers it with a page saying the tab can be closed.
final class LoopbackRedirectReceiver {

    enum ReceiverError: Error {
        case portUnavailable
        case timedOut
        case cancelled
    }

    /// Enough for any request line Spotify's redirect produces.
    private static let maxRequestBytes = 16 * 1024

    private let port: UInt16
    private let queue = DispatchQueue(label: "nl.jopmors.spindle.spotify-redirect")
    private var listener: NWListener?
    private var continuation: CheckedContinuation<String, Error>?

    init(port: UInt16) {
        self.port = port
    }

    /// Waits for the redirect and returns its request target, such as
    /// `/callback?code=…&state=…`.
    func waitForRedirect(timeout: Duration) async throws -> String {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                queue.async { self.start(continuation: continuation, timeout: timeout) }
            }
        } onCancel: {
            queue.async { self.finish(.failure(ReceiverError.cancelled)) }
        }
    }

    // MARK: - Listening

    private func start(continuation: CheckedContinuation<String, Error>, timeout: Duration) {
        self.continuation = continuation
        guard let nwPort = NWEndpoint.Port(rawValue: port) else {
            finish(.failure(ReceiverError.portUnavailable))
            return
        }
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: .ipv4(.loopback), port: nwPort)
        parameters.allowLocalEndpointReuse = true

        do {
            let listener = try NWListener(using: parameters)
            listener.newConnectionHandler = { [weak self] connection in self?.handle(connection) }
            listener.stateUpdateHandler = { [weak self] state in
                if case .failed(let error) = state {
                    NSLog("Spindle: redirect listener failed: \(error)")
                    self?.finish(.failure(ReceiverError.portUnavailable))
                }
            }
            listener.start(queue: queue)
            self.listener = listener
        } catch {
            NSLog("Spindle: could not listen on 127.0.0.1:\(port): \(error)")
            finish(.failure(ReceiverError.portUnavailable))
            return
        }

        let seconds = Double(timeout.components.seconds)
        queue.asyncAfter(deadline: .now() + seconds) { [weak self] in
            self?.finish(.failure(ReceiverError.timedOut))
        }
    }

    private func handle(_ connection: NWConnection) {
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: Self.maxRequestBytes) {
            [weak self] data, _, _, _ in
            guard let self else { return }
            let target = data.flatMap(Self.requestTarget(in:))
            // Browsers also ask for /favicon.ico; only the callback counts.
            guard let target, target.hasPrefix("/callback") else {
                self.respond(on: connection, status: "404 Not Found", body: "")
                return
            }
            self.respond(on: connection, status: "200 OK", body: Self.donePage)
            self.finish(.success(target))
        }
    }

    private func respond(on connection: NWConnection, status: String, body: String) {
        let response = """
        HTTP/1.1 \(status)\r
        Content-Type: text/html; charset=utf-8\r
        Content-Length: \(body.utf8.count)\r
        Connection: close\r
        \r
        \(body)
        """
        connection.send(content: Data(response.utf8), completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func finish(_ result: Result<String, Error>) {
        listener?.cancel()
        listener = nil
        guard let continuation else { return }
        self.continuation = nil
        continuation.resume(with: result)
    }

    // MARK: - Parsing

    /// The middle of `GET /callback?code=… HTTP/1.1`.
    static func requestTarget(in data: Data) -> String? {
        guard let text = String(data: data, encoding: .utf8),
              let line = text.split(separator: "\r\n", maxSplits: 1).first else { return nil }
        let parts = line.split(separator: " ")
        guard parts.count == 3, parts[0] == "GET" else { return nil }
        return String(parts[1])
    }

    private static let donePage = """
    <!doctype html><meta charset="utf-8"><title>Spindle</title>
    <body style="font: 15px -apple-system; text-align: center; padding-top: 80px">
    <h2>Spindle is connected to Spotify</h2><p>You can close this tab.</p></body>
    """
}
