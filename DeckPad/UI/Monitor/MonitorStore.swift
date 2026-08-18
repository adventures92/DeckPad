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
        let decoded = descriptor.decode(packet.message).map { String(describing: $0) }
        rows.append(MonitorRow(time: packet.receivedAt, raw: packet.message.display, decoded: decoded))
        if rows.count > Self.capacity {
            rows.removeFirst(rows.count - Self.capacity)
        }
    }

    func clear() {
        rows.removeAll()
    }
}
