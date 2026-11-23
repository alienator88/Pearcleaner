//
//  SpaceLensLayout.swift
//  Pearcleaner
//

import SwiftUI

// Pure layout helpers shared by both visualizations. Aggregation happens here so the
// full tree stays untouched in the model.
enum SpaceLensLayout {

    // Nodes below the top 12 children per parent are rolled into one "Other" node,
    // otherwise full-disk scans produce thousands of unreadable slivers.
    static let aggregationLimit = 12
    static let otherLabel = String(localized: "Other")

    static func aggregate(_ children: [SpaceLensNode]) -> [SpaceLensNode] {
        guard children.count > aggregationLimit else { return children }
        let top = Array(children.prefix(aggregationLimit))
        let rest = children.dropFirst(aggregationLimit)
        let restSize = rest.reduce(Int64(0)) { $0 + $1.size }
        // Virtual node: parent URL + isAggregated so it reveals and never trashes a real path.
        // Its ID appends a marker so it never collides with the parent's path-derived ID
        let parentURL = top[0].url.deletingLastPathComponent()
        return top + [SpaceLensNode(id: SpaceLensNode.stableID(forPath: parentURL.path + "\u{0}aggregated"),
                                    url: parentURL,
                                    name: otherLabel,
                                    size: restSize,
                                    isAggregated: true)]
    }

    // MARK: Squarified treemap (Bruls, Huizing, van Wijk)

    struct TreeMapRect: Identifiable {
        let id: UUID
        let node: SpaceLensNode
        let frame: CGRect
        let depth: Int
        let hue: Double
        let isOther: Bool
    }

    static func treemapRects(node: SpaceLensNode, in rect: CGRect, depth: Int = 0, maxDepth: Int = 3,
                             inheritedHue: Double? = nil) -> [TreeMapRect] {
        guard node.size > 0, rect.width > 1, rect.height > 1 else { return [] }

        // Aggregated children have no subtree, they draw as one flat tile
        let children = node.isAggregated ? [] : aggregate(node.children).filter { $0.size > 0 }
        guard !children.isEmpty else {
            let hue = inheritedHue ?? hue(of: node)
            return [TreeMapRect(id: node.id, node: node, frame: rect, depth: depth, hue: hue, isOther: node.isAggregated)]
        }

        let childFrames = squarify(weights: children.map { Double($0.size) }, in: rect)
        var rects: [TreeMapRect] = []
        for (index, child) in children.enumerated() {
            guard index < childFrames.count else { break }
            let frame = childFrames[index]
            // Siblings at the top level keep distinct hues; inside a nested preview
            // every level inherits the tile hue so contents read as one color family
            let childHue = inheritedHue ?? hue(of: child)
            rects.append(TreeMapRect(id: child.id, node: child, frame: frame,
                                     depth: depth, hue: childHue, isOther: child.isAggregated))
            if depth < maxDepth - 1 && child.size > node.size / 40 && !child.isAggregated && !child.children.isEmpty {
                // Nested levels sit inside a ring of the parent's own color, with a
                // header band left for the parent label, so the parent reads as a
                // containing box rather than being fully covered by its children
                let inner = insetForNested(frame)
                if inner.width > 12, inner.height > 12 {
                    rects.append(contentsOf: treemapRects(node: child, in: inner, depth: depth + 1, maxDepth: maxDepth,
                                                         inheritedHue: childHue))
                }
            }
        }
        return rects
    }

    // 8pt sides/bottom ring plus a label band at the top; shrinks
    // proportionally for small tiles so tiny parents keep a visible rim
    private static func insetForNested(_ rect: CGRect) -> CGRect {
        let ring = min(8, rect.width / 3, rect.height / 3)
        // Name draws at +9 and size at +21, so tall tiles get a band that
        // clears both lines; short tiles fall back to a proportional band
        let band = rect.height > 36 ? min(26, rect.height / 2) : min(18, rect.height / 2)
        return CGRect(x: rect.minX + ring, y: rect.minY + band,
                      width: rect.width - 2 * ring, height: rect.height - ring - band)
    }

