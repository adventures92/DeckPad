//
//  MenuBarView.swift
//  DeckPad
//
//  Menu-bar menu (docs/05 §8): device + permission status, profile
//  selection with pin semantics (FR-22), suspend toggle (FR-32).
//  Final icon states land in M4.
//

import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var engine = MIDIEngine.shared
    @ObservedObject private var permissions = PermissionsManager.shared
    @ObservedObject private var store = MappingStore.shared
    @ObservedObject private var switcher = ProfileSwitcher.shared
    @ObservedObject private var dispatcher = Dispatcher.shared

    var body: some View {
        Text(statusLine)

        if !permissions.accessibilityGranted {
            Button("⚠️ Grant Accessibility permission…") {
                PermissionsManager.shared.promptForAccessibility()
                PermissionsManager.shared.openAccessibilitySettings()
            }
        }

        Divider()

        // Profile selection: picking a profile pins it; Auto resumes
        // frontmost-app switching (FR-21/22).
        Section("Profile") {
            Button {
                switcher.pin(nil)
                Dispatcher.shared.resetPickup()
            } label: {
                menuLabel("Auto (follow frontmost app)", checked: switcher.pinnedProfileID == nil)
            }
            ForEach(store.profiles) { profile in
                Button {
                    switcher.pin(profile.id)
                    Dispatcher.shared.resetPickup()
                } label: {
                    menuLabel(profile.name, checked: switcher.pinnedProfileID == profile.id)
                }
            }
        }

        Divider()

        Toggle("Suspend DeckPad", isOn: $dispatcher.isSuspended)

        Button("Open DeckPad") {
            ServiceController.shared.enterActiveUI()
            openWindow(id: WindowID.main)
        }

        Button("MIDI Monitor") {
            ServiceController.shared.enterActiveUI()
            openWindow(id: WindowID.monitor)
        }

        Divider()

        Button("Quit DeckPad") {
            NSApp.terminate(nil)
        }
    }

    private var statusLine: String {
        if switcher.isCoexistencePaused {
            return "Paused — DJ software is running"
        }
        if dispatcher.isSuspended {
            return "Suspended"
        }
        let device = engine.isConnected ? "DDJ-FLX4 ✓" : "DDJ-FLX4: not connected"
        return "\(device) · \(switcher.activeProfile.name)"
    }

    private func menuLabel(_ title: String, checked: Bool) -> some View {
        HStack {
            if checked { Image(systemName: "checkmark") }
            Text(title)
        }
    }
}
