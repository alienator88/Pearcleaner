//
//  General.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//

import Foundation
import SwiftUI
import ServiceManagement
import FinderSync

struct GeneralSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @State private var windowSettings = WindowSettings()
    @AppStorage("settings.general.glass") private var glass: Bool = true
    @AppStorage("settings.general.mini") private var mini: Bool = false
    @AppStorage("settings.general.dark") var isDark: Bool = true
    @AppStorage("settings.general.popover") private var popoverStay: Bool = true
    @AppStorage("settings.general.miniview") private var miniView: Bool = true
    @AppStorage("settings.general.sidebarWidth") private var sidebarWidth: Double = 280
    @AppStorage("displayMode") var displayMode: DisplayMode = .system
    @AppStorage("settings.sentinel.enable") private var sentinel: Bool = false
    @AppStorage("settings.general.brew") private var brew: Bool = false
    @AppStorage("settings.general.selectedSort") var selectedSortAlpha: Bool = true
    @AppStorage("settings.general.sizeType") var sizeType: String = "Real"
    @State private var diskStatus: Bool = false
    @State private var accessStatus: Bool = false
    @Binding var showPopover: Bool
    @Binding var search: String

    @State var selectedIndex: Int?

    var body: some View {
        Form {
            VStack {

                HStack() {
                    Text("Functionality").font(.title2)
                    Spacer()
                }
                .padding(.leading)


                HStack(spacing: 0) {
                    Image(systemName: brew ? "mug.fill" : "mug")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(Color("mode").opacity(0.5))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(brew ? "Homebrew cleanup is enabled" : "Homebrew cleanup is disabled")")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))
                    }

                    InfoButton(text: "When homebrew cleanup is enabled, Pearcleaner will check if the app you are removing was installed via homebrew and execute a brew uninstall and brew cleanup command as well to let homebrew know that the app is removed. This way your homebrew list will be synced up correctly and caching will be removed.\n\nNOTE: If you undo the file delete with CMD+Z, the files will be put back but homebrew will not be aware of it. To get the homebrew list back in sync you'd need to run:\n brew install APPNAME --force", color: nil, label: "")

                    Spacer()
                    Toggle(isOn: $brew, label: {
                    })
                    .toggleStyle(.switch)
                }
                .padding(5)
                .padding(.leading)


                HStack(spacing: 0) {
                    Image(systemName: selectedSortAlpha ? "textformat.abc" : "textformat.123")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(Color("mode").opacity(0.5))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("File list sorting mode")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))
                    }
                    InfoButton(text: "When searching for app files or leftover files, the list will be sorted either alphabetically or by size(large to small)", color: nil, label: "")
                    Spacer()
                    SegmentedPicker(
                        ["Alpha", "Size"],
                        selectedIndex: Binding(
                            get: { selectedSortAlpha ? 0 : 1 },
                            set: { newIndex in
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    selectedSortAlpha = (newIndex == 0)
                                }
                            }),
                        selectionAlignment: .bottom,
                        content: { item, isSelected in
                            Text(item)
                                .font(.callout)
                                .foregroundColor(isSelected ? Color("mode") : Color("mode").opacity(0.5))
                                .padding(.horizontal)
                                .padding(.bottom, 5)
                                .frame(width: 75)

                        },
                        selection: {
                            VStack(spacing: 0) {
                                Spacer()
                                Color("pear").frame(height: 1)
                            }
                        })
                }
                .padding(5)
                .padding(.leading)


                HStack(spacing: 0) {
                    Image(systemName: "plus.forwardslash.minus")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(Color("mode").opacity(0.5))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("File size display")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))
                    }
                    InfoButton(text: "Real size type will show how much actual allocated space the file has on disk. Logical type shows the binary size. The filesystem can compress and deduplicate sectors on disk, so real size is sometimes smaller(or bigger) than logical size. Finder size is similar to if you right click > Get Info on a file in Finder, which will show both the logical and real sizes together.", color: nil, label: "")
                    Spacer()
                    SegmentedPicker(
                        ["Real", "Logical", "Finder"],
                        selectedIndex: Binding(
                            get: {
                                switch sizeType {
                                case "Real": return 0
                                case "Logical": return 1
                                case "Finder": return 2
                                default: return 0
                                }
                            },
                            set: { newIndex in
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    switch newIndex {
                                    case 0: sizeType = "Real"
                                    case 1: sizeType = "Logical"
                                    case 2: sizeType = "Finder"
                                    default: sizeType = "Real"
                                    }
                                }
                            }),
                        selectionAlignment: .bottom,
                        content: { item, isSelected in
                            Text(item)
                                .font(.callout)
                                .foregroundColor(isSelected ? Color("mode") : Color("mode").opacity(0.5) )
                                .padding(.horizontal)
                                .padding(.bottom, 5)
                                .frame(width: 75)
                        },
                        selection: {
                            VStack(spacing: 0) {
                                Spacer()
                                Color("pear").frame(height: 1)
                            }
                        })
                }
                .padding(5)
                .padding(.leading)


                // === Perms ================================================================================================


                Divider()
                    .padding()




                HStack() {
                    Text("Permissions").font(.title2)
                    Spacer()
                }
                .padding(.leading)

                HStack(spacing: 0) {
                    Image(systemName: diskStatus ? "externaldrive" : "externaldrive")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(diskStatus ? .green : .red)
                        .saturation(displayMode.colorScheme == .dark ? 0.5 : 1)
                    Text(diskStatus ? "Full Disk permission granted" : "Full Disk permission **NOT** granted")
                        .font(.callout)
                        .foregroundStyle(Color("mode").opacity(0.5))
                    Spacer()

                    Button("") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "folder", help: "View disk permissions pane"))

                }
                .padding(5)
                .padding(.leading)


                HStack(spacing: 0) {
                    Image(systemName: accessStatus ? "accessibility" : "accessibility")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(accessStatus ? .green : .red)
                        .saturation(displayMode.colorScheme == .dark ? 0.5 : 1)
                    Text(accessStatus ? "Accessibility permission granted" : "Accessibility permission **NOT** granted")
                        .font(.callout)
                        .foregroundStyle(Color("mode").opacity(0.5))
                    Spacer()

                    Button("") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "folder", help: "View accessibility permissions pane"))

                }
                .padding(5)
                .padding(.leading)


                // === Sentinel =============================================================================================

                Divider()
                    .padding()

                HStack() {
                    Text("Sentinel Monitor").font(.title2)
                    Spacer()
                }
                .padding(.leading)

                HStack(spacing: 0) {
                    Image(systemName: sentinel ? "eye.circle" : "eye.slash.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(sentinel ? .green : .red)
                        .saturation(displayMode.colorScheme == .dark ? 0.5 : 1)
                    Text(sentinel ? "Detecting when apps are moved to Trash" : "**NOT** detecting when apps are moved to Trash")
                        .font(.callout)
                        .foregroundStyle(Color("mode").opacity(0.5))
                    Spacer()

                    Toggle(isOn: $sentinel, label: {
                    })
                    .toggleStyle(.switch)
                    .onChange(of: sentinel) { newValue in
                        if newValue {
                            launchctl(load: true)
                        } else {
                            launchctl(load: false)
                        }
                    }

                }
                .padding(5)
                .padding(.leading)



                // === Finder Extension =============================================================================================

                Divider()
                    .padding()

                HStack() {
                    Text("Finder Extension").font(.title2)
                    Spacer()
                }
                .padding(.leading)

                HStack(spacing: 0) {
                    Image(systemName: appState.finderExtensionEnabled ? "puzzlepiece.extension.fill" : "puzzlepiece.extension")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(appState.finderExtensionEnabled ? .green : .red)
                    Text(appState.finderExtensionEnabled ? "Context menu extension for Finder is enabled" : "Context menu extension for Finder is disabled")
                        .font(.callout)
                        .foregroundStyle(Color("mode").opacity(0.5))
                    InfoButton(text: "Enabling the extension will allow you to right click apps in Finder and quickly uninstall them with Pearcleaner", color: nil, label: "")

                    Spacer()

                    Button("Extensions") {
                        FIFinderSyncController.showExtensionManagementInterface()
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "folder", help: "Show Extensions Pane"))


                }
                .padding(5)
                .padding(.leading)








                Spacer()
            }
            .onAppear {
                diskStatus = checkAndRequestFullDiskAccess(appState: appState, skipAlert: true)
                accessStatus = checkAndRequestAccessibilityAccess(appState: appState)
                appState.updateExtensionStatus()
            }

        }
        .padding(20)
        .frame(width: 500, height: 570)

    }
    
}
