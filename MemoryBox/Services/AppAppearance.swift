//
//  AppAppearance.swift
//  MemoryBox
//

import SwiftUI

enum AppAppearance: String, CaseIterable, Identifiable {
    case light
    case dark

    static let storageKey = "memoryBox.appAppearance"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .light:
            return "Sáng"
        case .dark:
            return "Tối"
        }
    }

    var icon: String {
        switch self {
        case .light:
            return "sun.max.fill"
        case .dark:
            return "moon.fill"
        }
    }

    var colorScheme: ColorScheme {
        switch self {
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    static var current: AppAppearance {
        guard let raw = UserDefaults.standard.string(forKey: storageKey),
              let appearance = AppAppearance(rawValue: raw) else {
            return .light
        }
        return appearance
    }
}
