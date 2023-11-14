//
//  General.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//

import Foundation
import SwiftUI

struct GeneralSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("settings.general.glass") private var glass: Bool = true
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.dark") var isDark: Bool = true
    @AppStorage("displayMode") var displayMode: DisplayMode = .dark

    var body: some View {
        Form {
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Transparency").font(.title2)
                        Text("Toggles the sidebar material on the app list drawer")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                    Toggle(isOn: $glass, label: {
                    })
                    .toggleStyle(.switch)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("mode").opacity(0.05))
                )
                
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Dark Mode").font(.title2)
                        Text("Toggles between dark and light mode")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                    Toggle(isOn: $isDark, label: {
                    })
                    .toggleStyle(.switch)
                    .onChange(of: isDark) { newValue in
                        displayMode.colorScheme = newValue ? .dark : .light
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("mode").opacity(0.05))
                )
                
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Mini").font(.title2)
                        Text("Toggles a smaller, unified view with hidden app list")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                    Toggle(isOn: $mini, label: {
                    })
                    .toggleStyle(.switch)
                    .onChange(of: mini) { newVal in
                            resizeWindow()
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("mode").opacity(0.05))
                )
                
                Spacer()
            }

        }
        .padding(20)
        .frame(width: 400, height: 250)
        
    }
    
}
