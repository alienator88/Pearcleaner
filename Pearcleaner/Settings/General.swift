//
//  General.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//

import Foundation
import SwiftUI
//import FinderSync
import AlinFoundation
import UniformTypeIdentifiers

struct GeneralSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var themeManager: ThemeManager
    @AppStorage("settings.sentinel.enable") private var sentinel: Bool = false
    @AppStorage("settings.general.brew") private var brew: Bool = false
    @AppStorage("settings.general.oneshot") private var oneShotMode: Bool = false
    @AppStorage("settings.general.confirmAlert") private var confirmAlert: Bool = false
    @AppStorage("settings.general.selectedSort") var selectedSortAlpha: Bool = true
    @AppStorage("settings.general.sizeType") var sizeType: String = "Real"
//    @AppStorage("settings.general.brewTerminal") var brewTerm: String = "Terminal"
    @State private var isResetting = false
    @State private var isCLISymlinked = false

    var body: some View {
        VStack() {

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
                    .foregroundStyle(.primary.opacity(0.5))
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 0) {
                        Text("\(brew ? "Homebrew cleanup is enabled" : "Homebrew cleanup is disabled")")
                            .font(.callout)
                            .foregroundStyle(.primary.opacity(0.5))
                        InfoButton(text: "When homebrew cleanup is enabled, Pearcleaner will check if the app you are removing was installed via homebrew and launch Terminal.app to execute a brew uninstall and cleanup command to let homebrew know that the app is removed. This way your homebrew list will be synced up correctly and caching will be removed. Terminal.app is required since some apps need sudo permissions to remove services and files placed in system folders. Since other terminal apps don't support applescript and/or the 'do script' command, I opted to use the default macOS Terminal app for this.\n\nNOTE: If you undo the file delete with CMD+Z, the files will be put back but homebrew will not be aware of it. To get the homebrew list back in sync you'd need to run:\n brew install APPNAME --force")
                    }

//                    HStack(spacing: 0) {
//                        Text("Cleanup application: \(brewTerm)")
//                            .font(.footnote)
//                            .foregroundStyle(.primary.opacity(0.4))
//
//                        Button("") {
//                            selectBrewTerm()
//                        }
//                        .buttonStyle(SimpleButtonStyle(icon: "gear", help: "Set terminal application, right click to Reset", size: 14))
//                        .contextMenu{
//                            Button("Reset") {
//                                brewTerm = "Terminal"
//                            }
//                        }
//                    }

                }



                Spacer()
                Toggle(isOn: $brew, label: {
                })
                .toggleStyle(.switch)
            }
            .padding(5)
            .padding(.leading)


            HStack(spacing: 0) {
                Image(systemName: confirmAlert ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(.trailing)
                    .foregroundStyle(.primary.opacity(0.5))
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(confirmAlert ? "Confirmation alerts enabled" : "Confirmation alerts disabled")")
                        .font(.callout)
                        .foregroundStyle(.primary.opacity(0.5))
                }

                InfoButton(text: "When deleting files using the Trash button, you can prevent accidental deletions by showing an alert before proceeding with the action. Unrelated to the password prompt alert when deleting files in system folders.")

                Spacer()
                Toggle(isOn: $confirmAlert, label: {
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
                    .foregroundStyle(.primary.opacity(0.5))
                VStack(alignment: .leading, spacing: 5) {
                    Text("\(oneShotMode ? "One-Shot Mode is enabled" : "One-Shot Mode is disabled")")
                        .font(.callout)
                        .foregroundStyle(.primary.opacity(0.5))
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
                    .foregroundStyle(.primary.opacity(0.5))
                VStack(alignment: .leading, spacing: 5) {
                    Text("File list sorting mode")
                        .font(.callout)
                        .foregroundStyle(.primary.opacity(0.5))
                }
//                InfoButton(text: "When searching for app files or leftover files, the list will be sorted either alphabetically or by size(large to small)")
                Spacer()
                Picker("", selection: $selectedSortAlpha) {
                    Text("Alphabetical")
                        .tag(true)
                    Text("File Size")
                        .tag(false)
                }
                .buttonStyle(.borderless)
            }
            .padding(5)
            .padding(.leading)


            HStack(spacing: 0) {
                Image(systemName: "plus.forwardslash.minus")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(.trailing)
                    .foregroundStyle(.primary.opacity(0.5))
                VStack(alignment: .leading, spacing: 5) {
                    Text("File size display mode")
                        .font(.callout)
                        .foregroundStyle(.primary.opacity(0.5))
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
                .buttonStyle(.borderless)

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
                    .saturation(themeManager.displayMode.colorScheme == .dark ? 0.8 : 1)
                Text(sentinel ? "Detecting when apps are moved to Trash" : "**NOT** detecting when apps are moved to Trash")
                    .font(.callout)
                    .foregroundStyle(.primary.opacity(0.5))
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
                    .saturation(themeManager.displayMode.colorScheme == .dark ? 0.8 : 1)
                Text(appState.finderExtensionEnabled ? "Context menu extension for Finder is enabled" : "Context menu extension for Finder is disabled")
                    .font(.callout)
                    .foregroundStyle(.primary.opacity(0.5))
                InfoButton(text: "Enabling the extension will allow you to right click apps in Finder and quickly uninstall them with Pearcleaner")

                Spacer()

//                Button("Extensions") {
//                    FIFinderSyncController.showExtensionManagementInterface()
//                }
//                .buttonStyle(SimpleButtonStyle(icon: "folder", help: "Show Extensions Pane"))

                Toggle(isOn: $appState.finderExtensionEnabled, label: {
                })
                .toggleStyle(.switch)
                .onChange(of: appState.finderExtensionEnabled) { newValue in
                    if newValue {
                        manageFinderPlugin(install: true)
                    } else {
                        manageFinderPlugin(install: false)
                    }
                }


            }
            .padding(5)
            .padding(.leading)


            // === CLI =============================================================================================

            Divider()
                .padding()

            HStack() {
                Text("Command Line").font(.title2)
                Spacer()
            }
            .padding(.leading)

            HStack(spacing: 0) {
                Image(systemName: "terminal")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(.trailing)
                    .foregroundStyle(isCLISymlinked ? .green : .red)
                    .saturation(themeManager.displayMode.colorScheme == .dark ? 0.8 : 1)
                Text(isCLISymlinked ? "Pearcleaner CLI is installed" : "Pearcleaner CLI is **not** installed")
                    .font(.callout)
                    .foregroundStyle(.primary.opacity(0.5))
                InfoButton(text: "Enabling the CLI will allow you to execute Pearcleaner actions from the Terminal. This will add pearcleaner command into /usr/local/bin so it's available directly from your PATH environment variable. Try it after enabling:\n\n > pearcleaner --help")
                Spacer()

                Toggle(isOn: $isCLISymlinked, label: {
                })
                .toggleStyle(.switch)
                .onChange(of: isCLISymlinked) { newValue in
                    if newValue {
                        manageSymlink(install: true)
                    } else {
                        manageSymlink(install: false)
                    }
                }

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
            .padding(.vertical, 10)

            Spacer()

        }
        .onAppear {
            appState.updateExtensionStatus()
            isCLISymlinked = checkCLISymlink()
        }
        .padding(20)
        .frame(width: 500, height: 640)

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

//    private func selectBrewTerm() {
//        let dialog = NSOpenPanel()
//        dialog.title = "Select a Terminal application"
//        dialog.allowedContentTypes = [UTType("com.apple.application-bundle")!] // Limit to .app bundles
//        dialog.allowsMultipleSelection = false
//        dialog.canChooseFiles = true
//        dialog.canChooseDirectories = false
//
//        if dialog.runModal() == .OK, let url = dialog.url {
//            let appNameWithExtension = url.lastPathComponent
//            brewTerm = appNameWithExtension.replacingOccurrences(of: ".app", with: "")
//        }
//    }

}



