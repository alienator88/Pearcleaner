//
//  Update.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 11/5/23.
//


import SwiftUI
import Foundation

struct Release: Codable {
    let id: Int
    let tag_name: String
    let body: String
    let assets: [Asset]
}

struct Asset: Codable {
    let name: String
    let url: String
    let browser_download_url: String
}


struct UpdateSettingsTab: View {
    @EnvironmentObject var appState: AppState
    @State private var showAlert = false
    @State private var showDone = false
    @AppStorage("settings.updater.updateTimeframe") private var updateTimeframe: Int = 1
    
    var body: some View {
        VStack {
            
            HStack {
                Text("Check for updates every ") +
                Text("**\(updateTimeframe)**").foregroundColor(.red) +
                Text(updateTimeframe == 1 ? " day" : " days")
                Stepper(value: $updateTimeframe, in: 1...7) {
                    Text("")
                }
            }
            
            ScrollView {
                VStack() {
                    ForEach(appState.releases, id: \.id) { release in
                        VStack(alignment: .leading) {
                            LabeledDivider(label: "\(release.tag_name)")
                            Text(release.body)
                        }
                        
                    }
                }
                .padding()
            }
            .frame(minHeight: 0, maxHeight: .infinity)
            .frame(minWidth: 0, maxWidth: .infinity)
            .padding()
            
            Text("Showing last 3").opacity(0.5).font(.footnote)
            
            
            
            HStack(alignment: .center, spacing: 5) {
                Spacer()
                Button("Check"){
                    loadGithubReleases(appState: appState)
                }.buttonStyle(BorderedButtonStyle())
                
                Button("Force Update"){
                    loadGithubReleases(appState: appState, manual: true)
                }.buttonStyle(BorderedButtonStyle())
                
                Button("GitHub"){
                    NSWorkspace.shared.open(URL(string: "https://github.com/alienator88/Pearcleaner/releases")!)
                }.buttonStyle(BorderedButtonStyle())
                
                
                Spacer()
            }
            .padding()
            
            
            
        }
        .padding(20)
        .frame(width: 500, height: 400)
    }
    
}


func loadGithubReleases(appState: AppState, manual: Bool = false) {
    let url = URL(string: "https://api.github.com/repos/alienator88/Pearcleaner/releases")!
    let request = URLRequest(url: url)
//    request.setValue("token \(ghToken)", forHTTPHeaderField: "Authorization")
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let data = data {
            if let decodedResponse = try? JSONDecoder().decode([Release].self, from: data) {
                DispatchQueue.main.async {
                    let lastFiveReleases = Array(decodedResponse.prefix(3)) // Get only the last 3 recent releases
                    appState.releases = lastFiveReleases
                    checkForUpdate(appState: appState, manual: manual)
                    
                }
                return
            }
        }
        print("Fetch failed: \(error?.localizedDescription ?? "Unknown error")")
    }.resume()
}

func checkForUpdate(appState: AppState, manual: Bool = false) {
    guard let latestRelease = appState.releases.first else { return }
    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    if latestRelease.tag_name > currentVersion ?? "" {
        appState.alertType = .update
        appState.showAlert = true
    } else {
        if manual {
            appState.alertType = .no_update
            appState.showAlert = true
        }
    }
}

func downloadUpdate(appState: AppState) {
    guard let latestRelease = appState.releases.first else { return }
    guard let asset = latestRelease.assets.first else { return }
    guard let url = URL(string: asset.url) else { return }
    var request = URLRequest(url: url)
//    request.setValue("token \(ghToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
    
    let downloadTask = URLSession.shared.downloadTask(with: request) { localURL, urlResponse, error in
        guard let localURL = localURL else { return }
        
        let fileManager = FileManager.default
        let destinationURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Pearcleaner").appendingPathComponent("\(asset.name)")

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.moveItem(at: localURL, to: destinationURL)
            
            UnzipAndReplace(DownloadedFileURL: destinationURL.path, appState: appState) {
                updateOnMain {
                    // Restart App
                    relaunchApp(afterDelay: 1)
                }
            }
            
        } catch {
            print("Error moving downloaded file: \(error.localizedDescription)")
        }
    }
    
    downloadTask.resume()
}

func UnzipAndReplace(DownloadedFileURL fileURL: String, appState: AppState, completion: @escaping () -> Void = {}) {
    let appDirectory = Bundle.main.bundleURL.deletingLastPathComponent().path
    let appBundle = Bundle.main.bundleURL.path
    let fileManager = FileManager.default
    
    do {
        // Remove the old version of your app
        try fileManager.removeItem(atPath: appBundle)
        
        // Unzip the downloaded update file to your app's bundle path
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
        process.arguments = [fileURL, "-d", appDirectory]
        try process.run()
        process.waitUntilExit()
        
        // After unzipping, remove the update file
        try fileManager.removeItem(atPath: fileURL)
        
    } catch {
        print("Error updating the app: \(error)")
    }
    
    completion()
}
