//
//  PermissionsManager.swift
//  DeckPad
//
//  Central truth for TCC permission state (docs/08 §4). Accessibility gates
//  all event injection; Automation is prompted lazily by macOS itself on
//  first AppleEvent per target.
//

import AppKit
import ApplicationServices
import Combine
import Foundation

@MainActor
final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published private(set) var accessibilityGranted: Bool
    /// Set when an action needed Accessibility and it was missing/revoked —
    /// drives the menu-bar warning badge and the one-time toast (docs/08 §4).
    @Published private(set) var accessibilityFailureObserved = false

    private var pollTimer: Timer?
    private var pollHolders = 0

    private init() {
        accessibilityGranted = AXIsProcessTrusted()
    }

    func refresh() {
        let granted = AXIsProcessTrusted()
        if granted != accessibilityGranted {
            accessibilityGranted = granted
        }
        if granted {
            accessibilityFailureObserved = false
        }
    }

    /// Triggers the one-time system prompt (macOS shows it only once per install).
    func promptForAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func noteAccessibilityFailure() {
        refresh()
        if !accessibilityGranted {
            accessibilityFailureObserved = true
        }
    }

    /// 1 Hz polling, active only while some UI showing permission state is
    /// visible (docs/08 §4 — never poll in the background).
    func beginPollingWhileVisible() {
        pollHolders += 1
        guard pollTimer == nil else { return }
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in PermissionsManager.shared.refresh() }
        }
    }

    func endPollingWhileVisible() {
        pollHolders = max(0, pollHolders - 1)
        if pollHolders == 0 {
            pollTimer?.invalidate()
            pollTimer = nil
        }
    }
}
