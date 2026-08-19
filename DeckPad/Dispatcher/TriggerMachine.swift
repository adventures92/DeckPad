//
//  TriggerMachine.swift
//  DeckPad
//
//  Deterministic trigger detection (FR-13, docs/06 §9). Pure state machine
//  driven by explicit timestamps so tests use a virtual clock: `handleDown`/
//  `handleUp` on control events, `tick(at:)` from the Dispatcher's timers.
//
//  Semantics per (control, layer):
//  - press: fires on down — unless a doubleTap sibling exists (then fires on
//    the 300 ms timeout) or a hold sibling exists (then fires on release
//    before the hold threshold, i.e. a "click").
//  - doubleTap: two downs within 300 ms.
//  - hold: fires after N ms held; its releaseAction fires on the eventual up.
//  - toggle: like press, alternating primary/secondary action.
//  - release: always fires on up.
//

import Foundation

nonisolated struct FiredMapping: Equatable, Sendable {
    var mapping: Mapping
    var useSecondaryAction: Bool = false
}

/// The mappings bound to one (control, layer) slot, split by trigger kind.
nonisolated struct TriggerSlot: Sendable {
    var press: Mapping?
    var release: Mapping?
    var doubleTap: Mapping?
    var hold: Mapping?      // trigger == .hold(ms:)
    var toggle: Mapping?

    init(mappings: [Mapping]) {
        for mapping in mappings {
            switch mapping.trigger {
            case .press: press = mapping
            case .release: release = mapping
            case .doubleTap: doubleTap = mapping
            case .hold: hold = mapping
            case .toggle: toggle = mapping
            case .continuous, .relative: break
            }
        }
    }

    var immediateOnDown: Bool { doubleTap == nil && hold == nil }
    var isEmpty: Bool { press == nil && release == nil && doubleTap == nil && hold == nil && toggle == nil }
}

@MainActor
final class TriggerMachine {
    static let doubleTapWindow: TimeInterval = 0.3

    private struct SlotState {
        var downAt: Date?
        var holdDeadline: Date?
        var holdFired = false
        var awaitingSecondTapSince: Date?
        var pendingSingle: TriggerSlot?
    }

    private var states: [String: SlotState] = [:]
    /// Toggle alternation, read/written through the store for persistence.
    var toggleStateProvider: (UUID) -> Bool = { _ in false }
    var toggleStateSink: (Bool, UUID) -> Void = { _, _ in }

    /// The earliest pending deadline, so the Dispatcher can schedule one timer.
    private(set) var nextDeadline: Date?

    func handleDown(key: String, slot: TriggerSlot, at now: Date) -> [FiredMapping] {
        var state = states[key] ?? SlotState()
        var fired: [FiredMapping] = []

        if let since = state.awaitingSecondTapSince, let double = slot.doubleTap {
            if now.timeIntervalSince(since) <= Self.doubleTapWindow {
                fired.append(FiredMapping(mapping: double))
                state.awaitingSecondTapSince = nil
                state.pendingSingle = nil
                state.downAt = now
                state.holdFired = false
                states[key] = state
                recomputeDeadline()
                return fired
            }
            // Window expired without a tick — flush the single now.
            fired += flushPendingSingle(&state)
        }

        state.downAt = now
        state.holdFired = false
        state.holdDeadline = holdMs(of: slot).map { now.addingTimeInterval(Double($0) / 1000) }

        if slot.immediateOnDown {
            fired += fireSingle(slot)
        }
        states[key] = state
        recomputeDeadline()
        return fired
    }

    func handleUp(key: String, slot: TriggerSlot, at now: Date) -> [FiredMapping] {
        var state = states[key] ?? SlotState()
        var fired: [FiredMapping] = []

        if let release = slot.release {
            fired.append(FiredMapping(mapping: release))
        }

        if state.holdFired {
            if let hold = slot.hold, hold.releaseAction != nil {
                fired.append(FiredMapping(mapping: hold, useSecondaryAction: true))  // secondary == releaseAction for holds
            }
            state.holdFired = false
        } else if !slot.immediateOnDown, state.downAt != nil {
            // Released before the hold threshold: a click.
            if slot.doubleTap != nil {
                state.awaitingSecondTapSince = state.downAt
                state.pendingSingle = slot
            } else {
                fired += fireSingle(slot)
            }
        }

        state.downAt = nil
        state.holdDeadline = nil
        states[key] = state
        recomputeDeadline()
        return fired
    }

    /// Called by the Dispatcher's timer; also safe to call at any time.
    func tick(at now: Date, slots: (String) -> TriggerSlot?) -> [FiredMapping] {
        var fired: [FiredMapping] = []
        for (key, var state) in states {
            guard let slot = slots(key) else { continue }
            // Hold threshold
            if let deadline = state.holdDeadline, !state.holdFired, let hold = slot.hold,
               now >= deadline {
                fired.append(FiredMapping(mapping: hold))
                state.holdFired = true
                state.holdDeadline = nil
            }
            // Double-tap window expiry → delayed single
            if let since = state.awaitingSecondTapSince,
               now.timeIntervalSince(since) > Self.doubleTapWindow {
                fired += flushPendingSingle(&state)
            }
            states[key] = state
        }
        recomputeDeadline()
        return fired
    }

    // MARK: - Internals

    private func fireSingle(_ slot: TriggerSlot) -> [FiredMapping] {
        if let toggle = slot.toggle {
            let next = !toggleStateProvider(toggle.id)
            toggleStateSink(next, toggle.id)
            return [FiredMapping(mapping: toggle, useSecondaryAction: !next)]
        }
        if let press = slot.press {
            return [FiredMapping(mapping: press)]
        }
        return []
    }

    private func flushPendingSingle(_ state: inout SlotState) -> [FiredMapping] {
        defer {
            state.awaitingSecondTapSince = nil
            state.pendingSingle = nil
        }
        guard let slot = state.pendingSingle else { return [] }
        return fireSingle(slot)
    }

    private func holdMs(of slot: TriggerSlot) -> Int? {
        if case let .hold(ms)? = slot.hold?.trigger { return ms }
        return nil
    }

    private func recomputeDeadline() {
        var earliest: Date?
        func consider(_ date: Date?) {
            guard let date else { return }
            if earliest == nil || date < earliest! { earliest = date }
        }
        for state in states.values {
            consider(state.holdDeadline)
            if let since = state.awaitingSecondTapSince {
                consider(since.addingTimeInterval(Self.doubleTapWindow))
            }
        }
        nextDeadline = earliest
    }
}
