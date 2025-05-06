//
//  About.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//

import SwiftUI
import AlinFoundation

struct AboutSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @State private var disclose = false
    @State private var discloseCredits = false

    var body: some View {

        VStack(alignment: .center) {

            HStack {
                Spacer()
                Button(action: {
                    NSWorkspace.shared.open(URL(string: "https://github.com/sponsors/alienator88")!)
                }, label: {
                    HStack(alignment: .center, spacing: 8) {
                        Image(systemName: "heart")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 16, height: 16)
                            .foregroundStyle(.pink)

                        Text("Sponsor")
                            .font(.body)
                            .bold()
                    }
                    .padding(5)
                })
            }

            VStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                Text(Bundle.main.name)
                    .font(.title)
                    .bold()
                HStack {
                    Text("Version \(Bundle.main.version)")
                    Text("(Build \(Bundle.main.buildVersion))").font(.footnote)
                }

                Text("Made with ❤️ by Alin Lupascu").font(.footnote)
            }
            .padding(.vertical, 50)


            VStack(spacing: 20) {
                // GitHub
                PearGroupBox(header: { Text("Support").font(.title) }, content: {
                    HStack{
                        Image(systemName: "ant")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(.trailing)

                        VStack(alignment: .leading){
                            Text("Submit a bug or feature request")
                                .font(.title3)
                                .foregroundStyle(.primary)

                        }
                        Spacer()
                        Button {
                            NSWorkspace.shared.open(URL(string: "https://github.com/alienator88/Pearcleaner/issues/new/choose")!)
                        } label: {
                            Text("View")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.secondary)
                    }

                })

                // Translators
                PearGroupBox(header: { Text("Translation").font(.title) }, content: {
                    HStack{
                        Image(systemName: "globe")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(.trailing)

                        VStack(alignment: .leading, spacing: 10){
                            Text("A **huge** thank you to everyone who has contributed so far!")
                                .font(.title3)
                                .foregroundStyle(.primary)
                            Text(translators)
                                .font(.callout)
                                .foregroundStyle(.secondary)

                        }

                        Spacer()
                        Button {
                            NSWorkspace.shared.open(URL(string: "https://github.com/alienator88/Pearcleaner/discussions/137")!)
                        } label: {
                            Text("View")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.secondary)

                    }

                })
            }

        }
    }
}


let translators = "changanmoon, L1cardo, funsiyuan, megabitsenmzq, iFloneUEFN, vogt65, kiwamizamurai, exituser, Svec-Tomas, realkeremcam, Ihor-Khomenko, HungThinhIT"
