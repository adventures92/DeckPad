//
//  MenuBarView.swift
//  DeckPad
//
//  Menu-bar menu. Live device status via MIDIEngine (M1); profile submenu
//  and suspend toggle land in M3, final icon states in M4
//  (docs/05-ui-spec.md §8).
//

import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var engine = MIDIEngine.shared

    var body: some View {
        Text(engine.isConnected
            ? "DDJ-FLX4: connected"
            : "DDJ-FLX4: not connected")

        Divider()

        Button("Open DeckPad") {
            ServiceController.shared.enterActiveUI()
            openWindow(id: WindowID.main)
        }

        Button("MIDI Monitor") {
            ServiceController.shared.enterActiveUI()
            openWindow(id: WindowID.monitor)
        }

        Divider()

        // Quit confirmation dialog lands in M3 (FR-50 spec, docs/08 §1).
        Button("Quit DeckPad") {
            NSApp.terminate(nil)
        }
    }
}
