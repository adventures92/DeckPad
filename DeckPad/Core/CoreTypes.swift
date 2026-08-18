//
//  CoreTypes.swift
//  DeckPad
//
//  Core vocabulary per docs/02-architecture.md §2. These names are canonical
//  across all modules, profile JSON, and the docs — change them only together
//  with the architecture doc.
//

import Foundation

/// Stable identity for a physical control, defined by the device descriptor.
/// Examples: `deck1.play`, `deck1.pad5`, `deck2.jog`, `mixer.crossfader`.
nonisolated struct ControlID: Hashable, Codable, Sendable, CustomStringConvertible {
    let rawValue: String

    init(_ rawValue: String) { self.rawValue = rawValue }

    var description: String { rawValue }

    init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated enum ControlKind: String, Codable, Sendable {
    case button, pad, fader, knob, encoder, jog, slider
}

/// Semantic event out of the DeviceLayer — the rest of the app never sees raw MIDI.
nonisolated enum ControlEvent: Equatable, Sendable {
    case pressed(ControlID, shifted: Bool)
    case released(ControlID, shifted: Bool)
    /// Absolute position 0.0…1.0 (14-bit aware).
    case value(ControlID, Double, shifted: Bool)
    /// Relative ticks from jogs/encoders; `touched` reflects jog capacitive state.
    case relative(ControlID, ticks: Int, touched: Bool, shifted: Bool)
}

nonisolated enum Trigger: Codable, Equatable, Sendable {
    case press
    case release
    case doubleTap
    case hold(ms: Int)
    case toggle
    case continuous
    case relative
}
