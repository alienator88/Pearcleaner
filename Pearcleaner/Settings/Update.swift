//
//  Update.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//


import SwiftUI
import Foundation
import AlinFoundation

struct UpdateSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var updater: Updater
    @State private var showAlert = false
    @State private var showDone = false

    var body: some View {
        VStack {

            FrequencyView(updater: updater)
                .padding(5)
                .padding(.horizontal)

            ReleasesView(updater: updater)
                .frame(maxWidth: .infinity, maxHeight: 400)
                .backgroundAF(opacity: 0.5)
            
            
            HStack(alignment: .center, spacing: 20) {
                Spacer()
                
                Button(""){
                    updater.checkForUpdates(showSheet: false)
                }
                .buttonStyle(SimpleButtonStyle(icon: "arrow.uturn.left.circle", help: "Refresh updater"))

                Spacer()

                Button(""){
                    NewWin.show(appState: appState, width: 500, height: 440, newWin: .feature)
                }
                .buttonStyle(SimpleButtonStyle(icon: "star", help: "Show last feature alert"))

                Spacer()

//                Button(""){
//                    updater.checkForUpdates(showSheet: true)
//                }
//                .buttonStyle(SimpleButtonStyle(icon: "arrow.down.square", help: "Check for updates"))
//
//                Spacer()

                Button(""){
                    NSWorkspace.shared.open(URL(string: "https://github.com/alienator88/Pearcleaner/releases")!)
                }
                .buttonStyle(SimpleButtonStyle(icon: "link", help: "View releases on GitHub"))
                
                Spacer()
            }
            .padding()
            
        }
        .padding(20)
        .frame(width: 500)//, height: 520)
    }
    
}
