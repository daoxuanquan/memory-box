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

    var previewImageName: String {
        switch self {
        case .dragonBulliesPig:
            return "AppIconDragonPreview"
        case .pigBulliesDragon:
            return "AppIconPigPreview"
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

enum AppIconApplyError: LocalizedError {
    case notSupported
    case systemError(String)

    var errorDescription: String? {
        switch self {
        case .notSupported:
            return "Thiết bị này không hỗ trợ đổi icon ứng dụng."
        case .systemError(let message):
            return "Không đổi được icon: \(message)"
        }
    }
}

@MainActor
enum AppIconManager {
    static var currentChoice: AppIconChoice {
        switch UIApplication.shared.alternateIconName {
        case "AppIconPigBully":
            return .pigBulliesDragon
        default:
            return .dragonBulliesPig
        }
    }

    @discardableResult
    static func setIcon(_ choice: AppIconChoice) async -> Result<Void, AppIconApplyError> {
        guard UIApplication.shared.supportsAlternateIcons else {
            return .failure(.notSupported)
        }

        let name = choice.alternateIconName
        if UIApplication.shared.alternateIconName == name {
            return .success(())
        }

        return await withCheckedContinuation { continuation in
            UIApplication.shared.setAlternateIconName(name) { error in
                if let error {
                    print("[MemoryBox][Icon] Đổi icon thất bại: \(error.localizedDescription)")
                    continuation.resume(returning: .failure(.systemError(error.localizedDescription)))
                } else {
                    print("[MemoryBox][Icon] Đã đổi icon -> \(name ?? "gốc")")
                    continuation.resume(returning: .success(()))
                }
            }
        }
    }
}
