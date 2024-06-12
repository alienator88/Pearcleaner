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
    @AppStorage("settings.updater.nextUpdateDate") private var nextUpdateDate = Date.now.timeIntervalSinceReferenceDate
    @AppStorage("settings.updater.updateTimeframe") private var updateTimeframe: Int = 1
    @AppStorage("settings.updater.enableUpdates") private var enableUpdates: Bool = true

    var body: some View {
        VStack {

            HStack(spacing: 0) {
                Image(systemName: "arrow.down.square")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(.trailing)
                    .foregroundStyle(Color("mode").opacity(0.5))

                VStack {
                    HStack(spacing: 0) {
                        Text("\(enableUpdates ? "Pearcleaner will check for updates every " : "Automatic updates are disabled")")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))

                        if enableUpdates {
                            Text("**\(updateTimeframe)**").font(.system(.callout, design: .monospaced)).monospacedDigit()
                            Text(updateTimeframe == 1 ? " day" : " days")
                                .font(.callout)
                                .foregroundStyle(Color("mode").opacity(0.5))

                            Stepper("", value: $updateTimeframe, in: 0...30)
                                .onChange(of: updateTimeframe, perform: { _ in
                                    updateNextUpdateDate()
                                })
                        }
                        Spacer()
                    }

                    if enableUpdates {
                        HStack {
                            Text("Next update check: \(formattedDate(Date(timeIntervalSinceReferenceDate: nextUpdateDate)))")
                                .font(.footnote)
                                .foregroundStyle(Color("mode").opacity(0.3))
                            Spacer()
                        }
                    }



                }

                Spacer()
                Toggle(isOn: $enableUpdates, label: {
                })
                .toggleStyle(.switch)
            }
            .padding(5)
            .padding(.leading)

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
//        .onAppear {
//            // Convert TimeInterval to Date on appearance
//            let _ = Date(timeIntervalSinceReferenceDate: nextUpdateDate)
//        }
    }
    
}
