//
//  MenuBarView.swift
//  DeckPad
//
//  Menu-bar menu. Live device status (M1) + permission warning and the
//  temporary M2 test bench toggle. Profile submenu and suspend toggle land
//  in M3, final icon states in M4 (docs/05-ui-spec.md §8).
//

import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var engine = MIDIEngine.shared
    @ObservedObject private var permissions = PermissionsManager.shared
    @ObservedObject private var bench = DemoBench.shared

    var body: some View {
        Text(engine.isConnected
            ? "DDJ-FLX4: connected"
            : "DDJ-FLX4: not connected")

        if !permissions.accessibilityGranted {
            Button("⚠️ Grant Accessibility permission…") {
                PermissionsManager.shared.promptForAccessibility()
                PermissionsManager.shared.openAccessibilitySettings()
            }
        }

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

        // Temporary until the real mapping system lands (M3).
        Toggle("Test Bench (M2 demo)", isOn: $bench.isEnabled)

        Divider()

        // Quit confirmation dialog lands in M3 (FR-50 spec, docs/08 §1).
        Button("Quit DeckPad") {
            NSApp.terminate(nil)
        }
    }
}
