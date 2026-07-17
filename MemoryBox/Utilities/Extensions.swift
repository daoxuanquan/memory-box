//
//  Extensions.swift
//  MemoryBox
//

import Foundation

extension Notification.Name {
    static let memoryStoreDidChange = Notification.Name("memoryStoreDidChange")
}

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    var relativeDayText: String {
        let days = Calendar.current.dateComponents([.day], from: Date().startOfDay, to: startOfDay).day ?? 0

        if days == 0 {
            return "Hôm nay"
        } else if days > 0 {
            return "Còn \(days) ngày"
        } else {
            return "Đã qua \(abs(days)) ngày"
        }
    }

    var pastRelativeText: String {
        let days = Calendar.current.dateComponents([.day], from: startOfDay, to: Date().startOfDay).day ?? 0

        if days == 0 {
            return "Hôm nay"
        } else if days == 1 {
            return "Hôm qua"
        } else if days == 2 {
            return "Hôm kia"
        } else if days > 0 {
            return "\(days) ngày trước"
        } else {
            return "Trong \(abs(days)) ngày"
        }
    }

    func nextAnnualOccurrence() -> Date {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: Date())
        let components = calendar.dateComponents([.month, .day], from: self)

        guard let month = components.month, let day = components.day else { return self }

        var nextComponents = DateComponents()
        nextComponents.year = currentYear
        nextComponents.month = month
        nextComponents.day = day

        let thisYear = calendar.date(from: nextComponents) ?? self
        if thisYear.startOfDay >= Date().startOfDay {
            return thisYear
        }

        nextComponents.year = currentYear + 1
        return calendar.date(from: nextComponents) ?? thisYear
    }
}

extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

extension Array where Element == String {
    func stableChoice(seed: String) -> String {
        guard !isEmpty else { return "" }
        let value = seed.unicodeScalars.reduce(0) { result, scalar in
            result + Int(scalar.value)
        }

        return self[value % count]
    }
}
