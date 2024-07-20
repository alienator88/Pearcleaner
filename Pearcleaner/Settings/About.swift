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
        let credits = Credit.credits

        VStack(alignment: .center) {



            VStack(alignment: .center, spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
//                    .padding(.top, 20)
                Text(Bundle.main.name)
                    .font(.title)
                    .bold()
                HStack {
                    Text("Version \(Bundle.main.version)")
                    Text("(Build \(Bundle.main.buildVersion))").font(.footnote)
                }


                HStack{
                    Image(systemName: "star")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)

                    VStack(alignment: .leading){
                        Text("GitHub")
                        Text("Submit a bug or feature request via the repo")
                            .font(.callout)
                            .foregroundStyle(.primary.opacity(0.5))

                    }
                    Spacer()
                    Button(""){
                        NSWorkspace.shared.open(URL(string: "https://github.com/alienator88/Pearcleaner/issues/new/choose")!)
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "link", help: "View"))

                }
                .padding(5)
                .padding(.leading)
                .padding(.top, 5)

            }

            Divider()

            HStack{
                Image(systemName: "dollarsign.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(.trailing)

                DisclosureGroup(isExpanded: $disclose, content: {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0) {
                            ForEach(sponsors) { sponsor in
                                HStack() {
                                    Text(sponsor.name)
                                    Spacer()
                                    Button(""){
                                        NSWorkspace.shared.open(sponsor.url)
                                    }
                                    .buttonStyle(SimpleButtonStyle(icon: "link", help: "View", padding: 5))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: 100)
                    .padding(5)
                }, label: {
                    Text("GitHub Sponsors")
                        .font(.title2)
                })



            }
            .padding(5)
            .padding(.leading)

            Divider()

            HStack{
                Image(systemName: "info.circle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                    .padding(.trailing)

                DisclosureGroup(isExpanded: $discloseCredits, content: {
                    VStack(alignment: .leading) {

                        ForEach(credits) { credit in
                            HStack{
                                VStack(alignment: .leading){
                                    Text(credit.name)
                                    Text(credit.description)
                                        .font(.callout)
                                        .foregroundStyle(.primary.opacity(0.5))

                                }
                                Spacer()
                                Button(""){
                                    NSWorkspace.shared.open(credit.url)
                                }
                                .buttonStyle(SimpleButtonStyle(icon: "link", help: "View"))

                            }
                        }
                    }
                    .padding(5)
                }, label: {
                    Text("Credits")
                        .font(.title2)
                })



            }
            .padding(5)
            .padding(.leading)

            Spacer()

            Text("Made with ❤️ by Alin Lupascu").font(.footnote)//.padding(.bottom)
        }
        .padding(20)
        .frame(width: 500, height: 500)

    }
}



//MARK: Sponsors
struct Sponsor: Identifiable {
    let id = UUID()
    let name: String
    let url: URL

    static let sponsors: [Sponsor] = [
        Sponsor(name: "DharsanB", url: URL(string: "https://github.com/dharsanb")!),
        Sponsor(name: "MadMacMad", url: URL(string: "https://github.com/MadMacMad")!),
        Sponsor(name: "Butterdawgs", url: URL(string: "https://github.com/butterdawgs")!),
        Sponsor(name: "y-u-s-u-f", url: URL(string: "https://github.com/y-u-s-u-f")!)
    ]
}

//MARK: Credits
struct Credit: Identifiable {
    let id = UUID()
//    let icon: String
    let name: String
    let description: String
    let url: URL

    static let credits: [Credit] = [
        Credit(name: "Microsoft Designer", description: "Application icon resource", url: URL(string: "https://designer.microsoft.com/image-creator")!),
        Credit(name: "Privacy Guides", description: "Inspired by open-source appcleaner script from Sun Knudsen", url: URL(string: "https://sunknudsen.com/privacy-guides/how-to-clean-uninstall-macos-apps-using-appcleaner-open-source-alternative")!),
        Credit(name: "AppCleaner", description: "Inspired by AppCleaner from Freemacsoft", url: URL(string: "https://freemacsoft.net/appcleaner/")!)
    ]
}

