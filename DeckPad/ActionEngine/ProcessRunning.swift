//
//  ProcessRunning.swift
//  DeckPad
//
//  Seam for subprocess-based actions (shell, Shortcuts, osascript).
//  Runs off the main actor; results feed feedback success/failure (FR-31:
//  slow actions never block the hub).
//

import Foundation

nonisolated struct ProcessOutput: Sendable, Equatable {
    var status: Int32
    var stdout: String
    var stderr: String
}

nonisolated protocol ProcessRunning: Sendable {
    func run(
        executable: String,
        arguments: [String],
        environment: [String: String]?,
        workingDirectory: String?,
        timeoutSeconds: Int
    ) async -> ProcessOutput
}

nonisolated struct SubprocessRunner: ProcessRunning {
    func run(
        executable: String,
        arguments: [String],
        environment: [String: String]?,
        workingDirectory: String?,
        timeoutSeconds: Int
    ) async -> ProcessOutput {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments
                if let environment {
                    process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, new in new }
                }
                if let workingDirectory {
                    process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory)
                }
                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: ProcessOutput(status: -1, stdout: "", stderr: error.localizedDescription))
                    return
                }

                let deadline = DispatchTime.now() + .seconds(max(1, timeoutSeconds))
                DispatchQueue.global(qos: .utility).asyncAfter(deadline: deadline) {
                    if process.isRunning { process.terminate() }
                }

                process.waitUntilExit()
                let stdout = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                continuation.resume(returning: ProcessOutput(status: process.terminationStatus, stdout: stdout, stderr: stderr))
            }
        }
    }
}
