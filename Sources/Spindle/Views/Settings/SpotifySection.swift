import AppKit
import SwiftUI

/// Connecting a Spotify account, so the menu can browse it.
struct SpotifySection: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var authorizer: SpotifyAuthorizer

    private static let dashboardURL = URL(string: "https://developer.spotify.com/dashboard")!

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                WheelTargetLogo(target: .spotify)
                    .frame(width: 16, height: 16)
                SectionHeader("Spotify")
            }
            Text("""
            Lets the menu browse your playlists and Liked Songs when the note \
            button is set to Spotify, or to Media while Spotify plays.
            """)
                .font(.caption)
                .foregroundStyle(.secondary)

            setupSteps

            TextField("Client ID", text: $settings.spotifyClientID)
                .textFieldStyle(.roundedBorder)
                .font(.callout.monospaced())
                .disabled(authorizer.isConnected)

            HStack {
                connectButton
                statusText
            }
        }
    }

    private var setupSteps: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("1. Create an app in the Spotify developer dashboard (needs Premium).")
            HStack(spacing: 4) {
                Text("2. Add this redirect URI:")
                Text(SpotifyAuthorizer.redirectURI)
                    .font(.caption.monospaced())
                    .textSelection(.enabled)
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(SpotifyAuthorizer.redirectURI, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy")
            }
            Text("3. Paste the app's Client ID below and connect.")
            Link("Open the Spotify dashboard", destination: Self.dashboardURL)
        }
        .font(.caption)
    }

    @ViewBuilder
    private var connectButton: some View {
        switch authorizer.status {
        case .connected:
            Button("Disconnect") { authorizer.disconnect() }
        case .connecting:
            Button("Waiting for browser…") {}
                .disabled(true)
        case .disconnected, .failed:
            Button("Connect Spotify") { authorizer.connect() }
                .disabled(settings.spotifyClientID.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    @ViewBuilder
    private var statusText: some View {
        switch authorizer.status {
        case .connected:
            Label("Connected", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .failed(let message):
            Text(message)
                .foregroundStyle(.red)
        case .connecting, .disconnected:
            EmptyView()
        }
    }
}
