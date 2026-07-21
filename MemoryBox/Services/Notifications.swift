//
//  Notifications.swift
//  MemoryBox
//

import Foundation
import UserNotifications

final class LoveNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}

enum LoveNotificationScheduler {
    private static let center = UNUserNotificationCenter.current()
    private static let delegate = LoveNotificationDelegate()
    private static let identifierPrefix = "memorybox.love."
    private static let specialDayHour = 8
    private static let previewHour = 20
    private static let milestoneHour = 9
    private static let maxScheduledSpecialDays = 24
    private static let specialDayReminderOffsets = [30, 7, 3, 1]
    private static let milestoneDays = [100, 365, 500, 1000, 1500, 2000, 3000, 3650]
    private static let todayReminderDefaultsPrefix = "memorybox.todayReminder."

    static func refresh(
        specialDays: [SpecialDay],
        relationshipStart: Date,
        hasRelationshipStart: Bool
    ) async {
        configureForegroundPresentation()
        guard await ensureAuthorization() else { return }

        await clearExistingRequests()
        await scheduleSpecialDays(specialDays)

        if hasRelationshipStart {
            await scheduleRelationshipMilestones(from: relationshipStart)
        }
    }

    static func notifyNewLoveMessage() async {
        configureForegroundPresentation()
        guard await ensureAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Có tin nhắn yêu thương"
        content.body = "Bạn có một tin nhắn yêu thương đang chờ bạn mở."
        content.sound = .default
        content.categoryIdentifier = "MEMORYBOX_LOVE_MESSAGE"

        let request = UNNotificationRequest(
            identifier: "\(identifierPrefix)loveMessage.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        await add(request)
    }

    static func notifyRemoteCoupleUpdate() async {
        configureForegroundPresentation()
        guard await ensureAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = "MemoryBox vừa có cập nhật"
        content.body = "Người kia đã thêm hoặc chỉnh sửa dữ liệu trong không gian chung."
        content.sound = .default
        content.categoryIdentifier = "MEMORYBOX_REMOTE_UPDATE"

        let request = UNNotificationRequest(
            identifier: "\(identifierPrefix)remote.\(UUID().uuidString)",
            content: content,
            trigger: UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        )
        await add(request)
    }

    private static func configureForegroundPresentation() {
        center.delegate = delegate
    }

    private static func ensureAuthorization() async -> Bool {
        let settings = await currentSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            return await requestAuthorization()
        @unknown default:
            return false
        }
    }

    private static func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    private static func clearExistingRequests() async {
        let identifiers = await pendingRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(identifierPrefix) }

        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private static func scheduleSpecialDays(_ specialDays: [SpecialDay]) async {
        let upcomingDays = specialDays
            .sorted { $0.date.nextAnnualOccurrence() < $1.date.nextAnnualOccurrence() }
            .prefix(maxScheduledSpecialDays)

        for day in upcomingDays {
            await scheduleAnnualSpecialDay(day)
            await scheduleSpecialDayReminders(day)
            if day.date.nextAnnualOccurrence().startOfDay == Date().startOfDay && shouldScheduleTodayReminder(for: day) {
                await scheduleImmediateSpecialDayReminder(day)
                markTodayReminderScheduled(for: day)
            }
        }
    }

