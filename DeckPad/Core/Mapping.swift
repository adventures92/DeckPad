//
//  Mapping.swift
//  DeckPad
//
//  Persistence models per docs/02-architecture.md §2 (NFR-7: versioned,
//  human-readable JSON). Payload changes require a schemaVersion bump and
//  a loader migration.
//

import Foundation

nonisolated enum SchemaVersion {
    static let current = 1
}

nonisolated enum FeedbackChannelSetting: String, Codable, Sendable {
    case inherit, on, off
}

/// Per-mapping feedback override (FR-40); consumed by FeedbackCenter in M5.
nonisolated struct FeedbackOverride: Codable, Equatable, Sendable {
    var toast: FeedbackChannelSetting = .inherit
    var pill: FeedbackChannelSetting = .inherit
    var sound: FeedbackChannelSetting = .inherit
    var led: FeedbackChannelSetting = .inherit

    static let inherit = FeedbackOverride()
}

nonisolated struct Mapping: Codable, Equatable, Sendable, Identifiable {
    var id: UUID = UUID()
    var control: ControlID
    /// false = base layer, true = SHIFT held (FR-14).
    var shiftLayer: Bool = false
    var trigger: Trigger
    var action: Action
    /// Fired on release after a `.hold` trigger has fired (docs/06 §9).
    var releaseAction: Action?
    /// The alternate action for `.toggle` triggers (docs/06 §9).
    var secondaryAction: Action?
    /// Continuous mappings: bypass soft-takeover pickup (docs/06 §7).
    var jumpImmediately: Bool = false
    var feedback: FeedbackOverride = .inherit
    var label: String
}

nonisolated struct Profile: Codable, Equatable, Sendable, Identifiable {
    var id: UUID = UUID()
    var name: String
    /// Bundle IDs this profile auto-activates for; empty = the Global profile (FR-20/21).
    var appBundleIDs: [String] = []
    var mappings: [Mapping] = []
    var schemaVersion: Int = SchemaVersion.current

    var isGlobal: Bool { appBundleIDs.isEmpty && name == Profile.globalName }
    static let globalName = "Global"
}

nonisolated enum CoexistenceBehavior: String, Codable, Sendable {
    case pauseAutomatically, keepRunning
}

/// App-level settings (settings.json). Decoding is tolerant: missing keys
/// fall back to defaults so adding fields never breaks older files.
nonisolated struct AppSettings: Codable, Equatable, Sendable {
    var schemaVersion: Int = SchemaVersion.current
    var coexistence: CoexistenceBehavior = .pauseAutomatically
    var djAppBundleIDs: [String] = AppSettings.defaultDJApps
    var onboardingCompleted: Bool = false
    var suppressQuitConfirmation: Bool = false
    /// Toggle-trigger states, persisted per mapping (docs/06 §9).
    var toggleStates: [UUID: Bool] = [:]

    static let defaultDJApps = [
        "com.pioneerdj.rekordboxdj",
        "com.algoriddim.djay-pro-mac",
        "com.serato.dj.lite",
        "com.serato.dj.pro",
    ]

    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? SchemaVersion.current
        coexistence = try c.decodeIfPresent(CoexistenceBehavior.self, forKey: .coexistence) ?? .pauseAutomatically
        djAppBundleIDs = try c.decodeIfPresent([String].self, forKey: .djAppBundleIDs) ?? Self.defaultDJApps
        onboardingCompleted = try c.decodeIfPresent(Bool.self, forKey: .onboardingCompleted) ?? false
        suppressQuitConfirmation = try c.decodeIfPresent(Bool.self, forKey: .suppressQuitConfirmation) ?? false
        toggleStates = try c.decodeIfPresent([UUID: Bool].self, forKey: .toggleStates) ?? [:]
    }
}
