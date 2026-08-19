//
//  ActionEngine.swift
//  DeckPad
//
//  Executes Actions (FR-30/31). Fast path (keystrokes, media keys, scroll,
//  volume/brightness) runs synchronously on the main actor; subprocess
//  actions run async and report their result later. All seams
//  (EventPosting, ProcessRunning, Volume/BrightnessControlling) are
//  injectable for tests.
//

import AppKit
import ApplicationServices
import Foundation
import os

@MainActor
final class ActionEngine {
    static let shared = ActionEngine()

    private let poster: EventPosting
    private let runner: ProcessRunning
    private let volumeControl: VolumeControlling
    private let brightnessControl: BrightnessControlling
    private let permissions: PermissionsManager
    private let trustCheck: () -> Bool

    private static let log = Logger(subsystem: "com.adven.DeckPad", category: "action")
    static let signposter = OSSignposter(subsystem: "com.adven.DeckPad", category: "latency")

    /// Accumulators for relative modes that step (arrowStepper/zoom/dial),
    /// keyed by mapping token (control ID in the demo bench; mapping UUID in M3).
    private var tickAccumulators: [String: Int] = [:]
    /// Tracked values for relative dials.
    private var dialValues: [String: Double] = [:]

    init(
        poster: EventPosting? = nil,
        runner: ProcessRunning? = nil,
        volumeControl: VolumeControlling? = nil,
        brightnessControl: BrightnessControlling? = nil,
        permissions: PermissionsManager? = nil,
        trustCheck: @escaping () -> Bool = { AXIsProcessTrusted() }
    ) {
        self.poster = poster ?? SystemEventPoster()
        self.runner = runner ?? SubprocessRunner()
        self.volumeControl = volumeControl ?? CoreAudioVolume()
        self.brightnessControl = brightnessControl ?? DisplayServicesBrightness()
        self.permissions = permissions ?? .shared
        self.trustCheck = trustCheck
    }

    // MARK: - Discrete actions

