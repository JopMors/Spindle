import CryptoKit
import Foundation
import Security

/// The pure half of Spotify's sign-in: Authorization Code with PKCE.
///
/// PKCE needs no client secret, which is the point — Spindle is open source
/// and has nowhere safe to keep one.
enum SpotifyPKCE {

    static let authorizeEndpoint = URL(string: "https://accounts.spotify.com/authorize")!
    static let tokenEndpoint = URL(string: "https://accounts.spotify.com/api/token")!

    /// 64 random bytes, which base64url-encode to 86 characters — inside the
    /// 43…128 the spec allows.
    private static let verifierByteCount = 64
    private static let stateByteCount = 16

    /// Unreserved characters, the only ones a form value may carry unescaped.
    private static let formAllowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))

    static func makeVerifier() -> String {
        base64URL(randomBytes(verifierByteCount))
    }

    static func makeState() -> String {
        base64URL(randomBytes(stateByteCount))
    }

    static func challenge(for verifier: String) -> String {
        base64URL(Data(SHA256.hash(data: Data(verifier.utf8))))
    }

    static func authorizeURL(
        clientID: String,
        redirectURI: String,
        challenge: String,
        state: String,
        scopes: [String]
    ) -> URL {
        var components = URLComponents(url: authorizeEndpoint, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "code_challenge_method", value: "S256"),
            URLQueryItem(name: "code_challenge", value: challenge),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "scope", value: scopes.joined(separator: " "))
        ]
        return components.url!
    }

    /// Reads the authorisation code off the request line's target, e.g.
    /// `/callback?code=…&state=…`. The state has to be ours, or the redirect
    /// was not the answer to the link we opened.
    static func callbackCode(from requestTarget: String, expectedState: String) -> Result<String, SpotifyError> {
        let query = URLComponents(string: requestTarget)?.queryItems ?? []
        let value = { (name: String) in query.first { $0.name == name }?.value }

        guard value("state") == expectedState else {
            return .failure(.authorization("The sign-in did not match. Try again."))
        }
        if let error = value("error") {
            return .failure(.authorization("Spotify said: \(error)"))
        }
        guard let code = value("code"), !code.isEmpty else {
            return .failure(.authorization("Spotify sent no sign-in code."))
        }
        return .success(code)
    }

    /// `application/x-www-form-urlencoded`, which the token endpoint requires.
    static func formBody(_ fields: [(String, String)]) -> String {
        fields
            .map { name, value in
                let escaped = value.addingPercentEncoding(withAllowedCharacters: formAllowed) ?? ""
                return "\(name)=\(escaped)"
            }
            .joined(separator: "&")
    }

    // MARK: - Helpers

    private static func randomBytes(_ count: Int) -> Data {
        var bytes = [UInt8](repeating: 0, count: count)
        let status = SecRandomCopyBytes(kSecRandomDefault, count, &bytes)
        precondition(status == errSecSuccess, "No system randomness available")
        return Data(bytes)
    }

    private static func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
