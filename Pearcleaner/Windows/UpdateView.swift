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
        VStack {
            HStack {
                
                Spacer()
                    .frame(width: appState.progressBar.1 != 1.0 ? 150 : 180)
                
                Text("\(appState.progressBar.1 != 1.0 ? "Update Available 🥳" : "Completed 🚀")")
                    .font(.title)
                    .bold()
                    .padding(.vertical)
                
                Spacer()
                
                Text("v\(appState.releases.first?.tag_name ?? "")")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding()
                
            }
            .background(.blue)
            
            Spacer()
            
            ScrollView {
                Text("\(appState.releases.first?.body ?? "No release information")")
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 20)
            }
            .frame(height: 160)
            .padding()
            
            Spacer()
            
            if !isAppInAppsDir {
                HStack {
                    Text("Pearcleaner not in /Applications directory. Updater could have permission issues updating files.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .padding()
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                

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
                .buttonStyle(WindowActionButton(action: .cancel))
                
                if appState.progressBar.1 != 1.0 {
                    Button(action: {
                        downloadUpdate(appState: appState)
                    }) {
                        Text("Update")
                    }
                    .buttonStyle(WindowActionButton(action: .accept))
                } else {
                    Button(action: {
                        NewWin.close()
                        relaunchApp(afterDelay: 1)
                    }) {
                        Text("Restart")
                    }
                    .buttonStyle(WindowActionButton(action: .accept))
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
        VStack {
            HStack {
                
                Spacer()
                    .frame(width: appState.progressBar.1 != 1.0 ? 140 : 180)
                
                Text("\(appState.progressBar.1 != 1.0 ? "No Update Available 😌" : "Completed 🚀")")
                    .font(.title)
                    .bold()
                    .padding(.vertical)
                
                Spacer()
                
                Text("v\(appState.releases.first?.tag_name ?? "")")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.white.opacity(0.5))
                    .padding()
                
            }
            .background(.blue)
            
            Spacer()
            
            Text("Pearcleaner is on the most current release available, but you may force a re-download of the same version below.")
                .font(.body)
                .lineLimit(3)
                .multilineTextAlignment(.leading)
                .padding(20)
            
            
            
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
                    .buttonStyle(WindowActionButton(action: .cancel))
                    
                    Button(action: {
                        NewWin.close()
                    }) {
                        Text("Okay")
                    }
                    .buttonStyle(WindowActionButton(action: .accept))
                    
                }
                
                
                if appState.progressBar.1 == 1.0 {
                    Button(action: {
                        NewWin.close()
                        relaunchApp()
                    }) {
                        Text("Restart")
                    }
                    .buttonStyle(WindowActionButton(action: .accept))
                }
            }
            .padding(.bottom)
            
            
            
        }
        .padding(EdgeInsets(top: -25, leading: 0, bottom: 25, trailing: 0))
        
        
        
    }
    
    
}

