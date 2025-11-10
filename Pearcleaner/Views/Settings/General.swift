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
    @AppStorage("settings.general.searchSensitivity") private var sensitivityLevel: SearchSensitivityLevel = .strict
    @AppStorage("settings.general.deepLevelAlertShown") private var deepLevelAlertShown: Bool = false
    @AppStorage("settings.app.autoSlim") private var autoSlim: Bool = false
    @AppStorage("settings.general.sudoCacheTimeout") private var sudoCacheTimeoutData: Data = {
        let defaultTimeout = SudoCacheTimeout()
        return (try? JSONEncoder().encode(defaultTimeout)) ?? Data()
    }()
    @State private var showAppIconInMenu = UserDefaults.showAppIconInMenu
    @State private var showDeepAlert: Bool = false
    @State private var sudoCacheTimeout = SudoCacheTimeout()
    @FocusState private var isTimeoutFieldFocused: Bool

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


//                        VStack(spacing: 0) {
//                            HStack(spacing: 0) {
//                                Image(systemName: "wand.and.stars")
//                                    .resizable()
//                                    .scaledToFit()
//                                    .frame(width: 15, height: 15)
//                                    .padding(.trailing)
//                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
//                                VStack(alignment: .leading, spacing: 5) {
//                                    Text("Auto slim Pearcleaner")
//                                        .font(.callout)
//                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
//                                }
//
//                                InfoButton(text: "Automatically removes unused architectures/translations to reduce bundle size after an update")
//
//                                Spacer()
//                                Toggle(isOn: $autoSlim, label: {
//                                })
//                                .toggleStyle(SettingsToggle())
//                                .onChange(of: autoSlim) { newValue in
//                                    if newValue {
//                                        // Capture original size when first enabled
//                                        if AppState.shared.autoSlimStats.originalSize == 0 {
//                                            DispatchQueue.global(qos: .utility).async {
//                                                let bundleURL = URL(fileURLWithPath: Bundle.main.bundlePath)
//                                                let originalSize = totalSizeOnDisk(for: bundleURL)
//                                                DispatchQueue.main.async {
//                                                    var stats = AppState.shared.autoSlimStats
//                                                    stats.originalSize = originalSize
//                                                    AppState.shared.autoSlimStats = stats
//                                                }
//                                            }
//                                        }
//                                    } else {
//                                        // Wipe stats when disabled
//                                        var stats = AppState.shared.autoSlimStats
//                                        stats.originalSize = 0
//                                        stats.currentSize = 0
//                                        stats.lastRunVersion = ""
//                                        AppState.shared.autoSlimStats = stats
//                                    }
//                                }
//                            }
//
//                            if autoSlim && appState.autoSlimStats.originalSize > 0 && appState.autoSlimStats.currentSize > 0 {
//                                HStack(spacing: 0) {
//                                    Spacer()
//                                        .frame(width: 15)
//                                        .padding(.trailing)
//                                    let savings = appState.autoSlimSavings
//                                    let original = appState.autoSlimStats.originalSize
//                                    let percentage = original > 0 ? Int((Double(savings) / Double(original)) * 100) : 0
//                                    Text("Saved: \(ByteCountFormatter.string(fromByteCount: savings, countStyle: .file)) (\(percentage)%)")
//                                        .font(.caption)
//                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
//                                    Spacer()
//                                }
//                                .padding(.top, 5)
//                            }
//                        }
//                        .padding(5)


                        HStack(spacing: 0) {
                            Image(systemName: "key.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                                .padding(.trailing)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            VStack(alignment: .leading, spacing: 0) {
                                HStack(spacing: 0) {
                                    Text("Password cache timeout")
                                        .font(.callout)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                    InfoButton(text: String(localized: "When running privileged Homebrew operations, Pearcleaner caches your password in the macOS Keychain for this duration to avoid repeated password prompts. Homebrew commands cannot be executed with the privileged helper tool Pearcleaner offers."))
                                }
                            }

                            Spacer()

                            HStack(spacing: 4) {
                                TextField("", value: $sudoCacheTimeout.value, format: .number)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 50)
                                    .multilineTextAlignment(.center)
                                    .focusable(false)
                                    .focused($isTimeoutFieldFocused)

                                Stepper {
                                    Text("")
                                } onIncrement: {
                                    if sudoCacheTimeout.value < 999 {
                                        sudoCacheTimeout.value += 1
                                    }
                                    isTimeoutFieldFocused = false
                                } onDecrement: {
                                    if sudoCacheTimeout.value > 1 {
                                        sudoCacheTimeout.value -= 1
                                    }
                                    isTimeoutFieldFocused = false
                                }
                            }

                            Picker("", selection: $sudoCacheTimeout.unit) {
                                ForEach(SudoCacheTimeout.TimeUnit.allCases, id: \.self) { unit in
                                    Text(unit.displayName(for: sudoCacheTimeout.value)).tag(unit)
                                }
                            }
                            .pickerStyle(.menu)
                            .frame(width: 100)
                        }
                        .padding(5)
                        .onChange(of: sudoCacheTimeout) { newValue in
                            sudoCacheTimeoutData = (try? JSONEncoder().encode(newValue)) ?? Data()
                        }


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
                    
                    • Enhanced – \(SearchSensitivityLevel.enhanced.description)
                    
                    • Deep – \(SearchSensitivityLevel.deep.description)

                    At levels higher than Strict it is recommended to check found files manually.
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
                    VStack {
                        HStack(spacing: 0) {
                            Image(systemName: "terminal")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                                .padding(.trailing)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            VStack {

                                HStack {
                                    Text("Pearcleaner CLI support")
                                        .font(.callout)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                    InfoButton(text: String(localized: "Enabling the CLI will allow you to execute Pearcleaner actions from the Terminal. This will add pearcleaner command into /usr/local/bin so it's available directly from your PATH environment variable. Try it after enabling:\n\n> pear --help"))
                                    Spacer()
                                }


                                if !HelperToolManager.shared.isHelperToolInstalled {
                                    HStack {
                                        Text("Helper tool needs to be enabled")
                                            .foregroundStyle(Color.red)
                                            .font(.footnote)
                                        Spacer()
                                    }

                                }
                            }





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
                            .disabled(!HelperToolManager.shared.isHelperToolInstalled)

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

            // Load sudo cache timeout from AppStorage
            if let decoded = try? JSONDecoder().decode(SudoCacheTimeout.self, from: sudoCacheTimeoutData) {
                sudoCacheTimeout = decoded
            }
        }

    }


}



