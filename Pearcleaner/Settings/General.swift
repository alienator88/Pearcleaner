//
//  General.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//

import Foundation
import SwiftUI

struct GeneralSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @AppStorage("settings.general.glass") private var glass: Bool = true
//    @AppStorage("settings.general.ants") private var ants: Bool = false
    
    var body: some View {
        Form {
            VStack {
                HStack {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Transparency").font(.title2)
                        Text("Toggles the sidebar material on the app list drawer")
                            .font(.footnote)
                            .foregroundStyle(.gray)
                    }
                    Spacer()
                    Toggle(isOn: $glass, label: {
                    })
                    .toggleStyle(.switch)
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color("mode").opacity(0.05))
                )
                
//                HStack {
//                    VStack(alignment: .leading, spacing: 5) {
//                        Text("Animation").font(.title2)
//                        Text("Toggles the marching ants animation on the drop zone")
//                            .font(.footnote)
//                            .foregroundStyle(.gray)
//                    }
//                    Spacer()
//                    Toggle(isOn: $ants, label: {
//                    })
//                    .toggleStyle(.switch)
//                }
//                .padding()
//                .background(
//                    RoundedRectangle(cornerRadius: 8)
//                        .fill(Color("mode").opacity(0.05))
//                )
                
                Spacer()
            }

        }
        .padding(20)
        .frame(width: 400, height: 100)
        
    }
    
}
