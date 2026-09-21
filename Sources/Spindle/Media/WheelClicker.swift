import AVFoundation
import Foundation

/// The click wheel's tick.
///
/// Synthesised rather than sampled, so nothing has to be bundled: a damped
/// resonant burst, which is what a small mechanical detent actually sounds
/// like. The first version was four milliseconds of white noise, which is
/// indistinguishable from a driver glitch — people reported it as broken audio.
final class WheelClicker {

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var buffer: AVAudioPCMBuffer?
    private var isRunning = false
    private var configurationObserver: NSObjectProtocol?

    /// 0…1, scaling the synthesised amplitude.
    var volume: Float = WheelClicker.defaultVolume {
        didSet {
            guard volume != oldValue else { return }
            player.volume = max(min(volume, 1), 0)
        }
    }

    /// Clicks any faster than this are dropped; a fast flick would otherwise
    /// queue dozens of overlapping ticks and turn into a buzz.
    private static let minimumInterval: TimeInterval = 0.02
    private var lastClick = Date.distantPast

    init() {
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: nil)
        player.volume = Self.defaultVolume
        observeConfigurationChanges()
    }

    deinit {
        if let configurationObserver {
            NotificationCenter.default.removeObserver(configurationObserver)
        }
    }

    func click() {
        let now = Date()
        guard now.timeIntervalSince(lastClick) >= Self.minimumInterval else { return }
        lastClick = now

        guard start(), let buffer = currentBuffer() else { return }
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        player.play()
    }

    // MARK: - Engine lifecycle

    /// Started lazily so a widget that never gets scrolled never opens an audio
    /// device.
    private func start() -> Bool {
        guard !isRunning else { return true }
        do {
            try engine.start()
            isRunning = true
            return true
        } catch {
            Diagnostics.log("wheel click engine failed to start: \(error.localizedDescription)")
            return false
        }
    }

    /// Plugging in headphones or connecting AirPods changes the output device,
    /// and macOS stops the engine when that happens. Without this the click
    /// went silent for the rest of the session — the "sometimes it clicks,
    /// sometimes it doesn't" report. The sample rate can change with the
    /// device too, so the buffer is thrown away and rebuilt.
    private func observeConfigurationChanges() {
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.isRunning = false
            self.buffer = nil
            Diagnostics.log("audio configuration changed; wheel click will rebuild")
        }
    }

    func stop() {
        guard isRunning else { return }
        player.stop()
        engine.stop()
        isRunning = false
    }

    // MARK: - Synthesis

    private static let defaultVolume: Float = 0.6
    /// Long enough to read as a body, short enough to stay a tick.
    private static let durationSeconds: Double = 0.012
    /// The pitch of the detent. High enough to cut through, low enough not to
    /// sound like an alert.
    private static let toneHz: Double = 2_100
    private static let amplitude: Float = 0.22
    /// How much unpitched noise rides on the attack, for the contact sound.
    private static let transientMix: Float = 0.35
    /// Steep enough that the noise is gone within half a millisecond, leaving
    /// the tone to carry the rest.
    private static let transientDecayPerSecond: Float = 6_000

    /// Built on demand, from the format the engine actually negotiated. The old
    /// version asked the mixer for its format in `init`, before the engine had
    /// started and before any output device was known.
    private func currentBuffer() -> AVAudioPCMBuffer? {
        if let buffer { return buffer }
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        let made = Self.makeClickBuffer(format: format)
        buffer = made
        return made
    }

    private static func makeClickBuffer(format: AVAudioFormat) -> AVAudioPCMBuffer? {
        let frames = AVAudioFrameCount(format.sampleRate * durationSeconds)
        guard frames > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames),
              let channels = buffer.floatChannelData else { return nil }
        buffer.frameLength = frames

        var generator = SystemRandomNumberGenerator()
        for frame in 0..<Int(frames) {
            let sample = self.sample(
                at: frame,
                of: Int(frames),
                sampleRate: format.sampleRate,
                generator: &generator
            )
            for channel in 0..<Int(format.channelCount) {
                channels[channel][frame] = sample
            }
        }
        return buffer
    }

    /// A decaying sine for the body of the tick, plus a much faster-decaying
    /// noise burst on the attack for the contact.
    private static func sample(
        at frame: Int,
        of frames: Int,
        sampleRate: Double,
        generator: inout SystemRandomNumberGenerator
    ) -> Float {
        let seconds = Double(frame) / sampleRate
        let progress = Float(frame) / Float(frames)
        // Cubic fade to zero so the buffer never ends on a step, which is
        // itself an audible click of the wrong kind.
        let envelope = pow(1 - progress, 3)
        let tone = Float(sin(2 * .pi * toneHz * seconds))
        let transient = Float.random(in: -1...1, using: &generator)
            * exp(-transientDecayPerSecond * Float(seconds))
        let mixed = tone * (1 - transientMix) + transient * transientMix
        return mixed * envelope * amplitude
    }
}
