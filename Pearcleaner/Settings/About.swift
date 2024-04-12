//
//  About.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//

import SwiftUI

struct AboutSettingsTab: View {
    @EnvironmentObject var appState: AppState

    var body: some View {

        VStack(alignment: .center) {



            VStack(alignment: .center, spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .padding(.top, 30)
                Text(Bundle.main.name)
                    .font(.title)
                    .bold()
                HStack {
                    Text("Version \(Bundle.main.version)")
                    Text("(Build \(Bundle.main.buildVersion))").font(.footnote)
                }


                Divider()
                    .padding()

            }

            VStack(alignment: .leading) {

                HStack() {
                    Text("Credits").font(.title2)
                    Spacer()
                }
                .padding(.leading)
                .padding(.bottom)

                HStack{
                    Image(systemName: "paintbrush.pointed")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)

                    VStack(alignment: .leading){
                        Text("Microsoft Designer")
                        Text("Application icon resource")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))

                    }
                    Spacer()
                    Button(""){
                        NSWorkspace.shared.open(URL(string: "https://designer.microsoft.com/image-creator")!)
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "link", help: "View"))

                }
                .padding(5)
                .padding(.leading)


                HStack{
                    Image(systemName: "n.circle")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)

                    VStack(alignment: .leading){
                        Text("Namelix")
                        Text("Logo and branding generation")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))

                    }
                    Spacer()
                    Button(""){
                        NSWorkspace.shared.open(URL(string: "https://namelix.com/")!)
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "link", help: "View"))

                }
                .padding(5)
                .padding(.leading)


                HStack{
                    Image(systemName: "applescript")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)

                    VStack(alignment: .leading){
                        Text("Privacy Guides")
                        Text("Inspired by open-source appcleaner script from Sun Knudsen")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))
                            .lineLimit(2)

                    }
                    Spacer()

                    Button("") {
                        NSWorkspace.shared.open(URL(string: "https://sunknudsen.com/privacy-guides/how-to-clean-uninstall-macos-apps-using-appcleaner-open-source-alternative")!)
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "link", help: "View"))

                }
                .padding(5)
                .padding(.leading)


                HStack{
                    Image(systemName: "trash")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 20, height: 20)
                        .padding(.trailing)

                    VStack(alignment: .leading){
                        Text("AppCleaner")
                        Text("Inspired by AppCleaner from Freemacsoft")
                            .font(.callout)
                            .foregroundStyle(Color("mode").opacity(0.5))

                    }
                    Spacer()
                    Button(""){
                        NSWorkspace.shared.open(URL(string: "https://freemacsoft.net/appcleaner/")!)
                    }
                    .buttonStyle(SimpleButtonStyle(icon: "link", help: "View"))

                }
                .padding(5)
                .padding(.leading)

                Spacer()

            }

            Spacer()

            Text("Made with ❤️ by Alin Lupascu (dev@itsalin.com)").font(.footnote).padding(.bottom)
        }
        .padding(20)
        .frame(width: 500, height: 600)

    }
}



extension Bundle {

    var name: String {
        func string(for key: String) -> String? {
            object(forInfoDictionaryKey: key) as? String
        }
        return string(for: "CFBundleDisplayName")
        ?? string(for: "CFBundleName")
        ?? "N/A"
    }

    var version: String {
        infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
    }

    var buildVersion: String {
        infoDictionary?["CFBundleVersion"] as? String ?? "N/A"
    }

}

