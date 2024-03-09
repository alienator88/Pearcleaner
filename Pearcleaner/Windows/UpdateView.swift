//
//  UpdateView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/16/23.
//


import SwiftUI

struct UpdateView: View {
    @EnvironmentObject var appState: AppState
    let isAppInAppsDir = isAppInApplicationsDir()
    
    var body: some View {
        VStack(spacing: 5) {
            HStack {
                
                Text("App: \(Bundle.main.version)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .opacity(0.5)
                    .padding()

                Spacer()
//                    .frame(width: appState.progressBar.1 != 1.0 ? 150 : 180)
                
                Text("\(appState.progressBar.1 != 1.0 ? "Update Available 🥳" : "Completed 🚀")")
                    .font(.title)
                    .bold()
                    .padding(.vertical)
                
                Spacer()
                
                Text("GitHub: \(appState.releases.first?.tag_name ?? "")")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .opacity(0.5)
                    .padding()
                
            }

            Divider()
                .padding([.horizontal])

            ScrollView {
                Text("\(appState.releases.first?.modifiedBody ?? "No release information")")
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .padding(20)
            }
            
            Spacer()
            
            if !isAppInAppsDir {
                Text("Please move Pearcleaner to the **Applications** folder before updating!")
                    .font(.callout)
                    .foregroundStyle(.red)
                    .padding(.top, 0)
            }
            
            VStack() {
                ProgressView("\(appState.progressBar.0)", value: appState.progressBar.1, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(height: 10)
            }
            .padding()
            
            
            HStack(alignment: .center, spacing: 20) {
                Button(action: NewWin.close) {
                    Text("Cancel")
                }
                .buttonStyle(SimpleButtonBrightStyle(icon: "x.circle", help: "Close", color: .red))
                
                if appState.progressBar.1 != 1.0 {
                    Button(action: {
                        downloadUpdate(appState: appState)
                    }) {
                        Text("Update")
                    }
                    .buttonStyle(SimpleButtonBrightStyle(icon: "arrow.down.circle", help: "Update", color: .accentColor))
                } else {
                    Button(action: {
                        NewWin.close()
                        relaunchApp(afterDelay: 1)
                    }) {
                        Text("Restart")
                    }
                    .buttonStyle(SimpleButtonBrightStyle(icon: "arrow.uturn.left.circle", help: "Restart", color: .accentColor))
                }
                
            }
            .padding(.bottom)
            
            
            
        }
        .padding(EdgeInsets(top: -25, leading: 0, bottom: 25, trailing: 0))

        
        
    }
    
    
}


struct NoUpdateView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(spacing: 5) {
            HStack {
                
                Text("App: \(Bundle.main.version)")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .opacity(0.5)
                    .padding()

                Spacer()
//                    .frame(width: appState.progressBar.1 != 1.0 ? 140 : 180)
                
                Text("\(appState.progressBar.1 != 1.0 ? "No Update 😌" : "Completed 🚀")")
                    .font(.title)
                    .bold()
                    .padding(.vertical)

                Spacer()
                
                Text("GitHub: \(appState.releases.first?.tag_name ?? "")")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .opacity(0.5)
                    .padding()
                
            }

//            Text("App: \(Bundle.main.version) | GitHub: \(appState.releases.first?.tag_name ?? "")")
//                .font(.title3)
//                .fontWeight(.semibold)
//                .opacity(0.5)
//                .padding(.vertical, 5)

            Divider()
                .padding([.horizontal])
            
            Text("Pearcleaner is on the most current release available, but you may force a re-download of the same version below.")
                .font(.body)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .padding()
            
            
            
            Spacer()
            
            VStack() {
                ProgressView("\(appState.progressBar.0)", value: appState.progressBar.1, total: 1.0)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .frame(height: 10)
            }
            .padding()
            
            HStack(alignment: .center, spacing: 20) {
                if appState.progressBar.1 < 0.1 {
                    Button(action: {
                        downloadUpdate(appState: appState)
                    }) {
                        Text("Force Update")
                    }
                    .buttonStyle(SimpleButtonBrightStyle(icon: "arrow.down.circle", help: "Force-Update", color: .red))

                    Button(action: {
                        NewWin.close()
                    }) {
                        Text("Okay")
                    }
                    .buttonStyle(SimpleButtonBrightStyle(icon: "checkmark.circle", help: "Ok", color: .accentColor))

                }
                
                
                if appState.progressBar.1 == 1.0 {
                    Button(action: {
                        NewWin.close()
                        relaunchApp()
                    }) {
                        Text("Restart")
                    }
                    .buttonStyle(SimpleButtonBrightStyle(icon: "arrow.uturn.left.circle", help: "Restart", color: .accentColor))
                }
            }
            .padding(.bottom)
            
            
            
        }
        .padding(EdgeInsets(top: -25, leading: 0, bottom: 25, trailing: 0))
        
        
    }
    
    
}

