//
//  SegmentedPicker.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 4/17/24.
//

import SwiftUI

public struct SegmentedPicker<Element, Content, Selection>: View
where
Content: View,
Selection: View {

    public typealias Data = [Element]

    @State private var frames: [CGRect]
    @Binding private var selectedIndex: Data.Index?

    private let data: Data
    private let selection: () -> Selection
    private let content: (Data.Element, Bool) -> Content
    private let selectionAlignment: VerticalAlignment

    public init(_ data: Data,
                selectedIndex: Binding<Data.Index?>,
                selectionAlignment: VerticalAlignment = .center,
                @ViewBuilder content: @escaping (Data.Element, Bool) -> Content,
                @ViewBuilder selection: @escaping () -> Selection) {

        self.data = data
        self.content = content
        self.selection = selection
        self._selectedIndex = selectedIndex
        self._frames = State(wrappedValue: Array(repeating: .zero,
                                                 count: data.count))
        self.selectionAlignment = selectionAlignment
    }

    public var body: some View {
        ZStack(alignment: Alignment(horizontal: .horizontalCenterAlignment,
                                    vertical: selectionAlignment)) {

            if let selectedIndex = selectedIndex {
                selection()
                    .frame(width: frames[selectedIndex].width,
                           height: frames[selectedIndex].height)
                    .alignmentGuide(.horizontalCenterAlignment) { dimensions in
                        dimensions[HorizontalAlignment.center]
                    }
            }

            HStack(spacing: 0) {
                ForEach(data.indices, id: \.self) { index in
                    Button(action: { selectedIndex = index },
                           label: { content(data[index], selectedIndex == index) }
                    )
                    .buttonStyle(PlainButtonStyle())
                    .background(GeometryReader { proxy in
                        Color.clear.onAppear { frames[index] = proxy.frame(in: .global) }
                    })
                    .alignmentGuide(.horizontalCenterAlignment,
                                    isActive: selectedIndex == index) { dimensions in
                        dimensions[HorizontalAlignment.center]
                    }
                }
            }
        }
    }
}


extension HorizontalAlignment {
    private enum CenterAlignmentID: AlignmentID {
        static func defaultValue(in dimension: ViewDimensions) -> CGFloat {
            return dimension[HorizontalAlignment.center]
        }
    }

    static var horizontalCenterAlignment: HorizontalAlignment {
        HorizontalAlignment(CenterAlignmentID.self)
    }
}


extension View {
    @ViewBuilder
    @inlinable func alignmentGuide(_ alignment: HorizontalAlignment,
                                   isActive: Bool,
                                   computeValue: @escaping (ViewDimensions) -> CGFloat) -> some View {
        if isActive {
            alignmentGuide(alignment, computeValue: computeValue)
        } else {
            self
        }
    }

    @ViewBuilder
    @inlinable func alignmentGuide(_ alignment: VerticalAlignment,
                                   isActive: Bool,
                                   computeValue: @escaping (ViewDimensions) -> CGFloat) -> some View {

        if isActive {
            alignmentGuide(alignment, computeValue: computeValue)
        } else {
            self
        }
    }
}


//                    SegmentedPicker(
//                        ["Alpha", "Size"],
//                        selectedIndex: Binding(
//                            get: { selectedSortAlpha ? 0 : 1 },
//                            set: { newIndex in
//                                withAnimation(.easeInOut(duration: 0.3)) {
//                                    selectedSortAlpha = (newIndex == 0)
//                                }
//                            }),
//                        selectionAlignment: .bottom,
//                        content: { item, isSelected in
//                            Text(item)
//                                .font(.callout)
//                                .foregroundColor(isSelected ? .primary : .primary.opacity(0.5))
//                                .padding(.horizontal)
//                                .padding(.bottom, 5)
//                                .frame(width: 75)
//
//                        },
//                        selection: {
//                            VStack(spacing: 0) {
//                                Spacer()
//                                Color("pear").frame(height: 1)
//                            }
//                        })


//                    SegmentedPicker(
//                        ["Real", "Logical", "Finder"],
//                        selectedIndex: Binding(
//                            get: {
//                                switch sizeType {
//                                case "Real": return 0
//                                case "Logical": return 1
//                                case "Finder": return 2
//                                default: return 0
//                                }
//                            },
//                            set: { newIndex in
//                                withAnimation(.easeInOut(duration: 0.3)) {
//                                    switch newIndex {
//                                    case 0: sizeType = "Real"
//                                    case 1: sizeType = "Logical"
//                                    case 2: sizeType = "Finder"
//                                    default: sizeType = "Real"
//                                    }
//                                }
//                            }),
//                        selectionAlignment: .bottom,
//                        content: { item, isSelected in
//                            Text(item)
//                                .font(.callout)
//                                .foregroundColor(isSelected ? .primary : .primary.opacity(0.5) )
//                                .padding(.horizontal)
//                                .padding(.bottom, 5)
//                                .frame(width: 75)
//                        },
//                        selection: {
//                            VStack(spacing: 0) {
//                                Spacer()
//                                Color("pear").frame(height: 1)
//                            }
//                        })



//                    SegmentedPicker(
//                        ["Auto", "Dark", "Light"],
//                        selectedIndex: Binding(
//                            get: {
//                                switch selectedTheme {
//                                case "Dark": return 1
//                                case "Light": return 2
//                                default: return 0
//                                }
//                            },
//                            set: { newIndex in
//                                withAnimation(.easeInOut(duration: 0.3)) {
//                                    switch newIndex {
//                                    case 1: selectedTheme = "Dark"
//                                    case 2: selectedTheme = "Light"
//                                    default: selectedTheme = "Auto"
//                                    }
//                                }
//                            }),
//                        selectionAlignment: .bottom,
//                        content: { item, isSelected in
//                            Text(item)
//                                .font(.callout)
//                                .foregroundColor(isSelected ? .primary : .primary.opacity(0.5) )
//                                .padding(.horizontal)
//                                .padding(.bottom, 5)
//                                .frame(width: 65)
//                        },
//                        selection: {
//                            VStack(spacing: 0) {
//                                Spacer()
//                                Color("pear").frame(height: 1)
//                            }
//                        })
