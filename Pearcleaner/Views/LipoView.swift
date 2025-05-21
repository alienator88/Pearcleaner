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
    @State private var savingsAllApps: UInt32 = 0
    @State private var binaryAllApps: UInt32 = 0
    @State private var sliceSizesByPath = [String:(binary: UInt32,savings:UInt32)]()
    @State private var totalSpaceSaved: UInt64 = 0

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


                    HStack(){
                        Text("Lipo").font(.title).fontWeight(.bold)
                        BetaBadge()
                        Spacer()
                        Text("Saved: \(formatByte(size: Int64(totalSpaceSaved)).human)").foregroundStyle(.green)
                    }
                }
                .padding(.horizontal, 5)
            }, content: {
                VStack(alignment: .leading, spacing: 10) {
                    Text("App lipo targets the Mach-O binaries inside your universal app bundles and removes any unused architectures, such as x86_64 or arm64, leaving only the architectures your computer actually supports. The list shows only universal type apps, not your full app list.")
                    Text("After lipo, the green portion will be removed from your app's binary. It's recommended to open an app at least once before lipo to make sure macOS has cached the signature. **Privileged Helper is required to perform this action on certain applications.**")
                        .foregroundStyle(.secondary)
                        .font(.callout)
                }
            })

            HStack() {
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

                Rectangle().fill(.green).frame(width: 10, height: 10)
                Text("Savings Size").foregroundStyle(.secondary).padding(.trailing)
                Rectangle().fill(.orange).frame(width: 10, height: 10)
                Text("Binary Size").foregroundStyle(.secondary)

                Spacer()

                Text("\(universalApps.count) universal apps")
            }
            .padding(.horizontal)

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
                            let (bin, sav) = sliceSizesByPath[app.path.path] ?? (0, 0)
                            AppRowView(app: app, selectedApps: $selectedApps, savingsSize: sav, binarySize: bin)
                        }
                    }
                }
            }


            // Button to start the lipo process on selected apps
            HStack {

                Text("\(formatByte(size: Int64(savingsAllApps)).human)").foregroundStyle(.green)
                    .help("Total possible savings between all the apps")

                Spacer()

                Button {
                    startLipo()
                } label: {
                    HStack {
                        Text("Start Lipo")
                        if isProcessing {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "scissors")
                        }
                    }
                    .frame(minWidth: 100)
                    .padding(4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)

                Spacer()

                Text("\(formatByte(size: Int64(binaryAllApps)).human)").foregroundStyle(.orange)
                    .help("Total binary size between all the apps")


            }

        }
        .frame(maxWidth: .infinity)
        .padding(30)
        .padding(.top)
        .onAppear { calculateAllSizes() }
    }

    private func calculateAllSizes() {
        DispatchQueue.global(qos: .userInitiated).async {
            var temp = [String:(UInt32,UInt32)]()
            for app in universalApps {
                if let execURL = app.executableURL,
                   let sizes = getArchitectureSliceSizes(from: execURL.path) {
                    temp[app.path.path] = (sizes.full, isOSArm() ? sizes.intel : sizes.arm)
                }
            }
            DispatchQueue.main.async {
                sliceSizesByPath = temp
                savingsAllApps = temp.values.reduce(0) { $0 + $1.1 }
                binaryAllApps = temp.values.reduce(0) { $0 + $1.0 }
            }
        }
    }

    private func startLipo() {
        isProcessing = true
        DispatchQueue.global(qos: .userInitiated).async {
            var totalPreSize: UInt64 = 0
            var totalPostSize: UInt64 = 0

            for app in universalApps where selectedApps.contains(app.path.path) {
                let (success, sizes) = thinAppBundleArchitecture(at: app.path, of: app.arch, multi: true)
                if success, let sizes = sizes {
                    totalPreSize += sizes["pre"] ?? 0
                    totalPostSize += sizes["post"] ?? 0
                    totalSpaceSaved += (sizes["pre"] ?? 0) - (sizes["post"] ?? 0)
                }
            }
            let overallSavings = totalPreSize > 0 ? Int((Double(totalPreSize - totalPostSize) / Double(totalPreSize)) * 100) : 0

            let titleFormat = NSLocalizedString("Space Savings: %d%%\nTotal Space Saved: %@", comment: "Lipo completion title")
            let messageFormat = NSLocalizedString("The total space savings between all the lipo'd apps\nSize Before: %@\nSize After: %@", comment: "Lipo completion message")

            let title = String(format: titleFormat, overallSavings, formatByte(size: Int64(totalSpaceSaved)).human)
            let message = String(format: messageFormat, formatByte(size: Int64(totalPreSize)).human, formatByte(size: Int64(totalPostSize)).human)


            DispatchQueue.main.async {
                showCustomAlert(title: title, message: message, style: .informational)
            }
            isProcessing = false
        }
    }
}



struct AppRowView: View {
    let app: AppInfo
    @Binding var selectedApps: Set<String>
    let savingsSize: UInt32
    let binarySize: UInt32
    @State private var sizeLoading: Bool = true
    @State private var isHovered: Bool = false
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

            VStack {
                HStack {

                    if let icon = app.appIcon {
                        Image(nsImage: icon)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 20, height: 20)
                    }

                    Text(app.appName).font(.title3)

                    if binarySize > 0 && savingsSize > 0 {
                        Text("**\(Int((Double(savingsSize) / Double(binarySize)) * 100))%** savings")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    HStack(spacing: 0) {
                        Text("Bundle Size: ")
                            .foregroundStyle(.gray)
                        Text("\(formatByte(size: Int64(app.bundleSize)).human)")
                            .foregroundStyle(.primary)
                            .frame(minWidth: 50, alignment: .trailing)
                    }
                    .font(.callout)

                }

                HorizontalSizeBarView(binarySize: binarySize, savingsSize: savingsSize)
                    .frame(maxWidth: .infinity)

                HStack {
                    Text("\(formatByte(size: Int64(savingsSize)).human)")
                        .foregroundStyle(.green)

                    Spacer()

                    Text("\(formatByte(size: Int64(binarySize)).human)")
                        .foregroundStyle(.orange)
                }
                .font(.callout)

            }

        }

        .padding()
        .background(RoundedRectangle(cornerRadius: 10)
            .fill(.quaternary.opacity(isHovered ? 0.5 : 0.3))
            .shadow(radius: 2))
        .onTapGesture {
            NSWorkspace.shared.selectFile(app.path.path, inFileViewerRootedAtPath: app.path.deletingLastPathComponent().path)
        }
        .onHover { hovered in
            isHovered = hovered
        }
    }
}



struct HorizontalSizeBarView: View {
    let binarySize: UInt32
    let savingsSize: UInt32

    var body: some View {
        GeometryReader { geo in
            let totalWidth = geo.size.width
            let binaryWidth = totalWidth * (Double(binarySize) / Double(binarySize))
            let savingsWidth = binaryWidth * (Double(savingsSize) / Double(binarySize))

            RoundedRectangle(cornerRadius: 4).fill(Color.orange)
                .frame(width: .infinity, height: 4)
                .padding(2)
                .overlay(
                    RoundedRectangle(cornerRadius: 4).strokeBorder(Color.gray, lineWidth: 1),
                    alignment: .center
                )
                .overlay (
                    RoundedRectangle(cornerRadius: 4).fill(Color.green)
                        .frame(width: savingsWidth, height: 4)
                        .padding(2),
                    alignment: .leading
                )
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
            // For a lipo'd binary, assume the whole file is the slice.
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
