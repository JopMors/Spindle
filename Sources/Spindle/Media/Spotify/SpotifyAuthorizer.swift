import AppKit
import Foundation

/// Signs in to Spotify and keeps an access token fresh.
///
/// Uses the user's own Client ID from developer.spotify.com, entered in
/// Settings: since February 2026 a development-mode app is limited to five
/// users, so one shared ID could never serve everyone who downloads Spindle.
@MainActor
final class SpotifyAuthorizer: ObservableObject, SpotifyTokenProviding {

    enum Status: Equatable {
        case disconnected
        case connecting
        case connected
        case failed(String)
    }

    /// Fixed so it can be registered in the Spotify dashboard once.
    static let redirectPort: UInt16 = 43721
    static let redirectURI = "http://127.0.0.1:\(redirectPort)/callback"
    static let scopes = [
        "playlist-read-private",
        "playlist-read-collaborative",
        "user-library-read",
        "user-read-recently-played"
    ]

    /// How long the browser sign-in may take before we stop listening.
    private static let signInTimeout: Duration = .seconds(300)
    /// Refresh this early, so a token cannot lapse mid-request.
    private static let expiryMargin: TimeInterval = 60

    @Published private(set) var status: Status

    private let settings: AppSettings
    private let store: SpotifyTokenStore
    private let session: URLSession

    private var accessToken: String?
    private var expiresAt: Date = .distantPast
    private var refreshTask: Task<String, Error>?
    private var signInTask: Task<Void, Never>?

    init(
        settings: AppSettings,
        store: SpotifyTokenStore = KeychainTokenStore(),
        session: URLSession = .shared
    ) {
        self.settings = settings
        self.store = store
        self.session = session
        self.status = store.load() == nil ? .disconnected : .connected
    }

    private var clientID: String {
        settings.spotifyClientID.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isConnected: Bool { status == .connected }

    // MARK: - Sign-in

    func connect() {
        guard SpotifyWebAPI.isSafeIdentifier(clientID) else {
            status = .failed("Paste the Client ID from your Spotify app first.")
            return
        }
        signInTask?.cancel()
        status = .connecting
        signInTask = Task { [weak self] in await self?.signIn() }
    }

    func disconnect() {
        signInTask?.cancel()
        refreshTask?.cancel()
        refreshTask = nil
        store.delete()
        accessToken = nil
        expiresAt = .distantPast
        status = .disconnected
    }

    private func signIn() async {
        let verifier = SpotifyPKCE.makeVerifier()
        let state = SpotifyPKCE.makeState()
        let receiver = LoopbackRedirectReceiver(port: Self.redirectPort)
        let url = SpotifyPKCE.authorizeURL(
            clientID: clientID,
            redirectURI: Self.redirectURI,
            challenge: SpotifyPKCE.challenge(for: verifier),
            state: state,
            scopes: Self.scopes
        )

        do {
            async let redirect = receiver.waitForRedirect(timeout: Self.signInTimeout)
            NSWorkspace.shared.open(url)
            let code = try SpotifyPKCE.callbackCode(from: try await redirect, expectedState: state).get()
            try await exchange([
                ("grant_type", "authorization_code"),
                ("code", code),
                ("redirect_uri", Self.redirectURI),
                ("client_id", clientID),
                ("code_verifier", verifier)
            ])
            status = .connected
        } catch is CancellationError {
            status = store.load() == nil ? .disconnected : .connected
        } catch {
            status = .failed(Self.describe(error))
        }
    }

    // MARK: - Tokens

    func accessToken(forceRefresh: Bool) async throws -> String {
        if !forceRefresh, let accessToken, Date() < expiresAt {
            return accessToken
        }
        // Menus fire several requests at once; they share one refresh.
        if let refreshTask { return try await refreshTask.value }
        let task = Task { try await self.refresh() }
        refreshTask = task
        defer { refreshTask = nil }
        return try await task.value
    }

    private func refresh() async throws -> String {
        guard let refreshToken = store.load(), !clientID.isEmpty else {
            throw SpotifyError.notConnected
        }
        do {
            try await exchange([
                ("grant_type", "refresh_token"),
                ("refresh_token", refreshToken),
                ("client_id", clientID)
            ])
        } catch SpotifyError.http(400) {
            // Revoked, or the Client ID changed: the stored grant is dead.
            disconnect()
            throw SpotifyError.notConnected
        }
        guard let accessToken else { throw SpotifyError.invalidResponse }
        return accessToken
    }

    /// Posts to the token endpoint and keeps what comes back. Spotify may
    /// rotate the refresh token, so a new one replaces the stored one.
    private func exchange(_ fields: [(String, String)]) async throws {
        var request = URLRequest(url: SpotifyPKCE.tokenEndpoint)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(SpotifyPKCE.formBody(fields).utf8)

        let (data, response) = try await session.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            NSLog("Spindle: Spotify token request failed (\(status))")
            throw SpotifyError.http(status)
        }
        guard let token = try? SpotifyWebAPI.decoder.decode(SpotifyTokenResponse.self, from: data) else {
            throw SpotifyError.invalidResponse
        }
        accessToken = token.accessToken
        expiresAt = Date().addingTimeInterval(TimeInterval(token.expiresIn) - Self.expiryMargin)
        if let refreshToken = token.refreshToken {
            store.save(refreshToken)
        }
    }

    private static func describe(_ error: Error) -> String {
        switch error {
        case let spotify as SpotifyError:
            if case .http(400) = spotify {
                return "Spotify refused the sign-in. Check the Client ID and redirect URI."
            }
            return spotify.message
        case LoopbackRedirectReceiver.ReceiverError.portUnavailable:
            return "Port \(redirectPort) is in use. Quit whatever holds it and try again."
        case LoopbackRedirectReceiver.ReceiverError.timedOut:
            return "The sign-in timed out. Try again."
        default:
            return error.localizedDescription
        }
    }
}
