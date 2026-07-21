//
//  AppIconManager.swift
//  MemoryBox
//

import UIKit

enum AppIconChoice: String, CaseIterable, Identifiable {
    case dragonBulliesPig
    case pigBulliesDragon

    var id: String { rawValue }

    var title: String {
        switch self {
        case .dragonBulliesPig:
            return "Rồng bắt nạt heo"
        case .pigBulliesDragon:
            return "Heo bắt nạt rồng"
        }
    }

    var alternateIconName: String? {
        switch self {
        case .dragonBulliesPig:
            return nil
        case .pigBulliesDragon:
            return "AppIconPigBully"
        }
    }
}

@MainActor
enum AppIconManager {
    static var currentChoice: AppIconChoice {
        UIApplication.shared.alternateIconName == "AppIconPigBully"
            ? .pigBulliesDragon
            : .dragonBulliesPig
    }

    static func setIcon(_ choice: AppIconChoice) {
        guard UIApplication.shared.supportsAlternateIcons else { return }
        let name = choice.alternateIconName
        guard UIApplication.shared.alternateIconName != name else { return }

        UIApplication.shared.setAlternateIconName(name) { error in
            if let error {
                print("[MemoryBox][Icon] Đổi icon thất bại: \(error.localizedDescription)")
            } else {
                print("[MemoryBox][Icon] Đã đổi icon -> \(name ?? "gốc")")
            }
        }
    }
}
