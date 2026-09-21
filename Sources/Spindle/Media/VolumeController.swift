import CoreAudio
import Foundation

/// Reads and writes the default output device's volume.
///
/// The main element is not universally supported — AirPods, for one, expose
/// volume only per channel — so both are tried in turn. The device is looked up
/// on every call rather than cached, because it changes when headphones come
/// and go.
enum VolumeController {

    /// Elements to try, in order: main first, then the stereo channels.
    private static let elements: [UInt32] = [kAudioObjectPropertyElementMain, 1, 2]

    /// Current output volume in 0...1, or nil when the device has no volume
    /// control at all (some HDMI and digital outputs).
    static func currentVolume() -> Float? {
        guard let device = defaultOutputDevice() else { return nil }
        for element in elements {
            var address = volumeAddress(element)
            guard AudioObjectHasProperty(device, &address) else { continue }
            var value = Float32(0)
            var size = UInt32(MemoryLayout<Float32>.size)
            if AudioObjectGetPropertyData(device, &address, 0, nil, &size, &value) == noErr {
                return value
            }
        }
        return nil
    }

    /// Sets the output volume, clamped to 0...1. Returns false when the device
    /// exposes no settable volume, so callers can stay quiet rather than
    /// pretending the change happened.
    @discardableResult
    static func setVolume(_ volume: Float) -> Bool {
        guard let device = defaultOutputDevice() else { return false }
        let clamped = min(max(volume, 0), 1)
        var didSet = false
        for element in elements {
            var address = volumeAddress(element)
            guard AudioObjectHasProperty(device, &address), isSettable(device, &address) else {
                continue
            }
            var value = Float32(clamped)
            let status = AudioObjectSetPropertyData(
                device, &address, 0, nil, UInt32(MemoryLayout<Float32>.size), &value
            )
            if status == noErr { didSet = true }
            // The main element covers the whole device; per-channel needs both.
            if didSet && element == kAudioObjectPropertyElementMain { break }
        }
        return didSet
    }

    /// Nudges the volume by a delta and returns the level that resulted.
    @discardableResult
    static func adjustVolume(by delta: Float) -> Float? {
        guard let current = currentVolume() else { return nil }
        let target = min(max(current + delta, 0), 1)
        guard setVolume(target) else { return nil }
        return target
    }

    // MARK: - CoreAudio plumbing

    private static func defaultOutputDevice() -> AudioDeviceID? {
        var device = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &device
        )
        return status == noErr && device != kAudioObjectUnknown ? device : nil
    }

    private static func volumeAddress(_ element: UInt32) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyVolumeScalar,
            mScope: kAudioDevicePropertyScopeOutput,
            mElement: element
        )
    }

    private static func isSettable(
        _ device: AudioDeviceID, _ address: inout AudioObjectPropertyAddress
    ) -> Bool {
        var settable: DarwinBoolean = false
        return AudioObjectIsPropertySettable(device, &address, &settable) == noErr
            && settable.boolValue
    }
}
