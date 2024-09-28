//
//  IceGroupBox.swift
//  Pearcleaner
//
//  Created by Jordan Baird (Ice), slightly altered for Pearcleaner usage by Alin Lupascu on 9/27/24.
//
import SwiftUI

struct PearGroupBox<Header: View, Content: View, Footer: View>: View {
    private let header: Header
    private let content: Content
    private let footer: Footer
    private let padding: CGFloat

    /// Example usage:
    /// ```
    /// PearGroupBox(
    ///     header: { Text("Header View") },
    ///     content: { Text("Content View") },
    ///     footer: { Text("Footer View") }
    /// )
    /// ```
    init(
        padding: CGFloat = 10,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) {
        self.padding = padding
        self.header = header()
        self.content = content()
        self.footer = footer()
    }

    /// Example usage with no header:
    /// ```
    /// PearGroupBox(
    ///     content: { Text("Content View") },
    ///     footer: { Text("Footer View") }
    /// )
    /// ```
    init(
        padding: CGFloat = 10,
        @ViewBuilder content: () -> Content,
        @ViewBuilder footer: () -> Footer
    ) where Header == EmptyView {
        self.init(padding: padding) {
            EmptyView()
        } content: {
            content()
        } footer: {
            footer()
        }
    }

    /// Example usage with no footer:
    /// ```
    /// PearGroupBox(
    ///     header: { Text("Header View") },
    ///     content: { Text("Content View") }
    /// )
    /// ```
    init(
        padding: CGFloat = 10,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> Content
    ) where Footer == EmptyView {
        self.init(padding: padding) {
            header()
        } content: {
            content()
        } footer: {
            EmptyView()
        }
    }

    /// Example usage with content only:
    /// ```
    /// PearGroupBox {
    ///     Text("Content View Only")
    /// }
    /// ```
    init(
        padding: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) where Header == EmptyView, Footer == EmptyView {
        self.init(padding: padding) {
            EmptyView()
        } content: {
            content()
        } footer: {
            EmptyView()
        }
    }

    /// Example usage with a title and content only:
    /// ```
    /// PearGroupBox("Header Title") {
    ///     Text("Content View")
    /// }
    /// ```
    init(
        _ title: LocalizedStringKey,
        padding: CGFloat = 10,
        @ViewBuilder content: () -> Content
    ) where Header == Text, Footer == EmptyView {
        self.init(padding: padding) {
            Text(title)
                .font(.headline)
        } content: {
            content()
        }
    }

    var body: some View {
        VStack(alignment: .leading) {
            header
            content
                .padding(padding)
                .background {
                    backgroundShape
                        .fill(.quinary)
                        .overlay {
                            backgroundShape
                                .stroke(.quaternary)
                        }
                }
            footer
        }
    }

    @ViewBuilder
    private var backgroundShape: some Shape {
        RoundedRectangle(cornerRadius: 7, style: .circular)
    }
}
