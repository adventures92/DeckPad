//
//  ActionEngineTests.swift
//  DeckPadTests
//
//  Executor tests against mocked seams — no real events are posted, no
//  processes spawned, no audio/display touched.
//

import Foundation
import Testing
@testable import DeckPad

// MARK: - Mocks

@MainActor
final class MockPoster: EventPosting {
    enum Posted: Equatable {
        case keystroke(UInt16, UInt64)
        case text(String)
        case systemKey(Int32)
        case scroll(Int32, Int32)
    }
    var posted: [Posted] = []

    func postKeystroke(keyCode: UInt16, modifiers: UInt64) { posted.append(.keystroke(keyCode, modifiers)) }
    func postText(_ chunk: String) { posted.append(.text(chunk)) }
    func postSystemKey(_ nxKeyType: Int32) { posted.append(.systemKey(nxKeyType)) }
    func postScroll(dx: Int32, dy: Int32) { posted.append(.scroll(dx, dy)) }
}

nonisolated final class MockRunner: ProcessRunning, @unchecked Sendable {
    struct Invocation: Sendable {
        var executable: String
        var arguments: [String]
        var environment: [String: String]?
    }
    let lock = NSLock()
    private(set) var invocations: [Invocation] = []
    var result = ProcessOutput(status: 0, stdout: "", stderr: "")

    func run(
        executable: String,
        arguments: [String],
        environment: [String: String]?,
        workingDirectory: String?,
        timeoutSeconds: Int
    ) async -> ProcessOutput {
        lock.lock()
        invocations.append(Invocation(executable: executable, arguments: arguments, environment: environment))
        let result = self.result
        lock.unlock()
        return result
    }
}

@MainActor
final class MockVolume: VolumeControlling {
    var current: Double? = 0.5
    var setCalls: [Double] = []
    func setVolume(_ value: Double) { setCalls.append(value); current = value }
    func volume() -> Double? { current }
}

@MainActor
final class MockBrightness: BrightnessControlling {
    var isAvailable: Bool
    var setCalls: [Double] = []
    init(available: Bool) { isAvailable = available }
    func setBrightness(_ value: Double) -> Bool {
        guard isAvailable else { return false }
        setCalls.append(value)
        return true
    }
}

@MainActor
private func makeEngine(
    poster: MockPoster? = nil,
    runner: MockRunner? = nil,
    volume: MockVolume? = nil,
    brightness: MockBrightness? = nil,
    trusted: Bool = true
) -> (ActionEngine, MockPoster, MockRunner, MockVolume, MockBrightness) {
    let poster = poster ?? MockPoster()
    let runner = runner ?? MockRunner()
    let volume = volume ?? MockVolume()
    let brightness = brightness ?? MockBrightness(available: true)
    let engine = ActionEngine(
        poster: poster, runner: runner, volumeControl: volume,
        brightnessControl: brightness, trustCheck: { trusted }
    )
    return (engine, poster, runner, volume, brightness)
}

// MARK: - Tests

@MainActor
struct ActionEngineTests {
    @Test func keystrokePostsWithModifiers() {
        let (engine, poster, _, _, _) = makeEngine()
        let result = engine.execute(.keystroke(KeyCombo(keyCode: 17, modifiers: KeyCombo.command | KeyCombo.shift)))
        #expect(result == .success)
        #expect(poster.posted == [.keystroke(17, KeyCombo.command | KeyCombo.shift)])
    }

    @Test func missingAccessibilityFailsVisibly() {
        let (engine, poster, _, _, _) = makeEngine(trusted: false)
        let result = engine.execute(.keystroke(KeyCombo(keyCode: 0, modifiers: 0)))
        #expect(result == .permissionMissing("Accessibility permission required"))
        #expect(poster.posted.isEmpty)
    }

    @Test func textSnippetChunksAt20UTF16Units() {
        let (engine, poster, _, _, _) = makeEngine()
        let text = String(repeating: "a", count: 45)
        #expect(engine.execute(.textSnippet(text)) == .success)
        let chunks = poster.posted.compactMap { if case let .text(t) = $0 { t } else { nil } }
        #expect(chunks.count == 3)
        #expect(chunks.joined() == text)
    }

    @Test func mediaKeyRepeatsSteps() {
        let (engine, poster, _, _, _) = makeEngine()
        #expect(engine.execute(.mediaKey(.volumeUp, steps: 3)) == .success)
        #expect(poster.posted == [.systemKey(0), .systemKey(0), .systemKey(0)])
    }

    @Test func shellCommandRunsThroughZshAndReportsCompletion() async {
        let (engine, _, runner, _, _) = makeEngine()
        let result = await withCheckedContinuation { continuation in
            _ = engine.execute(.shellCommand(command: "echo hi", workingDirectory: nil, timeoutSeconds: 5)) {
                continuation.resume(returning: $0)
            }
        }
        #expect(result == .success)
        #expect(runner.invocations.first?.executable == "/bin/zsh")
        #expect(runner.invocations.first?.arguments == ["-c", "echo hi"])
    }

