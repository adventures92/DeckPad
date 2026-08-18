//
//  Action.swift
//  DeckPad
//
//  The mappable action vocabulary — docs/06-actions-catalog.md is the
//  authoritative catalog; this file is its Codable Swift form. Payload
//  shapes changing later requires a schemaVersion bump (NFR-7, M3).
//

import Foundation

/// A recorded key combination. `keyCode` is a macOS virtual key code;
/// `modifiers` are CGEventFlags raw values (device-independent masks).
nonisolated struct KeyCombo: Codable, Equatable, Sendable {
    var keyCode: UInt16
    var modifiers: UInt64

    static let command: UInt64 = 1 << 20     // maskCommand
    static let shift: UInt64 = 1 << 17       // maskShift
    static let option: UInt64 = 1 << 19      // maskAlternate
    static let control: UInt64 = 1 << 18     // maskControl
}

nonisolated enum MediaKey: String, Codable, Sendable {
    case playPause, next, previous
    case volumeUp, volumeDown, mute
    case brightnessUp, brightnessDown
    case keyboardIlluminationUp, keyboardIlluminationDown

    /// NX_KEYTYPE_* constants for system-defined events.
    var nxKeyType: Int32 {
        switch self {
        case .volumeUp: 0
        case .volumeDown: 1
        case .brightnessUp: 2
        case .brightnessDown: 3
        case .mute: 7
        case .playPause: 16
        case .next: 17
        case .previous: 18
        case .keyboardIlluminationUp: 21
        case .keyboardIlluminationDown: 22
        }
    }
}

nonisolated enum ScreenshotMode: String, Codable, Sendable {
    case fullScreen, window, area, areaToClipboard
}

nonisolated enum ScrollAxis: String, Codable, Sendable {
    case vertical, horizontal
}

/// Response shaping for continuous targets (docs/06 §7).
nonisolated struct ContinuousShape: Codable, Equatable, Sendable {
    var rangeMin: Double = 0
    var rangeMax: Double = 1
    var curve: Curve = .linear

    nonisolated enum Curve: String, Codable, Sendable { case linear, eased }

    func apply(_ value: Double) -> Double {
        let clamped = min(max(value, 0), 1)
        let curved = curve == .eased ? clamped * clamped * (3 - 2 * clamped) : clamped
        return rangeMin + (rangeMax - rangeMin) * curved
    }
}

nonisolated indirect enum Action: Codable, Equatable, Sendable {
    // Keyboard (docs/06 §1)
    case keystroke(KeyCombo)
    case textSnippet(String)

    // Media & system keys (§2)
    case mediaKey(MediaKey, steps: Int)

    // Apps & files (§3)
    case launchApp(bundleID: String)
    case hideApp(bundleID: String)
    case quitApp(bundleID: String, force: Bool)
    case cycleWindows
    case openURL(String)
    case openFile(path: String)
    case missionControl
    case launchpad

    // Automation (§4)
    case runShortcut(name: String, input: String?)
    case shellCommand(command: String, workingDirectory: String?, timeoutSeconds: Int)
    case appleScript(source: String)

    // System toggles & session (§5)
    case lockScreen
    case startScreenSaver
    case toggleDarkMode
    case screenshot(ScreenshotMode)
    case toggleDoNotDisturb        // runs the user-installed "DeckPad DND" Shortcut (bundled asset lands in M6)
    case sleepDisplays

    // DeckPad internal (§6) — wired to real modules in M3
    case switchProfile(name: String)
    case pinActiveProfile
    case suspendDeckPad
    case openDeckPad
    case toggleMIDIMonitor
    case noOp(label: String)

    // Continuous targets (§7) — used with Trigger.continuous
    case systemVolume(ContinuousShape)
    case displayBrightness(ContinuousShape)
    case customCommandContinuous(command: String)

    // Relative/jog modes (§8) — used with Trigger.relative
    case scroll(axis: ScrollAxis, speedMultiplier: Double, natural: Bool)
    case arrowStepper(perTick: KeyCombo, reverseTick: KeyCombo, ticksPerStep: Int)
    case zoom(ticksPerStep: Int)
    case volumeDial(stepSize: Double)
    case brightnessDial(stepSize: Double)
    case customCommandPerTick(command: String, ticksPerRun: Int)
}

nonisolated enum ActionResult: Equatable, Sendable {
    case success
    case failure(String)
    case permissionMissing(String)

    var isSuccess: Bool { self == .success }
}
