//
//  DeviceDescriptor.swift
//  DeckPad
//
//  The device seam (docs/02-architecture.md): everything device-specific
//  lives behind this protocol. v1 ships exactly one descriptor (DDJ-FLX4).
//

import Foundation

/// A physical control on the device, in documented capture order
/// (docs/03-device-ddj-flx4.md §2).
nonisolated struct ControlSpec: Identifiable, Sendable, Equatable {
    let id: ControlID
    let kind: ControlKind
    let section: String
    let name: String
}

nonisolated protocol DeviceDescriptor: Sendable {
    /// Substring that identifies the device's CoreMIDI endpoints.
    static var endpointNameMarker: String { get }

    /// Full mappable-control inventory, in capture/checklist order.
    var controls: [ControlSpec] { get }

    /// Raw MIDI → semantic event. Returns nil for unknown messages.
    /// The DDJ-FLX4 table is generated from the M1 capture session (ADR-004).
    func decode(_ message: RawMIDIMessage) -> ControlEvent?
}
