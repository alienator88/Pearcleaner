//
//  TreeMap.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 8/1/24.
//

import Foundation
import SwiftUI
import AlinFoundation



struct TreeMapChart: View {
    let items: [Item]
    var onItemSelected: (Item) -> Void
    @Binding var hoveredItem: Item?
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    var displayedItems: [Item] {
        items//.filter { $0.size >= 1_048_576 } // Filter to keep only items with size >= 1MB
            .sorted(by: { $0.size > $1.size }) // Then sort the remaining items by size
    }

    var body: some View {

        GeometryReader { proxy in

            let ld = calculateLayout(
                w: proxy.size.width,
                h: proxy.size.height,
                data: displayedItems.map { Double($0.size) },
                from: 0
            )

            TreeMapView(ld: ld, items: displayedItems, onItemSelected: onItemSelected, hoveredItem: $hoveredItem)

        }
        .ignoresSafeArea()
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct TreeMapView: View {
    let ld: LayoutData
    let items: [Item]
    var onItemSelected: (Item) -> Void
    @Binding var hoveredItem: Item?
    @State private var hoveredIndex: Int?
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    var body: some View {
        Group {
            if ld.direction == .h {
                HStack(spacing: 0) {
                    VStack(spacing: 0) {
                        content
                    }
                    if let child = ld.child {
                        TreeMapView(ld: child, items: items, onItemSelected: onItemSelected, hoveredItem: $hoveredItem)
                    }
                }
            } else {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        content
                    }

                    if let child = ld.child {
                        TreeMapView(ld: child, items: items, onItemSelected: onItemSelected, hoveredItem: $hoveredItem)
                    }
                }
            }
        }
    }

    private var content: some View {
        ForEach(0..<ld.content.count, id: \.self) { i in
            let file = items[ld.content[i].index]
//            let maxDimension = max(ld.content[i].w, ld.content[i].h) / 5

            ZStack {
                Rectangle()
                //                    .foregroundStyle(randomColor())
                //                    .foregroundStyle(colorForItem(file))
                    .fill(gradientForItem(file))
                    .brightness(hoveredIndex == i ? 0.1 : 0)
                    .frame(width: ld.content[i].w, height: ld.content[i].h)
                    .border(.black, width: 0.5)
                    .onTapGesture {
                        onItemSelected(file)
                    }
                    .overlay {

                        if hoveredIndex == i {
                            VStack {
                                Text(file.name)
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(2)
                                Text("\(formatSize(file.size))")
                                    .minimumScaleFactor(0.5)
                                    .lineLimit(1)
                            }
                            .padding(5)
                            .padding(.horizontal, 2)
                            .background(.background.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .zIndex(1)

                        }
                    }
            }
            .onHover { isHovering in
                withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                    hoveredIndex = isHovering ? i : nil
                    hoveredItem = isHovering ? file : nil
                }
            }

        }
    }

//    private func colorForItem(_ item: Item) -> Color {
//        item.isDirectory ? .blue : .gray
//    }

    private func gradientForItem(_ item: Item) -> LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [Color.cyan, Color.blue]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
//        item.isDirectory ? LinearGradient(
//            gradient: Gradient(colors: [Color.cyan, Color.blue]),
//            startPoint: .topLeading,
//            endPoint: .bottomTrailing
//        ) : LinearGradient(
//            gradient: Gradient(colors: [Color.pink, Color.orange]),
//            startPoint: .topLeading,
//            endPoint: .bottomTrailing
//        )
    }

}


func formatSize(_ size: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useAll]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: size)
}

func randomColor() -> Color {
    Color(hue: Double.random(in: 0.0...1.0),
          saturation: Double.random(in: 0.08...0.18),
          brightness: Double.random(in: 0.90...1.0))
}

final class Item: Identifiable {
    let url: URL
    let name: String
    var size: Int64
    let isDirectory: Bool?

    init(url: URL, name: String, size: Int64, isDirectory: Bool = false) {
        self.url = url
        self.name = name
        self.size = size
        self.isDirectory = isDirectory
    }
}

//MARK: Layout Generator ============================================================================================================

// Layout
enum Direction {
    case h
    case v
}

class LayoutData {
    var direction: Direction = .h
    var content: [(index: Int, w: Double, h: Double)] = []
    var child: LayoutData? = nil
}

func calculateLayout(w: Double, h: Double, data: [Double], from: Int) -> LayoutData {

    let returnData = LayoutData()
    if data.isEmpty {
        print("TreeMap layout data is empty")
        return returnData
    }
    let dataToArea = w * h / data[from...].reduce(0.0, +)
    if w < h {
        returnData.direction = .v
    } else {
        returnData.direction = .h
    }
    let mainLength = min(w, h)
    var currentIndex = from
    var area = data[currentIndex] * dataToArea
    var crossLength = area / mainLength

    var cellRatio = mainLength / crossLength
    cellRatio = max(cellRatio, 1.0 / cellRatio)

    while currentIndex + 1 < data.count {
        let newIndex = currentIndex + 1
        let newArea = area + data[newIndex] * dataToArea
        let newCrossLength = newArea / mainLength
        var newCellRatio = data[newIndex] * dataToArea / newCrossLength / newCrossLength
        newCellRatio = max(newCellRatio, 1.0 / newCellRatio)

        if newCellRatio < cellRatio {
            currentIndex = newIndex
            area = newArea
            crossLength = newCrossLength
            cellRatio = newCellRatio
        } else {
            break
        }
    }

    switch returnData.direction {
    case .h:
        for i in from...currentIndex {
            returnData.content.append((
                index: i,
                w: crossLength,
                h: data[i] * dataToArea / crossLength))
        }
    case .v:
        for i in from...currentIndex {
            returnData.content.append((
                index: i,
                w: data[i] * dataToArea / crossLength,
                h: crossLength))
        }
    }

    if currentIndex != data.count - 1 {
        switch returnData.direction {
        case .h:
            returnData.child = calculateLayout(
                w: w - crossLength,
                h: h,
                data: data,
                from: currentIndex + 1)
        case .v:
            returnData.child = calculateLayout(
                w: w,
                h: h - crossLength,
                data: data,
                from: currentIndex + 1)
        }
    }
    return returnData
}
