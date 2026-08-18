//
//  MainWindowView.swift
//  DeckPad
//
//  M0 placeholder. The real controller canvas + three-pane layout lands in M4
//  per docs/05-ui-spec.md; colors move to the asset-catalog token set then
//  (docs/04-design-language.md §2).
//

import SwiftUI

struct MainWindowView: View {
    var body: some View {
        ZStack {
            // bg.canvas #121216 with the subtle "stage light" glow
            Color(.sRGB, red: 0x12 / 255, green: 0x12 / 255, blue: 0x16 / 255)
            RadialGradient(
                colors: [Color(.sRGB, red: 0x4A / 255, green: 0x15 / 255, blue: 0x4B / 255).opacity(0.20), .clear],
                center: .top,
                startRadius: 0,
                endRadius: 520
            )

            VStack(spacing: 16) {
                Text("DeckPad")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(.sRGB, red: 0xB4 / 255, green: 0x8C / 255, blue: 0xF2 / 255),
                                Color(.sRGB, red: 0xFF / 255, green: 0x63 / 255, blue: 0x63 / 255),
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                Text("Turn your DJ controller into a Mac control surface.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                Text("Controller canvas arrives in milestone M4 — close this window to drop into the menu bar.")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
            .padding(32)
        }
        .ignoresSafeArea()
        .frame(minWidth: 960, minHeight: 600)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    MainWindowView()
}
