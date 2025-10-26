//
//  TranslationSelectionSheet.swift
//  Pearcleaner
//
//  Created by Claude on 10/20/25.
//

import SwiftUI
import AlinFoundation

struct TranslationSelectionSheet: View {
    let appName: String
    let appPath: String
    @Binding var languages: [LanguageInfo]
    @Binding var selectedLanguages: Set<String>
    @Binding var isLoading: Bool
    let onConfirm: () -> Void
    let onCancel: () -> Void

    @State private var searchText = ""
    @Environment(\.colorScheme) var colorScheme

    private var filteredLanguages: [LanguageInfo] {
        if searchText.isEmpty {
            return languages
        }
        return languages.filter { language in
            language.displayName.localizedCaseInsensitiveContains(searchText) ||
            language.code.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var allSelected: Bool {
        selectedLanguages.count == languages.count
    }

    var body: some View {
        StandardSheetView(
            title: "Choose Translations to Remove",
            width: 600,
            height: 500,
            onClose: onCancel
        ) {
            // Content
            VStack(spacing: 0) {
                // Subtitle with app name
                VStack(spacing: 8) {
                    Text(appName)
                        .font(.headline)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                    if isLoading {
                        Text("Loading languages...")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    } else if languages.isEmpty {
                        Text("No translations found")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    } else {
                        Text("\(selectedLanguages.count) of \(languages.count) language\(languages.count == 1 ? "" : "s") selected for removal")
                            .font(.caption)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                }

                // Search bar (only show if not loading and has languages)
                if !isLoading && !languages.isEmpty {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                        TextField("Filter languages...", text: $searchText)
                            .textFieldStyle(.plain)

                        if !searchText.isEmpty {
                            Button {
                                searchText = ""
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 12)

                    Divider()
                        .padding(.top, 12)
                }

                // Language list, loading state, or empty state
                if isLoading {
                    // Loading state
                    VStack(spacing: 12) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Finding available languages...")
                            .font(.callout)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 400)
                    .frame(minHeight: 200)
                } else if languages.isEmpty {
                    // Empty state - no languages found
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.orange)
                        Text("No translations found")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                        Text("This app has no removable language translation files.")
                            .font(.callout)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    .frame(maxWidth: .infinity, maxHeight: 400)
                    .frame(minHeight: 200)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(filteredLanguages) { language in
                                HStack(spacing: 8) {
                                    Button {
                                        toggleSelection(language.code)
                                    } label: {
                                        Image(systemName: selectedLanguages.contains(language.code) ? "checkmark.square.fill" : "square")
                                            .foregroundStyle(selectedLanguages.contains(language.code) ? .blue : ThemeColors.shared(for: colorScheme).secondaryText)
                                    }
                                    .buttonStyle(.plain)

                                    HStack(spacing: 6) {
                                        Text(language.displayName)
                                            .font(.callout)
                                            .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                                        Text(verbatim: "(\(language.code))")
                                            .font(.caption2)
                                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                                        if language.isPreferred {
                                            Image(systemName: "star.fill")
                                                .font(.caption2)
                                                .foregroundStyle(.orange)
                                                .help("Preferred language")
                                        }
                                    }

                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 6)
                                .background(filteredLanguages.firstIndex(of: language).map { $0 % 2 == 0 } == true ? Color.clear : ThemeColors.shared(for: colorScheme).secondaryText.opacity(0.05))
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    .frame(maxHeight: 400)
                }
            }
        } selectionControls: {
            // Selection controls (only show if not loading and has languages)
            if !isLoading && !languages.isEmpty {
                HStack(spacing: 12) {
                    Button {
                        selectAll()
                    } label: {
                        Text("Select All")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .disabled(allSelected)

                    Button {
                        deselectAll()
                    } label: {
                        Text("Deselect All")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .disabled(selectedLanguages.isEmpty)
                }
            }
        } actionButtons: {
            Button("Cancel") {
                onCancel()
            }
            .keyboardShortcut(.cancelAction)

            Button("Remove Selected") {
                onConfirm()
            }
            .keyboardShortcut(.defaultAction)
            .disabled(isLoading || selectedLanguages.isEmpty)
        }
    }

    private func toggleSelection(_ languageCode: String) {
        if selectedLanguages.contains(languageCode) {
            selectedLanguages.remove(languageCode)
        } else {
            selectedLanguages.insert(languageCode)
        }
    }

    private func selectAll() {
        selectedLanguages = Set(languages.map { $0.code })
    }

    private func deselectAll() {
        selectedLanguages.removeAll()
    }
}
