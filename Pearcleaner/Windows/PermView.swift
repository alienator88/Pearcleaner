//
//  PermView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/16/23.
//


import SwiftUI

struct PermView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack {
            HStack {
                
                Spacer()
                
                Text("Attention")
                    .font(.title)
                    .bold()
                    .padding(.vertical)
                
                Spacer()
                
            }
            .background(.red)
            
            Text("Pearcleaner requires the following permissions:")
                .font(.title3)
                .fontWeight(.semibold)
            //                .padding(.horizontal, 20)
                .padding(.vertical)
            //                .padding(.bottom)
            
            
            ScrollView {
                Text(" - Full Disk Access permission to find and delete files in non-user locations.\n - Accessibility permission to delete files via Finder which allows for the Undo function.\n\nAdd Pearcleaner in both Privacy panes via the + or by dragging the app over the pane. If the app is already pre-populated in the list, just toggle On. Restart app when both permissions are granted.")
                    .font(.body)
                    .multilineTextAlignment(.leading)
                    .padding(.horizontal, 20)
            }
            .frame(height: 130)
            .padding(.horizontal)
            
            Spacer()
            
            HStack {
                
                Button(action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("Full Disk Access")
                }
                .buttonStyle(WindowActionButton(action: .accept))
                .padding()
                
                Button(action: {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    Text("Accessibility")
                }
                .buttonStyle(WindowActionButton(action: .accept))
                .padding()
                
                Button(action: {
//                    NewWin.close
                    relaunchApp(afterDelay: 1)
                }) {
                    Text("Restart")
                }
                .buttonStyle(WindowActionButton(action: .cancel))
                .padding()
            }
            
            
        }
        .padding(EdgeInsets(top: -25, leading: 0, bottom: 25, trailing: 0))
        
        
        
    }
    
    
}