    // Children sorted descending, rows filled along the shorter side, picking the row
    // split that minimizes the worst aspect ratio.
    static func squarify(weights: [Double], in rect: CGRect) -> [CGRect] {
        guard !weights.isEmpty else { return [] }
        let sorted = weights.sorted(by: >)
        let total = sorted.reduce(0, +)
        guard total > 0 else { return [] }
        let scale = Double(rect.width * rect.height) / total

        var rects: [CGRect] = []
        var remaining = rect
        var i = 0

        while i < sorted.count, remaining.width > 0, remaining.height > 0 {
            let horizontal = remaining.width >= remaining.height
            let shorter = horizontal ? Double(remaining.height) : Double(remaining.width)
            let longer = horizontal ? Double(remaining.width) : Double(remaining.height)
            guard shorter > 0 else { break }

            // Row thickness runs along the longer side, entries divide the shorter side
            var row: [Int] = []
            var bestWorst = Double.infinity

            while i < sorted.count {
                let candidate = row + [i]
                let area = candidate.reduce(0.0) { $0 + sorted[$1] * scale }
                let strip = min(area / shorter, longer)
                let worst = candidate.map { idx -> Double in
                    let len = sorted[idx] * scale / strip
                    return max(strip / len, len / strip)
                }.max() ?? .infinity
                if worst > bestWorst, !row.isEmpty { break }
                bestWorst = worst
                row = candidate
                i += 1
            }

            if row.isEmpty { row = [i]; i += 1 }

            let area = row.reduce(0.0) { $0 + sorted[$1] * scale }
            let strip = CGFloat(min(area / shorter, longer))

            var offset: CGFloat = 0
            for idx in row {
                let len = CGFloat(sorted[idx] * scale / area * shorter)
                if horizontal {
                    rects.append(CGRect(x: remaining.minX, y: remaining.minY + offset,
                                        width: strip, height: len))
                    offset += len
                } else {
                    rects.append(CGRect(x: remaining.minX + offset, y: remaining.minY,
                                        width: len, height: strip))
                    offset += len
                }
            }

            if horizontal {
                remaining = CGRect(x: remaining.minX + strip, y: remaining.minY,
                                   width: remaining.width - strip, height: remaining.height)
            } else {
                remaining = CGRect(x: remaining.minX, y: remaining.minY + strip,
                                   width: remaining.width, height: remaining.height - strip)
            }
        }

        return rects
    }

    // MARK: Sunburst

    struct SunburstSegment: Identifiable {
        let id: UUID
        let node: SpaceLensNode
        let start: Angle
        let end: Angle
        let innerR: CGFloat
        let outerR: CGFloat
        let depth: Int
        let hue: Double
        let isOther: Bool
    }

    // Rings below the focused node, count follows the levels setting; angles proportional to
    // size within each ring.
    static func sunburstSegments(node: SpaceLensNode, center: CGPoint, maxRadius: CGFloat,
                                 ringWidth: CGFloat, maxRings: Int = 3,
                                 baseAngle: Angle = .degrees(-90)) -> [SunburstSegment] {
        var segments: [SunburstSegment] = []

        func layoutChildren(_ children: [SpaceLensNode], start: Angle, span: Angle,
                            depth: Int, innerR: CGFloat) {
            let ringChildren = node.isAggregated ? [] : aggregate(children).filter { $0.size > 0 }
            let total = ringChildren.reduce(Int64(0)) { $0 + $1.size }
            guard total > 0 else { return }
            let outer = innerR + ringWidth
            var cursor = start
            for child in ringChildren {
                let childSpan = Angle(radians: span.radians * Double(child.size) / Double(total))
                // Sector drawn clockwise from start; angles normalized at hit-test time
                segments.append(SunburstSegment(id: child.id, node: child,
                                               start: cursor, end: cursor + childSpan,
                                               innerR: innerR, outerR: outer,
                                               depth: depth,
                                               hue: hue(of: child),
                                               isOther: child.isAggregated))
                if depth < maxRings - 1 && !child.isAggregated && !child.children.isEmpty {
                    layoutChildren(child.children, start: cursor, span: childSpan,
                                   depth: depth + 1, innerR: outer)
                }
                cursor = cursor + childSpan
            }
        }

        layoutChildren(node.children, start: baseAngle, span: .degrees(360), depth: 0, innerR: maxRadius * 0.22)
        return segments
    }

