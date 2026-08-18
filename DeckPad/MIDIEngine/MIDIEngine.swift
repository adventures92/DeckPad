//
//  MIDIEngine.swift
//  DeckPad
//
//  Owns CoreMIDI via MIDIKit (ADR-003). MIDIKit types are confined to this
//  file. Publishes connection state and fans out RawMIDIPackets to
//  registered listeners on the main actor (monitor, capture; the Dispatcher
//  gets its own queue-based path in M3).
//

import Combine
import Foundation
import SwiftMIDI
import os

@MainActor
final class MIDIEngine: ObservableObject {
    static let shared = MIDIEngine()

    @Published private(set) var isConnected = false
    @Published private(set) var endpointDescription: String?

    private static let log = Logger(subsystem: "com.adven.DeckPad", category: "midi")
    private static let inputTag = "DeckPadIn"
    private static let outputTag = "DeckPadOut"

    private var manager: MIDIManager?
    private var listeners: [UUID: (RawMIDIPacket) -> Void] = [:]

    // MARK: Lifecycle

    func start() {
        let manager = MIDIManager(
            clientName: "DeckPad",
            model: "DeckPad",
            manufacturer: "adven"
        )
        self.manager = manager

        manager.notificationHandler = { [weak self] _ in
            Task { @MainActor [weak self] in self?.refreshConnection() }
        }

        do {
            try manager.start()
            try manager.addInputConnection(
                to: .allOutputs,
                tag: Self.inputTag,
                receiver: .events { [weak self] events, _, _ in
                    let now = Date()
                    let packets = events.compactMap { event in
                        Self.rawMessage(from: event).map { RawMIDIPacket(message: $0, receivedAt: now) }
                    }
                    guard !packets.isEmpty else { return }
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        for packet in packets { self.dispatch(packet) }
                    }
                }
            )
            try manager.addOutputConnection(to: .allInputs, tag: Self.outputTag)
        } catch {
            Self.log.error("MIDI manager start failed: \(error.localizedDescription)")
        }

        refreshConnection()
    }

    // MARK: Listeners (main-actor fan-out)

    func addListener(_ id: UUID, handler: @escaping (RawMIDIPacket) -> Void) {
        listeners[id] = handler
    }

    func removeListener(_ id: UUID) {
        listeners.removeValue(forKey: id)
    }

    private func dispatch(_ packet: RawMIDIPacket) {
        for handler in listeners.values { handler(packet) }
    }

    // MARK: Output (LED groundwork, FR-5)

    func send(_ message: RawMIDIMessage) {
        guard let connection = manager?.managedOutputConnections[Self.outputTag] else { return }
        do {
            switch message {
            case let .noteOn(channel, note, velocity):
                try connection.send(event: .noteOn(
                    UInt7(note),
                    velocity: .midi1(UInt7(velocity)),
                    channel: UInt4(channel)
                ))
            case let .noteOff(channel, note, velocity):
                try connection.send(event: .noteOff(
                    UInt7(note),
                    velocity: .midi1(UInt7(velocity)),
                    channel: UInt4(channel)
                ))
            case let .controlChange(channel, controller, value):
                try connection.send(event: .cc(
                    UInt7(controller),
                    value: .midi1(UInt7(value)),
                    channel: UInt4(channel)
                ))
            case .other:
                break
            }
        } catch {
            Self.log.error("MIDI send failed: \(error.localizedDescription)")
        }
    }

    // MARK: Connection state (FR-1, FR-4)

    private func refreshConnection() {
        guard let manager else {
            isConnected = false
            endpointDescription = nil
            return
        }
        let source = manager.endpoints.outputs.first {
            $0.displayName.contains(DDJFLX4Descriptor.endpointNameMarker)
                || $0.name.contains(DDJFLX4Descriptor.endpointNameMarker)
        }
        let wasConnected = isConnected
        isConnected = source != nil
        endpointDescription = source?.displayName
        if wasConnected != isConnected {
            Self.log.info("DDJ-FLX4 \(self.isConnected ? "connected" : "disconnected")")
        }
    }

    // MARK: MIDIKit → RawMIDI mapping (MIDIKit types stay in this file)

    private nonisolated static func rawMessage(from event: MIDIEvent) -> RawMIDIMessage? {
        switch event {
        case let .noteOn(payload):
            return .noteOn(
                channel: payload.channel.uInt8Value,
                note: payload.note.number.uInt8Value,
                velocity: payload.velocity.midi1Value.uInt8Value
            )
        case let .noteOff(payload):
            return .noteOff(
                channel: payload.channel.uInt8Value,
                note: payload.note.number.uInt8Value,
                velocity: payload.velocity.midi1Value.uInt8Value
            )
        case let .cc(payload):
            return .controlChange(
                channel: payload.channel.uInt8Value,
                controller: payload.controller.number.uInt8Value,
                value: payload.value.midi1Value.uInt8Value
            )
        default:
            return .other(description: String(describing: event))
        }
    }
}
