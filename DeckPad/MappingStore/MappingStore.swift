//
//  MappingStore.swift
//  DeckPad
//
//  Source of truth for profiles and settings (FR-20, FR-23, NFR-7).
//  One `<uuid>.deckpad.json` per profile + `settings.json`, atomic writes,
//  500 ms save debounce, broken-file quarantine (docs/02 §5–6, ADR-005).
//

import Combine
import Foundation
import os

@MainActor
final class MappingStore: ObservableObject {
    static let shared = MappingStore()

    @Published private(set) var profiles: [Profile] = []
    @Published var settings = AppSettings() {
        didSet { scheduleSave() }
    }
    /// Non-fatal load problems, surfaced non-modally (docs/02 §6).
    @Published private(set) var loadIssues: [String] = []

    private static let log = Logger(subsystem: "com.adven.DeckPad", category: "store")

    private let directory: URL
    private var profilesDirectory: URL { directory.appendingPathComponent("profiles") }
    private var settingsURL: URL { directory.appendingPathComponent("settings.json") }

    private var saveTask: Task<Void, Never>?
    private var undoStack: [[Profile]] = []

    // MARK: - Init & load

    init(directory: URL? = nil) {
        self.directory = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("DeckPad")
        load()
    }

    func load() {
        loadIssues = []
        let fm = FileManager.default
        try? fm.createDirectory(at: profilesDirectory, withIntermediateDirectories: true)

        // Settings
        if let data = try? Data(contentsOf: settingsURL) {
            if let decoded = try? JSONDecoder().decode(AppSettings.self, from: data),
               decoded.schemaVersion <= SchemaVersion.current {
                settings = decoded
            } else {
                loadIssues.append("settings.json is from a newer DeckPad version — using defaults, file preserved")
            }
        }

        // Profiles
        var loaded: [Profile] = []
        let files = (try? fm.contentsOfDirectory(at: profilesDirectory, includingPropertiesForKeys: nil)) ?? []
        for file in files where file.lastPathComponent.hasSuffix(".deckpad.json") {
            do {
                let profile = try JSONDecoder().decode(Profile.self, from: Data(contentsOf: file))
                guard profile.schemaVersion <= SchemaVersion.current else {
                    loadIssues.append("\(file.lastPathComponent) needs a newer DeckPad (schema \(profile.schemaVersion)) — skipped, file preserved")
                    continue
                }
                loaded.append(profile)
            } catch {
                // Quarantine, never destroy (docs/02 §6).
                let quarantined = file.appendingPathExtension("broken")
                try? fm.moveItem(at: file, to: quarantined)
                loadIssues.append("\(file.lastPathComponent) was unreadable — quarantined as .broken")
                Self.log.error("quarantined \(file.lastPathComponent): \(error.localizedDescription)")
            }
        }

        // The Global profile always exists (FR-20).
        if !loaded.contains(where: \.isGlobal) {
            loaded.insert(Self.starterGlobalProfile(), at: 0)
        }
        profiles = loaded.sorted { lhs, rhs in
            if lhs.isGlobal != rhs.isGlobal { return lhs.isGlobal }
            return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
        }
        persistAll()
    }

    var globalProfile: Profile {
        profiles.first(where: \.isGlobal) ?? profiles[0]
    }

    // MARK: - Mutations (all snapshot for undo, then debounce-save)

    func addProfile(named name: String, appBundleIDs: [String] = []) -> Profile {
        snapshotForUndo()
        let profile = Profile(name: name, appBundleIDs: appBundleIDs)
        profiles.append(profile)
        scheduleSave()
        return profile
    }

    func duplicateProfile(_ id: UUID) {
        guard let source = profiles.first(where: { $0.id == id }) else { return }
        snapshotForUndo()
        var copy = source
        copy.id = UUID()
        copy.name = source.isGlobal ? "Copy of Global" : "\(source.name) copy"
        copy.appBundleIDs = source.isGlobal ? [] : source.appBundleIDs
        copy.mappings = source.mappings.map { mapping in
            var m = mapping
            m.id = UUID()
            return m
        }
        profiles.append(copy)
        scheduleSave()
    }

    /// The Global profile is undeletable (FR-20).
    func deleteProfile(_ id: UUID) {
        guard let profile = profiles.first(where: { $0.id == id }), !profile.isGlobal else { return }
        snapshotForUndo()
        profiles.removeAll { $0.id == id }
        try? FileManager.default.removeItem(at: fileURL(for: id))
        scheduleSave()
    }

