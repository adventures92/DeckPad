//
//  DDJFLX4Descriptor.swift
//  DeckPad
//
//  Pioneer DJ DDJ-FLX4 descriptor. The decode tables below are populated
//  from the M1 capture session against the physical unit on 2026-08-18
//  (docs/fixtures/flx4-capture.json), cross-checked against the Mixxx
//  community mapping — per ADR-004, captured values are truth.
//
//  Layer facts (captured):
//  - Deck 1 = MIDI ch 0, Deck 2 = ch 1. Beat FX = ch 4/5. Browser + mixer
//    master section = ch 6. Performance pads: deck 1 = ch 7 (ch 8 with
//    SHIFT), deck 2 = ch 9 (ch 10 with SHIFT) — SHIFT is a channel switch
//    for pads, a different note/CC number for everything else.
//  - Buttons: noteOn vel 127 on press; release arrives as noteOff.
//  - Pad note numbers depend on the active pad mode (Hot Cue 0x00–0x07,
//    Pad FX 0x10–0x17, Beat Jump 0x20–0x27, Sampler 0x30–0x37, plus
//    2nd-layer modes 0x40/0x60/0x70). All ranges decode to the same
//    deckN.padK — DeckPad mappings are pad-mode-agnostic.
//  - Continuous controls are 14-bit: MSB on CC n, LSB on CC n+0x20.
//  - Jog platter/rim are 64-centered relative CCs; the browse encoder is
//    two's-complement relative (1 = +1, 127 = −1).
//  - SHIFT-variant numbers captured in Pass B (2026-08-18) — every
//    reference-sourced value confirmed, plus captured-only additions the
//    community map lacks (load/beat/smart SHIFT variants, fader-start).
//  - CUE/LOOP CALL ◀/▶ captured via targeted sniffer (2026-08-18):
//    base 0x51/0x53, SHIFT 0x3E/0x3D, per deck channel.
//
//  Endpoint identity confirmed (M1): name "DDJ-FLX4",
//  manufacturer "AlphaTheta Corporation", model "DDJ-FLX4".
//

import Foundation

final class DDJFLX4Descriptor: DeviceDescriptor {
    static let endpointNameMarker = "DDJ-FLX4"

    let controls: [ControlSpec] = DDJFLX4Descriptor.buildInventory()

    // MARK: - Layer state

    private var shiftDown = [false, false]   // deck 1, deck 2
    private var jogTouched = [false, false]
    private var msbLatch: [Key: UInt8] = [:]

    private struct Key: Hashable {
        let channel: UInt8
        let number: UInt8
    }

    private struct NoteMapping {
        let id: ControlID
        let forcedShift: Bool     // true for SHIFT-variant note numbers
        let deckScope: Int?       // 0/1 = that deck's SHIFT; nil = either SHIFT
    }

    private enum RelativeEncoding {
        case centered64           // jogs: value − 64
        case twosComplement       // browse encoder: 1…63 fwd, 127…65 = −1…−63
    }

    private struct RelativeMapping {
        let id: ControlID
        let encoding: RelativeEncoding
        let forcedShift: Bool
        let deckScope: Int?
        let jogDeck: Int?         // index into jogTouched, nil = not a jog
    }

    private let noteMap: [Key: NoteMapping]
    private let relativeMap: [Key: RelativeMapping]
    private let msbMap: [Key: (id: ControlID, deckScope: Int?)]

    init() {
        (noteMap, relativeMap, msbMap) = Self.buildDecodeTables()
    }

    // MARK: - Decode

    func decode(_ message: RawMIDIMessage) -> [ControlEvent] {
        switch message {
        case let .noteOn(channel, note, velocity):
            return handleNote(channel: channel, note: note, pressed: velocity > 0)
        case let .noteOff(channel, note, _):
            return handleNote(channel: channel, note: note, pressed: false)
        case let .controlChange(channel, controller, value):
            return handleCC(channel: channel, controller: controller, value: value)
        case .other:
            return []
        }
    }

