//
//  MonitorStore.swift
//  DeckPad
//
//  Row buffer for the MIDI monitor stream table (FR-6).
//

import Combine
import Foundation

struct MonitorRow: Identifiable {
    let id = UUID()
    let time: Date
    let raw: String
    let decoded: String?
}

@MainActor
final class MonitorStore: ObservableObject {
    @Published private(set) var rows: [MonitorRow] = []
    @Published var isPaused = false

    private let descriptor = DDJFLX4Descriptor()
    private static let capacity = 2000

    func append(_ packet: RawMIDIPacket) {
        guard !isPaused else { return }
        let events = descriptor.decode(packet.message)
        let decoded = events.isEmpty ? nil : events.map(\.monitorDisplay).joined(separator: "  ")
        rows.append(MonitorRow(time: packet.receivedAt, raw: packet.message.display, decoded: decoded))
        if rows.count > Self.capacity {
            rows.removeFirst(rows.count - Self.capacity)
        }
    }

    func clear() {
        rows.removeAll()
    }
}

extension ControlEvent {
    /// Compact monitor-column rendering, e.g. "deck1.play ↓ ⇧" or "mixer.crossfader = 0.531".
    var monitorDisplay: String {
        switch self {
        case let .pressed(id, shifted):
            return "\(id) ↓\(shifted ? " ⇧" : "")"
        case let .released(id, shifted):
            return "\(id) ↑\(shifted ? " ⇧" : "")"
        case let .value(id, value, shifted):
            return "\(id) = \(String(format: "%.3f", value))\(shifted ? " ⇧" : "")"
        case let .relative(id, ticks, touched, shifted):
            return "\(id) \(ticks > 0 ? "+" : "")\(ticks)\(touched ? " ✋" : "")\(shifted ? " ⇧" : "")"
        }
    }
}
