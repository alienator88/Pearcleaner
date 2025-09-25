//
//  NoticeView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 9/25/25.
//

import SwiftUI
import AlinFoundation

struct NoticeView: View {
    @EnvironmentObject var updater: Updater
    @EnvironmentObject var permissionManager: PermissionManager
    @State private var showUpdateView = false
    @State private var showFeatureView = false
    @State private var showPermissionList = false
    @State private var glowRadius = 0.0

    var body: some View {
        ZStack {
            if updater.updateAvailable {
                Button {
                    showUpdateView.toggle()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                    }
                    .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
                    .shadow(color: Color.blue, radius: glowRadius, x: 0, y: 0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: glowRadius)
                }
                .buttonStyle(.plain)
                .help("Update Available")
                .sheet(isPresented: $showUpdateView, content: {
                    updater.getUpdateView()
                })
            } else if updater.announcementAvailable {
                Button {
                    showFeatureView.toggle()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.purple)
                    }
                    .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
                    .shadow(color: Color.purple, radius: glowRadius, x: 0, y: 0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: glowRadius)
                }
                .buttonStyle(.plain)
                .help("New Feature")
                .sheet(isPresented: $showFeatureView, content: {
                    updater.getAnnouncementView()
                })
            } else if let _ = permissionManager.results, !permissionManager.allPermissionsGranted {
                Button {
                    showPermissionList.toggle()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.red)
                    }
                    .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
                    .shadow(color: Color.red.opacity(0.6), radius: glowRadius, x: 0, y: 0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: glowRadius)
                }
                .buttonStyle(.plain)
                .help("Permissions Missing")
                .sheet(isPresented: $showPermissionList) {
                    PermissionsListView()
                }
            } else if HelperToolManager.shared.shouldShowHelperBadge {
                Button {
                    openAppSettingsWindow(tab: .helper)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "key.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.orange)
                    }
                    .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
                    .shadow(color: Color.orange.opacity(0.6), radius: glowRadius, x: 0, y: 0)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: glowRadius)
                }
                .buttonStyle(.plain)
                .help("Helper Not Installed")
                
            }
        }
        .onAppear {
            glowRadius = 8.0
        }
    }
}
