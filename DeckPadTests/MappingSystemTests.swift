//
//  MappingSystemTests.swift
//  DeckPadTests
//
//  M3: trigger state machine (virtual clock), MappingStore persistence,
//  and profile resolution matrix.
//

import Foundation
import Testing
@testable import DeckPad

// MARK: - Trigger machine (deterministic, virtual clock)

@MainActor
struct TriggerMachineTests {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)

    private func mapping(_ trigger: Trigger, label: String = "m", release: Action? = nil, secondary: Action? = nil) -> Mapping {
        Mapping(control: ControlID("deck1.pad1"), trigger: trigger,
                action: .noOp(label: label), releaseAction: release, secondaryAction: secondary, label: label)
    }

    @Test func plainPressFiresOnDown() {
        let machine = TriggerMachine()
        let slot = TriggerSlot(mappings: [mapping(.press)])
        let fired = machine.handleDown(key: "k", slot: slot, at: t0)
        #expect(fired.map(\.mapping.label) == ["m"])
        #expect(machine.handleUp(key: "k", slot: slot, at: t0.addingTimeInterval(0.1)).isEmpty)
    }

    @Test func releaseAlwaysFiresOnUp() {
        let machine = TriggerMachine()
        let slot = TriggerSlot(mappings: [mapping(.release, label: "rel")])
        #expect(machine.handleDown(key: "k", slot: slot, at: t0).isEmpty)
        #expect(machine.handleUp(key: "k", slot: slot, at: t0.addingTimeInterval(0.05)).map(\.mapping.label) == ["rel"])
    }

    @Test func holdFiresAtThresholdAndClickFiresPress() {
        let machine = TriggerMachine()
        let slot = TriggerSlot(mappings: [
            mapping(.press, label: "click"),
            mapping(.hold(ms: 500), label: "hold", release: .noOp(label: "afterHold")),
        ])
        // Click: down + quick up → press fires on up, hold never fires.
        #expect(machine.handleDown(key: "k", slot: slot, at: t0).isEmpty)
        #expect(machine.handleUp(key: "k", slot: slot, at: t0.addingTimeInterval(0.2)).map(\.mapping.label) == ["click"])

        // Hold: down, tick past 500 ms → hold fires; up → its releaseAction.
        _ = machine.handleDown(key: "k", slot: slot, at: t0.addingTimeInterval(1))
        #expect(machine.nextDeadline != nil)
        let atThreshold = t0.addingTimeInterval(1.5)
        let firedAtTick = machine.tick(at: atThreshold) { _ in slot }
        #expect(firedAtTick.map(\.mapping.label) == ["hold"])
        let firedAtUp = machine.handleUp(key: "k", slot: slot, at: t0.addingTimeInterval(2))
        #expect(firedAtUp.count == 1)
        #expect(firedAtUp[0].mapping.label == "hold")
        #expect(firedAtUp[0].useSecondaryAction)
    }

    @Test func doubleTapDetectsAndDelaysSingle() {
        let machine = TriggerMachine()
        let slot = TriggerSlot(mappings: [
            mapping(.press, label: "single"),
            mapping(.doubleTap, label: "double"),
        ])
        // Double: two downs within 300 ms.
        #expect(machine.handleDown(key: "k", slot: slot, at: t0).isEmpty)
        #expect(machine.handleUp(key: "k", slot: slot, at: t0.addingTimeInterval(0.05)).isEmpty)
        let second = machine.handleDown(key: "k", slot: slot, at: t0.addingTimeInterval(0.2))
        #expect(second.map(\.mapping.label) == ["double"])
        _ = machine.handleUp(key: "k", slot: slot, at: t0.addingTimeInterval(0.25))

        // Single: one tap, window expires via tick → delayed press.
        _ = machine.handleDown(key: "k", slot: slot, at: t0.addingTimeInterval(1))
        #expect(machine.handleUp(key: "k", slot: slot, at: t0.addingTimeInterval(1.05)).isEmpty)
        let expired = machine.tick(at: t0.addingTimeInterval(1.45)) { _ in slot }
        #expect(expired.map(\.mapping.label) == ["single"])
    }

    @Test func toggleAlternatesWithPersistedState() {
        let machine = TriggerMachine()
        var stored: [UUID: Bool] = [:]
        machine.toggleStateProvider = { stored[$0] ?? false }
        machine.toggleStateSink = { stored[$1] = $0 }
        let slot = TriggerSlot(mappings: [mapping(.toggle, label: "tog", secondary: .noOp(label: "alt"))])

        let first = machine.handleDown(key: "k", slot: slot, at: t0)
        #expect(first.count == 1 && !first[0].useSecondaryAction)
        _ = machine.handleUp(key: "k", slot: slot, at: t0.addingTimeInterval(0.05))
        let second = machine.handleDown(key: "k", slot: slot, at: t0.addingTimeInterval(1))
        #expect(second.count == 1 && second[0].useSecondaryAction)
    }
}

