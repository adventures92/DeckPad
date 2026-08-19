//
//  ServiceController.swift
//  DeckPad
//
//  App lifecycle per docs/08: activation-policy switching (FR-50),
//  single-instance guard, quit confirmation, sleep/wake revalidation, and
//  fast-user-switch injection suspension. Suspend/coexistence gates live on
//  Dispatcher/ProfileSwitcher; login item (SMAppService) lands in M6.
//

import AppKit
import Combine
import os

@MainActor
final class ServiceController: ObservableObject {
    static let shared = ServiceController()

    enum Mode {
        case activeUI
        case accessoryService
    }

    @Published private(set) var mode: Mode = .activeUI

    private var observers: [NSObjectProtocol] = []
    private static let log = Logger(subsystem: "com.adven.DeckPad", category: "service")

    func start() {
        terminateIfAlreadyRunning()

        observers.append(NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: nil, queue: .main
        ) { note in
            guard let closing = note.object as? NSWindow,
                  closing.canBecomeMain, !(closing is NSPanel) else { return }
            Task { @MainActor in
                ServiceController.shared.enterAccessoryIfNoMainWindows(excluding: closing)
            }
        })

        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                MIDIEngine.shared.revalidate()
                Self.log.info("woke from sleep — MIDI revalidated")
            }
        })

        // Fast user switching: never inject events into another user's session (docs/08 §3).
        observers.append(workspace.addObserver(
            forName: NSWorkspace.sessionDidResignActiveNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                Dispatcher.shared.sessionInactive = true
                Self.log.info("session inactive — injection suspended")
            }
        })
        observers.append(workspace.addObserver(
            forName: NSWorkspace.sessionDidBecomeActiveNotification, object: nil, queue: .main
        ) { _ in
            Task { @MainActor in
                Dispatcher.shared.sessionInactive = false
                Self.log.info("session active — injection resumed")
            }
        })
    }

    // MARK: - Activation policy (FR-50)

    func enterActiveUI() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate()
        mode = .activeUI
    }

    func enterAccessoryService() {
        NSApp.setActivationPolicy(.accessory)
        mode = .accessoryService
    }

    private func enterAccessoryIfNoMainWindows(excluding closing: NSWindow) {
        let hasMainWindow = NSApp.windows.contains {
            $0 !== closing && $0.isVisible && $0.canBecomeMain && !($0 is NSPanel)
        }
        if !hasMainWindow {
            enterAccessoryService()
        }
    }

    // MARK: - Single instance (docs/08 §6)

    private func terminateIfAlreadyRunning() {
        let others = NSRunningApplication.runningApplications(
            withBundleIdentifier: Bundle.main.bundleIdentifier ?? ""
        ).filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
        guard let other = others.first else { return }
        Self.log.info("another DeckPad instance is running — activating it and exiting")
        other.activate()
        NSApp.terminate(nil)
    }

    // MARK: - Quit confirmation (docs/08 §1)

    func confirmQuitIfNeeded() -> NSApplication.TerminateReply {
        guard !MappingStore.shared.settings.suppressQuitConfirmation,
              MIDIEngine.shared.isConnected else {
            return .terminateNow
        }
        let alert = NSAlert()
        alert.messageText = "Quit DeckPad?"
        alert.informativeText = "DeckPad stops responding to your controller when quit."
        alert.addButton(withTitle: "Quit")
        alert.addButton(withTitle: "Cancel")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don't ask again"
        let response = alert.runModal()
        if alert.suppressionButton?.state == .on {
            MappingStore.shared.settings.suppressQuitConfirmation = true
        }
        return response == .alertFirstButtonReturn ? .terminateNow : .terminateCancel
    }
}