    // Angular containment is cheaper than per-segment Path testing with thousands of sectors.
    static func segment(at point: CGPoint, center: CGPoint, in segments: [SunburstSegment]) -> SunburstSegment? {
        let dx = point.x - center.x
        let dy = point.y - center.y
        let r = (dx * dx + dy * dy).squareRoot()
        var theta = atan2(dy, dx)
        if theta < 0 { theta += 2 * .pi }

        return segments.first { seg in
            guard r >= seg.innerR, r < seg.outerR else { return false }
            let start = normalize(seg.start.radians)
            let end = normalize(seg.end.radians)
            // A span of a full turn normalizes to start == end; the sector covers everything
            if abs(end - start) < 1e-9 {
                return true
            }
            if start <= end {
                return theta >= start && theta < end
            }
            // Segment wraps across the 0 axis
            return theta >= start || theta < end
        }
    }

    private static func normalize(_ radians: Double) -> Double {
        var value = radians
        while value < 0 { value += 2 * .pi }
        while value >= 2 * .pi { value -= 2 * .pi }
        return value
    }

    // MARK: Colors

    // Stable hue from the path so a folder keeps its color across rescans and modes.
    static func hue(of node: SpaceLensNode) -> Double {
        if node.accessError != nil {
            return 0.0
        }
        var hash: UInt64 = 1469598103934665603
        for byte in node.url.path.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return Double(hash % 360) / 360.0
    }

    // Tiles at one level get distinct hues; tiles nested inside a parent inherit its
    // hue and lighten with depth, so a parent's contents read as one color family and
    // the box-in-box hierarchy stays visible.
    static func color(hue: Double, depth: Int, isDark: Bool, isError: Bool = false) -> Color {
        if isError {
            return Color(red: 0.78, green: 0.22, blue: 0.22)
        }
        let (brightness, saturation) = tileValueSaturation(depth: depth, isDark: isDark)
        return Color(hue: hue, saturation: saturation, brightness: brightness)
    }

    // HSV of the tile fill at (hue, depth, scheme). labelColor consumes it to compute
    // WCAG luminance; tests use it to verify the contrast decision per hue sector.
    static func tileHSV(hue: Double, depth: Int, isDark: Bool) -> (v: Double, s: Double) {
        let step = Double(depth)
        let lightness = isDark
            ? 0.60 - step * 0.05
            : 0.52 - step * 0.05
        let saturation = isDark ? 0.42 - step * 0.04 : 0.52 - step * 0.04
        return (min(max(lightness + 0.25, 0.35), 0.85), max(saturation, 0.18))
    }

    private static func tileValueSaturation(depth: Int, isDark: Bool) -> (Double, Double) {
        tileHSV(hue: 0, depth: depth, isDark: isDark)
    }

    // Label color picked from the tile's own WCAG luminance: black on light tiles,
    // white on dark ones. 0.179 is the tie point where both contrast ratios meet, so
    // whichever side wins keeps the 9-10pt canvas text above AA in both schemes.
    static func labelColor(hue: Double, depth: Int, isDark: Bool, isError: Bool = false) -> Color {
        if isError {
            return .white
        }
        let (v, s) = tileValueSaturation(depth: depth, isDark: isDark)
        let c = s * v
        let hp = hue * 6
        let x = c * (1 - abs(hp.truncatingRemainder(dividingBy: 2) - 1))
        let m = v - c
        let rgb: (Double, Double, Double)
        switch Int(hp) {
        case 0: rgb = (c, x, 0)
        case 1: rgb = (x, c, 0)
        case 2: rgb = (0, c, x)
        case 3: rgb = (0, x, c)
        case 4: rgb = (x, 0, c)
        default: rgb = (c, 0, x)
        }
        func channel(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let red = channel(rgb.0 + m), green = channel(rgb.1 + m), blue = channel(rgb.2 + m)
        let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
        return luminance > 0.179 ? .black : .white
    }
}
