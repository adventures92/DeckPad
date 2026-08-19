//
//  Dispatcher.swift
//  DeckPad
//
//  The hub (docs/02 §1): ControlEvent → active profile → resolved mapping →
//  ActionEngine, with trigger detection, continuous coalescing (8 ms),
//  soft-takeover pickup, and the suspend/coexistence gates.
//
//  v1 runs on the main actor (see ADR-008): event rates are far below any
//  contention threshold; a dedicated queue remains a profiled optimization.
//

import Combine
import Foundation
import os

@MainActor
final class Dispatcher: ObservableObject {
    static let shared = Dispatcher(
        store: .shared, switcher: .shared, engine: .shared, actions: .shared
    )

    @Published var isSuspended = false          // FR-32
    /// Set during fast-user-switch deactivation (docs/08 §3).
    var sessionInactive = false

    private let store: MappingStore
    private let switcher: ProfileSwitcher
    private let engine: MIDIEngine
    private let actions: ActionEngine
    private let decoder = DDJFLX4Descriptor()
    private let triggers = TriggerMachine()
    private let listenerID = UUID()

    private static let log = Logger(subsystem: "com.adven.DeckPad", category: "dispatch")

    // Continuous coalescing (docs/02 §4): latest value per mapping per 8 ms tick.
    private var pendingContinuous: [UUID: (mapping: Mapping, value: Double)] = [:]
    private var drainScheduled = false

    // Soft-takeover pickup state per mapping (docs/06 §7).
    private struct PickupState {
        var engaged = false
        var lastPhysical: Double?
    }
    private var pickup: [UUID: PickupState] = [:]
    private var lastSetValues: [UUID: Double] = [:]

    private var timerTask: Task<Void, Never>?

    init(store: MappingStore, switcher: ProfileSwitcher, engine: MIDIEngine, actions: ActionEngine) {
        self.store = store
        self.switcher = switcher
        self.engine = engine
        self.actions = actions
        triggers.toggleStateProvider = { [weak store] id in store?.toggleState(for: id) ?? false }
        triggers.toggleStateSink = { [weak store] value, id in store?.setToggleState(value, for: id) }
    }

    func start() {
        engine.addListener(listenerID) { [weak self] packet in
            self?.handle(packet)
        }
    }

    /// Profile switches reset pickup so faders re-engage cleanly (docs/06 §7).
    func resetPickup() {
        pickup.removeAll()
    }

    // MARK: - Event path

    private var gateClosed: Bool {
        isSuspended || sessionInactive || switcher.isCoexistencePaused
    }

    private func handle(_ packet: RawMIDIPacket) {
        guard !gateClosed else {
            // While suspended (not session-inactive/coexistence), a mapped
            // suspend action still works so the hardware can resume itself.
            if isSuspended && !sessionInactive && !switcher.isCoexistencePaused {
                for event in decoder.decode(packet.message) {
                    if case let .pressed(control, shifted) = event,
                       let mapping = resolve(control: control, shifted: shifted, where: { $0.trigger == .press }),
                       mapping.action == .suspendDeckPad {
                        _ = actions.execute(.suspendDeckPad)
                    }
                }
            }
            return
        }
        for event in decoder.decode(packet.message) {
            dispatch(event, at: packet.receivedAt)
        }
        scheduleTimerIfNeeded()
    }

    private func dispatch(_ event: ControlEvent, at time: Date) {
        switch event {
        case let .pressed(control, shifted):
            let slot = triggerSlot(for: control, shifted: shifted)
            guard !slot.isEmpty else { return }
            fire(triggers.handleDown(key: slotKey(control, shifted), slot: slot, at: time))

        case let .released(control, shifted):
            let slot = triggerSlot(for: control, shifted: shifted)
            guard !slot.isEmpty else { return }
            fire(triggers.handleUp(key: slotKey(control, shifted), slot: slot, at: time))

        case let .value(control, value, shifted):
            guard let mapping = resolve(control: control, shifted: shifted, where: { $0.trigger == .continuous }) else { return }
            pendingContinuous[mapping.id] = (mapping, value)
            scheduleDrain()

        case let .relative(control, ticks, _, shifted):
            guard let mapping = resolve(control: control, shifted: shifted, where: { $0.trigger == .relative }) else { return }
            actions.executeRelative(mapping.action, ticks: ticks, token: mapping.id.uuidString)
        }
    }

