//
//  GlobalConsoleView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/13/24.
//

import SwiftUI

struct GlobalConsoleView: View {
    let output: String
    @Binding var height: Double
    let onClear: () -> Void
    @Environment(\.colorScheme) var colorScheme
//    @State private var cursorState: CursorState = .normal
//    @State private var isHovering: Bool = false

//    enum CursorState {
//        case normal
//        case hovering
//        case dragging
//
//        var cursor: NSCursor {
//            switch self {
//            case .normal: return .arrow
//            case .hovering: return .openHand
//            case .dragging: return .closedHand
//            }
//        }
//
//        func apply() {
//            cursor.set()
//        }
//    }

    private var shouldShowLineCount: Bool {
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmedOutput.isEmpty && trimmedOutput != "Ready.."
    }

    private var lineCountText: String {
        // Trim trailing newlines before counting to avoid counting empty trailing lines
        let trimmedOutput = output.trimmingCharacters(in: .whitespacesAndNewlines)
        let lineCount = trimmedOutput.components(separatedBy: "\n").count
        return lineCount == 1 ? "1 line" : "\(lineCount) lines"
    }



    var body: some View {
        VStack(spacing: 0) {
            // Header with grab handle and buttons
            ZStack {
                // Label on left
                HStack {
                    Text("Console")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    if shouldShowLineCount {
                        Divider()
                            .frame(height: 10)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                        Text(lineCountText)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }

                    Spacer()
                }

                // Centered resize handle
                RoundedRectangle(cornerRadius: 2)
                    .fill(ThemeColors.shared(for: colorScheme).secondaryText)
                    .frame(width: 30, height: 2)
                    .padding(6)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button("Reset Size") {
                            height = 200
                        }
                    }
//                    .onHover { hovering in
//                        isHovering = hovering
//                        if cursorState != .dragging {
//                            cursorState = hovering ? .hovering : .normal
//                            cursorState.apply()
//                        }
//                    }
                    .gesture(
                        DragGesture()
                            .onChanged { value in
//                                if cursorState != .dragging {
//                                    cursorState = .dragging
//                                    cursorState.apply()
//                                }
                                let newHeight = height - value.translation.height
                                height = min(max(newHeight, 150), 400)
                            }
//                            .onEnded { _ in
//                                // Restore cursor based on hover state
//                                cursorState = isHovering ? .hovering : .normal
//                                cursorState.apply()
//                            }
                    )

                // Buttons on right
                HStack {
                    Spacer()
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(output, forType: .string)
                    } label: {
                        Image(systemName: "clipboard")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 15)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                    }
                    .buttonStyle(.plain)
                    .help("Copy console output to clipboard")

                    Button {
                        onClear()
                    } label: {
                        Image(systemName: "trash")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 14, height: 15)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    .buttonStyle(.plain)
                    .help("Clear console output")
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                .padding(.horizontal, 8)

            // Console output
            ScrollView {
                ScrollViewReader { proxy in
                    Text(output.isEmpty ? "Ready.." : output)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.green)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .id("consoleBottom")
                        .textSelection(.enabled)
                        .lineSpacing(1)
                        .onChange(of: output) { _ in
                            withAnimation {
                                proxy.scrollTo("consoleBottom", anchor: .bottom)
                            }
                        }
                        .onChange(of: height) { _ in
                            withAnimation {
                                proxy.scrollTo("consoleBottom", anchor: .bottom)
                            }
                        }
                }
            }
        }
        .background(RoundedRectangle(cornerRadius: ifOSBelow(macOS: 26) ? 8 : 20).fill(Color.black))
        .shadow(color: Color.black.opacity(1), radius: 10, x: 0, y: 0)
        .padding(8)
    }
}
