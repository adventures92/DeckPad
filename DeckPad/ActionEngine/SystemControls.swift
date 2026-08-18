//
//  SystemControls.swift
//  DeckPad
//
//  Volume (public CoreAudio API) and display brightness (private
//  DisplayServices, ADR-007) behind test seams. Brightness exposes
//  availability so ActionEngine can fall back to stepped brightness keys.
//

import AudioToolbox
import CoreAudio
import CoreGraphics
import Foundation

@MainActor
protocol VolumeControlling {
    func setVolume(_ value: Double)
    func volume() -> Double?
}

@MainActor
protocol BrightnessControlling {
    var isAvailable: Bool { get }
    /// Returns false on failure (caller falls back to stepped keys).
    func setBrightness(_ value: Double) -> Bool
}

@MainActor
final class CoreAudioVolume: VolumeControlling {
    private func defaultOutputDevice() -> AudioDeviceID? {
        var deviceID = AudioDeviceID(0)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(AudioObjectID(kAudioObjectSystemObject), &address, 0, nil, &size, &deviceID)
        return status == noErr ? deviceID : nil
    }

    private var volumeAddress = AudioObjectPropertyAddress(
        mSelector: kAudioHardwareServiceDeviceProperty_VirtualMainVolume,
        mScope: kAudioDevicePropertyScopeOutput,
        mElement: kAudioObjectPropertyElementMain
    )

    func setVolume(_ value: Double) {
        guard let device = defaultOutputDevice() else { return }
        var volume = Float32(min(max(value, 0), 1))
        AudioObjectSetPropertyData(device, &volumeAddress, 0, nil, UInt32(MemoryLayout<Float32>.size), &volume)
    }

    func volume() -> Double? {
        guard let device = defaultOutputDevice() else { return nil }
        var volume = Float32(0)
        var size = UInt32(MemoryLayout<Float32>.size)
        let status = AudioObjectGetPropertyData(device, &volumeAddress, 0, nil, &size, &volume)
        return status == noErr ? Double(volume) : nil
    }
}

@MainActor
final class DisplayServicesBrightness: BrightnessControlling {
    private typealias SetBrightnessFn = @convention(c) (CGDirectDisplayID, Float) -> Int32
    private let setFn: SetBrightnessFn?

    init() {
        if let handle = dlopen("/System/Library/PrivateFrameworks/DisplayServices.framework/DisplayServices", RTLD_LAZY),
           let symbol = dlsym(handle, "DisplayServicesSetBrightness") {
            setFn = unsafeBitCast(symbol, to: SetBrightnessFn.self)
        } else {
            setFn = nil
        }
    }

    var isAvailable: Bool { setFn != nil }

    func setBrightness(_ value: Double) -> Bool {
        guard let setFn else { return false }
        return setFn(CGMainDisplayID(), Float(min(max(value, 0), 1))) == 0
    }
}
