//
//  ServiceController.swift
//  DeckPad
//
//  M0 skeleton of the lifecycle controller (FR-50): closing the main window
//  drops the app to a menu-bar accessory; reopening restores the regular
//  activation policy. The full state machine (Suspended, CoexistencePause,
//  quit confirmation, single-instance guard) lands in M3 per
//  docs/08-background-service.md §1.
//

import AppKit
import Combine

@MainActor
final class ServiceController: ObservableObject {
    static let shared = ServiceController()

    enum Mode {
        case activeUI
        case accessoryService
    }

    @Published private(set) var mode: Mode = .activeUI

    private var windowCloseObserver: NSObjectProtocol?

    func start() {
        windowCloseObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { note in
            guard let closing = note.object as? NSWindow,
                  closing.canBecomeMain, !(closing is NSPanel) else { return }
            Task { @MainActor in
                ServiceController.shared.enterAccessoryIfNoMainWindows(excluding: closing)
            }
        }
    }

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
}
