//
//  LogViewerSheet.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/26/25.
//

import SwiftUI

struct LogViewerSheet: View {
    let logContent: String
    let onClose: () -> Void
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Homebrew Auto-Update Log")
                    .font(.headline)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                Spacer()
            }
            .padding()

            Divider()

            // Log content in ScrollView
            ScrollView {
                Text(logContent)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }

            Divider()

            // Bottom button
            HStack {
                Spacer()

                Button("Close") {
                    onClose()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()
        }
        .frame(width: 700, height: 500)
        .background(ThemeColors.shared(for: colorScheme).primaryBG)
    }
}
