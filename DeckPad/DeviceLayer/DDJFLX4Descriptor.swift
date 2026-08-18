//
//  DDJFLX4Descriptor.swift
//  DeckPad
//
//  Pioneer DJ DDJ-FLX4 descriptor. Control inventory mirrors
//  docs/03-device-ddj-flx4.md §2 — same ControlIDs, same order (the capture
//  checklist walks this list). The decode table is data-driven and gets
//  generated from the M1 capture session; until then decode() returns nil
//  and the monitor shows raw messages only.
//
//  Endpoint identity confirmed against the physical unit (M1):
//  name "DDJ-FLX4", manufacturer "AlphaTheta Corporation", model "DDJ-FLX4".
//

import Foundation

nonisolated struct DDJFLX4Descriptor: DeviceDescriptor {
    static let endpointNameMarker = "DDJ-FLX4"

    let controls: [ControlSpec] = Self.buildInventory()

    func decode(_ message: RawMIDIMessage) -> ControlEvent? {
        // Populated from docs/fixtures/flx4-capture.json after the capture
        // session (ADR-004). Unknown messages are dropped upstream (NFR-3).
        nil
    }

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
                ControlSpec(id: ControlID("\(d).tempo"), kind: .slider, section: s, name: "Tempo Slider"),
                ControlSpec(id: ControlID("\(d).jogTouch"), kind: .button, section: s, name: "Jog Touch"),
                ControlSpec(id: ControlID("\(d).jog"), kind: .jog, section: s, name: "Jog Turn (touched)"),
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
            ControlSpec(id: ControlID("mixer.masterLevel"), kind: .knob, section: "Mixer", name: "Master Level (may be analog)"),
            ControlSpec(id: ControlID("mixer.hpMix"), kind: .knob, section: "Mixer", name: "Headphones Mixing (may be analog)"),
            ControlSpec(id: ControlID("mixer.hpLevel"), kind: .knob, section: "Mixer", name: "Headphones Level (may be analog)"),
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
