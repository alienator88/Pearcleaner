//
//  Features.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/1/24.
//

import Foundation
import SwiftUI

func getFeatures(appState: AppState, show: Binding<Bool>, features: Binding<String>) {

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
                            show.wrappedValue = true
                        }
                    } else {
                        show.wrappedValue = false
//                        print("Same version")
                    }

                } else {
                    show.wrappedValue = false
//                    print("No features for version found")
                }
            } catch {
                show.wrappedValue = false
                printOS("Error reading features JSON from GitHub: \(error.localizedDescription)")
            }
        } else {
            show.wrappedValue = false
            printOS("Error reading features JSON from GitHub: \(error?.localizedDescription ?? "Unknown error")")
        }
    }.resume()
}

