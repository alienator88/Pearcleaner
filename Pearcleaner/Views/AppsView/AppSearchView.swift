//
//  Searchbar.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 4/26/24.
//

import SwiftUI
import AlinFoundation
import Ifrit

struct AppSearchView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var locations: Locations
    @EnvironmentObject var fsm: FolderSettingsManager
    @EnvironmentObject var updater: Updater
    @EnvironmentObject var permissionManager: PermissionManager
    @Environment(\.colorScheme) var colorScheme
    var glass: Bool
    @Binding var search: String
    @AppStorage("settings.general.selectedSortAppsList") var selectedSortOption: SortOption = .alphabetical
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.interface.multiSelect") private var multiSelect: Bool = false

    var body: some View {

        VStack(alignment: .center, spacing: 0) {
            if appState.reload || appState.sortedApps.isEmpty {
                VStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {

                SearchBarSidebar(search: $search, glass: glass)
                    .padding()

                AppsListView(search: $search, filteredApps: filteredApps)
                    .padding([.bottom, .horizontal], 5)

                if updater.updateAvailable {
                    Divider()
                    UpdateBadge(updater: updater)
                        .padding(8)
                } else if updater.announcementAvailable {
                    Divider()
                    FeatureBadge(updater: updater)
                        .padding(8)
                } else if let _ = permissionManager.results, !permissionManager.allPermissionsGranted {
                    Divider()
                    PermissionsBadge()
                        .padding(8)
                } else if HelperToolManager.shared.shouldShowHelperBadge {
                    Divider()
                    HelperBadge()
                        .padding(8)
                }
            }
        }

    }


    private var filteredApps: [AppInfo] {
        let apps: [AppInfo]
        if search.isEmpty {
            apps = appState.sortedApps
        } else {
            let fuse = Fuse()
            apps = appState.sortedApps.filter { app in
                if app.appName.localizedCaseInsensitiveContains(search) {
                    return true
                }
                let result = fuse.searchSync(search, in: app.appName)
                return result?.score ?? 1.0 < 0.4 // Adjust threshold as needed (lower = stricter)
            }
        }

        // Sort based on the selected option
        switch selectedSortOption {
        case .alphabetical:
            return apps.sorted {
                $0.appName.replacingOccurrences(of: ".", with: "").lowercased() < $1.appName.replacingOccurrences(of: ".", with: "").lowercased()
            }
        case .size:
            return apps.sorted { $0.bundleSize > $1.bundleSize }
        case .creationDate:
            return apps.sorted { ($0.creationDate ?? Date.distantPast) > ($1.creationDate ?? Date.distantPast) }
        case .contentChangeDate:
            return apps.sorted { ($0.contentChangeDate ?? Date.distantPast) > ($1.contentChangeDate ?? Date.distantPast) }
        case .lastUsedDate:
            return apps.sorted { ($0.lastUsedDate ?? Date.distantPast) > ($1.lastUsedDate ?? Date.distantPast) }
        }

    }

}


struct SimpleSearchStyle: TextFieldStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    @State var trash: Bool = false
    @Binding var text: String
    @State var glass: Bool = false
    @State var padding: CGFloat = 5
    @EnvironmentObject var appState: AppState
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    func _body(configuration: TextField<Self._Label>) -> some View {

        ZStack {

            ZStack {
                if text.isEmpty {
                    HStack {
                        Spacer()
                        Text(isFocused ? String(localized: "Type to search") : String(localized: "Hover to search"))
                            .font(.subheadline)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        Spacer()
                    }
                }
                HStack {
                    configuration
                        .font(.title3)
                        .textFieldStyle(PlainTextFieldStyle())

                    Spacer()

                    if trash && text != "" {
                        Button {
                            text = ""
                        } label: { EmptyView() }
                            .buttonStyle(SimpleButtonStyle(icon: "delete.left.fill", help: String(localized: "Clear text"), size: 16, padding: 0))
                    }
                }

            }
            .padding(.horizontal, 5)

        }
        .onHover { hovering in
            withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                self.isHovered = hovering
                self.isFocused = true
            }
        }
        .focused($isFocused)
        .onAppear {
            updateOnMain {
                self.isFocused = true
            }
        }
    }
}


struct SimpleSearchStyleSidebar: TextFieldStyle {
    @Environment(\.colorScheme) var colorScheme
    @State private var isHovered = false
    @FocusState private var isFocused: Bool
    @State var trash: Bool = false
    @Binding var text: String
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var fsm: FolderSettingsManager
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @AppStorage("settings.general.selectedSortAppsList") var selectedSortOption: SortOption = .alphabetical
    @AppStorage("settings.interface.multiSelect") private var multiSelect: Bool = false

    func _body(configuration: TextField<Self._Label>) -> some View {

        HStack {
            configuration
                .font(.title3)
                .textFieldStyle(PlainTextFieldStyle())

            Spacer()

            if trash && text != "" {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "delete.left.fill")
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }
            }

            Menu {
                Section(header: Text("Sorting (\(selectedSortOption.title))")) {
                    ForEach(SortOption.allCases) { option in
                        Button {
                            withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                                selectedSortOption = option
                            }
                        } label: {
                            Label(option.title, systemImage: selectedSortOption == option ? "circle.inset.filled" : "circle")
                        }
                    }
                }

                Section(header: Text("Options")) {
                    Button("Refresh List") {
                        withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                            reloadAppsList(appState: appState, fsm: fsm)
                        }
                    }

                    Button(multiSelect ? "Hide checkboxes" : "Show checkboxes") {
                        withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                            multiSelect.toggle()
                        }
                    }
                }
            } label: {
                Image(systemName: "line.3.horizontal")
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .menuIndicator(.hidden)
            .frame(width: 16)
        }
        .buttonStyle(.plain)
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .controlGroup(Capsule(style: .continuous), level: .secondary)
        .onHover { hovering in
            withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                self.isHovered = hovering
                self.isFocused = true
            }
        }
        .focused($isFocused)
        .onAppear {
            updateOnMain {
                self.isFocused = true
            }
        }
    }
}

// Hide blinking textfield caret
extension NSTextView {
    open override var frame: CGRect {
        didSet {
            insertionPointColor = NSColor(.primary.opacity(0.2))//.clear
        }
    }
}

struct SearchBar: View {
    @Binding var search: String
    @State var glass: Bool = false
    @State var padding: CGFloat = 5
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack {
            TextField(text: $search) { EmptyView() }
                .textFieldStyle(SimpleSearchStyle(trash: true, text: $search, glass: glass, padding: padding))
        }
    }
}


struct SearchBarSidebar: View {
    @Binding var search: String
    @State var glass: Bool = false
    @State var padding: CGFloat = 5
    @State var sidebar: Bool = true
    @EnvironmentObject var appState: AppState

    var body: some View {
        HStack {
            TextField("Search apps..", text: $search)
                .textFieldStyle(SimpleSearchStyleSidebar(trash: true, text: $search))
        }
    }
}
