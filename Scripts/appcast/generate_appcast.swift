// Generates the Sparkle 2 appcast.xml for Pearcleaner fork releases from a
// GitHub Release DMG.
//
// swift generate_appcast.swift <output.xml> <appcast-url> <ed25519-seed-b64> <item> [item ...]
//   item    source|url|version|build  (or source|version|build when the
//           enclosure URL is the source itself)
//   source  local file path or download URL of the release DMG to sign
//   url     enclosure URL Sparkle will download from
//   version marketing version, e.g. 5.6.0
//   build   CFBundleVersion of that release, e.g. 124 (must grow per release)

import CryptoKit
import Foundation

func fail(_ msg: String) -> Never {
    FileHandle.standardError.write(Data(("error: " + msg + "\n").utf8))
    exit(1)
}

func esc(_ s: String) -> String {
    s.replacingOccurrences(of: "&", with: "&amp;")
     .replacingOccurrences(of: "<", with: "&lt;")
     .replacingOccurrences(of: ">", with: "&gt;")
     .replacingOccurrences(of: "\"", with: "&quot;")
}

func rfc1123(_ date: Date) -> String {
    let f = DateFormatter()
    f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss ZZ"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f.string(from: date)
}

guard CommandLine.arguments.count >= 5 else {
    fail("usage: generate_appcast.swift <output.xml> <appcast-url> <seed-b64> <source|url|version|build> [item ...]")
}

let output = CommandLine.arguments[1]
let appcastURL = CommandLine.arguments[2].trimmingCharacters(in: .whitespaces)
let seedB64 = CommandLine.arguments[3].trimmingCharacters(in: .whitespaces)

guard let seedData = Data(base64Encoded: seedB64), seedData.count == 32 else {
    fail("seed must be base64 of 32 bytes")
}
let privateKey: Curve25519.Signing.PrivateKey
do {
    privateKey = try Curve25519.Signing.PrivateKey(rawRepresentation: seedData)
} catch {
    fail("bad seed: \(error)")
}

struct Item {
    let url: String
    let version: String
    let build: Int
    let length: Int
    let signature: String
}

var items: [Item] = []

for arg in CommandLine.arguments[4...] {
    let parts = arg.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
    let source: String, url: String, version: String, buildStr: String
    switch parts.count {
    case 4:
        source = parts[0]
        url = parts[1]
        version = parts[2]
        buildStr = parts[3]
    case 3:
        source = parts[0]
        url = parts[0]
        version = parts[1]
        buildStr = parts[2]
    default:
        fail("argument '\(arg)' must be source|url|version|build")
    }
    guard let build = Int(buildStr) else { fail("build must be an integer in '\(arg)'") }

    let data: Data
    do {
        if source.hasPrefix("http") {
            guard let url = URL(string: source) else { fail("bad url \(source)") }
            // Plain Data(contentsOf:) sends no User-Agent and GitHub rejects
            // those asset downloads with 403
            var req = URLRequest(url: url)
            req.setValue("PearcleanerAppcastGen", forHTTPHeaderField: "User-Agent")
            let sem = DispatchSemaphore(value: 0)
            var fetched: Data?
            var fetchError: Error?
            let task = URLSession.shared.dataTask(with: req) { d, _, err in
                fetched = d
                fetchError = err
                sem.signal()
            }
            task.resume()
            sem.wait()
            if let fetchError {
                fail("fetch \(source): \(fetchError)")
            }
            guard let fetched, !fetched.isEmpty else { fail("empty download from \(source)") }
            data = fetched
        } else {
            data = try Data(contentsOf: URL(fileURLWithPath: source))
        }
    } catch {
        fail("load \(source): \(error)")
    }

    let signature = try! privateKey.signature(for: data).base64EncodedString()
    items.append(Item(url: url, version: version, build: build, length: data.count, signature: signature))
}

guard !items.isEmpty else { fail("no items") }

let sorted = items.sorted { $0.build > $1.build }

var xml = """
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
<channel>
<title>Pearcleaner Fork</title>
<link>\(esc(appcastURL))</link>
<description>Pearcleaner fork release feed</description>
<language>en</language>

"""

for item in sorted {
    xml += """
<item>
<title>Pearcleaner \(esc(item.version)) (\(item.build))</title>
<description>Pearcleaner fork build \(esc(item.version)) (\(item.build))</description>
<pubDate>\(rfc1123(Date()))</pubDate>
<sparkle:version>\(item.build)</sparkle:version>
<sparkle:shortVersionString>\(esc(item.version))</sparkle:shortVersionString>
<sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
<enclosure
url="\(esc(item.url))"
sparkle:edSignature="\(item.signature)"
length="\(item.length)"
type="application/x-apple-diskimage"
/>
</item>

"""
}

xml += """
</channel>
</rss>
"""

do {
    try xml.write(to: URL(fileURLWithPath: output), atomically: true, encoding: .utf8)
    print("wrote \(output) with \(sorted.count) item(s)")
} catch {
    fail("write \(output): \(error)")
}
