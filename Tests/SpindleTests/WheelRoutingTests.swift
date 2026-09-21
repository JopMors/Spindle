import Foundation
import Testing
@testable import Spindle

/// The wheel's meaning depends on which screen is up. These cover the menu
/// path; the Now Playing path moves the system volume, which a test has no
/// business doing.
@Suite("Wheel routing")
@MainActor
struct WheelRoutingTests {

    private static let suiteName = "nl.jopmors.Spindle.wheelTests"

    private func withDevice(_ body: (SpindleViewModel, AppSettings) throws -> Void) rethrows {
        let defaults = UserDefaults(suiteName: Self.suiteName) ?? .standard
        defer {
            defaults.removePersistentDomain(forName: Self.suiteName)
            UserDefaults.standard.removeSuite(named: Self.suiteName)
            try? FileManager.default.removeItem(
                at: FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Preferences/\(Self.suiteName).plist")
            )
        }
        let settings = AppSettings(defaults: defaults)
        // No audio device in a test run.
        settings.isWheelClickEnabled = false
        // And nothing that reaches MediaRemote: cycling modes for real would
        // change what the machine running the tests is playing.
        let device = SpindleViewModel(settings: settings, modes: RecordingModes())
        try body(device, settings)
    }

    /// Swallows mode changes and remembers them.
    private final class RecordingModes: PlaybackModeSetting {
        private(set) var shuffle: [ShuffleMode] = []
        private(set) var repeats: [RepeatMode] = []

        func setShuffle(_ mode: ShuffleMode) { shuffle.append(mode) }
        func setRepeat(_ mode: RepeatMode) { repeats.append(mode) }
    }

    @Test("A full detent moves the highlight one row")
    func oneDetentOneRow() {
        withDevice { device, _ in
            device.showMenu()

            device.wheelScrolled(by: 4)

            #expect(device.menu.selection == 1)
        }
    }

    @Test("Partial travel accumulates instead of being dropped")
    func accumulatesPartialTravel() {
        withDevice { device, _ in
            device.showMenu()

            device.wheelScrolled(by: 1.5)
            #expect(device.menu.selection == 0)
            device.wheelScrolled(by: 1.5)
            #expect(device.menu.selection == 0)
            device.wheelScrolled(by: 1.5)

            // 4.5 units of travel is one detent, with 0.5 carried forward.
            #expect(device.menu.selection == 1)
        }
    }

    @Test("One long sweep steps several rows")
    func longSweepStepsRepeatedly() {
        withDevice { device, _ in
            device.showMenu()

            device.wheelScrolled(by: 12)

            #expect(device.menu.selection == 3)
        }
    }

    @Test("Scrolling back moves the highlight up again")
    func reverseDirection() {
        withDevice { device, _ in
            device.showMenu()
            device.wheelScrolled(by: 8)
            #expect(device.menu.selection == 2)

            device.wheelScrolled(by: -8)

            #expect(device.menu.selection == 0)
        }
    }

    @Test("Lifting the finger discards travel that never made a detent")
    func resetsPartialTravel() {
        withDevice { device, _ in
            device.showMenu()

            device.wheelScrolled(by: 3)
            device.resetWheelTravel()
            device.wheelScrolled(by: 3)

            #expect(device.menu.selection == 0)
        }
    }

    @Test("Turning wheel scrolling off makes the gesture inert")
    func honoursTheSetting() {
        withDevice { device, settings in
            settings.isWheelScrollEnabled = false
            device.showMenu()

            device.wheelScrolled(by: 40)

            #expect(device.menu.selection == 0)
        }
    }

    @Test("MENU walks back up and then off the menu entirely")
    func menuButtonWalksUp() {
        withDevice { device, _ in
            device.menuButtonPressed()
            #expect(device.mode == .menu)
            #expect(device.menu.level == .main)

            // Into Music…
            device.centerButtonPressed { _ in }
            #expect(device.menu.level == .music)

            // …back out…
            device.menuButtonPressed()
            #expect(device.menu.level == .main)
            #expect(device.mode == .menu)

            // …and off the menu.
            device.menuButtonPressed()
            #expect(device.mode == .nowPlaying)
        }
    }

    @Test("Centre plays and pauses only when Now Playing is up")
    func centreDependsOnScreen() {
        withDevice { device, _ in
            var commands: [TransportCommand] = []

            device.centerButtonPressed { commands.append($0) }
            #expect(commands == [.togglePlayPause])

            device.showMenu()
            device.centerButtonPressed { commands.append($0) }

            // In a menu the centre button selects; it must not also play.
            #expect(commands == [.togglePlayPause])
        }
    }

    @Test("Cycling shuffle and repeat persists and reaches the menu labels")
    func cyclesModes() {
        withDevice { device, settings in
            device.cycleShuffle()
            #expect(device.shuffle == .songs)
            #expect(settings.shuffleMode == .songs)
            #expect(device.menu.shuffleLabel == "Songs")

            device.cycleRepeat()
            #expect(device.repeatMode == .all)
            #expect(settings.repeatMode == .all)

            device.cycleRepeat()
            #expect(device.repeatMode == .one)
        }
    }
}
