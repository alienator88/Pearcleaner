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

        let sponsors = Sponsor.sponsors
//        let credits = Credit.credits

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
                PearGroupBox(header: { Text("Support").font(.title2) }, content: {
                    HStack{
                        Image(systemName: "star")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(.trailing)

                        VStack(alignment: .leading){
                            Text("Submit a bug or feature request")
                                .font(.callout)
                                .foregroundStyle(.primary)

                        }
                        Spacer()
                        Button {
                            NSWorkspace.shared.open(URL(string: "https://github.com/alienator88/Pearcleaner/issues/new/choose")!)
                        } label: { EmptyView() }
                        .buttonStyle(SimpleButtonStyle(icon: "paperplane", help: String(localized: "View")))

                    }

                })

                // GitHub Sponsors
                PearGroupBox(header: { Text("GitHub Sponsors").font(.title2) }, content: {
                    HStack{
                        Image(systemName: "dollarsign.circle")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                            .padding(.trailing)

                        Text("View project contributors")

                        DisclosureGroup(isExpanded: $disclose) {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 0) {
                                    ForEach(sponsors) { sponsor in
                                        HStack() {
                                            Text(sponsor.name)
                                            Spacer()
                                            Button {
                                                NSWorkspace.shared.open(sponsor.url)
                                            } label: { EmptyView() }
                                            .buttonStyle(SimpleButtonStyle(icon: "link", help: String(localized: "View")))
                                            .padding(.trailing)
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            }
                            .frame(height: 45)
                            .padding(5)
                        } label: { EmptyView() }

                    }
                })


            }

        }
    }
}



//MARK: Sponsors
struct Sponsor: Identifiable {
    let id = UUID()
    let name: String
    let url: URL

    static let sponsors: [Sponsor] = [
        Sponsor(name: "Sagittarius", url: URL(string: "https://github.com/sagittarius-codebase")!),
        Sponsor(name: "Ilovecatz17", url: URL(string: "https://github.com/Ilovecatz17")!),
        Sponsor(name: "ichoosetoaccept", url: URL(string: "https://github.com/ichoosetoaccept")!),
        Sponsor(name: "barats", url: URL(string: "https://github.com/barats")!),
        Sponsor(name: "mzdr (monthly)", url: URL(string: "https://github.com/mzdr")!),
        Sponsor(name: "chris3ware", url: URL(string: "https://github.com/chris3ware")!),
        Sponsor(name: "fpuhan", url: URL(string: "https://github.com/fpuhan")!),
        Sponsor(name: "HungThinhIT", url: URL(string: "https://github.com/HungThinhIT")!),
        Sponsor(name: "DharsanB", url: URL(string: "https://github.com/dharsanb")!),
        Sponsor(name: "MadMacMad", url: URL(string: "https://github.com/MadMacMad")!),
        Sponsor(name: "Butterdawgs", url: URL(string: "https://github.com/butterdawgs")!),
        Sponsor(name: "y-u-s-u-f", url: URL(string: "https://github.com/y-u-s-u-f")!)
    ]
}

//MARK: Credits
struct Credit: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let url: URL

    static let credits: [Credit] = [
        Credit(name: "Microsoft Designer", description: "Application icon resource", url: URL(string: "https://designer.microsoft.com/image-creator")!),
        Credit(name: "Privacy Guides", description: "Inspired by open-source appcleaner script from Sun Knudsen", url: URL(string: "https://sunknudsen.com/privacy-guides/how-to-clean-uninstall-macos-apps-using-appcleaner-open-source-alternative")!),
        Credit(name: "AppCleaner", description: "Inspired by AppCleaner from Freemacsoft", url: URL(string: "https://freemacsoft.net/appcleaner/")!)
    ]
}

