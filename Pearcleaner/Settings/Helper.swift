//
//  Helper.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/14/25.
//

import SwiftUI
import Foundation
import AlinFoundation

struct HelperSettingsTab: View {
    @ObservedObject private var helperToolManager = HelperToolManager.shared
    @State private var commandOutput: String = "Command output will display here"
    @State private var commandToRun: String = "whoami"
    @State private var commandToRunManual: String = ""

    var body: some View {
        VStack(spacing: 20) {

            // === Frequency ============================================================================================
            PearGroupBox(
                header: {
                    HStack {
                        Text("Management").font(.title2)
                        Spacer()
                        Button(action: {
                            helperToolManager.openSMSettings()
                        }) {
                            Label("Login Items", systemImage: "gear")
                                .padding(4)
                        }
                        .buttonStyle(ResetSettingsButtonStyle(isResetting: .constant(false), label: String(localized: "Login Items"), help: ""))
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
                                .foregroundStyle(.primary)
                            Text("Perform privileged commands without prompts")
                                .font(.callout)
                                .foregroundStyle(.primary)
                                .frame(minWidth: 270, alignment: .leading)
                            InfoButton(text: String(localized: "Without a privileged helper tool, Pearcleaner asks the user for a password prompt any time it needs to delete files from a folder the user doesn't have full access to. With a privileged helper tool, you only enter your password once to enable the helper and all subsequent commands will run without any prompts as long as the helper stays enabled in Settings > Login Items.\nLeaving the helper disabled, Pearcleaner will fallback on the legacy logic using Authorization Services and prompt every time a protected file needs to be removed."))

                            Spacer()

                            Toggle(isOn: Binding(
                                get: { helperToolManager.isHelperToolInstalled },
                                set: { newValue in
                                    Task {
                                        if newValue {
                                            await helperToolManager.manageHelperTool(action: .install)
                                        } else {
                                            await helperToolManager.manageHelperTool(action: .uninstall)
                                        }
                                    }
                                }
                            ), label: {
                            })
                            .toggleStyle(SettingsToggle())

                        }

                        Divider()
                            .padding(.vertical, 5)

                        HStack {
                            Text(helperToolManager.message)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            Spacer()

                        }
                    }
                    .padding(5)



                })


            PearGroupBox(header: {
                Text("Permission Testing").font(.title2)
            }, content: {
                VStack {

                    Picker("Example privileged commands", selection: $commandToRun) {
                        Text("whoami").tag("whoami")
                        Text("systemsetup -getsleep").tag("systemsetup -getsleep")
                        Text("systemsetup -getcomputername").tag("systemsetup -getcomputername")
                    }
                    .pickerStyle(MenuPickerStyle())
                    .onChange(of: commandToRun) { newValue in
                        if helperToolManager.isHelperToolInstalled {
                            Task {
                                let (success, output) = await helperToolManager.runCommand(commandToRun)
                                if success {
                                    commandOutput = output
                                } else {
                                    commandOutput = "Error: \(output)"
                                }
                            }
                        }
                    }
                    .onAppear{
                        if helperToolManager.isHelperToolInstalled {
                            Task {
                                let (success, output) = await helperToolManager.runCommand(commandToRun)
                                if success {
                                    commandOutput = output
                                } else {
                                    commandOutput = "Error: \(output)"
                                }
                            }
                        }
                    }

                    TextField("Enter manual command here, Enter to run", text: $commandToRunManual)
                        .padding(8)
                        .background(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.2), lineWidth: 1))
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
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                            .padding()
                    }
                    .frame(height: 380)
                    .frame(maxWidth: .infinity)
                    .background(.tertiary.opacity(0.1))
                    .cornerRadius(8)
                }
                .padding(5)
            })
            .disabled(!helperToolManager.isHelperToolInstalled)
            .opacity(helperToolManager.isHelperToolInstalled ? 1 : 0.5)

        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task {
                await helperToolManager.manageHelperTool()
            }
            if helperToolManager.isHelperToolInstalled {
                Task {
                    let (success, output) = await helperToolManager.runCommand(commandToRun)
                    if success {
                        commandOutput = output
                    } else {
                        printOS("Helper: \(output)")
                    }
                }
            }
        }

    }

}
