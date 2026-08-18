//
//  CaptureSession.swift
//  DeckPad
//
//  Capture-mode state machine (docs/03-device-ddj-flx4.md §5): walks the
//  DDJ-FLX4 inventory in documented order, prompts the user to actuate each
//  control, aggregates the observed raw messages, and exports the fixture
//  (flx4-capture.json) plus a Markdown table for the device doc.
//
//  Deliberately dumb-and-faithful: it records every distinct
//  (type, channel, number) tuple seen per prompt with value stats;
//  interpretation (14-bit pairs, relative encodings, shift variants)
//  happens offline when the descriptor table is generated.
//

import AppKit
import Combine
import Foundation

nonisolated struct CaptureObservation: Codable, Identifiable, Equatable {
    var type: String        // "noteOn" / "noteOff" / "cc" / "other"
    var channel: UInt8
    var number: UInt8
    var count: Int
    var minValue: UInt8
    var maxValue: UInt8
    var firstValue: UInt8
    var lastValue: UInt8

    var id: String { "\(type)/\(channel)/\(number)" }

    var display: String {
        let range = minValue == maxValue ? "\(minValue)" : "\(minValue)–\(maxValue)"
        return "\(type) ch\(channel) #\(number) val \(range) ×\(count)"
    }
}

nonisolated struct CaptureEntry: Codable, Identifiable {
    var control: String
    var pass: String        // "base" / "shift"
    var skipped: Bool
    var observations: [CaptureObservation]

    var id: String { "\(pass)/\(control)" }
}

nonisolated struct CaptureFixture: Codable {
    var device: String
    var endpointName: String
    var endpointManufacturer: String
    var capturedAt: Date
    var entries: [CaptureEntry]
}

@MainActor
final class CaptureSession: ObservableObject {
    enum Pass: String, CaseIterable, Identifiable {
        case base, shift
        var id: String { rawValue }
        var label: String { self == .base ? "Pass A — Base" : "Pass B — SHIFT held" }
    }

    enum Phase: Equatable {
        case idle           // capture mode off
        case prompting      // waiting for first message for current item
        case collecting     // messages arriving; finalizes after silence
        case done
    }

    @Published private(set) var phase: Phase = .idle
    @Published var pass: Pass = .base
    @Published private(set) var index = 0
    @Published private(set) var entries: [CaptureEntry] = []
    @Published private(set) var liveObservations: [CaptureObservation] = []
    @Published var statusLine: String?

    private var aggregates: [String: CaptureObservation] = [:]
    private var silenceTask: Task<Void, Never>?
    private var cooldownUntil: Date = .distantPast

    private let inventory = DDJFLX4Descriptor().controls

    /// SHIFT pass skips the shift buttons themselves (they're the modifier).
    var items: [ControlSpec] {
        pass == .base
            ? inventory
            : inventory.filter { !$0.id.rawValue.hasSuffix(".shift") }
    }

    var currentItem: ControlSpec? {
        guard phase == .prompting || phase == .collecting, index < items.count else { return nil }
        return items[index]
    }

    var progressLabel: String { "\(min(index + 1, items.count)) / \(items.count)" }

    var capturedCount: Int { entries.filter { !$0.skipped }.count }

    // MARK: Session control

    func begin(_ pass: Pass) {
        self.pass = pass
        entries.removeAll { $0.pass == pass.rawValue }
        index = 0
        resetAggregation()
        phase = .prompting
        statusLine = nil
    }

    func stop() {
        silenceTask?.cancel()
        resetAggregation()
        phase = .idle
    }

    func skip() {
        guard let item = currentItem else { return }
        silenceTask?.cancel()
        entries.append(CaptureEntry(control: item.id.rawValue, pass: pass.rawValue, skipped: true, observations: []))
        advance()
    }

    func redoPrevious() {
        guard index > 0, phase != .idle else { return }
        silenceTask?.cancel()
        index -= 1
        let redoID = items[index].id.rawValue
        entries.removeAll { $0.control == redoID && $0.pass == pass.rawValue }
        resetAggregation()
        phase = .prompting
    }

    // MARK: Prompting

    func prompt(for item: ControlSpec) -> String {
        let shiftPrefix = pass == .shift ? "Hold SHIFT, then: " : ""
        let base: String
        switch item.kind {
        case .button, .pad:
            base = item.id.rawValue.hasSuffix(".jogTouch")
                ? "Touch the jog surface, hold ~1s, release — do not turn"
                : "Press and release once"
        case .fader, .knob, .slider:
            base = "Sweep slowly: min → max → min"
        case .jog:
            base = item.id.rawValue.hasSuffix(".jogSide")
                ? "WITHOUT touching the top, turn the rim forward ~a quarter turn"
                : "Touch the top surface and turn forward ~a quarter turn"
        case .encoder:
            base = "Turn forward 3–4 clicks, then backward 3–4 clicks"
        }
        return shiftPrefix + base
    }

