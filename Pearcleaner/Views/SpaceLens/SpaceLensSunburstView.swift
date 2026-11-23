//
//  SpaceLensSunburstView.swift
//  Pearcleaner
//

import SwiftUI

struct SpaceLensSunburstView: View {
    let focusedNode: SpaceLensNode
    var maxRings: Int = 3
    let onDrill: (SpaceLensNode) -> Void
    let onTrash: (SpaceLensNode) -> Void

    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled = true
    @State private var hoverSegmentID: UUID?
    @State private var hoverPoint: CGPoint?
    @State private var drillGeneration: UUID?

    private var isDark: Bool { colorScheme == .dark }

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let maxRadius = min(geo.size.width, geo.size.height) / 2 - 4
            let ringWidth = (maxRadius * 0.78 - maxRadius * 0.22) / CGFloat(maxRings)
            let segments = SpaceLensLayout.sunburstSegments(node: focusedNode,
                                                            center: center,
                                                            maxRadius: maxRadius,
                                                            ringWidth: ringWidth,
                                                            maxRings: maxRings)

            Canvas { context, _ in
                // Center disk with the focused node summary
                let diskColor = ThemeColors.shared(for: colorScheme).secondaryBG
                var disk = Path()
                disk.addEllipse(in: CGRect(x: center.x - maxRadius * 0.20, y: center.y - maxRadius * 0.20,
                                           width: maxRadius * 0.40, height: maxRadius * 0.40))
                context.fill(disk, with: .color(diskColor))

                for segment in segments {
                    let color = SpaceLensLayout.color(hue: segment.hue, depth: segment.depth, isDark: isDark,
                                                        isError: segment.node.accessError != nil)
                    let isHovered = hoverSegmentID == segment.id
                    var path = Path()
                    // Sector path: outer arc forward, inner arc back, close. Gaps come from
                    // shrinking radii and angles slightly so sectors never touch.
                    path.addArc(center: center, radius: segment.outerR - 1,
                                startAngle: segment.start, endAngle: segment.end, clockwise: false)
                    path.addArc(center: center, radius: segment.innerR + 1,
                                startAngle: segment.end, endAngle: segment.start, clockwise: true)
                    path.closeSubpath()
                    context.fill(path, with: .color(isHovered ? color.opacity(0.8) : color))
                }

                let nameText = Text(focusedNode.name)
                    .font(.system(size: min(13, maxRadius * 0.09), weight: .semibold))
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                context.draw(nameText, at: CGPoint(x: center.x, y: center.y - maxRadius * 0.05))
                let sizeText = Text(formatBytes(focusedNode.size))
                    .font(.system(size: min(10, maxRadius * 0.07)))
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                context.draw(sizeText, at: CGPoint(x: center.x, y: center.y + maxRadius * 0.07))
            }
            .overlay {
                if let point = hoverPoint,
                   let segment = segments.first(where: { $0.id == hoverSegmentID }) {
                    tooltip(for: segment.node)
                        .padding(6)
                        .background(ThemeColors.shared(for: colorScheme).secondaryBG)
                        .cornerRadius(6)
                        .shadow(color: .black.opacity(0.2), radius: 3)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .offset(x: min(point.x + 16, geo.size.width - 200),
                                y: min(point.y + 20, geo.size.height - 64))
                        .allowsHitTesting(false)
                }
            }
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoverPoint = location
                    hoverSegmentID = SpaceLensLayout.segment(at: location, center: center, in: segments)?.id
                case .ended:
                    hoverPoint = nil
                    hoverSegmentID = nil
                }
            }
            .onTapGesture { location in
                if let segment = SpaceLensLayout.segment(at: location, center: center, in: segments) {
                    onDrill(segment.node)
                }
            }
            .contextMenu {
                if let segment = segments.first(where: { $0.id == hoverSegmentID }) {
                    contextMenu(for: segment.node)
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
