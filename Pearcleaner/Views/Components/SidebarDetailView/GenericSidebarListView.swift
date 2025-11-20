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
    let categories: [(title: String, filter: (Item) -> Bool, initiallyExpanded: Bool)]

    // Bindings
    @Binding var searchText: String

    // Customization
    let searchFilter: ((Item, String) -> Bool)?
    let emptyMessage: String
    let noResultsMessage: String
    let isLoading: Bool
    let loadingMessage: String
    @ViewBuilder let itemView: (Item) -> Content

    // Internal state
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("settings.general.sidebarWidth") private var sidebarWidth: Double = 265
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true
    @State private var dimensionStart: Double?

    init(
        items: [Item],
        categories: [(title: String, filter: (Item) -> Bool, initiallyExpanded: Bool)],
        searchText: Binding<String>,
        searchFilter: ((Item, String) -> Bool)? = nil,
        emptyMessage: String = "No items found",
        noResultsMessage: String = "No results",
        isLoading: Bool = false,
        loadingMessage: String = "Loading...",
        @ViewBuilder itemView: @escaping (Item) -> Content
    ) {
        self.items = items
        self.categories = categories
        self._searchText = searchText
        self.searchFilter = searchFilter
        self.emptyMessage = emptyMessage
        self.noResultsMessage = noResultsMessage
        self.isLoading = isLoading
        self.loadingMessage = loadingMessage
        self.itemView = itemView
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            if items.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    if isLoading {
                        ProgressView()
                            .controlSize(.regular)
                        Text(loadingMessage)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .font(.callout)
                    } else {
                        Text(emptyMessage)
                            .foregroundStyle(ThemeColors.shared(for: colorScheme).secondaryText)
                            .font(.callout)
                    }
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {

                SearchBarSidebar(search: $searchText, menu: false)
                    .padding()
                    .padding(.top, 20)

                CategorizedListView(
                    categories: categorizedItems,
                    itemView: itemView
                )
                .padding([.bottom, .horizontal], 5)
            }
        }
        .frame(width: sidebarWidth)
        .ifGlassMain()
        .padding([.leading, .vertical], 8)
        .ignoresSafeArea(edges: .top)
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
                let minWidth: Double = 220
                let maxWidth: Double = 350
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
            // Use custom searchFilter if provided
            if let customFilter = searchFilter {
                return items.filter { customFilter($0, searchText) }
            }
            // Otherwise, check if items conform to FuzzySearchable and use fuzzy matching
            else if let fuzzySearchableItems = items as? [any FuzzySearchable] {
                return fuzzySearchableItems.filter { item in
                    item.fuzzyMatch(query: searchText).weight > 0
                } as? [Item] ?? []
            }
            // Fallback: no filtering (return empty to show "no results")
            else {
                return []
            }
        }
    }

    private var categorizedItems: [(title: String, items: [Item], initiallyExpanded: Bool)] {
        return categories.map { category in
            let categoryItems = filteredItems.filter(category.filter)
            return (category.title, categoryItems, category.initiallyExpanded)
        }
    }
}

// MARK: - Categorized List View

struct CategorizedListView<Item: Identifiable & Hashable, Content: View>: View {
    let categories: [(title: String, items: [Item], initiallyExpanded: Bool)]
    @ViewBuilder let itemView: (Item) -> Content
    @AppStorage("settings.interface.scrollIndicators") private var scrollIndicators: Bool = false
    @Environment(\.colorScheme) var colorScheme

    // Split categories: those with items go above divider, empty/Unsupported go below
    private var categoriesAboveDivider: [(title: String, items: [Item], initiallyExpanded: Bool)] {
        categories.filter { $0.items.count > 0 && $0.title != "Unsupported" }
    }

    private var categoriesBelowDivider: [(title: String, items: [Item], initiallyExpanded: Bool)] {
        categories.filter { $0.items.count == 0 || $0.title == "Unsupported" }
    }

    private var shouldShowDivider: Bool {
        !categoriesAboveDivider.isEmpty && !categoriesBelowDivider.isEmpty
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Categories with updates
                ForEach(Array(categoriesAboveDivider.enumerated()), id: \.offset) { index, category in
                    GenericSectionView(
                        title: category.title,
                        count: category.items.count,
                        items: category.items,
                        initiallyExpanded: category.initiallyExpanded,
                        itemView: itemView
                    )
                    .padding(.top, index > 0 ? 5 : 0)
                }

                // Divider (only if there are categories both above and below)
                if shouldShowDivider {
                    Divider()
                        .padding(10)
                }

                // Empty categories and Unsupported
                ForEach(Array(categoriesBelowDivider.enumerated()), id: \.offset) { index, category in
                    GenericSectionView(
                        title: category.title,
                        count: category.items.count,
                        items: category.items,
                        initiallyExpanded: category.initiallyExpanded,
                        itemView: itemView
                    )
                    .padding(.top, (shouldShowDivider && index == 0) ? 0 : 5)
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
    let initiallyExpanded: Bool
    @ViewBuilder let itemView: (Item) -> Content

    @State private var showItems: Bool
    @AppStorage("settings.interface.animationEnabled") private var animationEnabled: Bool = true

    init(title: String, count: Int, items: [Item], initiallyExpanded: Bool = true, @ViewBuilder itemView: @escaping (Item) -> Content) {
        self.title = title
        self.count = count
        self.items = items
        self.initiallyExpanded = initiallyExpanded
        self.itemView = itemView
        self._showItems = State(initialValue: initiallyExpanded)
    }

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
