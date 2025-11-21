//
//  CaskAdoptionContentView.swift
//  Pearcleaner
//
//  Reusable adoption UI content shared between AdoptionSheetView and UpdateDetailView
//

import SwiftUI

struct CaskAdoptionContentView: View {
    // Required bindings
    @Binding var matchingCasks: [AdoptableCask]
    @Binding var selectedCaskToken: String?
    @Binding var manualEntry: String
    @Binding var manualEntryValidation: AdoptableCask?
    @Binding var adoptionError: String?

    // Callbacks
    let onManualEntryChange: (String) -> Void

    // Optional customization
    let limitCaskListHeight: Bool

    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Matching casks section
            VStack(alignment: .leading, spacing: 12) {
                Text("Matching Casks")
                    .font(.headline)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                if matchingCasks.isEmpty {
                    Text("No matching casks found. Try manual entry below.")
                        .font(.body)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .italic()
                        .padding(.vertical, 8)
                } else {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(matchingCasks) { cask in
                                CaskRowView(
                                    cask: cask,
                                    isSelected: selectedCaskToken == cask.token,
                                    onSelect: {
                                        selectedCaskToken = cask.token
                                        manualEntry = ""  // Clear manual entry when selecting from list
                                        manualEntryValidation = nil
                                    }
                                )
                            }
                        }
                    }
                    .frame(maxHeight: limitCaskListHeight ? 250 : nil)
                }
            }

            // Manual entry section
            VStack(alignment: .leading, spacing: 8) {
                Text("Manual Entry")
                    .font(.headline)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)

                Text("If the correct cask isn't listed above, enter the cask token manually:")
                    .font(.caption)
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)

                HStack(spacing: 8) {
                    TextField("e.g., firefox", text: $manualEntry)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: manualEntry) { newValue in
                            onManualEntryChange(newValue)
                        }

                    if !manualEntry.isEmpty {
                        if let validation = manualEntryValidation {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .help("Valid cask: \(validation.displayName)")
                        } else if manualEntry.count >= 2 {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.red)
                                .help("Cask not found")
                        }
                    }
                }
            }

            // Error message
            if let error = adoptionError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
                .padding(.vertical, 8)
            }
        }
    }
}
