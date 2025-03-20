//
//  LipoView.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 3/20/25.
//

import SwiftUI
import AlinFoundation

struct LipoView: View {
    @EnvironmentObject var appState: AppState
    @State private var selectAll: Bool = false
    @State private var selectedApps: Set<String> = []
    @State private var isProcessing: Bool = false

    // Filter the apps to only include universal ones
    var universalApps: [AppInfo] {
        appState.sortedApps.filter { $0.arch == .universal }
    }

    var body: some View {

        VStack(alignment: .leading, spacing: 20) {

            PearGroupBox(header: {
                HStack(alignment: .center, spacing: 15) {
                    Image(systemName: "square.split.1x2")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                        .symbolRenderingMode(.hierarchical)

                    VStack(alignment: .leading){
                        Text("App Thinning").font(.title).fontWeight(.bold)
                        Text("Strip unused architectures from universal app bundles")
                            .font(.callout).foregroundStyle(.primary.opacity(0.5))
                    }
                }
            }, content: {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("App thinning targets the Mach-O binaries in your universal apps and removes any unused architectures, such as x86_64 or arm64, leaving only the architectures your computer actually supports. The list shows only universal type apps, not your full app list.")
                    }

                    Spacer()

                    //                    VStack(alignment: .trailing, spacing: 5) {
                    //                        Text("Bundle Size")
                    //
                    //                    }


                }
            })

            // Global "Select All" checkbox
            HStack {
                Toggle("Select All", isOn: Binding(
                    get: {
                        Set(universalApps.map { $0.path.path }) == selectedApps
                    },
                    set: { newValue in
                        if newValue {
                            selectedApps = Set(universalApps.map { $0.path.path })
                        } else {
                            selectedApps.removeAll()
                        }
                    }
                ))
                .toggleStyle(SimpleCheckboxToggleStyle())
                .help("Select all universal apps")

                Spacer()

                Text("Number of apps here")
            }

            if universalApps.isEmpty {
                VStack(alignment: .center) {
                    Spacer()
                    Text("No universal apps found.").font(.title).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .init(horizontal: .center, vertical: .center))
                    Spacer()
                }
            } else {
                // List of universal apps with individual checkboxes
                ScrollView {
                    LazyVStack {
                        ForEach(universalApps, id: \.self) { app in
                            AppRowView(app: app, selectedApps: $selectedApps)
                        }
                    }
                }
            }


            // Button to start the thinning process on selected apps
            HStack {
                Spacer()

                if isProcessing {
                    ProgressView().controlSize(.small)
                }

                Button {
                    isProcessing = true
                    DispatchQueue.global(qos: .userInitiated).async {
                        var totalPreSize: UInt64 = 0
                        var totalPostSize: UInt64 = 0

                        for app in universalApps where selectedApps.contains(app.path.path) {
                            let (success, sizes) = thinAppBundleArchitecture(at: app.path, of: app.arch, multi: true)
                            if success, let sizes = sizes {
                                totalPreSize += sizes["pre"] ?? 0
                                totalPostSize += sizes["post"] ?? 0
                            }
                        }
                        let overallSavings = totalPreSize > 0 ? Int((Double(totalPreSize - totalPostSize) / Double(totalPreSize)) * 100) : 0

                        DispatchQueue.main.async {
                            showCustomAlert(
                                title: "Space Savings: \(overallSavings)%",
                                message: "The total space savings between all the thinned apps\nSize Before: \(formatByte(size: Int64(totalPreSize)).human)\nSize After: \(formatByte(size: Int64(totalPostSize)).human)",
                                style: .informational
                            )
                        }
                        isProcessing = false
                    }
                } label: {
                    Label("Start Thinning", systemImage: "scissors")
                        .padding(4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

            }

        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .padding(.top)
    }
}



struct AppRowView: View {
    let app: AppInfo
    @Binding var selectedApps: Set<String>
    @State private var sizeLoading: Bool = true
    @State private var savingsSize: UInt32 = 0
    @State private var fullSize: UInt32 = 0
    @AppStorage("settings.general.sizeType") var sizeType: String = "Real"

