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

extension Release {
    var modifiedBody: String {
        return body.replacingOccurrences(of: "- [x]", with: "􀆊").replacingOccurrences(of: "###", with: "")
    }
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
                            Text(release.modifiedBody)
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
    // Set the token for a private repo
    // request.setValue("token \(ghToken)", forHTTPHeaderField: "Authorization")
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let data = data {
            if let decodedResponse = try? JSONDecoder().decode([Release].self, from: data) {
                DispatchQueue.main.async {
                    let lastFewReleases = Array(decodedResponse.prefix(3)) // Get only the last 3 recent releases
                    appState.releases = lastFewReleases

                    checkForUpdate(appState: appState, manual: manual)
                    
                }
                return
            }
        }
        printOS("Fetch failed: \(error?.localizedDescription ?? "Unknown error")")
    }.resume()
}

func checkForUpdate(appState: AppState, manual: Bool = false) {
    guard let latestRelease = appState.releases.first else { return }
    let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    if latestRelease.tag_name > currentVersion ?? "" {
        NewWin.show(appState: appState, width: 500, height: 440, newWin: .update)
//        appState.alertType = .update
//        appState.showAlert = true
    } else {
        if manual {
            NewWin.show(appState: appState, width: 500, height: 300, newWin: .no_update)
//            appState.alertType = .no_update
//            appState.showAlert = true
        }
    }
}


func downloadUpdate(appState: AppState) {
    updateOnMain {
        appState.progressBar.0 = "Getting update file links ready"
        appState.progressBar.1 = 0.1
    }
    
    guard let latestRelease = appState.releases.first else { return }
    guard let asset = latestRelease.assets.first else { return }
    guard let url = URL(string: asset.url) else { return }
    var request = URLRequest(url: url)
//    request.setValue("token \(ghToken)", forHTTPHeaderField: "Authorization")
    request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")
    
    let downloadTask = URLSession.shared.downloadTask(with: request) { localURL, urlResponse, error in
        updateOnMain {
            appState.progressBar.0 = "Downloading update file"
            appState.progressBar.1 = 0.2
        }
        
        guard let localURL = localURL else { return }
        
        let fileManager = FileManager.default
        let destinationURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!.appendingPathComponent("Pearcleaner").appendingPathComponent("\(asset.name)")

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try? fileManager.removeItem(at: destinationURL)
            }
            updateOnMain {
                appState.progressBar.0 = "Moving update file to Application Support"
                appState.progressBar.1 = 0.4
            }
            
            try fileManager.moveItem(at: localURL, to: destinationURL)
            
            UnzipAndReplace(DownloadedFileURL: destinationURL.path, appState: appState)
            
            updateOnMain {
                appState.progressBar.0 = "Done, please restart!"
                appState.progressBar.1 = 1.0
            }
            
            
        } catch {
            printOS("Error moving downloaded file: \(error.localizedDescription)")
        }
    }
    
    downloadTask.resume()
}

func UnzipAndReplace(DownloadedFileURL fileURL: String, appState: AppState) {
    let appDirectory = Bundle.main.bundleURL.deletingLastPathComponent().path
    let appBundle = Bundle.main.bundleURL.path
    let fileManager = FileManager.default
    
    do {
        updateOnMain {
            appState.progressBar.0 = "Deleting existing application"
            appState.progressBar.1 = 0.5
        }
        
        // Remove the old version of your app
        try fileManager.removeItem(atPath: appBundle)
        
        updateOnMain {
            appState.progressBar.0 = "Unziping new update file to original Pearcleaner location"
            appState.progressBar.1 = 0.6
        }
        

        // Unzip the downloaded update file to your app's bundle path
        let process = Process()
//        process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
//        process.arguments = [fileURL, "-d", appDirectory]
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-xk", fileURL, appDirectory]
//        let pipe = Pipe()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        
        try process.run()
        process.waitUntilExit()
        
//        let outputData = pipe.fileHandleForReading.readDataToEndOfFile()
//        let output = String(decoding: outputData, as: UTF8.self)
//        
//        writeLog(string: output)
        
        updateOnMain {
            appState.progressBar.0 = "Deleting update file"
            appState.progressBar.1 = 0.8
        }
        
        // After unzipping, remove the update file
        try fileManager.removeItem(atPath: fileURL)
        
        // Show Restart dialog
//        updateOnMain {
//            appState.alertType = .restartApp
//            appState.showAlert = true
//        }
        
        
    } catch {
        printOS("Error updating the app: \(error)")
    }
    
}
