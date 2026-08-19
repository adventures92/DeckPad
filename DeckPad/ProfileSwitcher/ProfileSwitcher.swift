//
//  ProfileSwitcher.swift
//  DeckPad
//
//  Per-app auto-switching (FR-21), manual pin (FR-22), and DJ-software
//  coexistence pause (FR-7, docs/08 §5). Resolution logic is a pure static
//  function so the matrix is unit-testable.
//

import AppKit
import Combine
import Foundation
import os

@MainActor
final class ProfileSwitcher: ObservableObject {
    static let shared = ProfileSwitcher(store: .shared)

    @Published private(set) var frontmostBundleID: String?
    @Published private(set) var pinnedProfileID: UUID?
    @Published private(set) var isCoexistencePaused = false

    private let store: MappingStore
    private var observers: [NSObjectProtocol] = []
    private static let log = Logger(subsystem: "com.adven.DeckPad", category: "dispatch")

    init(store: MappingStore) {
        self.store = store
    }

    var activeProfile: Profile {
        Self.resolveActive(
            profiles: store.profiles,
            pinnedID: pinnedProfileID,
            frontmostBundleID: frontmostBundleID
        ) ?? store.globalProfile
    }

    var globalProfile: Profile { store.globalProfile }

    /// Pure resolution: pinned wins; else the profile bound to the frontmost
    /// app; else nil (caller falls back to Global).
    nonisolated static func resolveActive(
        profiles: [Profile],
        pinnedID: UUID?,
        frontmostBundleID: String?
    ) -> Profile? {
        if let pinnedID, let pinned = profiles.first(where: { $0.id == pinnedID }) {
            return pinned
        }
        if let bundleID = frontmostBundleID,
           let bound = profiles.first(where: { $0.appBundleIDs.contains(bundleID) }) {
            return bound
        }
        return profiles.first(where: \.isGlobal)
    }

    // MARK: - Pin (FR-22)

    func pin(_ profileID: UUID?) {
        pinnedProfileID = profileID
        objectWillChange.send()
    }

    // MARK: - Watchers

    func start() {
        let center = NSWorkspace.shared.notificationCenter
        frontmostBundleID = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        refreshCoexistence()

        observers.append(center.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            let bundleID = (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?.bundleIdentifier
            Task { @MainActor in
                let switcher = ProfileSwitcher.shared
                // Ignore DeckPad itself so opening our own window doesn't flap profiles.
                guard bundleID != Bundle.main.bundleIdentifier else { return }
                if switcher.frontmostBundleID != bundleID {
                    switcher.frontmostBundleID = bundleID
                    Self.log.info("frontmost: \(bundleID ?? "?") → profile \(switcher.activeProfile.name)")
                }
            }
        })

        for name in [NSWorkspace.didLaunchApplicationNotification, NSWorkspace.didTerminateApplicationNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { _ in
                Task { @MainActor in ProfileSwitcher.shared.refreshCoexistence() }
            })
        }
    }

    // MARK: - Coexistence (FR-7)

    func refreshCoexistence() {
        guard store.settings.coexistence == .pauseAutomatically else {
            if isCoexistencePaused { isCoexistencePaused = false }
            return
        }
        let djApps = Set(store.settings.djAppBundleIDs)
        let djRunning = NSWorkspace.shared.runningApplications.contains {
            guard let id = $0.bundleIdentifier else { return false }
            return djApps.contains(id)
        }
        if djRunning != isCoexistencePaused {
            isCoexistencePaused = djRunning
            Self.log.info("coexistence pause: \(djRunning)")
        }
    }
}
