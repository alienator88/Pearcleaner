//
//  SidebarDetailLayout.swift
//  Pearcleaner
//
//  Created as a reusable layout component extracted from MainWindow applicationsView
//

import SwiftUI

struct SidebarDetailLayout<Sidebar: View, Detail: View>: View {
    @ViewBuilder let sidebar: () -> Sidebar
    @ViewBuilder let detail: () -> Detail

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            // Sidebar content
            sidebar()
                .transition(.opacity)

            // Detail content
            HStack(spacing: 0) {
                Group {
                    detail()
                }
                .transition(.opacity)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .zIndex(2)
        }
    }
}
