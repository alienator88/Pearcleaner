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


// --- Updater functionality


func loadGithubReleases(appState: AppState, manual: Bool = false, releaseOnly: Bool = false) {
    let url = URL(string: "https://api.github.com/repos/alienator88/Pearcleaner/releases")!
    let request = URLRequest(url: url)
    URLSession.shared.dataTask(with: request) { data, response, error in
        if let data = data {
            if let decodedResponse = try? JSONDecoder().decode([Release].self, from: data) {
                DispatchQueue.main.async {
                    let lastFewReleases = Array(decodedResponse.prefix(3)) // Get only the last 3 recent releases
                    appState.releases = lastFewReleases
                    if !releaseOnly {
                        checkForUpdate(appState: appState, manual: manual)
                    }
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
        appState.progressBar.0 = "UPDATER: Getting update link"
        appState.progressBar.1 = 0.1
    }
    let fileManager = FileManager.default
    guard let latestRelease = appState.releases.first else { return }
    guard let asset = latestRelease.assets.first else { return }
    guard let url = URL(string: asset.url) else { return }
    var request = URLRequest(url: url)
    request.setValue("application/octet-stream", forHTTPHeaderField: "Accept")

    let downloadTask = URLSession.shared.downloadTask(with: request) { localURL, urlResponse, error in
        updateOnMain {
            appState.progressBar.0 = "UPDATER: Starting download of update file"
            appState.progressBar.1 = 0.2
        }

        guard let localURL = localURL else { return }
        
        let destinationURL = FileManager.default.temporaryDirectory.appendingPathComponent("\(asset.name)")

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try? fileManager.removeItem(at: destinationURL)
            }

            updateOnMain {
                appState.progressBar.0 = "UPDATER: File downloaded to temp directory"
                appState.progressBar.1 = 0.3
            }
            try fileManager.moveItem(at: localURL, to: destinationURL)

            updateOnMain {
                appState.progressBar.0 = "UPDATER: File renamed using asset name"
                appState.progressBar.1 = 0.4
            }

            UnzipAndReplace(DownloadedFileURL: destinationURL.path, appState: appState)

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
            appState.progressBar.0 = "UPDATER: Removing currently installed application bundle"
            appState.progressBar.1 = 0.5
        }

        // Remove the old version of your app
        try fileManager.removeItem(atPath: appBundle)

        updateOnMain {
            appState.progressBar.0 = "UPDATER: Unziping file to original install location"
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
            appState.progressBar.0 = "UPDATER: Removing file from temp directory"
            appState.progressBar.1 = 0.8
        }

        // After unzipping, remove the update file
        try fileManager.removeItem(atPath: fileURL)

        updateOnMain {
            appState.progressBar.0 = "UPDATER: Completed, please restart!"
            appState.progressBar.1 = 1.0
            appState.updateAvailable = false
        }

    } catch {
        printOS("Error updating the app: \(error)")
    }

}



// --- Updater check frequency

enum UpdateFrequency: String, CaseIterable, Identifiable {
    case none = "Never"
    case daily = "Daily"
    case weekly = "Weekly"
    case monthly = "Monthly"

    var id: String { self.rawValue }

    var interval: TimeInterval? {
        switch self {
        case .none:
            return nil
        case .daily:
            return 86400 // 1 day in seconds
        case .weekly:
            return 604800 // 7 days in seconds
        case .monthly:
            return 2592000 // 30 days in seconds
        }
    }

    func updateNextUpdateDate() {
        guard let updateInterval = self.interval else { return }
        let newUpdateDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(updateInterval))
        UserDefaults.standard.set(newUpdateDate.timeIntervalSinceReferenceDate, forKey: "settings.updater.nextUpdateDate")
    }
}

//func updateNextUpdateDate() {
//    @AppStorage("settings.updater.updateFrequency") var updateFrequency: UpdateFrequency = .daily
//    @AppStorage("settings.updater.nextUpdateDate") var nextUpdateDate = Date.now.timeIntervalSinceReferenceDate
//
//    guard let updateInterval = updateFrequency.interval else { return }
//    let newUpdateDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(updateInterval))
//    nextUpdateDate = newUpdateDate.timeIntervalSinceReferenceDate
//}

