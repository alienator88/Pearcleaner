//
//  ExpandableActionButton.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/25/25.
//

import SwiftUI
import AlinFoundation

struct ExpandableActionButton: View {
    let primaryAction: ActionButtonItem
    let secondaryActions: [ActionButtonItem]
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        HStack(spacing: 0) {
            // Primary action button
            Button(action: primaryAction.action) {
                Text(primaryAction.title)
                    .foregroundStyle(primaryAction.foregroundColor)
                    .padding(.leading, 4)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(primaryAction.isDisabled)

            if !secondaryActions.isEmpty {
                // Divider
                Divider()
                    .frame(height: 20)
//                    .padding(.horizontal, 4)

                // Chevron button that shows NSMenu
                MenuButton(
                    items: secondaryActions,
                    colorScheme: colorScheme
                )
                .frame(width: 20, height: 20)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
            }
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    primaryAction.backgroundColor.adjust(brightness: colorScheme == .dark ? 0.05 : 0),
                    primaryAction.backgroundColor.adjust(brightness: colorScheme == .dark ? -0.05 : 0)
                ]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(
                    LinearGradient(
                        gradient: Gradient(stops: [
                            .init(color: Color.white.opacity(0.4), location: 0.0),
                            .init(color: Color.white.opacity(0.2), location: 0.5),
                            .init(color: Color.black.opacity(0.3), location: 1.0)
                        ]),
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
        )
        .opacity(primaryAction.isDisabled ? 0.5 : 1.0)
    }

    // MARK: - NSViewRepresentable for Menu Button

    private struct MenuButton: NSViewRepresentable {
        let items: [ActionButtonItem]
        let colorScheme: ColorScheme

        func makeNSView(context: Context) -> NSView {
            let button = NSButton()
            button.title = ""

            // Create smaller chevron image
            let config = NSImage.SymbolConfiguration(pointSize: 10, weight: .regular)
            button.image = NSImage(systemSymbolName: "chevron.down", accessibilityDescription: nil)?.withSymbolConfiguration(config)

            button.isBordered = false
            button.bezelStyle = .regularSquare
            button.target = context.coordinator
            button.action = #selector(Coordinator.showMenu(_:))

            // Use ThemeColors primary text color
            button.contentTintColor = NSColor(ThemeColors.shared(for: colorScheme).primaryText)

            // Make the entire button area clickable
            button.imagePosition = .imageOnly

            // Set size constraints to match SwiftUI padding
            button.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                button.widthAnchor.constraint(equalToConstant: 24),
                button.heightAnchor.constraint(equalToConstant: 24)
            ])

            return button
        }

        func updateNSView(_ button: NSView, context: Context) {
            guard let button = button as? NSButton else { return }
            button.contentTintColor = NSColor(ThemeColors.shared(for: colorScheme).primaryText)
        }

        func makeCoordinator() -> Coordinator {
            Coordinator(items: items)
        }

        class Coordinator: NSObject {
            let items: [ActionButtonItem]

            init(items: [ActionButtonItem]) {
                self.items = items
            }

            @objc func showMenu(_ sender: NSButton) {
                let menu = NSMenu()

                for item in items {
                    let menuItem = NSMenuItem(
                        title: NSLocalizedString(item.title, comment: ""),
                        action: #selector(handleMenuAction(_:)),
                        keyEquivalent: ""
                    )

                    // Apply custom color via NSAttributedString
                    menuItem.attributedTitle = NSAttributedString(
                        string: NSLocalizedString(item.title, comment: ""),
                        attributes: [
                            .foregroundColor: NSColor(item.foregroundColor),
                            .font: NSFont.systemFont(ofSize: NSFont.systemFontSize)
                        ]
                    )

                    menuItem.target = self
                    menuItem.representedObject = item.action
                    menuItem.isEnabled = !item.isDisabled
                    menu.addItem(menuItem)
                }

                // Show menu below the button
                let location = NSPoint(x: 0, y: sender.bounds.height + 4)
                menu.popUp(positioning: nil, at: location, in: sender)
            }

            @objc func handleMenuAction(_ sender: NSMenuItem) {
                if let action = sender.representedObject as? () -> Void {
                    action()
                }
            }
        }
    }
}

struct ActionButtonItem {
    let title: String
    let foregroundColor: Color
    let backgroundColor: Color
    let isDisabled: Bool
    let action: () -> Void

    init(
        title: String,
        foregroundColor: Color,
        backgroundColor: Color,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.foregroundColor = foregroundColor
        self.backgroundColor = backgroundColor
        self.isDisabled = isDisabled
        self.action = action
    }

}
