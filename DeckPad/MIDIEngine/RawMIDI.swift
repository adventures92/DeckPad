//
//  RawMIDI.swift
//  DeckPad
//
//  DeckPad's own raw-MIDI vocabulary. MIDIKit types never leak past
//  MIDIEngine (ADR-003); everything downstream speaks these types.
//

import Foundation

nonisolated enum RawMIDIMessage: Equatable, Sendable {
    case noteOn(channel: UInt8, note: UInt8, velocity: UInt8)
    case noteOff(channel: UInt8, note: UInt8, velocity: UInt8)
    case controlChange(channel: UInt8, controller: UInt8, value: UInt8)
    case other(description: String)

    /// Compact human-readable form for the monitor table, e.g. "Note On  ch1  #11 vel 127".
    var display: String {
        switch self {
        case let .noteOn(ch, note, vel):
            return String(format: "NoteOn   ch%-2d #%-3d (0x%02X) vel %d", ch, note, note, vel)
        case let .noteOff(ch, note, vel):
            return String(format: "NoteOff  ch%-2d #%-3d (0x%02X) vel %d", ch, note, note, vel)
        case let .controlChange(ch, cc, value):
            return String(format: "CC       ch%-2d #%-3d (0x%02X) val %d", ch, cc, cc, value)
        case let .other(description):
            return "Other    \(description)"
        }
    }
}

nonisolated struct RawMIDIPacket: Equatable, Sendable {
    let message: RawMIDIMessage
    let receivedAt: Date
}
