//
//  Permissions.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//

import Foundation
import SwiftUI

struct PermissionsSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @State private var diskStatus: Bool = false
    @State private var accessStatus: Bool = false
    
    
    
    var body: some View {
        Form {
            VStack(alignment: .leading, spacing: 10) {
                
                HStack(spacing: 15) {
                    Image(systemName: "internaldrive")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Full Disk")
                        Text(diskStatus ? "Permission granted" : "Permission not granted")
                            .font(.footnote)
                            .foregroundStyle(diskStatus ? .green : .red)
                    }
                    
                    Spacer()
                    
                    Button("") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "paperplane", help: "View disk permission pane", color: Color("AccentColor")))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("mode").opacity(0.05))
                )
                
                
                HStack(spacing: 15) {
                    Image(systemName: "accessibility")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Accessibility")
                        Text(accessStatus ? "Permission granted" : "Permission not granted")
                            .font(.footnote)
                            .foregroundStyle(accessStatus ? .green : .red)
                    }
                    
                    Spacer()
                    
                    Button("") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "paperplane", help: "View accessibility pane", color: Color("AccentColor")))
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("mode").opacity(0.05))
                )
                
                

//                HStack(alignment: .center) {
//                    Spacer()
//                    Button("") {
//                        relaunchApp()
//                    }
//                    .buttonStyle(SimpleButtonStyle(icon: "restart", help: "Restart application", color: Color("AccentColor")))
//                    Text("Restart")
//                    Spacer()
//                }
//                .padding()
                
                
            }
  
        }
        .padding(20)
        .frame(width: 400, height: 200)
        .onAppear {
            diskStatus = checkAndRequestFullDiskAccess(appState: appState, skipAlert: true)
            accessStatus = checkAndRequestAccessibilityAccess(appState: appState)
        }
    }
    
}