    /// Fast actions return synchronously; subprocess actions return
    /// `.success` optimistically and deliver the real result to `completion`.
    @discardableResult
    func execute(_ action: Action, completion: (@MainActor (ActionResult) -> Void)? = nil) -> ActionResult {
        switch action {
        // Keyboard
        case let .keystroke(combo):
            return withAccessibility { poster.postKeystroke(keyCode: combo.keyCode, modifiers: combo.modifiers) }
        case let .textSnippet(text):
            return withAccessibility {
                for chunk in Self.chunked(text, size: 20) { poster.postText(chunk) }
            }

        // Media & system keys
        case let .mediaKey(key, steps):
            return withAccessibility {
                for _ in 0..<max(1, steps) { poster.postSystemKey(key.nxKeyType) }
            }

        // Apps & files
        case let .launchApp(bundleID):
            return launchOrFocus(bundleID: bundleID)
        case let .hideApp(bundleID):
            runningApp(bundleID)?.hide()
            return .success
        case let .quitApp(bundleID, force):
            guard let app = runningApp(bundleID) else { return .failure("\(bundleID) is not running") }
            _ = force ? app.forceTerminate() : app.terminate()
            return .success
        case .cycleWindows:
            return withAccessibility { poster.postKeystroke(keyCode: 50, modifiers: KeyCombo.command) }  // ⌘`
        case let .openURL(urlString):
            guard let url = URL(string: urlString) else { return .failure("invalid URL") }
            NSWorkspace.shared.open(url)
            return .success
        case let .openFile(path):
            NSWorkspace.shared.open(URL(fileURLWithPath: (path as NSString).expandingTildeInPath))
            return .success
        case .missionControl:
            return launchOrFocus(bundleID: "com.apple.exposelauncher")
        case .launchpad:
            return launchOrFocus(bundleID: "com.apple.launchpad.launcher")

        // Automation (async)
        case let .runShortcut(name, input):
            var args = ["run", name]
            if let input { args += ["-i", input] }
            return runAsync("/usr/bin/shortcuts", args, label: "Shortcut \(name)", completion: completion)
        case let .shellCommand(command, workingDirectory, timeout):
            return runAsync(
                "/bin/zsh", ["-c", command],
                workingDirectory: workingDirectory, timeout: timeout,
                label: "shell", completion: completion
            )
        case let .appleScript(source):
            return runAsync("/usr/bin/osascript", ["-e", source], label: "AppleScript", completion: completion)

        // System toggles
        case .lockScreen:
            return withAccessibility { poster.postKeystroke(keyCode: 12, modifiers: KeyCombo.control | KeyCombo.command) }  // ⌃⌘Q
        case .startScreenSaver:
            NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Library/CoreServices/ScreenSaverEngine.app"))
            return .success
        case .toggleDarkMode:
            let script = "tell application \"System Events\" to tell appearance preferences to set dark mode to not dark mode"
            return runAsync("/usr/bin/osascript", ["-e", script], label: "dark mode", completion: completion)
        case let .screenshot(mode):
            return withAccessibility {
                switch mode {
                case .fullScreen: poster.postKeystroke(keyCode: 20, modifiers: KeyCombo.shift | KeyCombo.command)                       // ⇧⌘3
                case .window, .area: poster.postKeystroke(keyCode: 21, modifiers: KeyCombo.shift | KeyCombo.command)                    // ⇧⌘4
                case .areaToClipboard: poster.postKeystroke(keyCode: 21, modifiers: KeyCombo.control | KeyCombo.shift | KeyCombo.command)
                }
            }
        case .toggleDoNotDisturb:
            return runAsync("/usr/bin/shortcuts", ["run", "DeckPad DND"], label: "DND", completion: completion)
        case .sleepDisplays:
            return runAsync("/usr/bin/pmset", ["displaysleepnow"], label: "display sleep", completion: completion)

        // Internal (FR-32, FR-20…22)
        case let .switchProfile(name):
            guard let profile = MappingStore.shared.profiles.first(where: { $0.name == name }) else {
                return .failure("no profile named \(name)")
            }
            ProfileSwitcher.shared.pin(profile.id)
            Dispatcher.shared.resetPickup()
            return .success
        case .pinActiveProfile:
            let switcher = ProfileSwitcher.shared
            switcher.pin(switcher.pinnedProfileID == nil ? switcher.activeProfile.id : nil)
            return .success
        case .suspendDeckPad:
            Dispatcher.shared.isSuspended.toggle()
            return .success
        case .openDeckPad:
            ServiceController.shared.enterActiveUI()
            return .success
        case .toggleMIDIMonitor:
            Self.log.info("toggleMIDIMonitor — needs openWindow environment; wired with M4 UI")
            return .success
        case .noOp:
            return .success

        // Continuous/relative actions used as discrete = configuration error
        case .systemVolume, .displayBrightness, .customCommandContinuous,
             .scroll, .arrowStepper, .zoom, .volumeDial, .brightnessDial, .customCommandPerTick:
            return .failure("continuous/relative action used with a discrete trigger")
        }
    }

    // MARK: - Continuous actions (FR-11)

    func executeContinuous(_ action: Action, value: Double) {
        switch action {
        case let .systemVolume(shape):
            volumeControl.setVolume(shape.apply(value))
        case let .displayBrightness(shape):
            let target = shape.apply(value)
            if !brightnessControl.setBrightness(target) {
                // ADR-007 fallback: no smooth control — approximate with stepped keys.
                steppedBrightnessFallback(toward: target)
            }
        case let .customCommandContinuous(command):
            throttledContinuousCommand(command, value: value)
        default:
            Self.log.error("non-continuous action \(String(describing: action)) got a continuous value")
        }
    }

    /// Current system volume 0–1, for soft-takeover pickup (docs/06 §7).
    func currentSystemVolume() -> Double? {
        volumeControl.volume()
    }

    // MARK: - Relative actions (FR-12)

