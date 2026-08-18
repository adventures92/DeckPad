//
//  EventPosting.swift
//  DeckPad
//
//  The seam between ActionEngine and the OS input system. The real
//  implementation posts CGEvents / NX system-defined events; tests inject
//  a recording mock. All posting requires Accessibility trust (checked by
//  ActionEngine, not here).
//

import AppKit
import Foundation

@MainActor
protocol EventPosting {
    func postKeystroke(keyCode: UInt16, modifiers: UInt64)
    func postText(_ chunk: String)
    func postSystemKey(_ nxKeyType: Int32)
    func postScroll(dx: Int32, dy: Int32)
}

@MainActor
final class SystemEventPoster: EventPosting {
    func postKeystroke(keyCode: UInt16, modifiers: UInt64) {
        let source = CGEventSource(stateID: .hidSystemState)
        let flags = CGEventFlags(rawValue: modifiers)
        for keyDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown) else { continue }
            event.flags = flags
            event.post(tap: .cghidEventTap)
        }
    }

    func postText(_ chunk: String) {
        let source = CGEventSource(stateID: .hidSystemState)
        let utf16 = Array(chunk.utf16)
        for keyDown in [true, false] {
            guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: keyDown) else { continue }
            event.keyboardSetUnicodeString(stringLength: utf16.count, unicodeString: utf16)
            event.post(tap: .cghidEventTap)
        }
    }

    func postSystemKey(_ nxKeyType: Int32) {
        // The F-row technique: NX system-defined events, subtype 8,
        // data1 = (key << 16) | (0x0A on down / 0x0B on up) << 8.
        for down in [true, false] {
            let data1 = (Int(nxKeyType) << 16) | ((down ? 0x0A : 0x0B) << 8)
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00),
                timestamp: ProcessInfo.processInfo.systemUptime,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
    }

    func postScroll(dx: Int32, dy: Int32) {
        guard let event = CGEvent(
            scrollWheelEvent2Source: CGEventSource(stateID: .hidSystemState),
            units: .pixel,
            wheelCount: 2,
            wheel1: dy,
            wheel2: dx,
            wheel3: 0
        ) else { return }
        event.post(tap: .cghidEventTap)
    }
}
