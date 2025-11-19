//
//  GenericSidebarListView.swift
//  Pearcleaner
//
//  Created as a reusable component extracted from AppSearchView
//

import AlinFoundation
import SwiftUI

struct GenericSidebarListView<Item: Identifiable & Hashable, Content: View>: View {
    // Data
    let items: [Item]
    let categories: [(title: String, filter: (Item) -> Bool)]

    // Bindings
    @Binding var searchText: String
    @Binding var sidebarWidth: Double

    // Customization
    let searchFilter: (Item, String) -> Bool
    let emptyMessage: String
    let noResultsMessage: String
    @ViewBuilder let itemView: (Item) -> Content

    // Internal state
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @State private var dimensionStart: Double?

    init(
        items: [Item],
        categories: [(title: String, filter: (Item) -> Bool)],
        searchText: Binding<String>,
        sidebarWidth: Binding<Double>,
        searchFilter: @escaping (Item, String) -> Bool,
        emptyMessage: String = "No items found",
        noResultsMessage: String = "No results",
        @ViewBuilder itemView: @escaping (Item) -> Content
    ) {
        self.items = items
        self.categories = categories
        self._searchText = searchText
        self._sidebarWidth = sidebarWidth
        self.searchFilter = searchFilter
        self.emptyMessage = emptyMessage
        self.noResultsMessage = noResultsMessage
        self.itemView = itemView
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if items.isEmpty {
                VStack {
                    Spacer()
                    Text(emptyMessage)
                        .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                        .font(.callout)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {

                SearchBarSidebar(search: $searchText)
                    .padding()
                    .padding(.top, 20)

                if !filteredItems.isEmpty {
                    CategorizedListView(
                        categories: categorizedItems,
                        itemView: itemView
                    )
                    .padding([.bottom, .horizontal], 5)
                } else {
                    VStack {
                        Spacer()
                        Text(noResultsMessage)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .font(.title2)
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .overlay(alignment: .trailing) {
            // Invisible resize handle on the trailing edge
            Rectangle()
                .fill(Color.clear)
                .frame(width: 10)
                .contentShape(Rectangle())
                .offset(x: 5)  // Center on the edge
                .onHover { inside in
                    if inside {
                        NSCursor.resizeLeftRight.push()
                    } else {
                        NSCursor.pop()
                    }
                }
                .contextMenu {
                    Button("Reset Size") {
                        sidebarWidth = 265
                    }
                }
                .gesture(sidebarDragGesture)
                .help("Right click to reset size")
        }
    }

    private var sidebarDragGesture: some Gesture {
        DragGesture(minimumDistance: 5, coordinateSpace: .global)
            .onChanged { val in
                if dimensionStart == nil {
                    dimensionStart = sidebarWidth
                }
                let delta = val.location.x - val.startLocation.x
                let newDimension = dimensionStart! + Double(delta)

                // Standard range for sidebar width
                let minWidth: Double = 240
                let maxWidth: Double = 640
                let newWidth = max(minWidth, min(maxWidth, newDimension))

                sidebarWidth = newWidth

                NSCursor.closedHand.set()
            }
            .onEnded { val in
                dimensionStart = nil
                NSCursor.arrow.set()
            }
    }

    private var filteredItems: [Item] {
        if searchText.isEmpty {
            return items
        } else {
            return items.filter { searchFilter($0, searchText) }
        }
    }

    private var categorizedItems: [(title: String, items: [Item])] {
        return categories.compactMap { category in
            let categoryItems = filteredItems.filter(category.filter)
            return categoryItems.isEmpty ? nil : (category.title, categoryItems)
        }
    }
}

// MARK: - Categorized List View

struct CategorizedListView<Item: Identifiable & Hashable, Content: View>: View {
    let categories: [(title: String, items: [Item])]
    @ViewBuilder let itemView: (Item) -> Content
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(categories.enumerated()), id: \.offset) { index, category in
                    GenericSectionView(
                        title: category.title,
                        count: category.items.count,
                        items: category.items,
                        itemView: itemView
                    )
                    .padding(.top, index > 0 ? 5 : 0)
                }
            }
        }
        .scrollIndicators(scrollIndicators ? .automatic : .never)
    }
}

// MARK: - Generic Section View

struct GenericSectionView<Item: Identifiable & Hashable, Content: View>: View {
    let title: String
    let count: Int
    let items: [Item]
    @ViewBuilder let itemView: (Item) -> Content

    @State private var showItems: Bool = true
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            Header(title: title, count: count)
                .padding(.leading, 5)
                .onTapGesture {
                    withAnimation(Animation.easeInOut(duration: animationEnabled ? 0.35 : 0)) {
                        showItems.toggle()
                    }
                }

            if showItems {
                ForEach(items) { item in
                    itemView(item)
                        .transition(.opacity)
                }
            }
        }
    }
}
