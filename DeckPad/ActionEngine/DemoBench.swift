//
//  DemoBench.swift
//  DeckPad
//
//  TEMPORARY (M2) — hardcoded control→action wiring proving the roadmap
//  demo before the real mapping system (M3) exists. Removed in M3.
//
//  Bindings while enabled:
//    deck1.pad1  → types "Hello from DeckPad! "
//    deck1.pad2  → media Play/Pause
//    deck1.pad4  → launch/focus TextEdit
//    mixer.ch1.fader → system volume
//    deck1.jog / jogSide → vertical scroll
//    browser.encoder → volume dial (fine steps)
//

import Combine
import Foundation
import os

@MainActor
final class DemoBench: ObservableObject {
    static let shared = DemoBench()

    @Published var isEnabled = false {
        didSet {
            guard isEnabled != oldValue else { return }
            isEnabled ? start() : stop()
        }
    }

    private let listenerID = UUID()
    private let decoder = DDJFLX4Descriptor()
    private static let log = Logger(subsystem: "com.adven.DeckPad", category: "latency")

    // Rolling latency stats for the M2 measurement (decode→post, discrete actions).
    private var samplesMicroseconds: [Double] = []

    private func start() {
        let permissions = PermissionsManager.shared
        permissions.refresh()
        if !permissions.accessibilityGranted {
            permissions.promptForAccessibility()
            permissions.openAccessibilitySettings()
        }
        MIDIEngine.shared.addListener(listenerID) { [weak self] packet in
            self?.handle(packet)
        }
        Self.log.info("M2 test bench enabled")
    }

    private func stop() {
        MIDIEngine.shared.removeListener(listenerID)
        Self.log.info("M2 test bench disabled")
    }

    private func handle(_ packet: RawMIDIPacket) {
        for event in decoder.decode(packet.message) {
            switch event {
            case let .pressed(id, _):
                let start = ContinuousClock.now
                var fired = true
                switch id.rawValue {
                case "deck1.pad1":
                    ActionEngine.shared.execute(.textSnippet("Hello from DeckPad! "))
                case "deck1.pad2":
                    ActionEngine.shared.execute(.mediaKey(.playPause, steps: 1))
                case "deck1.pad4":
                    ActionEngine.shared.execute(.launchApp(bundleID: "com.apple.TextEdit"))
                default:
                    fired = false
                }
                if fired { recordLatency(since: start) }

            case let .value(id, value, _) where id.rawValue == "mixer.ch1.fader":
                ActionEngine.shared.executeContinuous(.systemVolume(ContinuousShape()), value: value)

            case let .relative(id, ticks, _, _):
                switch id.rawValue {
                case "deck1.jog", "deck1.jogSide":
                    ActionEngine.shared.executeRelative(
                        .scroll(axis: .vertical, speedMultiplier: 1.5, natural: false),
                        ticks: ticks,
                        token: id.rawValue
                    )
                case "browser.encoder":
                    ActionEngine.shared.executeRelative(.volumeDial(stepSize: 0.02), ticks: ticks, token: id.rawValue)
                default:
                    break
                }

            default:
                break
            }
        }
    }

    private func recordLatency(since start: ContinuousClock.Instant) {
        let elapsed = start.duration(to: .now)
        let micros = Double(elapsed.components.attoseconds) / 1e12 + Double(elapsed.components.seconds) * 1e6
        samplesMicroseconds.append(micros)
        Self.log.info("action dispatch \(micros, format: .fixed(precision: 1)) µs (decode→post, in-process)")
        if samplesMicroseconds.count % 10 == 0 {
            let sorted = samplesMicroseconds.sorted()
            let p50 = sorted[sorted.count / 2]
            let p95 = sorted[Int(Double(sorted.count) * 0.95).clamped(to: 0...(sorted.count - 1))]
            Self.log.info("latency over \(sorted.count) actions: p50 \(p50, format: .fixed(precision: 1)) µs, p95 \(p95, format: .fixed(precision: 1)) µs")
        }
    }
}

private extension Int {
    func clamped(to range: ClosedRange<Int>) -> Int {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
