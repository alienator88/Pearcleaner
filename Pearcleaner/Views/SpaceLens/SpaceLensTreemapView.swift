//
//  SpaceLensTreemapView.swift
//  Pearcleaner
//

import SwiftUI

struct SpaceLensTreemapView: View {
    let focusedNode: SpaceLensNode
    var maxDepth: Int = 3
    let onDrill: (SpaceLensNode) -> Void
    let onTrash: (SpaceLensNode) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled = true
    @State private var hoverRectID: UUID?
    @State private var hoverPoint: CGPoint?
    @State private var drillGeneration: UUID?

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        GeometryReader { geo in
            let rects = SpaceLensLayout.treemapRects(node: focusedNode, in: CGRect(origin: .zero, size: geo.size), maxDepth: maxDepth)

            Canvas { context, _ in
                for rect in rects {
                    let color = SpaceLensLayout.color(hue: rect.hue, depth: rect.depth, isDark: isDark,
                                                     isError: rect.node.accessError != nil)
                    var path = Path()
                    path.addRect(rect.frame.insetBy(dx: 1, dy: 1))
                    let isHovered = hoverRectID == rect.id
                    let tileColor = isHovered ? color.opacity(0.8) : color
                    if rect.depth > 0 {
                        // Nested squares lift off the parent tile so the hierarchy is visible
                        context.drawLayer { layer in
                            layer.addFilter(.shadow(color: .black.opacity(isDark ? 0.5 : 0.3), radius: 2, x: 0, y: 1))
                            layer.fill(path, with: .color(tileColor))
                        }
                    } else {
                        context.fill(path, with: .color(tileColor))
                    }
                    // 2px gap between tiles comes from the inset plus this stroke
                    context.stroke(path, with: .color(ThemeColors.shared(for: colorScheme).primaryBG), lineWidth: 2)

                    if rect.frame.width > 48, rect.frame.height > 24, !rect.isOther {
                        let label = SpaceLensLayout.labelColor(hue: rect.hue, depth: rect.depth, isDark: isDark,
                                                               isError: rect.node.accessError != nil)
                        let name = Text(rect.node.name)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(label)
                        context.draw(name, at: CGPoint(x: rect.frame.midX, y: rect.frame.minY + 9))
                        if rect.frame.height > 36 {
                            let sizeText = Text(formatBytes(rect.node.size))
                                .font(.system(size: 9))
                                .foregroundStyle(label.opacity(0.85))
                            context.draw(sizeText, at: CGPoint(x: rect.frame.midX, y: rect.frame.minY + 21))
                        }
                    }
                }
            }
            .overlay {
                if let point = hoverPoint,
                   let rect = rects.first(where: { $0.id == hoverRectID }) {
                    tooltip(for: rect.node)
                        .padding(6)
                        .background(ThemeColors.shared(for: colorScheme).secondaryBG)
                        .cornerRadius(6)
                        .shadow(color: .black.opacity(0.2), radius: 3)
                        .position(x: min(point.x + 14, geo.size.width - 80),
                                  y: min(max(point.y, 24), geo.size.height - 24))
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoverPoint = location
                    // Children come after parents in the array and draw on top, so match deepest first
                    hoverRectID = rects.last(where: { $0.frame.insetBy(dx: 1, dy: 1).contains(location) })?.id
                case .ended:
                    hoverPoint = nil
                    hoverRectID = nil
                }
            }
            .onTapGesture { location in
                // Deepest rect under the cursor wins. A plain leaf promotes to its
                // containing folder; packages and folders drill via rescan
                if let rect = rects.last(where: { $0.frame.insetBy(dx: 1, dy: 1).contains(location) }) {
                    if rect.node.children.isEmpty && !rect.node.isAggregated && !rect.node.isPackage, rect.depth > 0,
                       let parent = rects.last(where: { $0.id != rect.id && $0.frame.insetBy(dx: 1, dy: 1).contains(location) && !$0.node.children.isEmpty && !$0.node.isAggregated }) {
                        onDrill(parent.node)
                    } else {
                        onDrill(rect.node)
                    }
                }
            }
            .contextMenu {
                if let rect = rects.first(where: { $0.id == hoverRectID }) {
                    contextMenu(for: rect.node)
                }
            }
            .id(drillGeneration)
        }
        .onChange(of: focusedNode.id) { _, newID in
            withAnimation(.easeInOut(duration: animationEnabled ? 0.25 : 0)) {
                drillGeneration = newID
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for node: SpaceLensNode) -> some View {
        Button {
            copyPath(node)
        } label: {
            Label(String(localized: "Copy Path"), systemImage: "doc.on.doc")
        }
        Button {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: node.url.path)
        } label: {
            Label(String(localized: "Reveal in Finder"), systemImage: "folder")
        }
        if !node.isProtected && !node.isAggregated && node.accessError == nil {
            Button(role: .destructive) {
                onTrash(node)
            } label: {
                Label(String(localized: "Move to Trash"), systemImage: "trash")
            }
        }
    }

    @ViewBuilder
    private func tooltip(for node: SpaceLensNode) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(node.name)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                .lineLimit(1)
            Text(node.accessError != nil
                 ? String(localized: "Access denied")
                 : (node.isProtected ? String(localized: "System protected") : formatBytes(node.size)))
                .font(.system(size: 10))
                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
        }
    }

    private func copyPath(_ node: SpaceLensNode) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(node.url.path, forType: .string)
    }
}