    func executeRelative(_ action: Action, ticks: Int, token: String) {
        switch action {
        case let .scroll(axis, speed, natural):
            let amount = Int32((Double(ticks) * speed * 4).rounded())
            let signed = natural ? -amount : amount
            _ = withAccessibility {
                poster.postScroll(dx: axis == .horizontal ? signed : 0, dy: axis == .vertical ? signed : 0)
            }
        case let .arrowStepper(perTick, reverseTick, ticksPerStep):
            step(token: token, ticks: ticks, ticksPerStep: ticksPerStep) { forward in
                let combo = forward ? perTick : reverseTick
                _ = withAccessibility { poster.postKeystroke(keyCode: combo.keyCode, modifiers: combo.modifiers) }
            }
        case let .zoom(ticksPerStep):
            step(token: token, ticks: ticks, ticksPerStep: ticksPerStep) { forward in
                // ⌘+ / ⌘−
                let keyCode: UInt16 = forward ? 24 : 27
                _ = withAccessibility { poster.postKeystroke(keyCode: keyCode, modifiers: KeyCombo.command) }
            }
        case let .volumeDial(stepSize):
            let current = dialValues[token] ?? volumeControl.volume() ?? 0.5
            let next = min(max(current + Double(ticks) * stepSize, 0), 1)
            dialValues[token] = next
            volumeControl.setVolume(next)
        case let .brightnessDial(stepSize):
            let current = dialValues[token] ?? 0.5
            let next = min(max(current + Double(ticks) * stepSize, 0), 1)
            dialValues[token] = next
            if !brightnessControl.setBrightness(next) {
                _ = withAccessibility {
                    poster.postSystemKey(ticks > 0 ? MediaKey.brightnessUp.nxKeyType : MediaKey.brightnessDown.nxKeyType)
                }
            }
        case let .customCommandPerTick(command, ticksPerRun):
            step(token: token, ticks: ticks, ticksPerStep: ticksPerRun) { forward in
                _ = self.execute(.shellCommand(
                    command: command, workingDirectory: nil, timeoutSeconds: 10
                ))
                _ = forward
            }
        default:
            Self.log.error("non-relative action \(String(describing: action)) got ticks")
        }
    }

    // MARK: - Helpers

    private func withAccessibility(_ body: () -> Void) -> ActionResult {
        guard trustCheck() else {
            permissions.noteAccessibilityFailure()
            return .permissionMissing("Accessibility permission required")
        }
        body()
        return .success
    }

    private func runningApp(_ bundleID: String) -> NSRunningApplication? {
        NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first
    }

    private func launchOrFocus(bundleID: String) -> ActionResult {
        if let running = runningApp(bundleID) {
            running.activate()
            return .success
        }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return .failure("app \(bundleID) not found")
        }
        NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
        return .success
    }

    private func runAsync(
        _ executable: String,
        _ arguments: [String],
        workingDirectory: String? = nil,
        timeout: Int = 30,
        environment: [String: String]? = nil,
        label: String,
        completion: (@MainActor (ActionResult) -> Void)?
    ) -> ActionResult {
        let runner = runner
        Task {
            let output = await runner.run(
                executable: executable,
                arguments: arguments,
                environment: environment,
                workingDirectory: workingDirectory,
                timeoutSeconds: timeout
            )
            let result: ActionResult = output.status == 0
                ? .success
                : .failure("\(label) failed (\(output.status)): \(output.stderr.prefix(200))")
            if !result.isSuccess {
                Self.log.error("\(label) failed: \(output.stderr)")
            }
            await MainActor.run { completion?(result) }
        }
        return .success
    }

    private func step(token: String, ticks: Int, ticksPerStep: Int, fire: (Bool) -> Void) {
        let per = max(1, ticksPerStep)
        var accumulator = tickAccumulators[token, default: 0] + ticks
        while accumulator >= per { fire(true); accumulator -= per }
        while accumulator <= -per { fire(false); accumulator += per }
        tickAccumulators[token] = accumulator
    }

    private var lastBrightnessKeyAt = Date.distantPast
    private func steppedBrightnessFallback(toward target: Double) {
        // Coarse 16-step fallback, rate-limited so a fader sweep doesn't flood.
        guard Date().timeIntervalSince(lastBrightnessKeyAt) > 0.05 else { return }
        lastBrightnessKeyAt = Date()
        _ = withAccessibility {
            poster.postSystemKey(target > 0.5 ? MediaKey.brightnessUp.nxKeyType : MediaKey.brightnessDown.nxKeyType)
        }
    }

    private var lastContinuousCommandAt = Date.distantPast
    private func throttledContinuousCommand(_ command: String, value: Double) {
        // 10 Hz max per docs/06 §4.
        guard Date().timeIntervalSince(lastContinuousCommandAt) > 0.1 else { return }
        lastContinuousCommandAt = Date()
        _ = runAsync(
            "/bin/zsh", ["-c", command],
            timeout: 10,
            environment: ["DECKPAD_VALUE": String(format: "%.4f", value)],
            label: "continuous shell",
            completion: nil
        )
    }

    private static func chunked(_ text: String, size: Int) -> [String] {
        var chunks: [String] = []
        var current = ""
        for character in text {
            current.append(character)
            if current.utf16.count >= size {
                chunks.append(current)
                current = ""
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }
}
