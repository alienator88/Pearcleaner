//
//  HomebrewTap.swift
//  Pearcleaner
//
//  Created by Alin Lupascu on 10/01/25.
//

import Foundation

struct HomebrewTapInfo: Identifiable, Equatable, Hashable {
    let id = UUID()
    let name: String
    let isOfficial: Bool

    var displayName: String {
        return name
    }

    static func == (lhs: HomebrewTapInfo, rhs: HomebrewTapInfo) -> Bool {
        return lhs.name == rhs.name
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(name)
    }
}
