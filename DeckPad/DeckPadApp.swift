//
//  DeckPadApp.swift
//  DeckPad
//

import SwiftUI

@main
struct DeckPadApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Window("DeckPad", id: WindowID.main) {
            MainWindowView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1080, height: 640)

        Window("MIDI Monitor", id: WindowID.monitor) {
            MonitorView()
        }
        .defaultSize(width: 940, height: 560)

        MenuBarExtra("DeckPad", systemImage: "dial.medium") {
            MenuBarView()
        }
    }
}

enum WindowID {
    static let main = "main"
    static let monitor = "monitor"
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        ServiceController.shared.start()
        MIDIEngine.shared.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        ServiceController.shared.enterActiveUI()
        return true
    }
}