    // MARK: Message intake

    func handle(_ packet: RawMIDIPacket) {
        guard phase == .prompting || phase == .collecting else { return }
        guard packet.receivedAt >= cooldownUntil else { return }

        aggregate(packet.message)
        phase = .collecting
        liveObservations = aggregates.values.sorted { $0.count > $1.count }

        silenceTask?.cancel()
        silenceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }
            self?.finalizeCurrent()
        }
    }

    private func aggregate(_ message: RawMIDIMessage) {
        let (type, channel, number, value): (String, UInt8, UInt8, UInt8)
        switch message {
        case let .noteOn(ch, note, vel): (type, channel, number, value) = ("noteOn", ch, note, vel)
        case let .noteOff(ch, note, vel): (type, channel, number, value) = ("noteOff", ch, note, vel)
        case let .controlChange(ch, cc, val): (type, channel, number, value) = ("cc", ch, cc, val)
        case .other: (type, channel, number, value) = ("other", 0, 0, 0)
        }
        let key = "\(type)/\(channel)/\(number)"
        if var existing = aggregates[key] {
            existing.count += 1
            existing.minValue = min(existing.minValue, value)
            existing.maxValue = max(existing.maxValue, value)
            existing.lastValue = value
            aggregates[key] = existing
        } else {
            aggregates[key] = CaptureObservation(
                type: type, channel: channel, number: number,
                count: 1, minValue: value, maxValue: value,
                firstValue: value, lastValue: value
            )
        }
    }

    private func finalizeCurrent() {
        guard let item = currentItem else { return }
        entries.append(CaptureEntry(
            control: item.id.rawValue,
            pass: pass.rawValue,
            skipped: false,
            observations: aggregates.values.sorted { ($0.type, $0.channel, $0.number) < ($1.type, $1.channel, $1.number) }
        ))
        advance()
    }

    private func advance() {
        resetAggregation()
        cooldownUntil = Date().addingTimeInterval(0.4)
        if index + 1 < items.count {
            index += 1
            phase = .prompting
        } else {
            phase = .done
            statusLine = "Pass complete — \(capturedCount) controls captured."
        }
    }

    private func resetAggregation() {
        aggregates.removeAll()
        liveObservations.removeAll()
    }

    // MARK: Export

    func export() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.prompt = "Export Here"
        panel.message = "Choose a folder for flx4-capture.json and flx4-capture.md (e.g. the repo's docs/fixtures/)"
        guard panel.runModal() == .OK, let dir = panel.url else { return }

        let fixture = CaptureFixture(
            device: "DDJ-FLX4",
            endpointName: MIDIEngine.shared.endpointDescription ?? "DDJ-FLX4",
            endpointManufacturer: "AlphaTheta Corporation",
            capturedAt: Date(),
            entries: entries.sorted { ($0.pass, $0.control) < ($1.pass, $1.control) }
        )
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(fixture).write(to: dir.appendingPathComponent("flx4-capture.json"))
            try markdownTable().data(using: .utf8)?.write(to: dir.appendingPathComponent("flx4-capture.md"))
            statusLine = "Exported to \(dir.path)"
        } catch {
            statusLine = "Export failed: \(error.localizedDescription)"
        }
    }

    private func markdownTable() -> String {
        var lines = [
            "| Control | Pass | Type | Ch | Num (dec/hex) | Values | Count |",
            "|---|---|---|---|---|---|---|",
        ]
        for entry in entries.sorted(by: { ($0.control, $0.pass) < ($1.control, $1.pass) }) {
            if entry.skipped {
                lines.append("| `\(entry.control)` | \(entry.pass) | — | — | — | skipped | — |")
                continue
            }
            for obs in entry.observations {
                let hex = String(format: "0x%02X", obs.number)
                let range = obs.minValue == obs.maxValue ? "\(obs.minValue)" : "\(obs.minValue)–\(obs.maxValue)"
                lines.append("| `\(entry.control)` | \(entry.pass) | \(obs.type) | \(obs.channel) | \(obs.number) / \(hex) | \(range) | \(obs.count) |")
            }
        }
        return lines.joined(separator: "\n") + "\n"
    }
}
