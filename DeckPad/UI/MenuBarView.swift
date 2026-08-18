//
//  MenuBarView.swift
//  DeckPad
//
//  M0 placeholder menu. Live device status arrives in M1, profile submenu and
//  suspend toggle in M3, final icon states in M4 (docs/05-ui-spec.md §8).
//

import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Text("DDJ-FLX4: not connected")

        Divider()

        Button("Open DeckPad") {
            ServiceController.shared.enterActiveUI()
            openWindow(id: WindowID.main)
        }

        Divider()

        // Quit confirmation dialog lands in M3 (FR-50 spec, docs/08 §1).
        Button("Quit DeckPad") {
            NSApp.terminate(nil)
        }
    }
}
