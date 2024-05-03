//
//  Updater.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 5/3/24.
//

import Foundation
import SwiftUI


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
        return body.replacingOccurrences(of: "- [x]", with: ">").replacingOccurrences(of: "###", with: "")
    }
}




func loadGithubReleases(appState: AppState, manual: Bool = false) {
    let url = URL(string: "https://api.github.com/repos/alienator88/Pearcleaner/releases")!
    let request = URLRequest(url: url)
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
        updateOnMain {
            appState.updateAvailable = true
        }
    } else {
        if manual {
            NewWin.show(appState: appState, width: 500, height: 300, newWin: .no_update)
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
                appState.updateAvailable = false
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
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = ["-xk", fileURL, appDirectory]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try process.run()
        process.waitUntilExit()

        updateOnMain {
            appState.progressBar.0 = "Deleting update file"
            appState.progressBar.1 = 0.8
        }

        // After unzipping, remove the update file
        try fileManager.removeItem(atPath: fileURL)


    } catch {
        printOS("Error updating the app: \(error)")
    }

}






struct UpdateNotificationView: View {
    let appState: AppState
    @State private var hovered: Bool = false

    var body: some View {
        HStack {

            Text("Update Available")
                .font(.callout)
                .opacity(0.5)
                .padding(.leading, 7)

            Spacer()

            HStack(alignment: .center) {
                Image(systemName: !hovered ? "square.and.arrow.down" : "square.and.arrow.down.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                    .animation(.easeInOut(duration: 0.2), value: hovered)
                    .foregroundStyle(.white)


                Text("v\(appState.releases.first?.tag_name ?? "Update")")
                    .foregroundStyle(.white)

            }
            .padding(3)
            .onHover { hovering in
                withAnimation() {
                    hovered = hovering
                }
            }
            .help("Download latest update")
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
            .background(Color("pear"))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .onTapGesture {
                NewWin.show(appState: appState, width: 500, height: 440, newWin: .update)
            }
        }
        .frame(height: 30)
        .padding(5)
        .background(Color("mode").opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal)
        .padding(.bottom)
    }
}
