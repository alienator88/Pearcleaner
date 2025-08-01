//
//  General.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//

import Foundation
import SwiftUI
import FinderSync
import AlinFoundation
import UniformTypeIdentifiers

struct GeneralSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @AppStorage("settings.sentinel.enable") private var sentinel: Bool = false
    @AppStorage("settings.general.brew") private var brew: Bool = false
    @AppStorage("settings.general.oneshot") private var oneShotMode: Bool = false
    @AppStorage("settings.general.confirmAlert") private var confirmAlert: Bool = false
    @AppStorage("settings.general.sizeType") var sizeType: String = "Real"
    @AppStorage("settings.general.cli") private var isCLISymlinked = false
    @AppStorage("settings.general.namesearchstrict") private var nameSearchStrict = false
    @AppStorage("settings.general.spotlight") private var spotlight = false
    @AppStorage("settings.general.permanentDelete") private var permanentDelete: Bool = false

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
                                    InfoButton(text: String(localized: "When Homebrew cleanup is enabled, Pearcleaner will check if the app you are removing was installed via Homebrew and launch a built-in Terminal to execute a brew uninstall and cleanup command to let Homebrew know that the app is removed. This way your Homebrew list will be synced up correctly and caching will be removed.\n\nNOTE: If you undo the file delete with CMD+Z, the files will be put back but Homebrew will not be aware of it. To get the Homebrew list back in sync you'd need to run:\n\n> brew install APPNAME --force"))
                                }

                            }



                            Spacer()
                            Toggle(isOn: $brew, label: {
                            })
                            .toggleStyle(SettingsToggle())
                        }
                        .padding(5)



                        HStack(spacing: 0) {
                            Image(systemName: nameSearchStrict ? "lock.fill" : "lock.open.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .padding(.trailing)
                                .foregroundStyle(.primary)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Strict app name search")
                                    .font(.callout)
                                    .foregroundStyle(.primary)
                            }

                            InfoButton(text: String(localized: "When searching for related application files, strict will check that the app name matches the found file exactly. Strict disabled will check if the app name is contained in the found file name. This can be useful when searching for multiple versions of the same app, or when searching for files that are not named after the app name. Strict disabled will likely find more files, but some unrelated as well, so make sure you check/uncheck the needed files."))

                            Spacer()
                            Toggle(isOn: $nameSearchStrict, label: {
                            })
                            .toggleStyle(SettingsToggle())
                        }
                        .padding(5)



                        HStack(spacing: 0) {
                            Image(systemName: spotlight ? "text.magnifyingglass" : "magnifyingglass")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .padding(.trailing)
                                .foregroundStyle(.primary)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Search Spotlight index")
                                    .font(.callout)
                                    .foregroundStyle(.primary)
                            }

                            InfoButton(text: String(localized: "The search algorithm will cross-check the Spotlight metadata index for matches. This can be useful for fuzzy name searches and directories missed by the standard search. This will likely find a lot more unrelated files if the file names are very short or generic."))

                            Spacer()
                            Toggle(isOn: $spotlight, label: {
                            })
                            .toggleStyle(SettingsToggle())
                        }
                        .padding(5)


                        HStack(spacing: 0) {
                            Image(systemName: permanentDelete ? "trash.slash" : "trash")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .padding(.trailing)
                                .foregroundStyle(.primary)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Permanently delete files")
                                    .font(.callout)
                                    .foregroundStyle(.primary)
                            }

                            InfoButton(text: String(localized: "Instead of moving files to Trash folder, this will permanently remove them. With this setting enabled, the Undo function is also not active as there's no files in Trash folder to undo."))

                            Spacer()
                            Toggle(isOn: $permanentDelete, label: {
                            })
                            .toggleStyle(SettingsToggle())
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
                            .toggleStyle(SettingsToggle())
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
                            .toggleStyle(SettingsToggle())
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
                            Picker(selection: $sizeType) {
                                Text("Real")
                                    .tag("Real")
                                Text("Logical")
                                    .tag("Logical")
//                                Text("Finder")
//                                    .tag("Finder")
                            } label: { EmptyView() }
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
                        Text("Detect when apps are moved to Trash")
                            .font(.callout)
                            .foregroundStyle(.primary)
                        InfoButton(text: String(localized: "When applications are moved to Trash, Pearcleaner will launch and find related files and folders for deletion."))
                        Spacer()

                        Toggle(isOn: $sentinel, label: {
                        })
                        .toggleStyle(SettingsToggle())
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
                    VStack {
                        HStack(spacing: 0) {
                            Image(systemName: appState.finderExtensionEnabled ? "puzzlepiece.extension.fill" : "puzzlepiece.extension")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .padding(.trailing)
                                .foregroundStyle(.primary)

                            VStack {

                                HStack(spacing: 0) {
                                    Text("Enable context menu extension for Finder")
                                        .font(.callout)
                                        .foregroundStyle(.primary)

                                    InfoButton(text: String(localized: "Enabling this extension will allow you to right click apps in Finder to quickly uninstall them with Pearcleaner"))
                                    Spacer()
                                }

                                HStack(spacing: 0) {
                                    Text("macOS only enables extensions if the main app is in Applications folder")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                    Button {
                                        FIFinderSyncController.showExtensionManagementInterface()
                                    } label: {
                                        Image(systemName: "gear")
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.leading, 5)
                                    Spacer()
                                }


                            }




                            Spacer()

                            Toggle(isOn: $appState.finderExtensionEnabled, label: {
                            })
                            .toggleStyle(SettingsToggle())
                            .onChange(of: appState.finderExtensionEnabled) { newValue in
                                if newValue {
                                    manageFinderPlugin(install: true)
                                } else {
                                    manageFinderPlugin(install: false)
                                }
                            }


                        }

//                        HStack(alignment: .center, spacing: 0) {
//
////                            if let appIcon = NSImage(named: "AppIcon") {
////                                Image(nsImage: appIcon)
////                                    .resizable()
////                                    .scaledToFit()
////                                    .frame(width: 20, height: 20)
////                                    .offset(x: -2)
////                                    .padding(.trailing)
////                            }
//
//
//                            Text("Finder extension will only be enabled if app is running from Applications directory")
//                                .font(.footnote)
//                                .foregroundStyle(.secondary)
//                                .padding(.trailing, 5)
////                            Toggle("", isOn: $finderIconToggle)
////                                .toggleStyle(SimpleCheckboxToggleStyle())
////                                .onAppear {
////                                    finderIconToggle = SharedData.finderIcon
////                                }
//                            Spacer()
//                        }

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
                        Text("Pearcleaner CLI support")
                            .font(.callout)
                            .foregroundStyle(.primary)
                        InfoButton(text: String(localized: "Enabling the CLI will allow you to execute Pearcleaner actions from the Terminal. This will add pearcleaner command into /usr/local/bin so it's available directly from your PATH environment variable. Try it after enabling:\n\n> pear --help"))
                        Spacer()

                        Toggle(isOn: $isCLISymlinked, label: {
                        })
                        .toggleStyle(SettingsToggle())
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
                fixLegacySymlink()
                isCLISymlinked = checkCLISymlink()
            }

        }

    }

}
