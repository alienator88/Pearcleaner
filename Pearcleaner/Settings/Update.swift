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
    @EnvironmentObject var themeSettings: ThemeSettings
    @State private var showAlert = false
    @State private var showDone = false
    @AppStorage("settings.updater.nextUpdateDate") private var nextUpdateDate = Date.now.timeIntervalSinceReferenceDate
    @AppStorage("settings.updater.updateFrequency") private var updateFrequency: UpdateFrequency = .daily

    var body: some View {
        VStack {

                VStack {
                    HStack(spacing: 0) {

                        Text("Pearcleaner will check for updates")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))

                        Spacer()

                        Picker("", selection: $updateFrequency) {
                            ForEach(UpdateFrequency.allCases, id: \.self) { frequency in
                                Text(frequency.rawValue).tag(frequency)
                            }
                        }
                        .onChange(of: updateFrequency) { frequency in
                            frequency.updateNextUpdateDate()
                        }
                        .pickerStyle(themeSettings: themeSettings)
                    }

                    if updateFrequency != .none {
                        HStack {
                            Text("Next update check: \(formattedDate(Date(timeIntervalSinceReferenceDate: nextUpdateDate)))")
                                .font(.footnote)
                                .foregroundStyle(Color("mode").opacity(0.3))
                            Spacer()
                        }
                    }
                }
                .padding(5)
                .padding(.horizontal)

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
//            .background(Color("mode").opacity(0.05))
            .background(backgroundView(themeSettings: themeSettings, darker: true))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.bottom)

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
                    NewWin.show(appState: appState, width: 500, height: 440, newWin: .feature)
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
