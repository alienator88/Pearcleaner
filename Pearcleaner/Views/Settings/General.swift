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
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.sentinel.enable") private var sentinel: Bool = false
    @AppStorage("settings.general.brew") private var brew: Bool = false
    @AppStorage("settings.general.oneshot") private var oneShotMode: Bool = false
    @AppStorage("settings.general.confirmAlert") private var confirmAlert: Bool = false
    @AppStorage("settings.general.cli") private var isCLISymlinked = false
    @AppStorage("settings.general.namesearchstrict") private var nameSearchStrict = false
    @AppStorage("settings.general.spotlight") private var spotlight = false
    @AppStorage("settings.general.permanentDelete") private var permanentDelete: Bool = false
    @AppStorage("settings.general.searchSensitivity") private var sensitivityLevel: SearchSensitivityLevel = .smart
    @AppStorage("settings.general.deepLevelAlertShown") private var deepLevelAlertShown: Bool = false
    @AppStorage("settings.app.autoSlim") private var autoSlim: Bool = false
    @State private var showAppIconInMenu = UserDefaults.showAppIconInMenu
    @State private var showDeepAlert: Bool = false

    var body: some View {
        VStack(spacing: 20) {

            // === Functionality ================================================================================================
            PearGroupBox(
                header: { Text("Functionality").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title2) },
                content: {
                    VStack {
                        HStack(spacing: 0) {
                            Image(systemName: brew ? "mug.fill" : "mug")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                                .padding(.trailing)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText.opacity(1))
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 0) {
                                    Text("Homebrew cleanup after uninstall")
                                        .font(.callout)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText.opacity(1))
                                    InfoButton(text: String(localized: "When Homebrew cleanup is enabled, Pearcleaner will check if the app you are removing was installed via Homebrew and remove the cache to keep everything synced up."))
                                }

                            }



                            Spacer()
                            Toggle(isOn: $brew, label: {
                            })
                            .toggleStyle(SettingsToggle())
                        }
                        .padding(5)


                        HStack(spacing: 0) {
                            Image(systemName: permanentDelete ? "trash.slash" : "trash")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                                .padding(.trailing)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Permanently delete files")
                                    .font(.callout)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
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
                                .frame(width: 15, height: 15)
                                .padding(.trailing)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Uninstall confirmation alerts")
                                    .font(.callout)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
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
                                .frame(width: 15, height: 15)
                                .padding(.trailing)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Close after uninstall")
                                    .font(.callout)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            }

                            InfoButton(text: String(localized: "When this mode is enabled, clicking the Uninstall button to remove an app will also close Pearcleaner right after.\nThis only affects Pearcleaner when it is opened via external means, like Sentinel Trash Monitor, Finder extension or a Deep Link.\nThis allows for single use of the app for a quick uninstall. When Pearcleaner is opened normally, this setting is ignored and will work as usual."))

                            Spacer()
                            Toggle(isOn: $oneShotMode, label: {
                            })
                            .toggleStyle(SettingsToggle())
                        }
                        .padding(5)


                        VStack(spacing: 0) {
                            HStack(spacing: 0) {
                                Image(systemName: "wand.and.stars")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 15, height: 15)
                                    .padding(.trailing)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text("Auto slim Pearcleaner")
                                        .font(.callout)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                }

                                InfoButton(text: "Automatically removes unused architectures/translations to reduce bundle size after an update")

                                Spacer()
                                Toggle(isOn: $autoSlim, label: {
                                })
                                .toggleStyle(SettingsToggle())
                                .onChange(of: autoSlim) { newValue in
                                    if newValue {
                                        // Capture original size when first enabled
                                        if AppState.shared.autoSlimStats.originalSize == 0 {
                                            DispatchQueue.global(qos: .utility).async {
                                                let bundleURL = URL(fileURLWithPath: Bundle.main.bundlePath)
                                                let originalSize = totalSizeOnDisk(for: bundleURL)
                                                DispatchQueue.main.async {
                                                    var stats = AppState.shared.autoSlimStats
                                                    stats.originalSize = originalSize
                                                    AppState.shared.autoSlimStats = stats
                                                }
                                            }
                                        }
                                    } else {
                                        // Wipe stats when disabled
                                        var stats = AppState.shared.autoSlimStats
                                        stats.originalSize = 0
                                        stats.currentSize = 0
                                        stats.lastRunVersion = ""
                                        AppState.shared.autoSlimStats = stats
                                    }
                                }
                            }

                            if autoSlim && appState.autoSlimStats.originalSize > 0 && appState.autoSlimStats.currentSize > 0 {
                                HStack(spacing: 0) {
                                    Spacer()
                                        .frame(width: 15)
                                        .padding(.trailing)
                                    let savings = appState.autoSlimSavings
                                    let original = appState.autoSlimStats.originalSize
                                    let percentage = original > 0 ? Int((Double(savings) / Double(original)) * 100) : 0
                                    Text("Saved: \(ByteCountFormatter.string(fromByteCount: savings, countStyle: .file)) (\(percentage)%)")
                                        .font(.caption)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                                    Spacer()
                                }
                                .padding(.top, 5)
                            }
                        }
                        .padding(5)


                    }

                }
            )

            // === Search Sensitivity =====================================================================================================
            PearGroupBox(
                header: {
                    HStack(spacing: 0) {
                        Text("Search Sensitivity").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title2)
                        InfoButton(text: String(localized: """
                    The search sensitivity level controls how strict or lenient Pearcleaner is when finding related files for an app:

                    • Strict – \(SearchSensitivityLevel.strict.description)
                    • Smart – \(SearchSensitivityLevel.smart.description)
                    • Deep – \(SearchSensitivityLevel.deep.description)

                    Higher levels may find more files but may include some unrelated results. It is recommended to check found files manually at these levels.
                    """))
                        Spacer()
                        Text(verbatim: "\(sensitivityLevel.title)")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(sensitivityLevel.color)
                            .padding(4)
                            .padding(.horizontal, 2)
                            .background {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(ThemeColors.shared(for: colorScheme).secondaryBG)
                            }
                    }
                },
                content: {
                    HStack {
                        Text("Fewer files").textCase(.uppercase).font(.caption2).foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        Slider(value: Binding(
                            get: { Double(sensitivityLevel.rawValue) },
                            set: { sensitivityLevel = SearchSensitivityLevel(rawValue: Int($0)) ?? .strict }
                        ), in: 0...Double(SearchSensitivityLevel.allCases.count - 1), step: 1)
                        .tint(sensitivityLevel.color)
                        .onChange(of: sensitivityLevel) { newLevel in
                            if newLevel == .deep && !deepLevelAlertShown {
                                showDeepAlert = true
                            }
                        }
                        Text("Most files").textCase(.uppercase).font(.caption2).foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    .padding(5)
                    .alert("Deep Search Level", isPresented: $showDeepAlert) {
                        Button("Okay") {
                            deepLevelAlertShown = true
                        }
                    } message: {
                        Text(SearchSensitivityLevel.deep.description)
                    }


                })

            // === Sentinel =====================================================================================================
            PearGroupBox(
                header: { Text("Sentinel Monitor").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title2) },
                content: {
                    HStack(spacing: 0) {
                        Image(systemName: sentinel ? "eye.circle" : "eye.slash.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .padding(.trailing)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        Text("Detect when apps are moved to Trash")
                            .font(.callout)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
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
                header: { Text("Finder Extension").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title2) },
                content: {
                    VStack {
                        HStack(spacing: 0) {
                            Image(systemName: appState.finderExtensionEnabled ? "puzzlepiece.extension.fill" : "puzzlepiece.extension")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                                .padding(.trailing)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                            VStack {

                                HStack(spacing: 0) {
                                    Text("Enable context menu extension for Finder")
                                        .font(.callout)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                                    InfoButton(text: String(localized: "Enabling this extension will allow you to right click apps in Finder to quickly uninstall them with Pearcleaner"))
                                    Spacer()
                                }

                                HStack(spacing: 0) {
                                    Text("macOS only enables extensions if the main app is in Applications folder")
                                        .font(.footnote)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
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

                        if appState.finderExtensionEnabled {
                            HStack(spacing: 0) {
                                Image(systemName: "")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 15, height: 15)
                                    .padding(.trailing)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                Text("Enable icon for Finder extension")
                                    .font(.callout)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                                Spacer()

                                Toggle(isOn: $showAppIconInMenu, label: {
                                })
                                .toggleStyle(SettingsToggle())
                                .onChange(of: showAppIconInMenu) { newValue in
                                    UserDefaults.showAppIconInMenu = newValue
                                }
                            }
                        }

                    }
                    .padding(5)

                })

            // === CLI ==========================================================================================================
            PearGroupBox(
                header: { Text("Command Line").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title2) },
                content: {
                    HStack(spacing: 0) {
                        Image(systemName: "terminal")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 15, height: 15)
                            .padding(.trailing)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        Text("Pearcleaner CLI support")
                            .font(.callout)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
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



enum SearchSensitivityLevel: Int, CaseIterable, Identifiable {
    case strict, smart, deep

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .strict: return String(localized: "Strict")
        case .smart: return String(localized: "Smart")
        case .deep: return String(localized: "Deep")
        }
    }

    var color: Color {
        switch self {
        case .strict: return .orange
        case .smart: return .green
        case .deep: return .red
        }
    }

    var description: String {
        switch self {
        case .strict:
            return String(localized: "Only exact app name and bundle ID matches. Most conservative, safest for all apps.")
        case .smart:
            return String(localized: "Finds related files using partial name matching and company name. Recommended as default option.")
        case .deep:
            return String(localized: "Searches file contents, metadata, Finder comments, and files created by the app. Most comprehensive cleanup, but will likely have a small amount of unrelated files.")
        }
    }

}
