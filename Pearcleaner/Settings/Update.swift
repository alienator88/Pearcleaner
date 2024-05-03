//
//  Update.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//


import SwiftUI
import Foundation

struct UpdateSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @State private var showAlert = false
    @State private var showDone = false
    @AppStorage("settings.updater.updateTimeframe") private var updateTimeframe: Int = 1
    @Binding var showFeature: Bool

    var body: some View {
        VStack {
            
            HStack {
                Text("Check for updates every ") +
                Text("**\(updateTimeframe)**").foregroundColor(.red) +
                Text(updateTimeframe == 1 ? " day" : " days")
                Stepper(value: $updateTimeframe, in: 1...7) {
                    Text("")
                }
            }
            
            ScrollView {
                VStack() {
                    ForEach(appState.releases, id: \.id) { release in
                        VStack(alignment: .leading) {
                            LabeledDivider(label: "\(release.tag_name)")
                            Text(release.modifiedBody)
                        }
                        
                    }
                }
                .padding()
            }
            .frame(minHeight: 0, maxHeight: .infinity)
            .frame(minWidth: 0, maxWidth: .infinity)
            .padding()
            
            Text("Showing last 3 releases")
                .font(.callout)
                .foregroundStyle(Color("mode").opacity(0.5))

            
            
            HStack(alignment: .center, spacing: 20) {
                Spacer()
                
                Button(""){
                    loadGithubReleases(appState: appState)
                }
                .buttonStyle(SimpleButtonStyle(icon: "arrow.uturn.left.circle", help: "Reload release notes"))

                Spacer()

                Button(""){
                    showFeature.toggle()
                }
                .buttonStyle(SimpleButtonStyle(icon: "star", help: "Show last feature alert"))

                Spacer()

                Button(""){
                    loadGithubReleases(appState: appState, manual: true)
                }
                .buttonStyle(SimpleButtonStyle(icon: "arrow.down.square", help: "Check for updates"))

                Spacer()

                Button(""){
                    NSWorkspace.shared.open(URL(string: "https://github.com/alienator88/Pearcleaner/releases")!)
                }
                .buttonStyle(SimpleButtonStyle(icon: "link", help: "View releases on GitHub"))
                
                Spacer()
            }
            .padding()
            
            
            
        }
        .padding(20)
        .frame(width: 500, height: 520)
    }
    
}
