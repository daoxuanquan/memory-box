//
//  OnboardingFlowState.swift
//  MemoryBox
//

import Foundation

enum OnboardingPath {
    case setupOwn
    case restoreOwn
    case importFromLink
}

enum RestoreDataErrorCode {
    case restoreNotFound
    case icloudUnavailable
    case networkUnavailable
    case hydrationTimeout
    case storeError

    var message: String {
        switch self {
        case .restoreNotFound:
            return "Không tìm thấy dữ liệu cũ trên máy hoặc iCloud. Hãy chọn Tự thiết lập hoặc Nhập từ link."
        case .icloudUnavailable:
            return "Cần đăng nhập iCloud để tải dữ liệu đã đồng bộ trước đây."
        case .networkUnavailable:
            return "Cần mạng để đồng bộ dữ liệu cũ từ iCloud."
        case .hydrationTimeout:
            return "Đồng bộ quá lâu. Thử lại hoặc kiểm tra mạng / iCloud."
        case .storeError:
            return "Không đọc được dữ liệu. Thử lại sau."
        }
    }
}

enum SharedImportErrorCode {
    case sharedZoneNotFound
    case acceptFailed
    case networkUnavailable
    case icloudUnavailable
    case shareRevoked
    case hydrationTimeout

    var message: String {
        switch self {
        case .sharedZoneNotFound:
            return "Chưa thấy không gian chia sẻ. Hãy mở lại link, nhấn Accept, rồi thử lại."
        case .acceptFailed:
            return "Không xác nhận được lời mời. Kiểm tra iCloud và thử lại."
        case .networkUnavailable:
            return "Cần kết nối mạng để tải không gian chia sẻ."
        case .icloudUnavailable:
            return "Cần đăng nhập iCloud để tham gia link mời."
        case .shareRevoked:
            return "Link không còn hiệu lực. Nhờ người ấy gửi link mới."
        case .hydrationTimeout:
            return "Đồng bộ quá lâu. Thử lại hoặc kiểm tra mạng."
        }
    }
}

enum OnboardingStep {
    case welcome
    case abandonLocalConfirm
    case restoreDataLoading(String)
    case restoreDataError(RestoreDataErrorCode)
    case joinExplain
    case sharedImportLoading(String)
    case sharedImportError(SharedImportErrorCode)
    case joinResult(Bool, String?)
    case profile
    case startDate
    case done
}
