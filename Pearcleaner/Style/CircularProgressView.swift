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

    @Environment(\.colorScheme) var colorScheme

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
        }
        .frame(width: size, height: size)
    }
}