func checkAndUpdateIfNeeded(appState: AppState) {
    @AppStorage("settings.updater.updateFrequency") var updateFrequency: UpdateFrequency = .daily
    @AppStorage("settings.updater.nextUpdateDate") var nextUpdateDate = Date.now.timeIntervalSinceReferenceDate

    guard let updateInterval = updateFrequency.interval else {
        printOS("Updater: no update frequency set, skipping check")
        return
    }

    let now = Date()
    let nextUpdateDateLocal = Date(timeIntervalSinceReferenceDate: nextUpdateDate)

    if !isSameDay(date1: nextUpdateDateLocal, date2: now) {
        printOS("Updater: next update date is in the future, skipping (\(nextUpdateDateLocal))")
        return
    }

    updateApp(appState: appState)
    setNextUpdateDate(interval: updateInterval)
}

func updateApp(appState: AppState) {
    // Perform your update logic here
    printOS("Updater: performing update")
    loadGithubReleases(appState: appState)
}

func setNextUpdateDate(interval: TimeInterval) {
    let newUpdateDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(interval))
    UserDefaults.standard.set(newUpdateDate.timeIntervalSinceReferenceDate, forKey: "settings.updater.nextUpdateDate")
}

func isSameDay(date1: Date, date2: Date) -> Bool {
    return Calendar.current.isDate(date1, inSameDayAs: date2)
}

//func updateNextUpdateDate() {
//    @AppStorage("settings.updater.updateTimeframe") var updateTimeframe: Int = 1
//    @AppStorage("settings.updater.nextUpdateDate") var nextUpdateDate = Date.now.timeIntervalSinceReferenceDate
//    let updateSeconds = updateTimeframe.daysToSeconds
//    let newUpdateDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(updateSeconds))
//    nextUpdateDate = newUpdateDate.timeIntervalSinceReferenceDate
//}
//
//func checkAndUpdateIfNeeded(appState: AppState) {
//    @AppStorage("settings.updater.updateTimeframe") var updateTimeframe: Int = 1
//    @AppStorage("settings.updater.nextUpdateDate") var nextUpdateDate = Date.now.timeIntervalSinceReferenceDate
//
//    let updateSeconds = updateTimeframe.daysToSeconds
//    let now = Date()
//
//    // Retrieve the next update date from UserDefaults
//    let nextUpdateDateLocal = Date(timeIntervalSinceReferenceDate: nextUpdateDate)
////    let nextUpdateDate = UserDefaults.standard.object(forKey: "settings.updater.nextUpdateDate") as? Date
//
//    // If there's no stored next update date or it's in the past, update immediately
//    if !isSameDay(date1: nextUpdateDateLocal, date2: now) {
//        // Next update date is in the future, no need to update
//        printOS("Updater: next update date is in the future, skipping")
//        return
//    }
//
//    // Update immediately and set next update date
//    updateApp(appState: appState)
//    setNextUpdateDate(interval: updateSeconds)
//}
//
//func updateApp(appState: AppState) {
//    // Perform your update logic here
//    printOS("Updater: performing update")
//    loadGithubReleases(appState: appState)
//}
//
//func setNextUpdateDate(interval: TimeInterval) {
//    let newUpdateDate = Calendar.current.startOfDay(for: Date().addingTimeInterval(interval))
//    UserDefaults.standard.set(newUpdateDate.timeIntervalSinceReferenceDate, forKey: "settings.updater.nextUpdateDate")
////    UserDefaults.standard.set(newUpdateDate, forKey: "settings.updater.nextUpdateDate")
//}
//
//func isSameDay(date1: Date, date2: Date) -> Bool {
//    return Calendar.current.isDate(date1, inSameDayAs: date2)
//}



// --- Updater Badge View


struct UpdateNotificationView: View {
    let appState: AppState
    @State private var hovered: Bool = false

    var body: some View {
        HStack {

            Text("Update Available!")
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
            .onTapGesture {
                NewWin.show(appState: appState, width: 500, height: 440, newWin: .update)
            }
            .help("Download latest update")
            .padding(.horizontal, 5)
            .padding(.vertical, 4)
            .background(Color("pear"))
            .clipShape(RoundedRectangle(cornerRadius: 6))

        }
        .frame(height: 30)
        .padding(5)
        .background(Color("mode").opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal)
        .padding(.bottom)
    }
}
