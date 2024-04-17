//
//  Conditions.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 4/15/24.
//

import Foundation


struct Condition: Decodable {
    var bundle_id: String
    var include: [String]
    var exclude: [String]
    var includeForce: [String]?
}

struct SkipCondition {
    var skipPrefix: String
    var allowPrefixes: [String]
}



// Conditions for some apps that need to include/exclude certain files/folders when names are more complicated
var conditions: [Condition] = [
    Condition(
        bundle_id: "comappledtxcode",
        include: ["comappledt", "xcode", "simulator"],
        exclude: ["comrobotsandpencilsxcodesapp", "comoneminutegamesxcodecleaner", "iohyperappxcodecleaner", "xcodesjson"],
        includeForce: ["\(home)/Library/Containers/com.apple.iphonesimulator.ShareExtension"]
    ),
    Condition(
        bundle_id: "comrobotsandpencilsxcodesapp",
        include: [],
        exclude: ["comappledtxcode", "comoneminutegamesxcodecleaner", "iohyperappxcodecleaner"]
    ),
    Condition(
        bundle_id: "iohyperappxcodecleaner",
        include: [],
        exclude: ["comrobotsandpencilsxcodesapp", "comoneminutegamesxcodecleaner", "comappledtxcode", "xcodesjson"]
    ),
    Condition(
        bundle_id: "uszoomxos",
        include: ["zoom"],
        exclude: []
    ),
    Condition(
        bundle_id: "combravebrowser",
        include: ["brave"],
        exclude: []
    ),
    Condition(
        bundle_id: "comoktamobile",
        include: ["okta"],
        exclude: []
    ),
    Condition(
        bundle_id: "comgooglechrome",
        include: ["google", "chrome"],
        exclude: ["iterm", "chromefeaturestate"]
    ),
    Condition(
        bundle_id: "commicrosoftedgemac",
        include: ["microsoft"],
        exclude: ["vscode", "rdc", "appcenter", "office", "oneauth"]
    ),
    Condition(
        bundle_id: "orgmozillafirefox",
        include: ["mozilla"],
        exclude: []
    ),
    Condition(
        bundle_id: "comlogioptionsplus",
        include: ["logi"],
        exclude: ["login", "logic"],
        includeForce: []
    ),
    Condition(
        bundle_id: "commicrosoftvscode",
        include: ["vscode"],
        exclude: [],
        includeForce: ["\(home)/Library/Application Support/Code"]
    ),
    Condition(
        bundle_id: "comfacebookarchondeveloperid",
        include: ["archonloginhelper"],
        exclude: []
    ),
    Condition(
        bundle_id: "euexelbanstats",
        include: [],
        exclude: ["video"]
    ),
    Condition(
        bundle_id: "jetbrains",
        include: ["jetbrains", "jcef"],
        exclude: []
    ),
]



// Skip com.apple files/folders since most are system originated, allow some for apps
let skipConditions: [SkipCondition] = [
    SkipCondition(
        skipPrefix: "comapple",
        allowPrefixes: ["comappleconfigurator", "comappledt", "comappleiwork", "comapplesfsymbols", "comappletestflight"]
    )
]


// Skip files/folders during reverse file search
let skipReverse = ["apple", "temporary", "btserver", "proapps", "scripteditor", "ilife", "livefsd", "siritoday", "addressbook", "animoji", "appstore", "askpermission", "callhistory", "clouddocs", "diskimages", "dock", "facetime", "fileprovider", "instruments", "knowledge", "mobilesync", "syncservices", "homeenergyd", "icloud", "icdd", "networkserviceproxy", "familycircle", "geoservices", "installation", "passkit", "sharedimagecache", "desktop", "mbuseragent", "swiftpm", "baseband", "coresimulator", "photoslegacyupgrade", "photosupgrade", "siritts", "ipod", "globalpreferences", "apmanalytics", "apmexperiment", "avatarcache", "byhost", "contextstoreagent", "mobilemeaccounts", "intentbuilderc", "loginwindow", "momc", "replayd", "sharedfilelistd", "clang", "audiocomponent", "csexattrcryptoservice", "livetranscriptionagent", "sandboxhelper", "statuskitagent", "betaenrollmentd", "contentlinkingd", "diagnosticextensionsd", "gamed", "heard", "homed", "itunescloudd", "lldb", "mds", "mediaanalysisd", "metrickitd", "mobiletimerd", "proactived", "ptpcamerad", "studentd", "talagent", "watchlistd", "apptranslocation", "xcrun", "ds_store", "caches", "crashreporter", "trash", "pearcleaner", "amsdatamigratortool", "arfilecache", "assistant", "chromium", "cloudkit", "webkit", "databases", "diagnostic", "cache", "gamekit", "homebrew", "logi", "microsoft", "mozilla", "sync", "google", "sentinel", "hexnode", "sentry", "tvappservices"]


// Function to load additional conditions from a GitHub JSON file
func loadConditionsFromGitHub() {
    let url = URL(string: "https://api.github.com/repos/alienator88/Pearcleaner/contents/conditions.json")!
    var request = URLRequest(url: url)
    request.setValue("application/vnd.github.VERSION.raw", forHTTPHeaderField: "Accept")
    request.setValue("2022-11-28", forHTTPHeaderField: "X-GitHub-Api-Version")

    URLSession.shared.dataTask(with: request) { data, response, error in
        if let data = data {
            do {
                // Assuming the JSON structure directly maps to an array of Condition
                let jsonObject = try JSONSerialization.jsonObject(with: data, options: [])
                if let conditionArray = jsonObject as? [[String: Any]] {
                    let jsonData = try JSONSerialization.data(withJSONObject: conditionArray, options: [])
                    let additionalConditions = try JSONDecoder().decode([Condition].self, from: jsonData)

                    if !additionalConditions.isEmpty {
                        DispatchQueue.main.async {
                            conditions += additionalConditions
                        }
                    }
                } else {
                    printOS("The data format is incorrect or empty for GitHub conditions processing.")
                }
            } catch {
                printOS("Failed to decode conditions JSON: \(error.localizedDescription)")
            }
        } else {
            printOS("Failed to fetch conditions data: \(error?.localizedDescription ?? "Unknown error")")
        }
    }.resume()
}

