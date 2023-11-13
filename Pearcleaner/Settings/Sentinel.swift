//
//  Sentinel.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/9/23.
//

import Foundation
import SwiftUI

struct SentinelSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("settings.sentinel.enable") private var sentinel: Bool = false
    
    var body: some View {
        Form {            
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Sentinel Monitor").font(.title2)
                            Text("Detects when apps are moved to Trash for file removal")
                                .font(.footnote)
                                .foregroundStyle(.gray)
                        }
                        Spacer()
                        Toggle(isOn: $sentinel, label: {
                        })
                        .toggleStyle(SentinelToggleStyle())
                        .onChange(of: sentinel) { newValue in
                            if newValue {
                                launchctl(load: true)
                            } else {
                                launchctl(load: false)
                            }
                        }
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color("mode").opacity(0.05))
                    )
                }

                
            
        }
        .padding(20)
        .frame(width: 450, height: 100)
        
    }
    
}
