////
////  NoticeView.swift
////  Pearcleaner
////
////  Created by Alin Lupascu on 9/25/25.
////
//
//import SwiftUI
//import AlinFoundation
//
//struct NoticeView: View {
//    @EnvironmentObject var updater: Updater
//    @EnvironmentObject var permissionManager: PermissionManager
//    @State private var showUpdateView = false
//    @State private var showFeatureView = false
//    @State private var showPermissionList = false
//    @State private var glowRadius = 0.0
//
//    struct NoticeButton: View {
//        let imageName: String
//        let color: Color
//        let helpText: String
//        let action: () -> Void
//        let glowRadius: Double
//
//        var body: some View {
//            Button(action: action) {
//                VStack(spacing: 4) {
//                    Image(systemName: imageName)
//                        .font(.system(size: 16, weight: .medium))
//                        .foregroundColor(color)
//                }
//                .shadow(color: Color.black.opacity(0.3), radius: 3, x: 0, y: 2)
//                .shadow(color: color.opacity(0.6), radius: glowRadius, x: 0, y: 0)
//                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: glowRadius)
//            }
//            .buttonStyle(.plain)
//            .help(helpText)
//        }
//    }
//
//    var body: some View {
//        ZStack {
//            if updater.updateAvailable {
//                NoticeButton(imageName: "arrow.down.circle", color: .blue, helpText: "Update Available", action: {
//                    showUpdateView.toggle()
//                }, glowRadius: glowRadius)
//                .sheet(isPresented: $showUpdateView, content: {
//                    updater.getUpdateView()
//                })
//            } else if updater.announcementAvailable {
//                NoticeButton(imageName: "sparkles", color: .purple, helpText: "New Feature", action: {
//                    showFeatureView.toggle()
//                }, glowRadius: glowRadius)
//                .sheet(isPresented: $showFeatureView, content: {
//                    updater.getAnnouncementView()
//                })
//            } else if let _ = permissionManager.results, !permissionManager.allPermissionsGranted {
//                NoticeButton(imageName: "xmark.circle.fill", color: .red, helpText: "Permissions Missing", action: {
//                    showPermissionList.toggle()
//                }, glowRadius: glowRadius)
//                .sheet(isPresented: $showPermissionList) {
//                    PermissionsListView()
//                }
//            } else if HelperToolManager.shared.shouldShowHelperBadge {
//                NoticeButton(imageName: "key.fill", color: .orange, helpText: "Helper Not Installed", action: {
//                    openAppSettingsWindow(tab: .helper)
//                }, glowRadius: glowRadius)
//            }
//        }
//        .onAppear {
//            glowRadius = 8.0
//        }
//    }
//}
