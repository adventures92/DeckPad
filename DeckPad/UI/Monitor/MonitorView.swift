//
//  MonitorView.swift
//  DeckPad
//
//  MIDI monitor (FR-6): live stream table + capture mode
//  (docs/05-ui-spec.md §7). Functional in M1; visual polish lands in M4.
//

import SwiftUI

struct MonitorView: View {
    @StateObject private var store = MonitorStore()
    @StateObject private var capture = CaptureSession()
    @ObservedObject private var engine = MIDIEngine.shared

    @State private var listenerID = UUID()
    @State private var captureEnabled = false

    var body: some View {
        HSplitView {
            streamTable
                .frame(minWidth: 460, idealWidth: 560)
            if captureEnabled {
                capturePanel
                    .frame(minWidth: 320, idealWidth: 360)
            }
        }
        .frame(minWidth: 480, minHeight: 420)
        .toolbar {
            ToolbarItemGroup {
                Label(
                    engine.isConnected ? "DDJ-FLX4 connected" : "No device",
                    systemImage: engine.isConnected ? "cable.connector" : "cable.connector.slash"
                )
                .foregroundStyle(engine.isConnected ? .green : .secondary)

                Button(store.isPaused ? "Resume" : "Pause", systemImage: store.isPaused ? "play.fill" : "pause.fill") {
                    store.isPaused.toggle()
                }
                Button("Clear", systemImage: "trash") { store.clear() }
                Toggle("Capture Mode", systemImage: "record.circle", isOn: $captureEnabled)
            }
        }
        .onAppear {
            MIDIEngine.shared.addListener(listenerID) { packet in
                store.append(packet)
                capture.handle(packet)
            }
        }
        .onDisappear {
            MIDIEngine.shared.removeListener(listenerID)
            capture.stop()
        }
        .onChange(of: captureEnabled) { _, enabled in
            if !enabled { capture.stop() }
        }
        .navigationTitle("MIDI Monitor")
    }

    // MARK: Stream

    private var streamTable: some View {
        ScrollViewReader { proxy in
            List(store.rows) { row in
                HStack(spacing: 12) {
                    Text(row.time, format: .dateTime.hour().minute().second().secondFraction(.fractional(3)))
                        .foregroundStyle(.secondary)
                    Text(row.raw)
                    if let decoded = row.decoded {
                        Text(decoded).foregroundStyle(.cyan)
                    }
                    Spacer()
                }
                .font(.system(size: 12, design: .monospaced))
                .listRowSeparator(.hidden)
                .id(row.id)
            }
            .onChange(of: store.rows.last?.id) { _, lastID in
                if let lastID { proxy.scrollTo(lastID, anchor: .bottom) }
            }
            .overlay {
                if store.rows.isEmpty {
                    ContentUnavailableView(
                        "Waiting for MIDI",
                        systemImage: "pianokeys",
                        description: Text("Touch any control on the DDJ-FLX4.")
                    )
                }
            }
        }
    }

    // MARK: Capture panel

    private var capturePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Device Map Capture")
                .font(.headline)

            Picker("Pass", selection: $capture.pass) {
                ForEach(CaptureSession.Pass.allCases) { pass in
                    Text(pass.label).tag(pass)
                }
            }
            .pickerStyle(.segmented)
            .disabled(capture.phase != .idle && capture.phase != .done)

            switch capture.phase {
            case .idle:
                Text("Walks every control in the documented order and records what the hardware sends. ~5 minutes per pass.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button("Start \(capture.pass.label)", systemImage: "record.circle.fill") {
                    capture.begin(capture.pass)
                }
                .buttonStyle(.borderedProminent)

            case .prompting, .collecting:
                if let item = capture.currentItem {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(capture.progressLabel) · \(item.section)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(item.name)
                            .font(.title2.bold())
                        Text("`\(item.id.rawValue)`")
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Text(capture.prompt(for: item))
                            .font(.body)
                            .padding(.top, 2)
                    }

                    if capture.phase == .collecting {
                        Label("Recording… release to finish", systemImage: "dot.radiowaves.left.and.right")
                            .foregroundStyle(.orange)
                            .font(.caption)
                    }

                    if !capture.liveObservations.isEmpty {
                        VStack(alignment: .leading, spacing: 2) {
                            ForEach(capture.liveObservations) { obs in
                                Text(obs.display)
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.green)
                            }
                        }
                        .padding(6)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                    }

                    HStack {
                        Button("Skip", systemImage: "forward.fill") { capture.skip() }
                        Button("Redo Previous", systemImage: "arrow.uturn.backward") { capture.redoPrevious() }
                            .disabled(capture.index == 0)
                        Spacer()
                        Button("Stop", role: .destructive) { capture.stop() }
                    }
                    .controlSize(.small)
                }

            case .done:
                Label("Pass complete", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                Text("\(capture.capturedCount) controls captured, \(capture.entries.count - capture.capturedCount) skipped.")
                    .font(.callout)
                if capture.pass == .base {
                    Text("Now run Pass B with SHIFT held to capture the shift layer.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            if let status = capture.statusLine {
                Text(status)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }

            HStack {
                Button("Export JSON + Markdown", systemImage: "square.and.arrow.up") {
                    capture.export()
                }
                .disabled(capture.entries.isEmpty)
                Spacer()
                Text("\(capture.entries.count) entries")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }
}
