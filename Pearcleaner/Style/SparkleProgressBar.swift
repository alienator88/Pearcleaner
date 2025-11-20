//
//  SparkleProgressBar.swift
//  Pearcleaner
//
//  Animated sparkle progress bar with twinkle effects
//  Created by Alin Lupascu on 10/24/2025
//

import SwiftUI

struct SparkleProgressBar: View {
    let maxWidth: CGFloat
    let progress: Double
    let height: CGFloat
    let source: UpdateSource

    @Environment(\.colorScheme) var colorScheme
    @State private var sparkles: [SparkleConfig] = []

    /// Get icon names based on update source
    private var iconNames: [String] {
        switch source {
        case .appStore:
            return ["cart", "cart.fill", "storefront", "storefront.fill"]
        case .sparkle:
            return ["star", "star.fill", "sparkle", "sparkles", "sparkles.2"]
        case .homebrew, .unsupported, .current:
            return ["star", "star.fill", "sparkle", "sparkles", "sparkles.2"]
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            // Background fill (full width)
            Rectangle()
                .fill(ThemeColors.shared(for: colorScheme).accent.opacity(0.3))
                .frame(width: maxWidth, height: height)

            // Sparkle overlay (full width, all pre-positioned)
            ZStack {
                ForEach(sparkles) { sparkle in
                    SparkleView(config: sparkle, colorScheme: colorScheme)
                }
            }
            .frame(width: maxWidth, height: height)
        }
        // Mask reveals progress from left to right
        .mask(
            HStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white)
                    .frame(width: maxWidth * progress)
                Spacer(minLength: 0)
            }
        )
        .onAppear {
            // Generate sparkles only once when view first appears
            if sparkles.isEmpty {
                let count = max(3, Int(maxWidth / 25))
                sparkles = (0..<count).map { index in
                    let xPosition = CGFloat.random(in: 0...maxWidth)
                    return SparkleConfig(
                        id: UUID(),
                        xPosition: xPosition,
                        yPosition: height * CGFloat.random(in: 0.0...1.0),
                        size: CGFloat.random(in: 5...15),
                        baseOpacity: Double.random(in: 0.15...0.4),
                        animationDelay: Double(index) * 0.15,
                        iconName: iconNames.randomElement() ?? iconNames.first ?? "star",
                        movementRange: CGFloat.random(in: 3...8)
                    )
                }
            }
        }
    }
}

// Individual sparkle configuration
private struct SparkleConfig: Identifiable {
    let id: UUID
    let xPosition: CGFloat
    let yPosition: CGFloat
    let size: CGFloat
    let baseOpacity: Double
    let animationDelay: Double
    let iconName: String
    let movementRange: CGFloat
}

// Individual animated sparkle
private struct SparkleView: View {
    let config: SparkleConfig
    let colorScheme: ColorScheme

    @State private var isAnimating = false
    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0

    var body: some View {
        Image(systemName: config.iconName)
            .font(.system(size: config.size))
            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
            .opacity(isAnimating ? config.baseOpacity + 0.3 : config.baseOpacity)
            .position(
                x: config.xPosition + offsetX,
                y: config.yPosition + offsetY
            )
            .task {
                // Start animation with delay as phase offset
                try? await Task.sleep(nanoseconds: UInt64(config.animationDelay * 1_000_000_000))

                // Fast opacity twinkle
                withAnimation(
                    .easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true)
                ) {
                    isAnimating = true
                }

                // Slow random drift movement
                withAnimation(
                    .easeInOut(duration: Double.random(in: 2...4))
                    .repeatForever(autoreverses: true)
                ) {
                    offsetX = CGFloat.random(in: -config.movementRange...config.movementRange)
                    offsetY = CGFloat.random(in: -config.movementRange...config.movementRange)
                }
            }
    }
}
