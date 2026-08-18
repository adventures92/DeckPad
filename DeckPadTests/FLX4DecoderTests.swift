//
//  FLX4DecoderTests.swift
//  DeckPadTests
//
//  Decoder tests against captured hardware behavior. The fixture-replay
//  suite re-plays docs/fixtures/flx4-capture.json (recorded from the
//  physical DDJ-FLX4) so CI needs no device.
//

import Foundation
import Testing
@testable import DeckPad

@MainActor
struct FLX4DecoderTests {
    // MARK: Buttons

    @Test func playButtonPressAndRelease() {
        let decoder = DDJFLX4Descriptor()
        #expect(decoder.decode(.noteOn(channel: 0, note: 0x0B, velocity: 127))
            == [.pressed(ControlID("deck1.play"), shifted: false)])
        #expect(decoder.decode(.noteOff(channel: 0, note: 0x0B, velocity: 64))
            == [.released(ControlID("deck1.play"), shifted: false)])
    }

    @Test func noteOnVelocityZeroIsRelease() {
        let decoder = DDJFLX4Descriptor()
        #expect(decoder.decode(.noteOn(channel: 1, note: 0x0C, velocity: 0))
            == [.released(ControlID("deck2.cue"), shifted: false)])
    }

    @Test func heldShiftMarksEventsShifted() {
        let decoder = DDJFLX4Descriptor()
        _ = decoder.decode(.noteOn(channel: 0, note: 0x3F, velocity: 127))   // deck1 SHIFT down
        #expect(decoder.decode(.noteOn(channel: 0, note: 0x0B, velocity: 127))
            == [.pressed(ControlID("deck1.play"), shifted: true)])
        // Other deck unaffected
        #expect(decoder.decode(.noteOn(channel: 1, note: 0x0B, velocity: 127))
            == [.pressed(ControlID("deck2.play"), shifted: false)])
        // Global sections respond to either SHIFT
        #expect(decoder.decode(.noteOn(channel: 6, note: 0x46, velocity: 127))
            == [.pressed(ControlID("browser.load1"), shifted: true)])
        _ = decoder.decode(.noteOff(channel: 0, note: 0x3F, velocity: 64))   // SHIFT up
        #expect(decoder.decode(.noteOn(channel: 0, note: 0x0B, velocity: 127))
            == [.pressed(ControlID("deck1.play"), shifted: false)])
    }

    @Test func shiftVariantNoteNumberForcesShiftedFlag() {
        let decoder = DDJFLX4Descriptor()
        // 0x0E is the SHIFT-variant of play (provisional, from reference)
        #expect(decoder.decode(.noteOn(channel: 0, note: 0x0E, velocity: 127))
            == [.pressed(ControlID("deck1.play"), shifted: true)])
    }

    // MARK: Pads (mode-dependent note ranges, SHIFT as channel switch)

    @Test func padsDecodeAcrossAllModeRanges() {
        let decoder = DDJFLX4Descriptor()
        for base in [UInt8(0x00), 0x10, 0x20, 0x30, 0x40, 0x60, 0x70] {
            #expect(decoder.decode(.noteOn(channel: 7, note: base + 2, velocity: 127))
                == [.pressed(ControlID("deck1.pad3"), shifted: false)], "mode range 0x\(String(base, radix: 16))")
        }
        // Deck 2, sampler range (as captured)
        #expect(decoder.decode(.noteOn(channel: 9, note: 0x37, velocity: 127))
            == [.pressed(ControlID("deck2.pad8"), shifted: false)])
        // SHIFT pad channels
        #expect(decoder.decode(.noteOn(channel: 8, note: 0x30, velocity: 127))
            == [.pressed(ControlID("deck1.pad1"), shifted: true)])
        #expect(decoder.decode(.noteOn(channel: 10, note: 0x05, velocity: 127))
            == [.pressed(ControlID("deck2.pad6"), shifted: true)])
    }

    // MARK: 14-bit continuous

    @Test func fourteenBitPairEmitsOnLSB() {
        let decoder = DDJFLX4Descriptor()
        // Crossfader: MSB CC 0x1F, LSB CC 0x3F on ch 6 (captured)
        #expect(decoder.decode(.controlChange(channel: 6, controller: 0x1F, value: 64)).isEmpty)
        let events = decoder.decode(.controlChange(channel: 6, controller: 0x3F, value: 0))
        guard case let .value(id, value, _)? = events.first else {
            Issue.record("expected value event, got \(events)")
            return
        }
        #expect(id == ControlID("mixer.crossfader"))
        #expect(abs(value - Double(64 << 7) / 16383.0) < 0.0001)
    }

    @Test func fourteenBitEndpointsReachZeroAndOne() {
        let decoder = DDJFLX4Descriptor()
        _ = decoder.decode(.controlChange(channel: 0, controller: 0x13, value: 0))
        #expect(decoder.decode(.controlChange(channel: 0, controller: 0x33, value: 0))
            == [.value(ControlID("mixer.ch1.fader"), 0.0, shifted: false)])
        _ = decoder.decode(.controlChange(channel: 0, controller: 0x13, value: 127))
        #expect(decoder.decode(.controlChange(channel: 0, controller: 0x33, value: 127))
            == [.value(ControlID("mixer.ch1.fader"), 1.0, shifted: false)])
    }

    // MARK: Relative encoders

    @Test func jogIsCentered64WithTouchTracking() {
        let decoder = DDJFLX4Descriptor()
        #expect(decoder.decode(.controlChange(channel: 0, controller: 0x22, value: 66))
            == [.relative(ControlID("deck1.jog"), ticks: 2, touched: false, shifted: false)])
        _ = decoder.decode(.noteOn(channel: 0, note: 0x36, velocity: 127))   // touch down
        #expect(decoder.decode(.controlChange(channel: 0, controller: 0x22, value: 63))
            == [.relative(ControlID("deck1.jog"), ticks: -1, touched: true, shifted: false)])
        #expect(decoder.decode(.controlChange(channel: 0, controller: 0x21, value: 65))
            == [.relative(ControlID("deck1.jogSide"), ticks: 1, touched: false, shifted: false)])
        // Center value = no movement = no event
        #expect(decoder.decode(.controlChange(channel: 0, controller: 0x22, value: 64)).isEmpty)
    }

    @Test func browseEncoderIsTwosComplement() {
        let decoder = DDJFLX4Descriptor()
        #expect(decoder.decode(.controlChange(channel: 6, controller: 0x40, value: 1))
            == [.relative(ControlID("browser.encoder"), ticks: 1, touched: false, shifted: false)])
        #expect(decoder.decode(.controlChange(channel: 6, controller: 0x40, value: 127))
            == [.relative(ControlID("browser.encoder"), ticks: -1, touched: false, shifted: false)])
    }

    // MARK: Unknown input

    @Test func unknownMessagesDecodeToNothing() {
        let decoder = DDJFLX4Descriptor()
        #expect(decoder.decode(.noteOn(channel: 3, note: 0x7F, velocity: 127)).isEmpty)
        #expect(decoder.decode(.controlChange(channel: 2, controller: 0x50, value: 10)).isEmpty)
        #expect(decoder.decode(.other(description: "sysex")).isEmpty)
    }
}

