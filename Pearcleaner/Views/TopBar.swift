//
//  TopBar.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/10/23.
//

import Foundation
import SwiftUI

struct TopBar: View {
    //    @Binding var sidebar: Bool
    @Binding var reload: Bool
    @AppStorage("displayMode") var displayMode: DisplayMode = .system
    @AppStorage("settings.general.glass") private var glass: Bool = false
    @AppStorage("settings.sentinel.enable") private var sentinel: Bool = false
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            
            Spacer()
            
            if appState.isReminderVisible {
                Text("CMD + Z to undo")
                    .font(.title2)
                    .foregroundStyle(Color("mode").opacity(0.5))
                    .fontWeight(.medium)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                            withAnimation {
                                appState.isReminderVisible = false
                            }
                        }
                    }
            }
            
            Spacer()
            
            if appState.currentView != .empty {
                Button("") {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        appState.currentView = .empty
                        appState.appInfo = AppInfo.empty
                    }
                }
                .buttonStyle(SimpleButtonStyle(icon: "house", help: "Home", color: Color("mode")))
            }
            
            
            
//            Spacer()
            
            
            
//            if sentinel {
//                Button("") {
//                    //
//                }
//                .buttonStyle(SimpleButtonStyle(icon: "lock.shield", help: "Sentinel enabled", color: .green, shield: true))
//            }
            
            
            
        }
        .padding(.horizontal, 5)
        .padding(.top, 10)
    }
}
