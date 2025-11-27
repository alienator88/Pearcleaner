//
//  CircularProgressView.swift
//  Pearcleaner
//
//  Circular progress indicator with thick stroke that fills clockwise
//  Created by Alin Lupascu on 11/20/25
//

import SwiftUI
import AlinFoundation

struct CircularProgressView: View {
    let progress: Double // 0.0 to 1.0
    let size: CGFloat
    let lineWidth: CGFloat
    let badgeText: String? // Optional badge overlay text (e.g., "3/5")

    @Environment(\.colorScheme) var colorScheme

    init(progress: Double, size: CGFloat, lineWidth: CGFloat, badgeText: String? = nil) {
        self.progress = progress
        self.size = size
        self.lineWidth = lineWidth
        self.badgeText = badgeText
    }

    private var accent: Color {
        ThemeColors.shared(for: colorScheme).accent
    }

    private var secondaryText: Color {
        ThemeColors.shared(for: colorScheme).secondaryText
    }

    var body: some View {
        ZStack {
            // Background circle (full ring)
            Circle()
                .stroke(secondaryText.opacity(0.3), lineWidth: lineWidth)

            // Progress circle (fills clockwise from top)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(accent, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90)) // Start from top
                .animation(.linear(duration: 0.3), value: progress)

            // Optional badge text overlay
            if let badgeText = badgeText {
                Text(badgeText)
                    .font(.system(size: size * 0.35, weight: .medium))
                    .foregroundStyle(secondaryText)
            }
        }
        .frame(width: size, height: size)
    }
}
