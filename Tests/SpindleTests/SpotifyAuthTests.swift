import Foundation
import Testing
@testable import Spindle

/// The sign-in maths: PKCE, the authorise link, and reading the code back off
/// the redirect.
@Suite("Spotify sign-in")
struct SpotifyAuthTests {

    @Test("The challenge matches the RFC 7636 worked example")
    func challengeMatchesRFC() {
        let challenge = SpotifyPKCE.challenge(for: "dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk")

        #expect(challenge == "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM")
    }

    @Test("A verifier is URL-safe and within the allowed length")
    func verifierShape() {
        let verifier = SpotifyPKCE.makeVerifier()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))

        #expect((43...128).contains(verifier.count))
        #expect(verifier.unicodeScalars.allSatisfy(allowed.contains))
        #expect(verifier != SpotifyPKCE.makeVerifier())
    }

    @Test("The authorise link carries everything Spotify asks for")
    func authorizeURL() throws {
        let url = SpotifyPKCE.authorizeURL(
            clientID: "abc123",
            redirectURI: "http://127.0.0.1:43721/callback",
            challenge: "chal",
            state: "st",
            scopes: ["playlist-read-private", "user-library-read"]
        )
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        let query = Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })

        #expect(url.host == "accounts.spotify.com")
        #expect(url.path == "/authorize")
        #expect(query["client_id"] == "abc123")
        #expect(query["response_type"] == "code")
        #expect(query["redirect_uri"] == "http://127.0.0.1:43721/callback")
        #expect(query["code_challenge_method"] == "S256")
        #expect(query["code_challenge"] == "chal")
        #expect(query["state"] == "st")
        #expect(query["scope"] == "playlist-read-private user-library-read")
    }

    @Test("The code is read off a matching redirect")
    func readsCode() {
        let result = SpotifyPKCE.callbackCode(
            from: "/callback?code=AQB-xyz&state=st", expectedState: "st"
        )

        #expect(result == .success("AQB-xyz"))
    }

    @Test("A redirect with someone else's state is refused")
    func refusesForeignState() {
        let result = SpotifyPKCE.callbackCode(
            from: "/callback?code=AQB-xyz&state=other", expectedState: "st"
        )

        #expect(result == .failure(.authorization("The sign-in did not match. Try again.")))
    }

    @Test("Declining in the browser comes back as a readable failure")
    func reportsDenial() {
        let result = SpotifyPKCE.callbackCode(
            from: "/callback?error=access_denied&state=st", expectedState: "st"
        )

        #expect(result == .failure(.authorization("Spotify said: access_denied")))
    }

    @Test("Form bodies escape reserved characters")
    func formEncoding() {
        let body = SpotifyPKCE.formBody([
            ("redirect_uri", "http://127.0.0.1:1/callback"),
            ("code", "a+b/c=")
        ])

        #expect(body == "redirect_uri=http%3A%2F%2F127.0.0.1%3A1%2Fcallback&code=a%2Bb%2Fc%3D")
    }
}