    private static func scheduleAnnualSpecialDay(_ day: SpecialDay) async {
        var components = annualComponents(from: day.date)
        components.hour = specialDayHour
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = "Hôm nay là \(day.title)"
        content.body = specialDayMessage(for: day)
        content.sound = .default
        content.categoryIdentifier = "MEMORYBOX_SPECIAL_DAY"

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "\(identifierPrefix)special.\(day.id.uuidString).day",
            content: content,
            trigger: trigger
        )
        await add(request)
    }

    private static func scheduleImmediateSpecialDayReminder(_ day: SpecialDay) async {
        let content = UNMutableNotificationContent()
        content.title = "Hôm nay là \(day.title)"
        content.body = specialDayMessage(for: day)
        content.sound = .default
        content.categoryIdentifier = "MEMORYBOX_SPECIAL_DAY"

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 10, repeats: false)
        let request = UNNotificationRequest(
            identifier: "\(identifierPrefix)special.\(day.id.uuidString).today.10s",
            content: content,
            trigger: trigger
        )
        await add(request)
    }

    private static func shouldScheduleTodayReminder(for day: SpecialDay) -> Bool {
        UserDefaults.standard.string(forKey: todayReminderDefaultsKey(for: day)) != todayKey
    }

    private static func markTodayReminderScheduled(for day: SpecialDay) {
        UserDefaults.standard.set(todayKey, forKey: todayReminderDefaultsKey(for: day))
    }

    private static func todayReminderDefaultsKey(for day: SpecialDay) -> String {
        "\(todayReminderDefaultsPrefix)\(day.id.uuidString)"
    }

    private static var todayKey: String {
        let components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        return "\(components.year ?? 0)-\(components.month ?? 0)-\(components.day ?? 0)"
    }

    private static func scheduleSpecialDayReminders(_ day: SpecialDay) async {
        for offset in specialDayReminderOffsets {
            await scheduleSpecialDayReminder(day, daysBefore: offset)
        }
    }

    private static func scheduleSpecialDayReminder(_ day: SpecialDay, daysBefore: Int) async {
        guard let reminderDate = Calendar.current.date(byAdding: .day, value: -daysBefore, to: day.date) else { return }

        var components = annualComponents(from: reminderDate)
        components.hour = previewHour
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = reminderTitle(for: day, daysBefore: daysBefore)
        content.body = reminderMessage(for: day, daysBefore: daysBefore)
        content.sound = .default
        content.categoryIdentifier = "MEMORYBOX_SPECIAL_DAY"

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(
            identifier: "\(identifierPrefix)special.\(day.id.uuidString).before.\(daysBefore)",
            content: content,
            trigger: trigger
        )
        await add(request)
    }

    private static func scheduleRelationshipMilestones(from startDate: Date) async {
        let calendar = Calendar.current
        let today = Date().startOfDay

        for days in milestoneDays {
            guard let milestoneDate = calendar.date(byAdding: .day, value: days, to: startDate.startOfDay),
                  milestoneDate.startOfDay >= today
            else { continue }

            await scheduleOneTimeNotification(
                identifier: "\(identifierPrefix)milestone.\(days)",
                date: milestoneDate,
                title: "\(days) ngày bên nhau",
                body: milestoneMessage(days: days)
            )
        }

        for year in 1...5 {
            guard let anniversaryDate = calendar.date(byAdding: .year, value: year, to: startDate.startOfDay),
                  anniversaryDate.startOfDay >= today
            else { continue }

            await scheduleOneTimeNotification(
                identifier: "\(identifierPrefix)anniversary.\(year)",
                date: anniversaryDate,
                title: "Kỷ niệm \(year) năm yêu nhau",
                body: anniversaryMessage(year: year)
            )
        }
    }

    private static func scheduleOneTimeNotification(identifier: String, date: Date, title: String, body: String) async {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: date)
        components.hour = milestoneHour
        components.minute = 0

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        content.categoryIdentifier = "MEMORYBOX_MILESTONE"

        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        await add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    private static func specialDayMessage(for day: SpecialDay) -> String {
        [
            "Một ngày đáng nhớ đã tới. Mở MemoryBox và lưu lại một khoảnh khắc thật đẹp cho \(day.title.lowercased()).",
            "\(day.title) không chỉ là một mốc thời gian, mà là lý do để hai bạn dịu dàng hơn với nhau hôm nay.",
            "Hôm nay hợp để nói một lời thương, chụp một tấm ảnh và cất lại trong MemoryBox."
        ].stableChoice(seed: day.id.uuidString)
    }

    private static func reminderTitle(for day: SpecialDay, daysBefore: Int) -> String {
        switch daysBefore {
        case 30:
            return "Còn khoảng 1 tháng tới \(day.title)"
        case 7:
            return "Còn 1 tuần tới \(day.title)"
        case 3:
            return "Còn 3 ngày tới \(day.title)"
        case 1:
            return "Ngày mai có \(day.title)"
        default:
            return "Sắp tới \(day.title)"
        }
    }

    private static func reminderMessage(for day: SpecialDay, daysBefore: Int) -> String {
        switch daysBefore {
        case 30:
            return [
                "Một mốc đẹp đang tới gần. Bắt đầu nghĩ về một món quà nhỏ, một chuyến đi ngắn hoặc một lời nhắn thật riêng nhé.",
                "Còn đủ thời gian để chuẩn bị điều gì đó tinh tế cho \(day.title.lowercased()). Đừng để sát ngày mới vội.",
                "Một tháng nữa là một ngày đáng nhớ. Lên ý tưởng từ hôm nay để ngày đó có thêm ánh sáng."
            ].stableChoice(seed: "reminder-30-\(day.id.uuidString)")
        case 7:
            return [
                "Một tuần nữa thôi. Hãy giữ lại chút thời gian cho nhau và chuẩn bị một điều thật dịu dàng.",
                "\(day.title) đang đến gần. Một kế hoạch nhỏ lúc này sẽ làm ngày đó đáng nhớ hơn.",
                "Còn 7 ngày để biến một ngày trên lịch thành một kỷ niệm có thật."
            ].stableChoice(seed: "reminder-7-\(day.id.uuidString)")
        case 3:
            return [
                "Còn 3 ngày. Đây là lúc chốt một lời nhắn, một tấm ảnh cũ hoặc một buổi hẹn nhỏ.",
                "Ngày đẹp đang rất gần. Chuẩn bị nhẹ thôi, nhưng hãy chuẩn bị bằng sự để tâm.",
                "Ba ngày nữa là \(day.title.lowercased()). MemoryBox đang chờ một khoảnh khắc mới."
            ].stableChoice(seed: "reminder-3-\(day.id.uuidString)")
        case 1:
            return [
                "Chuẩn bị một lời nhắn nhỏ hoặc một buổi hẹn xinh xắn cho ngày mai nhé.",
                "Một chút chuẩn bị hôm nay có thể làm \(day.title.lowercased()) ngày mai đáng nhớ hơn.",
                "Ngày mai là một mốc đẹp. Đừng để nó trôi qua như một ngày bình thường."
            ].stableChoice(seed: "reminder-1-\(day.id.uuidString)")
        default:
            return "Một ngày quan trọng đang tới gần. Nhớ chuẩn bị một điều nhỏ thật đẹp."
        }
    }

    private static func milestoneMessage(days: Int) -> String {
        [
            "Từng ngày nhỏ đã ghép thành một chặng đường đáng yêu. Hôm nay nhớ lưu lại một khoảnh khắc mới nhé.",
            "\(days) ngày là một con số đẹp. Hãy dành cho nhau một lời thật mềm và một kỷ niệm thật riêng.",
            "Có những mốc thời gian xứng đáng được giữ lại. MemoryBox đang chờ một tấm ảnh của hôm nay."
        ].stableChoice(seed: "milestone-\(days)")
    }

    private static func anniversaryMessage(year: Int) -> String {
        [
            "\(year) năm không chỉ là thời gian, mà là rất nhiều điều đã cùng nhau đi qua.",
            "Hôm nay là một ngày đẹp để nhìn lại, cảm ơn nhau và lưu thêm một kỷ niệm mới.",
            "Một vòng năm nữa đã qua. Mong hai bạn vẫn chọn nhau bằng những điều nhỏ dịu dàng."
        ].stableChoice(seed: "anniversary-\(year)")
    }

    private static func annualComponents(from date: Date) -> DateComponents {
        Calendar.current.dateComponents([.month, .day], from: date)
    }

    private static func currentSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private static func pendingRequests() async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private static func add(_ request: UNNotificationRequest) async {
        await withCheckedContinuation { continuation in
            center.add(request) { _ in
                continuation.resume()
            }
        }
    }
}
