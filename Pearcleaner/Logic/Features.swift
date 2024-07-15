//
//  Features.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/1/24.
//

import Foundation
import SwiftUI
import AlinFoundation


func getFeatures(appState: AppState, features: Binding<String>) {
    let url = URL(string: "https://api.github.com/repos/alienator88/Pearcleaner/contents/features.json")!
    var request = URLRequest(url: url)
    request.setValue("application/vnd.github.VERSION.raw", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let data = data {
            do {
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                if let jsonDict = jsonObject as? [String: String],
                   let bundleVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                   let featureText = jsonDict[bundleVersion] {
                    if features.wrappedValue != featureText.featureFormat() {
                        updateOnMain {
                            features.wrappedValue = featureText.featureFormat()
                            appState.featureAvailable = true
//                            show.wrappedValue = true
                        }
                    } else {
                        updateOnMain {
                            appState.featureAvailable = false
                        }
//                        show.wrappedValue = false
//                        print("Same version")
                    }

                } else {
                    updateOnMain {
                        appState.featureAvailable = false
                    }
//                    show.wrappedValue = false
//                    print("No features for version found")
                }
            } catch {
                printOS("Error reading features JSON from GitHub: \(error.localizedDescription)")
            }
        } else {
            printOS("Error reading features JSON from GitHub: \(error?.localizedDescription ?? "Unknown error")")
        }
    }.resume()
}





struct FeatureNotificationView: View {
    let appState: AppState
    @State private var hovered: Bool = false

    var body: some View {
        HStack {

            Text("New Features!")
                .font(.callout)
                .opacity(0.5)
                .padding(.leading, 7)

            Spacer()

            HStack(alignment: .center) {
                Image(systemName: !hovered ? "star" : "star.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .animation(.easeInOut(duration: 0.2), value: hovered)
                    .foregroundStyle(.white)


                Text("Check")
                    .foregroundStyle(.white)

            }
            .padding(3)
            .onHover { hovering in
                withAnimation() {
                    hovered = hovering
                }
            }
            .onTapGesture {
                NewWin.show(appState: appState, width: 500, height: 400, newWin: .feature)
                updateOnMain {
                    appState.featureAvailable = false
                }
            }
            .help("View latest features")
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
            .background(Color("pear"))
            .clipShape(RoundedRectangle(cornerRadius: 6))

        }
        .frame(height: 30)
        .padding(5)
        .background(.primary.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal)
        .padding(.bottom)
    }
}
