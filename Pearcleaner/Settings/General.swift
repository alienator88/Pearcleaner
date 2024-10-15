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
//    @AppStorage("settings.general.selectedSort") var selectedSortAlpha: Bool = true
    @AppStorage("settings.general.sizeType") var sizeType: String = "Real"
    @State private var isCLISymlinked = false

    var body: some View {
        VStack(spacing: 20) {

            // === Functionality ================================================================================================
            PearGroupBox(
                header: { Text("Functionality").font(.title2) },
                content: {
                    VStack {
                        HStack(spacing: 0) {
                            Image(systemName: brew ? "mug.fill" : "mug")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .padding(.trailing)
                                .foregroundStyle(.primary.opacity(1))
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 0) {
                                    Text("Homebrew cleanup after uninstall")
                                        .font(.callout)
                                        .foregroundStyle(.primary.opacity(1))
                                    InfoButton(text: String(localized: "When homebrew cleanup is enabled, Pearcleaner will check if the app you are removing was installed via homebrew and launch Terminal.app to execute a brew uninstall and cleanup command to let homebrew know that the app is removed. This way your homebrew list will be synced up correctly and caching will be removed. Terminal.app is required since some apps need sudo permissions to remove services and files placed in system folders. Since other terminal apps don't support applescript and/or the 'do script' command, I opted to use the default macOS Terminal app for this.\n\nNOTE: If you undo the file delete with CMD+Z, the files will be put back but homebrew will not be aware of it. To get the homebrew list back in sync you'd need to run:\n\n> brew install APPNAME --force"))
                                }

                            }



                            Spacer()
                            Toggle(isOn: $brew, label: {
                            })
                            .toggleStyle(.switch)
                        }
                        .padding(5)



                        HStack(spacing: 0) {
                            Image(systemName: confirmAlert ? "exclamationmark.triangle.fill" : "exclamationmark.triangle")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .padding(.trailing)
                                .foregroundStyle(.primary)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Uninstall confirmation alerts")
                                    .font(.callout)
                                    .foregroundStyle(.primary)
                            }

                            InfoButton(text: String(localized: "When deleting files using the Trash button, you can prevent accidental deletions by showing an alert before proceeding with the action."))

                            Spacer()
                            Toggle(isOn: $confirmAlert, label: {
                            })
                            .toggleStyle(.switch)
                        }
                        .padding(5)



                        HStack(spacing: 0) {
                            Image(systemName: oneShotMode ? "scope" : "circlebadge")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .padding(.trailing)
                                .foregroundStyle(.primary)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Close after uninstall")
                                    .font(.callout)
                                    .foregroundStyle(.primary)
                            }

                            InfoButton(text: String(localized: "When this mode is enabled, clicking the Uninstall button to remove an app will also close Pearcleaner right after.\nThis only affects Pearcleaner when it is opened via external means, like Sentinel Trash Monitor, Finder extension or a Deep Link.\nThis allows for single use of the app for a quick uninstall. When Pearcleaner is opened normally, this setting is ignored and will work as usual."))

                            Spacer()
                            Toggle(isOn: $oneShotMode, label: {
                            })
                            .toggleStyle(.switch)
                        }
                        .padding(5)



//                        HStack(spacing: 0) {
//                            Image(systemName: selectedSortAlpha ? "textformat.abc" : "textformat.123")
//                                .resizable()
//                                .scaledToFit()
//                                .frame(width: 20, height: 20)
//                                .padding(.trailing)
//                                .foregroundStyle(.primary)
//                            VStack(alignment: .leading, spacing: 5) {
//                                Text("File list sorting order")
//                                    .font(.callout)
//                                    .foregroundStyle(.primary)
//                            }
//                            Spacer()
//                            Picker("", selection: $selectedSortAlpha) {
//                                Text("Alphabetical")
//                                    .tag(true)
//                                Text("File Size")
//                                    .tag(false)
//                            }
//                            .buttonStyle(.borderless)
//                        }
//                        .padding(5)



                        HStack(spacing: 0) {
                            Image(systemName: "plus.forwardslash.minus")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .padding(.trailing)
                                .foregroundStyle(.primary)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("File size display options")
                                    .font(.callout)
                                    .foregroundStyle(.primary)
                            }
                            InfoButton(text: String(localized: "Real size type will show how much actual allocated space the file has on disk.\n\nLogical type shows the binary size. The filesystem can compress and deduplicate sectors on disk, so real size is sometimes smaller(or bigger) than logical size.\n\nFinder size is similar to if you right click > Get Info on a file in Finder, which will show both the logical and real sizes together."))
                            Spacer()
                            Picker("", selection: $sizeType) {
                                Text("Real")
                                    .tag("Real")
                                Text("Logical")
                                    .tag("Logical")
//                                Text("Finder")
//                                    .tag("Finder")
                            }
                            .buttonStyle(.borderless)

                        }
                        .padding(5)

                    }

                }
            )

            // === Sentinel =====================================================================================================
            PearGroupBox(
                header: { Text("Sentinel Monitor").font(.title2) },
                content: {
                    HStack(spacing: 0) {
                        Image(systemName: sentinel ? "eye.circle" : "eye.slash.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(.trailing)
                            .foregroundStyle(.primary)
//                            .saturation(themeManager.displayMode.colorScheme == .dark ? 0.8 : 1)
                        Text("Detect when apps are moved to Trash")
                            .font(.callout)
                            .foregroundStyle(.primary)
                        InfoButton(text: String(localized: "When applications are moved to Trash, Pearcleaner will launch and find related files and folders for deletion."))
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
            })

            // === Finder Extension =============================================================================================
            PearGroupBox(
                header: { Text("Finder Extension").font(.title2) },
                content: {
                    HStack(spacing: 0) {
                        Image(systemName: appState.finderExtensionEnabled ? "puzzlepiece.extension.fill" : "puzzlepiece.extension")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(.trailing)
                            .foregroundStyle(.primary)
//                            .saturation(themeManager.displayMode.colorScheme == .dark ? 0.8 : 1)
                        Text("Enable context menu extension for Finder")
                            .font(.callout)
                            .foregroundStyle(.primary)
                        InfoButton(text: String(localized: "Enabling this extension will allow you to right click apps in Finder to quickly uninstall them with Pearcleaner"))

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
            })

            // === CLI ==========================================================================================================
            PearGroupBox(
                header: { Text("Command Line").font(.title2) },
                content: {
                    HStack(spacing: 0) {
                        Image(systemName: "terminal")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(.trailing)
                            .foregroundStyle(.primary)
//                            .saturation(themeManager.displayMode.colorScheme == .dark ? 0.8 : 1)
                        Text("Pearcleaner CLI support")
                            .font(.callout)
                            .foregroundStyle(.primary)
                        InfoButton(text: String(localized: "Enabling the CLI will allow you to execute Pearcleaner actions from the Terminal. This will add pearcleaner command into /usr/local/bin so it's available directly from your PATH environment variable. Try it after enabling:\n\n> pearcleaner --help"))
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
            })

        }
        .onAppear {
            Task {
                appState.updateExtensionStatus()
                isCLISymlinked = checkCLISymlink()
            }

        }

    }

}