// MARK: - SudoCacheTimeout

struct SudoCacheTimeout: Codable, Equatable {
    var value: Int = 5
    var unit: TimeUnit = .minutes

    enum TimeUnit: String, Codable, CaseIterable {
        case minutes = "Minutes"
        case hours = "Hours"
        case days = "Days"

        func displayName(for value: Int) -> String {
            switch self {
            case .minutes: return value == 1 ? "Minute" : "Minutes"
            case .hours: return value == 1 ? "Hour" : "Hours"
            case .days: return value == 1 ? "Day" : "Days"
            }
        }
    }

    var seconds: TimeInterval {
        switch unit {
        case .minutes: return TimeInterval(value * 60)
        case .hours: return TimeInterval(value * 3600)
        case .days: return TimeInterval(value * 86400)
        }
    }
}



enum SearchSensitivityLevel: Int, CaseIterable, Identifiable {
    case strict, enhanced, deep

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .strict: return String(localized: "Strict")
        case .enhanced: return String(localized: "Enhanced")
        case .deep: return String(localized: "Deep")
        }
    }

    var color: Color {
        switch self {
        case .strict: return .orange
        case .enhanced: return .green
        case .deep: return .red
        }
    }

    var description: String {
        switch self {
        case .strict:
            return String(localized: "Exact string matches only for app name, bundle ID, and entitlements. Most conservative, recommended as default choice.")
        case .enhanced:
            return String(localized: "Everything in Strict plus partial string matches. May find a few unrelated files in some cases.")
        case .deep:
            return String(localized: "Everything in Enhanced plus adds company name and team identifier. Searches file contents, metadata, Finder comments, and files created by the app. Most comprehensive cleanup, finds all resources associated with the app and the developer, even other apps they create.")
        }
    }

}