    private func handleNote(channel: UInt8, note: UInt8, pressed: Bool) -> [ControlEvent] {
        // Performance pads: channel encodes deck + SHIFT, low 3 bits encode
        // the pad within any mode's note range.
        if (7...10).contains(channel) {
            let deck = channel <= 8 ? 1 : 2
            let shifted = channel == 8 || channel == 10
            let id = ControlID("deck\(deck).pad\((note & 0x07) + 1)")
            return [pressed ? .pressed(id, shifted: shifted) : .released(id, shifted: shifted)]
        }

        guard let mapping = noteMap[Key(channel: channel, number: note)] else { return [] }

        // Track layer state.
        if mapping.id.rawValue.hasSuffix(".shift"), let deck = mapping.deckScope {
            shiftDown[deck] = pressed
        }
        if mapping.id.rawValue.hasSuffix(".jogTouch"), let deck = mapping.deckScope {
            jogTouched[deck] = pressed
        }

        let shifted = mapping.forcedShift || isShifted(scope: mapping.deckScope)
        return [pressed ? .pressed(mapping.id, shifted: shifted) : .released(mapping.id, shifted: shifted)]
    }

    private func handleCC(channel: UInt8, controller: UInt8, value: UInt8) -> [ControlEvent] {
        let key = Key(channel: channel, number: controller)

        // Relative encoders first (their CC numbers overlap the LSB range).
        if let mapping = relativeMap[key] {
            let ticks: Int
            switch mapping.encoding {
            case .centered64:
                ticks = Int(value) - 64
            case .twosComplement:
                ticks = value < 64 ? Int(value) : Int(value) - 128
            }
            guard ticks != 0 else { return [] }
            let touched = mapping.jogDeck.map { jogTouched[$0] } ?? false
            let shifted = mapping.forcedShift || isShifted(scope: mapping.deckScope)
            return [.relative(mapping.id, ticks: ticks, touched: touched, shifted: shifted)]
        }

        // 14-bit absolute pairs: latch MSB, emit on LSB (CC = MSB + 0x20).
        if let entry = msbMap[key] {
            msbLatch[key] = value
            _ = entry
            return []
        }
        if controller >= 0x20 {
            let msbKey = Key(channel: channel, number: controller - 0x20)
            if let entry = msbMap[msbKey], let msb = msbLatch[msbKey] {
                let value14 = (Int(msb) << 7) | Int(value)
                let normalized = Double(value14) / 16383.0
                return [.value(entry.id, normalized, shifted: isShifted(scope: entry.deckScope))]
            }
        }

        return []
    }

    private func isShifted(scope: Int?) -> Bool {
        if let scope { return shiftDown[scope] }
        return shiftDown[0] || shiftDown[1]
    }

    // MARK: - Decode tables (captured 2026-08-18; "provisional" = from Mixxx reference, pending Pass B)

