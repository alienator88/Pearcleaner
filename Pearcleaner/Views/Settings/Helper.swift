//
//  Helper.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/14/25.
//

import SwiftUI
import Foundation

struct HelperSettingsTab: View {
    @Environment(\.colorScheme) var colorScheme
    @ObservedObject private var helperToolManager = HelperToolManager.shared
    @State private var commandOutput: String = String(localized: "Command output will display here")
    @State private var commandToRun: String = "whoami"
    @State private var commandToRunManual: String = ""

    var body: some View {
        VStack(spacing: 20) {

            // === Session privilege ============================================================================================
            PearGroupBox(
                header: {
                    HStack {
                        Text("Management").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title2)
                        Spacer()
                    }

                },
                content: {

                    VStack {
                        HStack(spacing: 0) {
                            Image(systemName: "key")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)
                                .padding(.trailing)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                            Text("Run privileged tasks without installing anything")
                                .font(.callout)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                                .frame(minWidth: 450, maxWidth: .infinity, alignment: .leading)

                            Button {
                                SessionPrivilegeManager.shared.invalidateSession()
                                commandOutput = String(localized: "Command output will display here")
                            } label: {
                                Text("Forget")
                            }
                            .buttonStyle(.borderless)

                        }

                        Divider()
                            .padding(.vertical, 5)

                        HStack {
                            Text(helperToolManager.message)
                                .font(.footnote)
                                .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            Spacer()

                        }
                    }
                    .padding(5)

                })

            PearGroupBox(header: {
                Text("Information").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title2)
            }, content: {
                let message: LocalizedStringKey = """
                Pearcleaner asks for your administrator password the first time a task needs elevated permissions, and keeps that authorization for the rest of the session while it stays open. No privileged helper is installed, nothing appears in Settings > Login Items, and when Pearcleaner quits the authorization is gone.
                """

                VStack(alignment: .leading, spacing: 20) {
                    Text(message).foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.body).lineSpacing(5)

                    Text("The password prompt is the standard macOS administrator dialog, the same one installers use. Each prompt covers one session; locking the screen or quitting Pearcleaner ends it.").font(.footnote).foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                }

            })

            PearGroupBox(header: {
                Text("Session Playground").foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText).font(.title2)
            }, content: {
                VStack {

                    Picker("Example privileged commands", selection: $commandToRun) {
                        Text(verbatim: "whoami").tag("whoami")
                        Text(verbatim: "systemsetup -getsleep").tag("systemsetup -getsleep")
                        Text(verbatim: "systemsetup -getcomputername").tag("systemsetup -getcomputername")
                    }
                    .foregroundStyle(ThemeColors.shared(for: colorScheme).primaryText)
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: commandToRun) { newValue in
                        Task {
                            let (success, output) = await helperToolManager.runCommand(commandToRun)
                            if success {
                                commandOutput = output
                            } else {
                                commandOutput = "Error: \(output)"
                            }
                        }
                    }

                    TextField("Enter manual command here, Enter to run", text: $commandToRunManual)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).strokeBorder(ThemeColors.shared(for: colorScheme).secondaryText.opacity(0.2), lineWidth: 1))
                        .textFieldStyle(.plain)
                        .onSubmit {
                            Task {
                                let (success, output) = await helperToolManager.runCommand(commandToRunManual)
                                if success {
                                    commandOutput = output
                                } else {
                                    commandOutput = "Error: \(output)"
                                }
                            }
                        }

                    ScrollView {
                        Text(commandOutput)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .padding()
                    }
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)
                    .background(.tertiary.opacity(0.1))
                    .cornerRadius(8)

                    Text("**whoami** command should return 'root' when the session authorization is working.").font(.footnote).foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .padding(.top, 5)
                }
                .padding(5)
            })

        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await helperToolManager.manageHelperTool()
            }
        }

    }

}