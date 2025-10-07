//
//  PackageDetailsSidebar.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/07/25.
//

import SwiftUI
import AlinFoundation

struct PackageDetailsSidebar: View {
    @Binding var drawerOpen: Bool
    let package: HomebrewSearchResult?
    let isCask: Bool
    let onClose: () -> Void

    var body: some View {
        if drawerOpen, let package = package {
            HStack(spacing: 0) {
                Spacer()

                PackageDetailsDrawer(
                    package: package,
                    isCask: isCask,
                    onClose: onClose
                )
//                .padding()
                .frame(width: 300)
                .ifGlassSidebar()
            }
            .background(.black.opacity(0.00000000001))
            .transition(.move(edge: .trailing))
            .onTapGesture {
                onClose()
            }
        }
    }
}
