////
////  SunburstChart.swift
////  Pearcleaner
////
////  Created by Alin Lupascu on 8/2/24.
////
//
//
//import SwiftUI
//import Charts
//
//final class Item: Identifiable {
//    let id = UUID()
//    let url: URL
//    let name: String
//    var size: Int64
//    let isDirectory: Bool?
//
//    init(url: URL, name: String, size: Int64, isDirectory: Bool = false) {
//        self.url = url
//        self.name = name
//        self.size = size
//        self.isDirectory = isDirectory
//    }
//}
//
//struct SunburstChart: View {
//    let chartWidth: CGFloat = 175
//    let items: [Item]
//
//    @State private var selectedTotal1: Double?
//    @State private var selectedSegment1: Item?
//
//    @State private var selectedTotal2: Double?
//    @State private var selectedSegment2: Item?
//
//    init(items: [Item]) {
//        self.items = items
//    }
//
//    var body: some View {
//        VStack {
//            Text(selectedText)
//                .font(.title)
//            Text(selectedSizeText)
//                .font(.title3)
//
//            ZStack {
//                Chart(getFiles()) { item in
//                    SectorMark(
//                        angle: .value("Size", Double(item.size)),
//                        innerRadius: .ratio(0.6),
//                        outerRadius: .ratio(0.9),
//                        angularInset: 1.5
//                    )
//                    .foregroundStyle(Color.blue.opacity(selectOpacity(item: item, selectedItem: selectedSegment2, ring: 2)))
//                }
//                .frame(width: chartWidth * 2, height: chartWidth * 2)
//                .chartAngleSelection(value: $selectedTotal2)
//                .onChange(of: selectedTotal2) { newValue in
//                    updateSelection(newValue: newValue, items: getFiles(), updateSelected: { selectedSegment2 = $0 })
//                    selectedSegment1 = nil
//                }
//
//                Chart(getDirectories()) { item in
//                    SectorMark(
//                        angle: .value("Size", Double(item.size)),
//                        innerRadius: .ratio(0.5),
//                        angularInset: 1.5
//                    )
//                    .foregroundStyle(Color.green.opacity(selectOpacity(item: item, selectedItem: selectedSegment1)))
//                }
//                .frame(width: chartWidth, height: chartWidth)
//                .chartAngleSelection(value: $selectedTotal1)
//                .onChange(of: selectedTotal1) { newValue in
//                    updateSelection(newValue: newValue, items: getDirectories(), updateSelected: { selectedSegment1 = $0 })
//                    selectedSegment2 = nil
//                }
//            }
//        }
//    }
//
//    private var selectedText: String {
//        if let selectedItem = selectedSegment1 ?? selectedSegment2 {
//            return selectedItem.name
//        } else {
//            return "File System Overview"
//        }
//    }
//
//    private var selectedSizeText: String {
//        if let selectedItem = selectedSegment1 ?? selectedSegment2 {
//            return ByteCountFormatter.string(fromByteCount: selectedItem.size, countStyle: .file)
//        } else {
//            return "Select a segment..."
//        }
//    }
//
//    private func getDirectories() -> [Item] {
//        return items.filter { $0.isDirectory == true }
//    }
//
//    private func getFiles() -> [Item] {
//        return items.filter { $0.isDirectory == false }
//    }
//
//    private func selectOpacity(item: Item, selectedItem: Item?, ring: Int = 1) -> Double {
//        if let selectedItem = selectedItem, selectedItem.id == item.id {
//            return 1.0
//        }
//        return ring == 1 ? 0.8 : 0.55
//    }
//
//    private func updateSelection(newValue: Double?, items: [Item], updateSelected: (Item?) -> Void) {
//        guard let newValue = newValue else {
//            updateSelected(nil)
//            return
//        }
//
//        var accumulatedSize: Double = 0
//        let selectedItem = items.first { item in
//            accumulatedSize += Double(item.size)
//            return newValue <= accumulatedSize
//        }
//
//        updateSelected(selectedItem)
//    }
//}
