//
//  ChromeBorder.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 8/8/25.
//

import SwiftUI

extension View {
    func chromeBorder(
        radius: CGFloat,
        highlightEnabled: Bool = true,
        rimEnabled: Bool = true,
        shadowEnabled: Bool = true,
        highlightIntensity: Double = 0.5,
        placeholderAnimationEnabled: Bool = true
    ) -> some View {
        chromeBorder(
            shape: RoundedRectangle(cornerRadius: radius, style: .continuous),
            highlightEnabled: highlightEnabled,
            rimEnabled: rimEnabled,
            shadowEnabled: shadowEnabled,
            highlightIntensity: highlightIntensity,
            placeholderAnimationEnabled: placeholderAnimationEnabled
        )
    }

    func chromeBorder<BorderShape: InsettableShape>(
        shape: BorderShape,
        highlightEnabled: Bool = true,
        rimEnabled: Bool = true,
        shadowEnabled: Bool = true,
        highlightIntensity: Double = 0.5,
        placeholderAnimationEnabled: Bool = true
    ) -> some View {
        modifier(ChromeBorderModifier(
            shape: shape,
            highlightEnabled: highlightEnabled,
            rimEnabled: rimEnabled,
            shadowEnabled: shadowEnabled,
            highlightIntensity: highlightIntensity,
            placeholderAnimationEnabled: placeholderAnimationEnabled
        ))
    }
}

private struct ChromeBorderModifier<BorderShape: InsettableShape>: ViewModifier {
    var shape: BorderShape
    var highlightEnabled = true
    var rimEnabled = true
    var shadowEnabled = true
    var highlightIntensity = 0.5
    var placeholderAnimationEnabled = true

    @State private var animate = false

    @Environment(\.redactionReasons)
    private var redaction

    func body(content: Content) -> some View {
        content
            .shadow(color: .black.opacity(shadowEnabled ? 0.2 : 0), radius: 6, x: 0, y: 0)
            .shadow(color: .black.opacity(rimEnabled ? 0.5 : 0), radius: 1, x: 0, y: 0)
            .overlay {
                if highlightEnabled {
                    ZStack {
                        shape
                            .strokeBorder(Color.white, lineWidth: 1)

                        LinearGradient(colors: [.white.opacity(0.4), .white.opacity(0.7)], startPoint: .top, endPoint: .bottom)
                            .blendMode(.destinationOut)
                    }
                    .compositingGroup()
                    .blendMode(.plusLighter)
                    .opacity(highlightIntensity)
                }
            }
            .overlay {
                if placeholderAnimationEnabled, !redaction.isEmpty {
                    LinearGradient(colors: [.white.opacity(0), .white.opacity(0.5), .white.opacity(0.6), .white.opacity(0.5), .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                        .scaleEffect(x: animate ? 1 : 2, anchor: .trailing)
                        .scaleEffect(x: animate ? 2 : 1, anchor: .leading)
                        .clipShape(shape)
                        .blendMode(.plusLighter)
                        .opacity(0.2)
                }
            }
            .task(id: placeholderAnimationEnabled && !redaction.isEmpty) {
                if placeholderAnimationEnabled, !redaction.isEmpty {
                    withAnimation(.easeInOut(duration: 5).repeatForever()) {
                        animate.toggle()
                    }
                }
            }
    }
}