    var body: some View {
        HStack {
            Toggle(isOn: Binding(
                get: { selectedApps.contains(app.path.path) },
                set: { isSelected in
                    if isSelected {
                        selectedApps.insert(app.path.path)
                    } else {
                        selectedApps.remove(app.path.path)
                    }
                }
            )) {
                EmptyView()
            }
            .toggleStyle(SimpleCheckboxToggleStyle())

            VStack(alignment: .leading) {
                Text(app.appName).font(.title3)
                Text("Bundle Size: \(formatByte(size: app.bundleSize).human)").font(.callout).foregroundStyle(.secondary)
            }

            Spacer()



            VStack(alignment: .trailing) {
                Button {
                    NSWorkspace.shared.selectFile(app.path.path, inFileViewerRootedAtPath: app.path.deletingLastPathComponent().path)
                } label: {
                    Label("Show", systemImage: "folder")
                        .padding(4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)

                HStack(spacing: 0) {
                    Text("Binary Size: ")
                        .foregroundStyle(.blue)
                    Text("\(formatByte(size: Int64(fullSize)).human)")
                        .foregroundStyle(.primary)
                }
                HStack(spacing: 0) {
                    Text("Space Savings: ")
                        .foregroundStyle(.yellow)
                    Text("\(formatByte(size: Int64(savingsSize)).human)")
                        .foregroundStyle(.primary)
                }
                .font(.callout)
            }

        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(.quaternary.opacity(0.3))
            .shadow(radius: 2))
        .onAppear {
            DispatchQueue.global(qos: .userInitiated).async {
                let infoPlistPath = app.path.appendingPathComponent("Contents/Info.plist")
                if let infoPlist = NSDictionary(contentsOf: infoPlistPath) as? [String: Any],
                   let bundleExecutable = infoPlist["CFBundleExecutable"] as? String {
                    let executablePath = app.path.appendingPathComponent("Contents/MacOS/\(bundleExecutable)")
                    if let sliceSizes = getArchitectureSliceSizes(from: executablePath.path) {
                        DispatchQueue.main.async {
                            self.savingsSize = isOSArm() ? sliceSizes.intel : sliceSizes.arm
                            self.fullSize = sliceSizes.full
                        }
                    } else {
                        DispatchQueue.main.async {
                            self.savingsSize = 0
                            self.fullSize = 0
                        }
                    }
                } else {
                    printOS("App Thinning: Failed to read Info.plist or CFBundleExecutable not found when loading slice size")
                }
            }
        }
    }

}


public func getArchitectureSliceSizes(from executablePath: String) -> (arm: UInt32, intel: UInt32, full: UInt32)? {
    do {
        let fileData = try Data(contentsOf: URL(fileURLWithPath: executablePath))
        let fullSize = UInt32(fileData.count)
        let FAT_MAGIC: UInt32 = 0xcafebabe
        let header = fileData.subdata(in: 0..<8).withUnsafeBytes { ptr in
            FatHeader(
                magic: ptr.load(fromByteOffset: 0, as: UInt32.self).bigEndian,
                numArchitectures: ptr.load(fromByteOffset: 4, as: UInt32.self).bigEndian
            )
        }

        var armSize: UInt32 = 0
        var intelSize: UInt32 = 0

        if header.magic == FAT_MAGIC {
            var offset = 8
            for _ in 0..<header.numArchitectures {
                let arch = fileData.subdata(in: offset..<(offset + 20)).withUnsafeBytes { ptr in
                    FatArch(
                        cpuType: ptr.load(fromByteOffset: 0, as: UInt32.self).bigEndian,
                        cpuSubtype: ptr.load(fromByteOffset: 4, as: UInt32.self).bigEndian,
                        offset: ptr.load(fromByteOffset: 8, as: UInt32.self).bigEndian,
                        size: ptr.load(fromByteOffset: 12, as: UInt32.self).bigEndian,
                        align: ptr.load(fromByteOffset: 16, as: UInt32.self).bigEndian
                    )
                }

                if arch.cpuType == 0x100000C {
                    armSize = arch.size
                } else if arch.cpuType == 0x01000007 {
                    intelSize = arch.size
                }
                offset += 20
            }
        } else {
            // For a thin binary, assume the whole file is the slice.
            let cpuType = fileData.subdata(in: 4..<8).withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            if cpuType == 0x100000C {
                armSize = fullSize
            } else if cpuType == 0x01000007 {
                intelSize = fullSize
            }
        }

        return (arm: armSize, intel: intelSize, full: fullSize)
    } catch {
        printOS("Error getting architecture slice sizes: \(error)")
        return nil
    }
}
