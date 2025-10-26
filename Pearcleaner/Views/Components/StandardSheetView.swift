//
//  StandardSheetView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/26/25.
//

import SwiftUI

struct StandardSheetView<Content: View, SelectionControls: View, ActionButtons: View>: View {
    let title: String
    let width: CGFloat
    let height: CGFloat
    let onClose: () -> Void
    let content: () -> Content
    let selectionControls: () -> SelectionControls
    let actionButtons: () -> ActionButtons

    @Environment(\.colorScheme) var colorScheme

    init(
        title: String,
        width: CGFloat = 600,
        height: CGFloat = 500,
        onClose: @escaping () -> Void,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder selectionControls: @escaping () -> SelectionControls = { EmptyView() },
        @ViewBuilder actionButtons: @escaping () -> ActionButtons
    ) {
        self.title = title
        self.width = width
        self.height = height
        self.onClose = onClose
        self.content = content
        self.selectionControls = selectionControls
        self.actionButtons = actionButtons
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                Spacer()

                Button {
                    onClose()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            Divider()

            // Content area with spacing
            VStack(spacing: 20) {
                content()

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)

            Divider()

            // Bottom toolbar
            HStack {
                if SelectionControls.self != EmptyView.self {
                    // Selection controls on left
                    selectionControls()

                    Spacer()

                    // Action buttons on right
                    actionButtons()
                } else {
                    // No selection controls - center action buttons
                    Spacer()
                    actionButtons()
                    Spacer()
                }
            }
            .padding(20)
        }
        .frame(width: width, height: height)
        .background(ThemeColors.shared(for: colorScheme).primaryBG)
    }
}