    private static func buildDecodeTables() -> (
        notes: [Key: NoteMapping],
        relative: [Key: RelativeMapping],
        msb: [Key: (id: ControlID, deckScope: Int?)]
    ) {
        var notes: [Key: NoteMapping] = [:]
        var relative: [Key: RelativeMapping] = [:]
        var msb: [Key: (id: ControlID, deckScope: Int?)] = [:]

        func note(_ ch: UInt8, _ num: UInt8, _ id: String, shift: Bool = false, deck: Int? = nil) {
            notes[Key(channel: ch, number: num)] = NoteMapping(id: ControlID(id), forcedShift: shift, deckScope: deck)
        }

        for deck in 0...1 {
            let ch = UInt8(deck)
            let d = "deck\(deck + 1)"

            // Captured (base pass)
            note(ch, 0x0B, "\(d).play", deck: deck)
            note(ch, 0x0C, "\(d).cue", deck: deck)
            note(ch, 0x58, "\(d).sync", deck: deck)
            note(ch, 0x3F, "\(d).shift", deck: deck)
            note(ch, 0x10, "\(d).loopIn", deck: deck)
            note(ch, 0x11, "\(d).loopOut", deck: deck)
            note(ch, 0x4D, "\(d).reloopExit", deck: deck)
            note(ch, 0x1B, "\(d).padModeHotCue", deck: deck)
            note(ch, 0x1E, "\(d).padModePadFX", deck: deck)
            note(ch, 0x20, "\(d).padModeBeatJump", deck: deck)
            note(ch, 0x22, "\(d).padModeSampler", deck: deck)
            note(ch, 0x36, "\(d).jogTouch", deck: deck)
            note(ch, 0x54, "mixer.ch\(deck + 1).cue", deck: deck)

            // CUE/LOOP CALL ◀/▶ (captured via targeted sniffer 2026-08-18)
            note(ch, 0x51, "\(d).cueLoopLeft", deck: deck)
            note(ch, 0x53, "\(d).cueLoopRight", deck: deck)
            note(ch, 0x3E, "\(d).cueLoopLeft", shift: true, deck: deck)
            note(ch, 0x3D, "\(d).cueLoopRight", shift: true, deck: deck)

            // Firmware auxiliary triggers (captured Pass B): SHIFT + fader
            // movement emits dedicated fader-start notes. Decoded but not in
            // the physical inventory; mappability decided in M3/M4.
            note(ch, 0x52, "\(d).faderStart", deck: deck)
            note(ch, 0x66, "\(d).xfaderStart", deck: deck)

            // SHIFT variants (captured Pass B 2026-08-18)
            note(ch, 0x0E, "\(d).play", shift: true, deck: deck)
            note(ch, 0x48, "\(d).cue", shift: true, deck: deck)
            note(ch, 0x60, "\(d).sync", shift: true, deck: deck)
            note(ch, 0x4C, "\(d).loopIn", shift: true, deck: deck)
            note(ch, 0x4E, "\(d).loopOut", shift: true, deck: deck)
            note(ch, 0x50, "\(d).reloopExit", shift: true, deck: deck)
            note(ch, 0x69, "\(d).padModeHotCue", shift: true, deck: deck)
            note(ch, 0x6B, "\(d).padModePadFX", shift: true, deck: deck)
            note(ch, 0x6D, "\(d).padModeBeatJump", shift: true, deck: deck)
            note(ch, 0x6F, "\(d).padModeSampler", shift: true, deck: deck)
            note(ch, 0x67, "\(d).jogTouch", shift: true, deck: deck)
            note(ch, 0x68, "mixer.ch\(deck + 1).cue", shift: true, deck: deck)

            // Jogs (captured): platter touched 0x22, platter untouched 0x23,
            // rim 0x21; SHIFT platter 0x29 provisional.
            relative[Key(channel: ch, number: 0x22)] = RelativeMapping(
                id: ControlID("\(d).jog"), encoding: .centered64, forcedShift: false, deckScope: deck, jogDeck: deck
            )
            relative[Key(channel: ch, number: 0x23)] = RelativeMapping(
                id: ControlID("\(d).jog"), encoding: .centered64, forcedShift: false, deckScope: deck, jogDeck: deck
            )
            relative[Key(channel: ch, number: 0x21)] = RelativeMapping(
                id: ControlID("\(d).jogSide"), encoding: .centered64, forcedShift: false, deckScope: deck, jogDeck: nil
            )
            relative[Key(channel: ch, number: 0x29)] = RelativeMapping(
                id: ControlID("\(d).jog"), encoding: .centered64, forcedShift: true, deckScope: deck, jogDeck: deck
            )

            // 14-bit absolute (captured): MSB CC listed; LSB = MSB + 0x20.
            msb[Key(channel: ch, number: 0x00)] = (ControlID("\(d).tempo"), deck)
            msb[Key(channel: ch, number: 0x04)] = (ControlID("mixer.ch\(deck + 1).trim"), deck)
            msb[Key(channel: ch, number: 0x07)] = (ControlID("mixer.ch\(deck + 1).eqHi"), deck)
            msb[Key(channel: ch, number: 0x0B)] = (ControlID("mixer.ch\(deck + 1).eqMid"), deck)
            msb[Key(channel: ch, number: 0x0F)] = (ControlID("mixer.ch\(deck + 1).eqLow"), deck)
            msb[Key(channel: ch, number: 0x13)] = (ControlID("mixer.ch\(deck + 1).fader"), deck)
        }

        // Beat FX (captured): ch 4, plus ch 5 rows for the CH SELECT switch
        // and the ON/OFF lever's CH2 position.
        note(4, 0x4A, "fx.beatLeft")
        note(4, 0x4B, "fx.beatRight")
        note(4, 0x63, "fx.select")
        note(4, 0x47, "fx.onOff")
        note(5, 0x47, "fx.onOff")
        note(4, 0x10, "fx.chSelect")
        note(4, 0x11, "fx.chSelect")
        note(5, 0x10, "fx.chSelect")
        note(5, 0x11, "fx.chSelect")
        // SHIFT variants (captured Pass B 2026-08-18)
        note(4, 0x64, "fx.select", shift: true)
        note(4, 0x43, "fx.onOff", shift: true)
        note(5, 0x43, "fx.onOff", shift: true)
        note(4, 0x66, "fx.beatLeft", shift: true)    // captured; not in community map
        note(4, 0x6B, "fx.beatRight", shift: true)   // captured; not in community map
        msb[Key(channel: 4, number: 0x02)] = (ControlID("fx.levelDepth"), nil)

        // Browser + master section (captured): ch 6.
        note(6, 0x41, "browser.encoderPress")
        note(6, 0x46, "browser.load1")
        note(6, 0x47, "browser.load2")
        note(6, 0x00, "mixer.smartCX")
        note(6, 0x01, "mixer.smartFader")
        // SHIFT variants (captured Pass B 2026-08-18; load/smart not in community map)
        note(6, 0x42, "browser.encoderPress", shift: true)
        note(6, 0x68, "browser.load1", shift: true)
        note(6, 0x7A, "browser.load2", shift: true)
        note(6, 0x08, "mixer.smartCX", shift: true)
        note(6, 0x09, "mixer.smartFader", shift: true)
        relative[Key(channel: 6, number: 0x40)] = RelativeMapping(
            id: ControlID("browser.encoder"), encoding: .twosComplement, forcedShift: false, deckScope: nil, jogDeck: nil
        )
        relative[Key(channel: 6, number: 0x64)] = RelativeMapping(  // captured Pass B
            id: ControlID("browser.encoder"), encoding: .twosComplement, forcedShift: true, deckScope: nil, jogDeck: nil
        )
        msb[Key(channel: 6, number: 0x08)] = (ControlID("mixer.masterLevel"), nil)
        msb[Key(channel: 6, number: 0x0C)] = (ControlID("mixer.hpMix"), nil)
        msb[Key(channel: 6, number: 0x0D)] = (ControlID("mixer.hpLevel"), nil)
        msb[Key(channel: 6, number: 0x17)] = (ControlID("mixer.ch1.cfx"), nil)
        msb[Key(channel: 6, number: 0x18)] = (ControlID("mixer.ch2.cfx"), nil)
        msb[Key(channel: 6, number: 0x1F)] = (ControlID("mixer.crossfader"), nil)

        return (notes, relative, msb)
    }

