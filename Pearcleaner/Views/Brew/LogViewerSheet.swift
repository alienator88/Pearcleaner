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
        StandardSheetView(
            title: "Homebrew Auto-Update Log",
            width: 700,
            height: 500,
            onClose: onClose
        ) {
            // Content
            ScrollView {
                Text(logContent)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } actionButtons: {
            Button("Close") {
                onClose()
            }
            .keyboardShortcut(.cancelAction)
        }
    }
}