    @Test func failingSubprocessReportsFailure() async {
        let runner = MockRunner()
        runner.result = ProcessOutput(status: 1, stdout: "", stderr: "boom")
        let (engine, _, _, _, _) = makeEngine(runner: runner)
        let result = await withCheckedContinuation { continuation in
            _ = engine.execute(.runShortcut(name: "Nope", input: nil)) {
                continuation.resume(returning: $0)
            }
        }
        guard case let .failure(message) = result else {
            Issue.record("expected failure, got \(result)")
            return
        }
        #expect(message.contains("boom"))
        #expect(runner.invocations.first?.arguments == ["run", "Nope"])
    }

    @Test func continuousVolumeAppliesShape() {
        let (engine, _, _, volume, _) = makeEngine()
        engine.executeContinuous(.systemVolume(ContinuousShape(rangeMin: 0.2, rangeMax: 0.8)), value: 0.5)
        #expect(volume.setCalls.count == 1)
        #expect(abs(volume.setCalls[0] - 0.5) < 0.0001)
        engine.executeContinuous(.systemVolume(ContinuousShape(rangeMin: 0.2, rangeMax: 0.8)), value: 1.0)
        #expect(abs(volume.setCalls[1] - 0.8) < 0.0001)
    }

    @Test func brightnessFallsBackToSteppedKeysWhenUnavailable() {
        let (engine, poster, _, _, brightness) = makeEngine(brightness: MockBrightness(available: false))
        engine.executeContinuous(.displayBrightness(ContinuousShape()), value: 0.9)
        #expect(brightness.setCalls.isEmpty)
        #expect(poster.posted == [.systemKey(MediaKey.brightnessUp.nxKeyType)])
    }

    @Test func scrollScalesTicksToPixels() {
        let (engine, poster, _, _, _) = makeEngine()
        engine.executeRelative(.scroll(axis: .vertical, speedMultiplier: 1.5, natural: false), ticks: 2, token: "t")
        #expect(poster.posted == [.scroll(0, 12)])
        engine.executeRelative(.scroll(axis: .horizontal, speedMultiplier: 1.0, natural: true), ticks: 3, token: "t")
        #expect(poster.posted.last == .scroll(-12, 0))
    }

    @Test func arrowStepperAccumulatesTicks() {
        let (engine, poster, _, _, _) = makeEngine()
        let fwd = KeyCombo(keyCode: 124, modifiers: 0)   // →
        let rev = KeyCombo(keyCode: 123, modifiers: 0)   // ←
        let action = Action.arrowStepper(perTick: fwd, reverseTick: rev, ticksPerStep: 4)
        engine.executeRelative(action, ticks: 3, token: "jog")
        #expect(poster.posted.isEmpty)
        engine.executeRelative(action, ticks: 2, token: "jog")
        #expect(poster.posted == [.keystroke(124, 0)])
        engine.executeRelative(action, ticks: -9, token: "jog")
        #expect(poster.posted == [.keystroke(124, 0), .keystroke(123, 0), .keystroke(123, 0)])
    }

    @Test func volumeDialStepsFromCurrentVolume() {
        let (engine, _, _, volume, _) = makeEngine()
        volume.current = 0.5
        engine.executeRelative(.volumeDial(stepSize: 0.02), ticks: 5, token: "enc")
        #expect(abs((volume.setCalls.last ?? 0) - 0.6) < 0.0001)
        engine.executeRelative(.volumeDial(stepSize: 0.02), ticks: -10, token: "enc")
        #expect(abs((volume.setCalls.last ?? 0) - 0.4) < 0.0001)
    }

    @Test func discreteTriggerRejectsContinuousActions() {
        let (engine, _, _, _, _) = makeEngine()
        let result = engine.execute(.systemVolume(ContinuousShape()))
        guard case .failure = result else {
            Issue.record("expected failure, got \(result)")
            return
        }
    }

    @Test func actionRoundTripsThroughJSON() throws {
        let actions: [Action] = [
            .keystroke(KeyCombo(keyCode: 17, modifiers: KeyCombo.command)),
            .textSnippet("hi"),
            .mediaKey(.playPause, steps: 1),
            .launchApp(bundleID: "com.apple.TextEdit"),
            .runShortcut(name: "X", input: "y"),
            .shellCommand(command: "ls", workingDirectory: "/tmp", timeoutSeconds: 30),
            .systemVolume(ContinuousShape(rangeMin: 0.1, rangeMax: 0.9, curve: .eased)),
            .scroll(axis: .vertical, speedMultiplier: 1.5, natural: true),
            .arrowStepper(perTick: KeyCombo(keyCode: 124, modifiers: 0), reverseTick: KeyCombo(keyCode: 123, modifiers: 0), ticksPerStep: 4),
            .noOp(label: "reserved"),
        ]
        for action in actions {
            let data = try JSONEncoder().encode(action)
            #expect(try JSONDecoder().decode(Action.self, from: data) == action)
        }
    }
}