// MARK: - MappingStore persistence

@MainActor
struct MappingStoreTests {
    private func makeTempStore() -> (MappingStore, URL) {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DeckPadTests-\(UUID().uuidString)")
        return (MappingStore(directory: dir), dir)
    }

    @Test func globalProfileAutoCreatedAndUndeletable() {
        let (store, dir) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        #expect(store.profiles.contains { $0.isGlobal })
        let globalID = store.globalProfile.id
        store.deleteProfile(globalID)
        #expect(store.profiles.contains { $0.id == globalID })
    }

    @Test func profilesRoundTripThroughDisk() {
        let (store, dir) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let profile = store.addProfile(named: "Xcode", appBundleIDs: ["com.apple.dt.Xcode"])
        store.upsertMapping(
            Mapping(control: ControlID("deck1.pad1"), trigger: .press, action: .noOp(label: "x"), label: "Test"),
            inProfile: profile.id
        )
        store.persistAll()

        let reloaded = MappingStore(directory: dir)
        let loaded = reloaded.profiles.first { $0.name == "Xcode" }
        #expect(loaded != nil)
        #expect(loaded?.appBundleIDs == ["com.apple.dt.Xcode"])
        #expect(loaded?.mappings.first?.label == "Test")
    }

    @Test func brokenFileIsQuarantinedNotDestroyed() throws {
        let (store, dir) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        store.persistAll()
        let bad = dir.appendingPathComponent("profiles/garbage.deckpad.json")
        try Data("not json".utf8).write(to: bad)

        let reloaded = MappingStore(directory: dir)
        #expect(!reloaded.loadIssues.isEmpty)
        #expect(FileManager.default.fileExists(atPath: bad.path + ".broken"))
    }

    @Test func newerSchemaIsRefusedPolitely() throws {
        let (store, dir) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        store.persistAll()
        var future = Profile(name: "FromTheFuture")
        future.appBundleIDs = ["x"]
        future.schemaVersion = 99
        let data = try JSONEncoder().encode(future)
        try data.write(to: dir.appendingPathComponent("profiles/\(future.id.uuidString).deckpad.json"))

        let reloaded = MappingStore(directory: dir)
        #expect(!reloaded.profiles.contains { $0.name == "FromTheFuture" })
        #expect(reloaded.loadIssues.contains { $0.contains("newer") })
        // File preserved for the newer version to read.
        #expect(FileManager.default.fileExists(atPath: dir.appendingPathComponent("profiles/\(future.id.uuidString).deckpad.json").path))
    }

    @Test func importRenamesDuplicatesAndAssignsNewID() throws {
        let (store, dir) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let original = store.addProfile(named: "Mine")
        let exportURL = dir.appendingPathComponent("export.deckpad.json")
        try store.export(original.id, to: exportURL)

        let imported = try store.importProfile(from: exportURL)
        #expect(imported.id != original.id)
        #expect(imported.name == "Mine (imported)")
    }

    @Test func undoRestoresPreviousState() {
        let (store, dir) = makeTempStore()
        defer { try? FileManager.default.removeItem(at: dir) }
        let countBefore = store.profiles.count
        _ = store.addProfile(named: "Oops")
        #expect(store.profiles.count == countBefore + 1)
        store.undo()
        #expect(store.profiles.count == countBefore)
    }
}

// MARK: - Profile resolution matrix (FR-21/22)

struct ProfileResolutionTests {
    private let global = Profile(name: Profile.globalName)
    private let xcode = Profile(name: "Xcode", appBundleIDs: ["com.apple.dt.Xcode"])
    private let safari = Profile(name: "Safari", appBundleIDs: ["com.apple.Safari"])

    private var all: [Profile] { [global, xcode, safari] }

    @Test func pinnedProfileAlwaysWins() {
        let resolved = ProfileSwitcher.resolveActive(profiles: all, pinnedID: safari.id, frontmostBundleID: "com.apple.dt.Xcode")
        #expect(resolved?.id == safari.id)
    }

    @Test func boundAppSelectsItsProfile() {
        let resolved = ProfileSwitcher.resolveActive(profiles: all, pinnedID: nil, frontmostBundleID: "com.apple.dt.Xcode")
        #expect(resolved?.id == xcode.id)
    }

    @Test func unboundAppFallsBackToGlobal() {
        let resolved = ProfileSwitcher.resolveActive(profiles: all, pinnedID: nil, frontmostBundleID: "com.apple.Terminal")
        #expect(resolved?.id == global.id)
    }

    @Test func stalePinFallsThrough() {
        let resolved = ProfileSwitcher.resolveActive(profiles: all, pinnedID: UUID(), frontmostBundleID: "com.apple.Safari")
        #expect(resolved?.id == safari.id)
    }
}
