//
//  ControlGroupChrome.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 8/8/25.
//

import SwiftUI

public enum ControlGroupLevel: Int {
    case primary
    case secondary
}

public struct ControlGroupMetrics {
    static let primaryGroupRadius: Double = 14
    static let secondaryGroupRadius: Double = 8
}

public extension ControlGroupLevel {
    var cornerRadius: Double {
        switch self {
        case .primary: ControlGroupMetrics.primaryGroupRadius
        case .secondary: ControlGroupMetrics.secondaryGroupRadius
        }
    }
}

public extension View {
    func controlGroup(level: ControlGroupLevel = .primary) -> some View {
        modifier(ControlGroupChrome(level: level, shapeBuilder: {
            RoundedRectangle(cornerRadius: level.cornerRadius, style: .continuous)
        }))
    }

    func controlGroup<S>(_ shape: S, level: ControlGroupLevel = .primary) -> some View where S: InsettableShape {
        modifier(ControlGroupChrome<S>(level: level, shapeBuilder: { shape }))
    }
}

private struct ControlGroupChrome<Shape: InsettableShape>: ViewModifier {
    @Environment(\.colorScheme)
    private var colorScheme

    var level: ControlGroupLevel
    var shapeBuilder: () -> Shape

    var dark: Bool { colorScheme == .dark }

    private var innerRimOpacity: Double {
        switch level {
        case .primary:
            return dark ? 0.15 : 0
        case .secondary:
            return dark ? 0.1 : 0
        }
    }

    private var outerRimOpacity: Double {
        switch level {
        case .primary:
            return dark ? 0.5 : 0.8
        case .secondary:
            return dark ? 0.4 : 0.7
        }
    }

    private var shadowOpacity: Double {
        switch level {
        case .primary:
            return dark ? 0.2 : 0.1
        case .secondary:
            return dark ? 0.1 : 0.05
        }
    }

    private var material: Material {
        switch level {
        case .primary:
            return .thin
        case .secondary:
            return .regular
        }
    }

    func body(content: Content) -> some View {
        content
            .background(material, in: shape)
            .clipShape(shape)
            .shadow(color: Color.black.opacity(outerRimOpacity), radius: 1, x: 0, y: 0)
            .shadow(color: Color.black.opacity(shadowOpacity), radius: dark ? 8 : 10, x: 0, y: 0)
            .chromeBorder(shape: shape, highlightEnabled: true, rimEnabled: false, shadowEnabled: false, highlightIntensity: innerRimOpacity)
            .containerShape(shape)
    }

    private var shape: Shape {
        shapeBuilder()
    }
}