    // MARK: - Inventory (docs/03 §2 order)

    private static func buildInventory() -> [ControlSpec] {
        var list: [ControlSpec] = []

        for deck in [1, 2] {
            let d = "deck\(deck)"
            let s = "Deck \(deck)"
            list += [
                ControlSpec(id: ControlID("\(d).play"), kind: .button, section: s, name: "Play/Pause"),
                ControlSpec(id: ControlID("\(d).cue"), kind: .button, section: s, name: "Cue"),
                ControlSpec(id: ControlID("\(d).sync"), kind: .button, section: s, name: "Beat Sync"),
                ControlSpec(id: ControlID("\(d).shift"), kind: .button, section: s, name: "Shift"),
            ]
            list += (1...8).map {
                ControlSpec(id: ControlID("\(d).pad\($0)"), kind: .pad, section: s, name: "Pad \($0)")
            }
            list += [
                ControlSpec(id: ControlID("\(d).padModeHotCue"), kind: .button, section: s, name: "Pad Mode: Hot Cue"),
                ControlSpec(id: ControlID("\(d).padModePadFX"), kind: .button, section: s, name: "Pad Mode: Pad FX"),
                ControlSpec(id: ControlID("\(d).padModeBeatJump"), kind: .button, section: s, name: "Pad Mode: Beat Jump"),
                ControlSpec(id: ControlID("\(d).padModeSampler"), kind: .button, section: s, name: "Pad Mode: Sampler"),
                ControlSpec(id: ControlID("\(d).loopIn"), kind: .button, section: s, name: "Loop In / 4Beat"),
                ControlSpec(id: ControlID("\(d).loopOut"), kind: .button, section: s, name: "Loop Out"),
                ControlSpec(id: ControlID("\(d).reloopExit"), kind: .button, section: s, name: "Reloop/Exit"),
                ControlSpec(id: ControlID("\(d).cueLoopLeft"), kind: .button, section: s, name: "Cue/Loop Call ◀"),
                ControlSpec(id: ControlID("\(d).cueLoopRight"), kind: .button, section: s, name: "Cue/Loop Call ▶"),
                ControlSpec(id: ControlID("\(d).tempo"), kind: .slider, section: s, name: "Tempo Slider"),
                ControlSpec(id: ControlID("\(d).jogTouch"), kind: .button, section: s, name: "Jog Touch"),
                ControlSpec(id: ControlID("\(d).jog"), kind: .jog, section: s, name: "Jog Turn (platter)"),
                ControlSpec(id: ControlID("\(d).jogSide"), kind: .jog, section: s, name: "Jog Rim Turn"),
            ]
        }

        for ch in [1, 2] {
            let c = "mixer.ch\(ch)"
            let s = "Mixer Ch \(ch)"
            list += [
                ControlSpec(id: ControlID("\(c).trim"), kind: .knob, section: s, name: "Trim"),
                ControlSpec(id: ControlID("\(c).eqHi"), kind: .knob, section: s, name: "EQ Hi"),
                ControlSpec(id: ControlID("\(c).eqMid"), kind: .knob, section: s, name: "EQ Mid"),
                ControlSpec(id: ControlID("\(c).eqLow"), kind: .knob, section: s, name: "EQ Low"),
                ControlSpec(id: ControlID("\(c).cfx"), kind: .knob, section: s, name: "CFX"),
                ControlSpec(id: ControlID("\(c).cue"), kind: .button, section: s, name: "Headphone Cue"),
                ControlSpec(id: ControlID("\(c).fader"), kind: .fader, section: s, name: "Channel Fader"),
            ]
        }
        list += [
            ControlSpec(id: ControlID("mixer.crossfader"), kind: .fader, section: "Mixer", name: "Crossfader"),
            ControlSpec(id: ControlID("mixer.smartFader"), kind: .button, section: "Mixer", name: "Smart Fader"),
            ControlSpec(id: ControlID("mixer.smartCX"), kind: .button, section: "Mixer", name: "Smart CX"),
            ControlSpec(id: ControlID("mixer.masterLevel"), kind: .knob, section: "Mixer", name: "Master Level"),
            ControlSpec(id: ControlID("mixer.hpMix"), kind: .knob, section: "Mixer", name: "Headphones Mixing"),
            ControlSpec(id: ControlID("mixer.hpLevel"), kind: .knob, section: "Mixer", name: "Headphones Level"),
        ]

        list += [
            ControlSpec(id: ControlID("fx.beatLeft"), kind: .button, section: "Effects", name: "Beat ◀"),
            ControlSpec(id: ControlID("fx.beatRight"), kind: .button, section: "Effects", name: "Beat ▶"),
            ControlSpec(id: ControlID("fx.select"), kind: .button, section: "Effects", name: "Beat FX Select"),
            ControlSpec(id: ControlID("fx.chSelect"), kind: .button, section: "Effects", name: "Beat FX Ch Select"),
            ControlSpec(id: ControlID("fx.onOff"), kind: .button, section: "Effects", name: "Beat FX On/Off"),
            ControlSpec(id: ControlID("fx.levelDepth"), kind: .knob, section: "Effects", name: "FX Level/Depth"),
        ]

        list += [
            ControlSpec(id: ControlID("browser.encoder"), kind: .encoder, section: "Browser", name: "Browse Encoder Turn"),
            ControlSpec(id: ControlID("browser.encoderPress"), kind: .button, section: "Browser", name: "Browse Encoder Press"),
            ControlSpec(id: ControlID("browser.load1"), kind: .button, section: "Browser", name: "Load 1"),
            ControlSpec(id: ControlID("browser.load2"), kind: .button, section: "Browser", name: "Load 2"),
        ]

        return list
    }
}
