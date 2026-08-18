//
//  DeviceDescriptor.swift
//  DeckPad
//
//  The device seam (docs/02-architecture.md): everything device-specific
//  lives behind this protocol. v1 ships exactly one descriptor (DDJ-FLX4).
//
//  Decoding is stateful (SHIFT tracking, jog-touch tracking, 14-bit MSB
//  latching), so descriptors are reference types. MainActor-isolated for
//  now; M3 moves decoding onto the Dispatcher queue.
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

protocol DeviceDescriptor: AnyObject {
    /// Substring that identifies the device's CoreMIDI endpoints.
    static var endpointNameMarker: String { get }

    /// Full mappable-control inventory, in capture/checklist order.
    var controls: [ControlSpec] { get }

    /// Raw MIDI → semantic events. Empty for unknown messages (logged and
    /// dropped upstream, NFR-3). May update internal layer state (SHIFT,
    /// jog touch, MSB latches) as a side effect.
    func decode(_ message: RawMIDIMessage) -> [ControlEvent]
}