    func update(_ profile: Profile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        snapshotForUndo()
        profiles[index] = profile
        scheduleSave()
    }

    func upsertMapping(_ mapping: Mapping, inProfile profileID: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else { return }
        snapshotForUndo()
        if let mIndex = profiles[index].mappings.firstIndex(where: { $0.id == mapping.id }) {
            profiles[index].mappings[mIndex] = mapping
        } else {
            profiles[index].mappings.append(mapping)
        }
        scheduleSave()
    }

    func removeMapping(_ mappingID: UUID, fromProfile profileID: UUID) {
        guard let index = profiles.firstIndex(where: { $0.id == profileID }) else { return }
        snapshotForUndo()
        profiles[index].mappings.removeAll { $0.id == mappingID }
        scheduleSave()
    }

    // MARK: - Toggle-trigger state (docs/06 §9, persisted)

    func toggleState(for mappingID: UUID) -> Bool {
        settings.toggleStates[mappingID] ?? false
    }

    func setToggleState(_ value: Bool, for mappingID: UUID) {
        settings.toggleStates[mappingID] = value
    }

    // MARK: - Undo (session-scoped; ⌘Z UI lands in M4)

    private func snapshotForUndo() {
        undoStack.append(profiles)
        if undoStack.count > 50 { undoStack.removeFirst() }
    }

    func undo() {
        guard let last = undoStack.popLast() else { return }
        profiles = last
        scheduleSave()
    }

    // MARK: - Import / export (FR-23)

    func export(_ profileID: UUID, to url: URL) throws {
        guard let profile = profiles.first(where: { $0.id == profileID }) else { return }
        try encode(profile).write(to: url, options: .atomic)
    }

    @discardableResult
    func importProfile(from url: URL) throws -> Profile {
        var profile = try JSONDecoder().decode(Profile.self, from: Data(contentsOf: url))
        guard profile.schemaVersion <= SchemaVersion.current else {
            throw NSError(domain: "DeckPad", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "This profile needs a newer version of DeckPad.",
            ])
        }
        snapshotForUndo()
        profile.id = UUID()   // imports never collide
        if profiles.contains(where: { $0.name == profile.name }) {
            profile.name += " (imported)"
        }
        profiles.append(profile)
        scheduleSave()
        return profile
    }

    // MARK: - Persistence

    private func fileURL(for profileID: UUID) -> URL {
        profilesDirectory.appendingPathComponent("\(profileID.uuidString).deckpad.json")
    }

    private func encode(_ value: some Encodable) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            self?.persistAll()
        }
    }

    /// Atomic writes; also called directly on quit (flush).
    func persistAll() {
        do {
            try FileManager.default.createDirectory(at: profilesDirectory, withIntermediateDirectories: true)
            for profile in profiles {
                try encode(profile).write(to: fileURL(for: profile.id), options: .atomic)
            }
            try encode(settings).write(to: settingsURL, options: .atomic)
        } catch {
            Self.log.error("save failed: \(error.localizedDescription)")
        }
    }

    // MARK: - First-run seed

    /// Starter mappings (mirrors the retired M2 demo bench) so a fresh
    /// install does something useful before the M4 editor exists.
    private static func starterGlobalProfile() -> Profile {
        Profile(
            name: Profile.globalName,
            appBundleIDs: [],
            mappings: [
                Mapping(control: ControlID("deck1.pad1"), trigger: .press,
                        action: .textSnippet("Hello from DeckPad! "), label: "Type hello"),
                Mapping(control: ControlID("deck1.pad2"), trigger: .press,
                        action: .mediaKey(.playPause, steps: 1), label: "Play/Pause"),
                Mapping(control: ControlID("deck1.pad4"), trigger: .press,
                        action: .launchApp(bundleID: "com.apple.TextEdit"), label: "TextEdit"),
                Mapping(control: ControlID("mixer.ch1.fader"), trigger: .continuous,
                        action: .systemVolume(ContinuousShape()), label: "Volume"),
                Mapping(control: ControlID("deck1.jog"), trigger: .relative,
                        action: .scroll(axis: .vertical, speedMultiplier: 1.5, natural: false), label: "Scroll"),
                Mapping(control: ControlID("deck1.jogSide"), trigger: .relative,
                        action: .scroll(axis: .vertical, speedMultiplier: 1.5, natural: false), label: "Scroll"),
                Mapping(control: ControlID("browser.encoder"), trigger: .relative,
                        action: .volumeDial(stepSize: 0.02), label: "Volume dial"),
            ]
        )
    }
}
