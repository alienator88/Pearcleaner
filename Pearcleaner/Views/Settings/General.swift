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
    @AppStorage("settings.general.sizeType") var sizeType: String = "Logical"
    @AppStorage("settings.general.cli") private var isCLISymlinked = false
    @AppStorage("settings.general.namesearchstrict") private var nameSearchStrict = false
    @AppStorage("settings.general.spotlight") private var spotlight = false
    @AppStorage("settings.general.permanentDelete") private var permanentDelete: Bool = false
    @AppStorage("settings.general.searchSensitivity") private var sensitivityLevel: SearchSensitivityLevel = .strict
    @State private var showAppIconInMenu = UserDefaults.showAppIconInMenu
    @State private var cacheSize: String = "Calculating..."

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


                        HStack(spacing: 0) {
                            Image(systemName: "plus.forwardslash.minus")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                                .padding(.trailing)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            VStack(alignment: .leading, spacing: 5) {
                                Text("File size display options")
                                    .font(.callout)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            }
                            InfoButton(text: String(localized: "Real size type will show how much actual allocated space the file has on disk.\n\nLogical type shows the binary size. The filesystem can compress and deduplicate sectors on disk, so real size is sometimes smaller (or bigger) than logical size.\n\nFinder size is similar to if you right click > Get Info on a file in Finder, which will show both the logical and real sizes together."))
                            Spacer()
                            Picker(selection: $sizeType) {
                                Text("Real")
                                    .tag("Real")
                                Text("Logical")
                                    .tag("Logical")
                            } label: { EmptyView() }
                                .buttonStyle(.borderless)
                        }
                        .padding(.vertical, 5)

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
                    • Balanced – \(SearchSensitivityLevel.balanced.description)
                    • Broad – \(SearchSensitivityLevel.broad.description)
                    
                    Higher levels may find more files but may include some unrelated results. It is recommended to check found files manually at these levels.
                    """))
                        Spacer()
                        Text("\(sensitivityLevel.title)")
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
                        Text("Less files").textCase(.uppercase).font(.caption2).foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        Slider(value: Binding(
                            get: { Double(sensitivityLevel.rawValue) },
                            set: { sensitivityLevel = SearchSensitivityLevel(rawValue: Int($0)) ?? .strict }
                        ), in: 0...Double(SearchSensitivityLevel.allCases.count - 1), step: 1)
                        Text("Most files").textCase(.uppercase).font(.caption2).foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    .padding(5)


                })

            // === Cache ==========================================================================================================
            if #available(macOS 14.0, *) {
                PearGroupBox(
                    header: { Text("Cache").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title2) },
                    content: {
                        HStack(spacing: 0) {
                            Image(systemName: "tray.full")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 15, height: 15)
                                .padding(.trailing)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 0) {
                                    Text("Clear app data cache")
                                        .font(.callout)
                                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                    InfoButton(text: String(localized: "Pearcleaner caches app metadata to improve loading times. Clearing the cache will force a fresh scan of all apps on the next launch. This is useful if app information seems outdated or incorrect."))
                                }
                                Text(cacheSize)
                                    .font(.caption)
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            }
                            Spacer()

                            Button {
                                clearAppCache()
                            } label: {
                                Text("Clear Cache")
                                    .font(.callout)
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.borderless)
                        }
                        .padding(5)
                    })
            }

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

                // Calculate cache size if on macOS 14+
                if #available(macOS 14.0, *) {
                    await calculateCacheSize()
                }
            }

        }

    }

    // MARK: - Cache Management

    @available(macOS 14.0, *)
    private func calculateCacheSize() async {
        let appSupportURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Pearcleaner")
        let storeURL = appSupportURL.appendingPathComponent("AppCache.sqlite")

        // Calculate size of all cache files (sqlite, sqlite-shm, sqlite-wal)
        let fileManager = FileManager.default
        var totalSize: Int64 = 0

        // Check main database file
        if let attrs = try? fileManager.attributesOfItem(atPath: storeURL.path),
           let fileSize = attrs[.size] as? Int64 {
            totalSize += fileSize
        }

        // Check WAL file
        let walURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-wal")
        if let attrs = try? fileManager.attributesOfItem(atPath: walURL.path),
           let fileSize = attrs[.size] as? Int64 {
            totalSize += fileSize
        }

        // Check SHM file
        let shmURL = storeURL.deletingPathExtension().appendingPathExtension("sqlite-shm")
        if let attrs = try? fileManager.attributesOfItem(atPath: shmURL.path),
           let fileSize = attrs[.size] as? Int64 {
            totalSize += fileSize
        }

        await MainActor.run {
            if totalSize > 0 {
                cacheSize = "Cache size: \(formatByte(size: totalSize).human)"
            } else {
                cacheSize = "No cached data"
            }
        }
    }

    @available(macOS 14.0, *)
    private func clearAppCache() {
        Task { @MainActor in
            do {
                try await AppCacheManager.shared.clearCache()

                // Recalculate cache size
                await calculateCacheSize()

                // Show confirmation alert
                let alert = NSAlert()
                alert.messageText = "Cache Cleared"
                alert.informativeText = "The app data cache has been cleared successfully. The cache will be rebuilt on the next app launch."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "OK")
                alert.runModal()
            } catch {
                print("❌ Failed to clear cache: \(error)")

                // Show error alert
                let alert = NSAlert()
                alert.messageText = "Cache Clear Failed"
                alert.informativeText = "Failed to clear the cache: \(error.localizedDescription)"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        }
    }

}



enum SearchSensitivityLevel: Int, CaseIterable, Identifiable {
    case strict, enhanced, balanced, broad

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .strict: return String(localized: "Strict")
        case .enhanced: return String(localized: "Enhanced")
        case .balanced: return String(localized: "Balanced")
        case .broad: return String(localized: "Broad")
        }
    }

    var color: Color {
        switch self {
        case .strict: return .green
        case .enhanced: return .blue
        case .balanced: return .orange
        case .broad: return .red
        }
    }

    var description: String {
        switch self {
        case .strict:
            return String(localized: "Exact app name and bundle ID matches against found files (Less files, most accurate)")
        case .enhanced:
            return String(localized: "Strict level and also includes Spotlight metadata search (Slightly more files, still accurate)")
        case .balanced:
            return String(localized: "Strict level and it also allows partial matches (More files, slightly less accurate)")
        case .broad:
            return String(localized: "Balanced level and also includes Spotlight metadata search (Most files, least accurate)")
        }
    }

}
