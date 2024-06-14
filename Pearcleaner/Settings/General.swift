//
//  General.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//

import Foundation
import SwiftUI
//import ServiceManagement
import FinderSync

struct GeneralSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var themeSettings: ThemeSettings
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
    @AppStorage("settings.general.oneshot") private var oneShotMode: Bool = false
    @AppStorage("settings.general.selectedSort") var selectedSortAlpha: Bool = true
    @AppStorage("settings.general.sizeType") var sizeType: String = "Real"
    @State private var diskStatus: Bool = false
    @State private var accessStatus: Bool = false
    @State private var autoStatus: Bool = false
    @Binding var showPopover: Bool
    @Binding var search: String
    @State var selectedIndex: Int?
    @State private var isResetting = false

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

                    InfoButton(text: "When homebrew cleanup is enabled, Pearcleaner will check if the app you are removing was installed via homebrew and execute a brew uninstall and brew cleanup command as well to let homebrew know that the app is removed. This way your homebrew list will be synced up correctly and caching will be removed.\n\nNOTE: If you undo the file delete with CMD+Z, the files will be put back but homebrew will not be aware of it. To get the homebrew list back in sync you'd need to run:\n brew install APPNAME --force")

                    Spacer()
                    Toggle(isOn: $brew, label: {
                    })
                    .toggleStyle(.switch)
                }
                .padding(5)
                .padding(.leading)


                HStack(spacing: 0) {
                    Image(systemName: oneShotMode ? "scope" : "circlebadge")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(Color("mode").opacity(0.5))
                    VStack(alignment: .leading, spacing: 5) {
                        Text("\(oneShotMode ? "One-Shot Mode is enabled" : "One-Shot Mode is disabled")")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))
                    }

                    InfoButton(text: "When one-shot mode is enabled, clicking the Uninstall button to remove an app will also close Pearcleaner right after. This only affects Pearcleaner when it is opened via external means, like Sentinel Trash Monitor or the Finder extension. This allows for single use of the app, AKA one-shot mode. When Pearcleaner is opened normally, this setting is ignored and will work as usual.")

                    Spacer()
                    Toggle(isOn: $oneShotMode, label: {
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
                    InfoButton(text: "When searching for app files or leftover files, the list will be sorted either alphabetically or by size(large to small)")
                    Spacer()
                    Picker("", selection: $selectedSortAlpha) {
                        Text("Alpha")
                            .tag(true)
                        Text("Size")
                            .tag(false)
                    }
                    .pickerStyle(themeSettings: themeSettings)
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
                        Text("File size display mode")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))
                    }
                    InfoButton(text: "Real size type will show how much actual allocated space the file has on disk. Logical type shows the binary size. The filesystem can compress and deduplicate sectors on disk, so real size is sometimes smaller(or bigger) than logical size. Finder size is similar to if you right click > Get Info on a file in Finder, which will show both the logical and real sizes together.")
                    Spacer()
                    Picker("", selection: $sizeType) {
                        Text("Real")
                            .tag("Real")
                        Text("Logical")
                            .tag("Logical")
                        Text("Finder")
                            .tag("Finder")
                    }
                    .pickerStyle(themeSettings: themeSettings)


                }
                .padding(5)
                .padding(.leading)


                // === Perms ================================================================================================


                Divider()
                    .padding()




                HStack() {
                    Text("Permissions").font(.title2)

                    InfoButtonPerms()

                    Spacer()

                    Button("Refresh") {
                        checkAllPermissions(appState: appState) { results in
                            updateOnMain {
                                appState.permissionResults = results
                            }
                            diskStatus = results.fullDiskAccess
                            accessStatus = results.accessibility
                            autoStatus = results.automation
                            if results.allPermissionsGranted {
                                updateOnMain {
                                    appState.permissionsOkay = true
                                }
                            }
                        }
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "arrow.triangle.2.circlepath", label: "Refresh", help: "Refresh permissions"))
                    .padding(.trailing, 5)

                }
                .padding(.leading)


                HStack(spacing: 0) {
                    Image(systemName: "externaldrive")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(diskStatus ? .green : .red)
                        .saturation(displayMode.colorScheme == .dark ? 0.8 : 1)
                    Text(diskStatus ? "Full Disk permission granted" : "Full Disk permission not granted")
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

                Spacer()


                HStack(spacing: 0) {
                    Image(systemName: "accessibility")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(accessStatus ? .green : .red)
                        .saturation(displayMode.colorScheme == .dark ? 0.8 : 1)
                    Text(accessStatus ? "Accessibility permission granted" : "Accessibility permission not granted")
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

                Spacer()

                HStack(spacing: 0) {
                    Image(systemName: "gearshape.2")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)
                        .foregroundStyle(autoStatus ? .green : .red)
                        .saturation(displayMode.colorScheme == .dark ? 0.8 : 1)
                    Text(autoStatus ? "Automation permission granted" : "Automation permission not granted")
                        .font(.callout)
                        .foregroundStyle(Color("mode").opacity(0.5))

                    Spacer()

                    Button("") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "folder", help: "View automation permissions pane"))

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
                        .saturation(displayMode.colorScheme == .dark ? 0.8 : 1)
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
                        .saturation(displayMode.colorScheme == .dark ? 0.8 : 1)
                    Text(appState.finderExtensionEnabled ? "Context menu extension for Finder is enabled" : "Context menu extension for Finder is disabled")
                        .font(.callout)
                        .foregroundStyle(Color("mode").opacity(0.5))
                    InfoButton(text: "Enabling the extension will allow you to right click apps in Finder and quickly uninstall them with Pearcleaner")

                    Spacer()

                    Button("Extensions") {
                        FIFinderSyncController.showExtensionManagementInterface()
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "folder", help: "Show Extensions Pane"))


                }
                .padding(5)
                .padding(.leading)

                // === Reset Settings =============================================================================================

                HStack() {
                    Spacer()

                    Button("") {
                        resetUserDefaults()
                    }
                    .buttonStyle(ResetSettingsButtonStyle(isResetting: $isResetting, label: "Reset Settings", help: "Reset all app settings to default"))
                    .disabled(isResetting)

                    Spacer()
                }
                .padding(.vertical, 5)






                Spacer()
            }
            .onAppear {
                checkAllPermissions(appState: appState) { results in
                    updateOnMain {
                        appState.permissionResults = results
                    }
                    diskStatus = results.fullDiskAccess
                    accessStatus = results.accessibility
                    autoStatus = results.automation
                    if results.allPermissionsGranted {
                        updateOnMain {
                            appState.permissionsOkay = true
                        }
                    }
                }
                appState.updateExtensionStatus()
            }

        }
        .padding(20)
        .frame(width: 500, height: 710)

    }

    private func resetUserDefaults() {
        isResetting = true
        DispatchQueue.global(qos: .background).async {
            UserDefaults.standard.dictionaryRepresentation().keys.forEach(UserDefaults.standard.removeObject(forKey:))
            DispatchQueue.main.async {
                isResetting = false
            }
        }
    }

}