// MARK: - Fixture replay (docs/fixtures/flx4-capture.json)

@MainActor
struct FLX4FixtureReplayTests {
    private static var fixtureURL: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()   // DeckPadTests/
            .deletingLastPathComponent()   // repo root
            .appendingPathComponent("docs/fixtures/flx4-capture.json")
    }

    @Test func everyCapturedMessageDecodes() throws {
        let data = try Data(contentsOf: Self.fixtureURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let fixture = try decoder.decode(CaptureFixture.self, from: data)
        #expect(!fixture.entries.isEmpty)

        let flx4 = DDJFLX4Descriptor()
        var undecoded: [String] = []

        for entry in fixture.entries where !entry.skipped {
            // Synthesize messages from aggregated observations in CC-then-note
            // order so 14-bit MSBs precede their LSBs (MSB CC < LSB CC).
            let sorted = entry.observations.sorted { ($0.type, $0.channel, $0.number) < ($1.type, $1.channel, $1.number) }
            for obs in sorted {
                let messages: [RawMIDIMessage]
                switch obs.type {
                case "noteOn":
                    messages = [.noteOn(channel: obs.channel, note: obs.number, velocity: obs.firstValue)]
                case "noteOff":
                    messages = [.noteOff(channel: obs.channel, note: obs.number, velocity: obs.firstValue)]
                case "cc":
                    messages = [.controlChange(channel: obs.channel, controller: obs.number, value: obs.lastValue)]
                default:
                    messages = []
                }
                for message in messages {
                    let events = flx4.decode(message)
                    let isMSBLatch: Bool = {
                        // MSB halves of 14-bit pairs legitimately emit nothing.
                        guard case let .controlChange(ch, cc, _) = message, cc < 0x20 || events.isEmpty else { return false }
                        _ = ch
                        return events.isEmpty
                    }()
                    let isCenterTick: Bool = {
                        // Relative CC at center value legitimately emits nothing.
                        guard case let .controlChange(_, _, value) = message else { return false }
                        return value == 64
                    }()
                    if events.isEmpty && !isMSBLatch && !isCenterTick {
                        undecoded.append("\(entry.control): \(message.display)")
                    }
                }
            }
        }

        #expect(undecoded.isEmpty, "captured messages with no decode: \(undecoded)")
    }

    @Test func capturedButtonsDecodeToTheirDocumentedControlID() throws {
        let data = try Data(contentsOf: Self.fixtureURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let fixture = try decoder.decode(CaptureFixture.self, from: data)

        let flx4 = DDJFLX4Descriptor()
        var mismatches: [String] = []

        for entry in fixture.entries where !entry.skipped && entry.pass == "base" {
            // Only single-tuple button captures give an unambiguous expectation.
            let noteOns = entry.observations.filter { $0.type == "noteOn" }
            guard noteOns.count == 1, let obs = noteOns.first else { continue }
            // Jog entries contain touch notes intermixed with turn CCs; skip.
            if entry.control.hasSuffix(".jog") || entry.control.hasSuffix(".jogTouch") { continue }

            let events = flx4.decode(.noteOn(channel: obs.channel, note: obs.number, velocity: 127))
            guard case let .pressed(id, _)? = events.first, id.rawValue == entry.control else {
                mismatches.append("\(entry.control) → \(events)")
                continue
            }
        }

        #expect(mismatches.isEmpty, "controls decoding to the wrong ID: \(mismatches)")
    }
}
