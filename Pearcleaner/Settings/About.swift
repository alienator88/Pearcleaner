//
//  About.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//

import SwiftUI

struct AboutSettingsTab: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        
        VStack {
            
            HStack(alignment: .center) {
                VStack(alignment: .center, spacing: 10){
                    Spacer()
                    
                    Image(nsImage: NSApp.applicationIconImage)
                        .padding()
//                        .padding(.bottom, 5)
                    
                    HStack(alignment: .center, spacing: 20) {
                        Button("") {
                            loadGithubReleases(appState: appState, manual: true)
                        }
                        .buttonStyle(SimpleButtonStyle(icon: "cloud", help: "Update application", color: Color("AccentColor")))
                        
                        Button("") {
                            NSWorkspace.shared.open(URL(string: "https://github.com/ghosted-labs/Pearcleaner")!)
                        }
                        .buttonStyle(SimpleButtonStyle(icon: "paperplane", help: "View repository", color: Color("AccentColor")))
                    }
                    
                    Spacer()
                    
                    
                }
//                .padding()
                //                .padding(.top, 10)
                .frame(width: 250)
                
                VStack(alignment: .center, spacing: 20) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(Bundle.main.name)
                            .font(.title)
                            .bold()
                        Spacer()
                        HStack {
                            Text("v\(Bundle.main.version)")
                            Text(" (build \(Bundle.main.buildVersion))")
                        }
                        
                    }
                    Divider()
                        .padding(.top, -8)
                    
                    VStack(alignment: .leading) {
                        
                        HStack{
                            Image(systemName: "applescript.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                            
                            VStack(alignment: .leading){
                                Text("Privacy Guides")
                                Text("Inspired by open-source appcleaner script from Sun Knudsen").font(.footnote).foregroundStyle(.gray)
                                
                            }
                            Spacer()
                            
                            Button("") {
                                NSWorkspace.shared.open(URL(string: "https://sunknudsen.com/privacy-guides/how-to-clean-uninstall-macos-apps-using-appcleaner-open-source-alternative")!)
                            }
                            .buttonStyle(SimpleButtonStyle(icon: "paperplane", help: "View", color: Color("AccentColor")))

                        }
                        .padding()
                        .background(Color("mode").opacity(0.05))
                        .cornerRadius(8)
                        
                        
                        HStack{
                            Image(systemName: "trash.fill")
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 16, height: 16)
                            
                            VStack(alignment: .leading){
                                Text("AppCleaner")
                                Text("Inspired by AppCleaner from Freemacsoft").font(.footnote).foregroundStyle(.gray)
                                
                            }
                            Spacer()
                            Button(""){
                                NSWorkspace.shared.open(URL(string: "https://freemacsoft.net/appcleaner/")!)
                            }
                            .buttonStyle(SimpleButtonStyle(icon: "paperplane", help: "View", color: Color("AccentColor")))

                        }
                        .padding()
                        .background(Color("mode").opacity(0.05))
                        .cornerRadius(8)
                        
                        
//                        HStack{
//                            Image(systemName: "paintbrush.fill")
//                                .resizable()
//                                .aspectRatio(contentMode: .fit)
//                                .frame(width: 16, height: 16)
//                            VStack(alignment: .leading){
//                                Text("Icon")
//                                Text("Created by Oviotti on DeviantArt").font(.footnote).foregroundStyle(.gray)
//                            }
//                            Spacer()
//                            
//                            Button("") {
//                                NSWorkspace.shared.open(URL(string: "https://www.deviantart.com/oviotti/art/AppCleaner-for-macOS-632260251")!)
//                            }
//                            .buttonStyle(SimpleButtonStyle(icon: "paperplane", help: "View", color: Color("AccentColor")))
//                            
//                        }
//                        .padding()
//                        .background(Color("mode").opacity(0.05))
//                        .cornerRadius(8)
                        
                    }
                    
                    Spacer()
                    
                }
                .padding(.trailing)
//                .padding()
//                .padding(.top, 30)
            }
            
            Spacer()
            
            Text("Made with ❤️ by Alin Lupascu").font(.footnote).padding(.bottom)
        }
        .padding(20)
        .frame(width: 750, height: 325)
        
    }
}



extension Bundle {
    
    var name: String {
        func string(for key: String) -> String? {
            object(forInfoDictionaryKey: key) as? String
        }
        return string(for: "CFBundleDisplayName")
        ?? string(for: "CFBundleName")
        ?? "N/A"
    }
    
    var version: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
    }
    
    var buildVersion: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
    }
    
}