    private func fire(_ list: [FiredMapping]) {
        for item in list {
            let action: Action?
            if item.useSecondaryAction {
                // For holds this is the releaseAction; for toggles the alternate.
                action = item.mapping.releaseAction ?? item.mapping.secondaryAction
            } else {
                action = item.mapping.action
            }
            guard let action else { continue }
            let start = ContinuousClock.now
            let result = actions.execute(action)
            recordLatency(since: start)
            if !result.isSuccess {
                Self.log.error("mapping '\(item.mapping.label)' failed: \(String(describing: result))")
            }
        }
    }

    // M2/NFR-1 measurement: dispatch→post duration per discrete action,
    // appended to /tmp/deckpad-latency.csv (readable without admin rights).
    private func recordLatency(since start: ContinuousClock.Instant) {
        let elapsed = start.duration(to: .now)
        let micros = Double(elapsed.components.attoseconds) / 1e12 + Double(elapsed.components.seconds) * 1e6
        Self.log.info("action dispatch \(micros, format: .fixed(precision: 1)) µs")
        let line = String(format: "%.1f\n", micros)
        if let data = line.data(using: .utf8) {
            let path = "/tmp/deckpad-latency.csv"
            if let handle = FileHandle(forWritingAtPath: path) {
                handle.seekToEndOfFile()
                handle.write(data)
                try? handle.close()
            } else {
                FileManager.default.createFile(atPath: path, contents: data)
            }
        }
    }

    // MARK: - Resolution (active profile with Global fallthrough, FR-21)

    private func mappings(for control: ControlID, shifted: Bool) -> [Mapping] {
        let active = switcher.activeProfile
        let inActive = active.mappings.filter { $0.control == control && $0.shiftLayer == shifted }
        if !inActive.isEmpty { return inActive }
        guard active.id != switcher.globalProfile.id else { return [] }
        return switcher.globalProfile.mappings.filter { $0.control == control && $0.shiftLayer == shifted }
    }

    private func resolve(control: ControlID, shifted: Bool, where predicate: (Mapping) -> Bool) -> Mapping? {
        mappings(for: control, shifted: shifted).first(where: predicate)
    }

    private func triggerSlot(for control: ControlID, shifted: Bool) -> TriggerSlot {
        TriggerSlot(mappings: mappings(for: control, shifted: shifted))
    }

    private func slotKey(_ control: ControlID, _ shifted: Bool) -> String {
        "\(control.rawValue)#\(shifted ? "S" : "B")"
    }

    // MARK: - Continuous coalescing + pickup

    private func scheduleDrain() {
        guard !drainScheduled else { return }
        drainScheduled = true
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(8))
            self?.drainContinuous()
        }
    }

    private func drainContinuous() {
        drainScheduled = false
        let pending = pendingContinuous
        pendingContinuous.removeAll()
        for (id, entry) in pending {
            guard engageOrTrack(id: id, mapping: entry.mapping, physical: entry.value) else { continue }
            actions.executeContinuous(entry.mapping.action, value: entry.value)
            lastSetValues[id] = entry.value
        }
    }

    /// Soft-takeover: stay inert until the physical position crosses the
    /// current target value, then engage (docs/06 §7).
    private func engageOrTrack(id: UUID, mapping: Mapping, physical: Double) -> Bool {
        if mapping.jumpImmediately { return true }
        var state = pickup[id] ?? PickupState()
        defer { state.lastPhysical = physical; pickup[id] = state }

        if state.engaged { return true }

        guard let target = currentTarget(for: mapping) else {
            state.engaged = true   // unknowable target: engage immediately
            return true
        }
        let crossed: Bool
        if let last = state.lastPhysical {
            crossed = (last <= target && physical >= target) || (last >= target && physical <= target)
        } else {
            crossed = abs(physical - target) < 0.03
        }
        if crossed || abs(physical - target) < 0.03 {
            state.engaged = true
            return true
        }
        return false
    }

    private func currentTarget(for mapping: Mapping) -> Double? {
        if case .systemVolume = mapping.action {
            return actions.currentSystemVolume()
        }
        return lastSetValues[mapping.id]
    }

    // MARK: - Trigger timers (hold / double-tap windows)

    private func scheduleTimerIfNeeded() {
        guard let deadline = triggers.nextDeadline else { return }
        timerTask?.cancel()
        let delay = max(0.001, deadline.timeIntervalSinceNow)
        timerTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(delay * 1000) + 1))
            guard !Task.isCancelled, let self else { return }
            self.fire(self.triggers.tick(at: Date()) { [weak self] key in
                guard let self else { return nil }
                let parts = key.split(separator: "#")
                guard parts.count == 2 else { return nil }
                return self.triggerSlot(for: ControlID(String(parts[0])), shifted: parts[1] == "S")
            })
            self.scheduleTimerIfNeeded()
        }
    }
}
