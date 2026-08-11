//
//  Models.swift
//  MemoryBox
//

import SwiftUI

struct LoveMemory: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var date: Date
    var place: String
    var note: String
    var kind: MemoryKind?
    var mood: MemoryMood
    var symbolName: String
    var imagePaths: [String]
    var isFavorite: Bool

    var imagePath: String? {
        get { imagePaths.first }
        set { imagePaths = newValue.map { [$0] } ?? [] }
    }

    var imageData: Data? {
        ImageFileStore.data(for: imagePath)
    }

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        place: String,
        note: String,
        kind: MemoryKind = .special,
        mood: MemoryMood,
        symbolName: String,
        imagePath: String? = nil,
        imagePaths: [String] = [],
        imageData: Data? = nil,
        isFavorite: Bool = false
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.place = place
        self.note = note
        self.kind = kind
        self.mood = mood
        self.symbolName = symbolName
        let savedImagePath = imagePath ?? ImageFileStore.save(data: imageData, category: "memories", id: id.uuidString)
        self.imagePaths = (imagePaths + (savedImagePath.map { [$0] } ?? [])).uniqued()
        self.isFavorite = isFavorite
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case date
        case place
        case note
        case kind
        case mood
        case symbolName
        case imagePath
        case imagePaths
        case imageData
        case isFavorite
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        place = try container.decode(String.self, forKey: .place)
        note = try container.decode(String.self, forKey: .note)
        kind = try container.decodeIfPresent(MemoryKind.self, forKey: .kind)
        mood = try container.decode(MemoryMood.self, forKey: .mood)
        symbolName = try container.decode(String.self, forKey: .symbolName)
        let decodedImagePaths = try container.decodeIfPresent([String].self, forKey: .imagePaths) ?? []
        let decodedImagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
            ?? ImageFileStore.save(
                data: try container.decodeIfPresent(Data.self, forKey: .imageData),
                category: "memories",
                id: id.uuidString
            )
        imagePaths = (decodedImagePaths + (decodedImagePath.map { [$0] } ?? [])).uniqued()
        isFavorite = try container.decode(Bool.self, forKey: .isFavorite)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(date, forKey: .date)
        try container.encode(place, forKey: .place)
        try container.encode(note, forKey: .note)
        try container.encodeIfPresent(kind, forKey: .kind)
        try container.encode(mood, forKey: .mood)
        try container.encode(symbolName, forKey: .symbolName)
        try container.encodeIfPresent(imagePath, forKey: .imagePath)
        try container.encode(imagePaths, forKey: .imagePaths)
        try container.encode(isFavorite, forKey: .isFavorite)
    }
}

enum MemoryKind: String, CaseIterable, Codable, Identifiable {
    case date = "Hẹn hò"
    case travel = "Du lịch"
    case gift = "Quà"
    case food = "Ăn uống"
    case family = "Gia đình"
    case special = "Đặc biệt"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .date:
            return "heart.fill"
        case .travel:
            return "airplane"
        case .gift:
            return "gift.fill"
        case .food:
            return "fork.knife"
        case .family:
            return "person.2.fill"
        case .special:
            return "sparkles"
        }
    }
}

extension LoveMemory {
    var displayKind: MemoryKind {
        kind ?? .special
    }
}

enum MemoryMood: String, CaseIterable, Codable, Identifiable {
    case happy = "Hạnh phúc"
    case sweet = "Ngọt ngào"
    case touched = "Xúc động"
    case missed = "Nhớ thương"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .happy:
            return .pink
        case .sweet:
            return .orange
        case .touched:
            return .purple
        case .missed:
            return .blue
        }
    }

    var icon: String {
        switch self {
        case .happy:
            return "heart.fill"
        case .sweet:
            return "sparkles"
        case .touched:
            return "hands.sparkles.fill"
        case .missed:
            return "moon.stars.fill"
        }
    }
}

enum MessageSenderRole: String, Codable, CaseIterable {
    case first
    case second
}

enum MessageMood: String, CaseIterable, Codable, Identifiable {
    case sweet = "Ngọt ngào"
    case angry = "Giận dữ"
    case romantic = "Lãng mạn"
    case missing = "Nhớ nhung"
    case playful = "Tinh nghịch"
    case grateful = "Biết ơn"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .sweet: return "heart.fill"
        case .angry: return "flame.fill"
        case .romantic: return "sparkles"
        case .missing: return "moon.stars.fill"
        case .playful: return "face.smiling"
        case .grateful: return "hands.sparkles.fill"
        }
    }

    var color: Color {
        switch self {
        case .sweet: return .pink
        case .angry: return .red
        case .romantic: return .purple
        case .missing: return .blue
        case .playful: return .orange
        case .grateful: return .green
        }
    }
}

enum MessageReaction: String, CaseIterable, Codable, Identifiable {
    case heart
    case kiss
    case hug
    case sparkle
    case fire

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .heart: return "❤️"
        case .kiss: return "💋"
        case .hug: return "🤗"
        case .sparkle: return "✨"
        case .fire: return "🔥"
        }
    }
}

struct LoveMessage: Identifiable, Codable, Equatable {
    static let currentSchemaVersion = 1

    let id: UUID
    var message: String
    var sentAt: Date
    var senderRole: MessageSenderRole
    var imageData: Data?
    var mood: MessageMood
    var reaction: MessageReaction?
    var replyToID: UUID?
    var isRead: Bool
    var readAt: Date?
    var isFavorite: Bool
    var schemaVersion: Int

    init(
        id: UUID = UUID(),
        message: String,
        sentAt: Date = Date(),
        senderRole: MessageSenderRole,
        imageData: Data? = nil,
        mood: MessageMood = .sweet,
        reaction: MessageReaction? = nil,
        replyToID: UUID? = nil,
        isRead: Bool = false,
        readAt: Date? = nil,
        isFavorite: Bool = false,
        schemaVersion: Int = LoveMessage.currentSchemaVersion
    ) {
        self.id = id
        self.message = message
        self.sentAt = sentAt
        self.senderRole = senderRole
        self.imageData = imageData
        self.mood = mood
        self.reaction = reaction
        self.replyToID = replyToID
        self.isRead = isRead
        self.readAt = readAt
        self.isFavorite = isFavorite
        self.schemaVersion = schemaVersion
    }

    var hasImage: Bool {
        imageData != nil
    }

    var hasText: Bool {
        !message.trimmed.isEmpty
    }
}

struct LoveMessageDraft {
    var message: String
    var mood: MessageMood
    var imageData: Data?
    var replyToID: UUID?
}

enum SpecialDayRecurrence: String, CaseIterable, Codable, Identifiable {
    case weekly = "Hàng tuần"
    case monthly = "Hàng tháng"
    case yearly = "Hằng năm"
    case once = "Một lần"

    var id: String { rawValue }
}

enum SpecialDayReminderOption: Int, CaseIterable, Codable, Identifiable {
    case oneMonth = 30
    case oneWeek = 7
    case threeDays = 3
    case oneDay = 1

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .oneMonth:
            return "Trước 1 tháng"
        case .oneWeek:
            return "Trước 7 ngày"
        case .threeDays:
            return "Trước 3 ngày"
        case .oneDay:
            return "Trước 1 ngày"
        }
    }

    var shortTitle: String {
        switch self {
        case .oneMonth:
            return "1 tháng"
        case .oneWeek:
            return "7 ngày"
        case .threeDays:
            return "3 ngày"
        case .oneDay:
            return "1 ngày"
        }
    }
}

struct SpecialDay: Identifiable, Codable {
    static let defaultReminderOffsets = SpecialDayReminderOption.allCases.map(\.rawValue)

    let id: UUID
    var title: String
    var date: Date
    var symbolName: String
    var recurrence: SpecialDayRecurrence
    var reminderOffsets: [Int]

    init(
        id: UUID = UUID(),
        title: String,
        date: Date,
        symbolName: String,
        recurrence: SpecialDayRecurrence = .yearly,
        reminderOffsets: [Int] = SpecialDay.defaultReminderOffsets
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.symbolName = symbolName
        self.recurrence = recurrence
        self.reminderOffsets = Self.normalizedReminderOffsets(reminderOffsets)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case date
        case symbolName
        case recurrence
        case reminderOffsets
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        date = try container.decode(Date.self, forKey: .date)
        symbolName = try container.decode(String.self, forKey: .symbolName)
        recurrence = try container.decodeIfPresent(SpecialDayRecurrence.self, forKey: .recurrence) ?? .yearly
        reminderOffsets = Self.normalizedReminderOffsets(
            try container.decodeIfPresent([Int].self, forKey: .reminderOffsets) ?? Self.defaultReminderOffsets
        )
    }

    var nextOccurrence: Date {
        let calendar = Calendar.current
        let today = Date().startOfDay
        let originalDate = date.startOfDay

        switch recurrence {
        case .once:
            return originalDate
        case .weekly:
            if originalDate >= today {
                return originalDate
            }

            let weekday = calendar.component(.weekday, from: originalDate)
            let matchingPolicy: Calendar.MatchingPolicy = .nextTimePreservingSmallerComponents
            return calendar.nextDate(
                after: today.addingTimeInterval(-1),
                matching: DateComponents(weekday: weekday),
                matchingPolicy: matchingPolicy
            ) ?? originalDate
        case .monthly:
            return nextMonthlyOccurrence(calendar: calendar, today: today, originalDate: originalDate)
        case .yearly:
            return date.nextAnnualOccurrence()
        }
    }

    var isPastSingleEvent: Bool {
        recurrence == .once && date.startOfDay < Date().startOfDay
    }

    var reminderOptions: [SpecialDayReminderOption] {
        reminderOffsets.compactMap(SpecialDayReminderOption.init(rawValue:))
    }

    private static func normalizedReminderOffsets(_ offsets: [Int]) -> [Int] {
        SpecialDayReminderOption.allCases
            .map(\.rawValue)
            .filter { offsets.contains($0) }
    }

    private func nextMonthlyOccurrence(calendar: Calendar, today: Date, originalDate: Date) -> Date {
        if originalDate >= today {
            return originalDate
        }

        let originalDay = calendar.component(.day, from: originalDate)
        var components = calendar.dateComponents([.year, .month], from: today)

        for monthOffset in 0...1 {
            guard let monthDate = calendar.date(byAdding: .month, value: monthOffset, to: calendar.date(from: components) ?? today) else {
                continue
            }

            components = calendar.dateComponents([.year, .month], from: monthDate)
            let daysInMonth = calendar.range(of: .day, in: .month, for: monthDate)?.count ?? originalDay
            components.day = min(originalDay, daysInMonth)

            if let candidate = calendar.date(from: components), candidate.startOfDay >= today {
                return candidate
            }
        }

        return originalDate
    }
}

struct CoupleProfile: Codable, Equatable {
    static let defaultAvatarSize: Double = 88

    var firstName: String
    var firstAvatar: String
    var firstColor: AvatarColor
    var firstImagePath: String?
    var firstAvatarSize: Double
    var secondName: String
    var secondAvatar: String
    var secondColor: AvatarColor
    var secondImagePath: String?
    var secondAvatarSize: Double

    var firstImageData: Data? {
        ImageFileStore.data(for: firstImagePath)
    }

    var secondImageData: Data? {
        ImageFileStore.data(for: secondImagePath)
    }

    init(
        firstName: String,
        firstAvatar: String,
        firstColor: AvatarColor,
        firstImagePath: String? = nil,
        firstImageData: Data? = nil,
        firstAvatarSize: Double = CoupleProfile.defaultAvatarSize,
        secondName: String,
        secondAvatar: String,
        secondColor: AvatarColor,
        secondImagePath: String? = nil,
        secondImageData: Data? = nil,
        secondAvatarSize: Double = CoupleProfile.defaultAvatarSize
    ) {
        self.firstName = firstName
        self.firstAvatar = firstAvatar
        self.firstColor = firstColor
        self.firstImagePath = firstImagePath ?? ImageFileStore.save(data: firstImageData, category: "profiles", id: "first")
        self.firstAvatarSize = firstAvatarSize
        self.secondName = secondName
        self.secondAvatar = secondAvatar
        self.secondColor = secondColor
        self.secondImagePath = secondImagePath ?? ImageFileStore.save(data: secondImageData, category: "profiles", id: "second")
        self.secondAvatarSize = secondAvatarSize
    }

    static let empty = CoupleProfile(
        firstName: "",
        firstAvatar: "person.fill",
        firstColor: .pink,
        firstImagePath: nil,
        firstAvatarSize: defaultAvatarSize,
        secondName: "",
        secondAvatar: "heart.fill",
        secondColor: .purple,
        secondImagePath: nil,
        secondAvatarSize: defaultAvatarSize
    )

    enum CodingKeys: String, CodingKey {
        case firstName
        case firstAvatar
        case firstColor
        case firstImagePath
        case firstImageData
        case firstAvatarSize
        case secondName
        case secondAvatar
        case secondColor
        case secondImagePath
        case secondImageData
        case secondAvatarSize
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        firstName = try container.decode(String.self, forKey: .firstName)
        firstAvatar = try container.decode(String.self, forKey: .firstAvatar)
        firstColor = try container.decode(AvatarColor.self, forKey: .firstColor)
        firstImagePath = try container.decodeIfPresent(String.self, forKey: .firstImagePath)
            ?? ImageFileStore.save(data: try container.decodeIfPresent(Data.self, forKey: .firstImageData), category: "profiles", id: "first")
        firstAvatarSize = try container.decodeIfPresent(Double.self, forKey: .firstAvatarSize) ?? Self.defaultAvatarSize
        secondName = try container.decode(String.self, forKey: .secondName)
        secondAvatar = try container.decode(String.self, forKey: .secondAvatar)
        secondColor = try container.decode(AvatarColor.self, forKey: .secondColor)
        secondImagePath = try container.decodeIfPresent(String.self, forKey: .secondImagePath)
            ?? ImageFileStore.save(data: try container.decodeIfPresent(Data.self, forKey: .secondImageData), category: "profiles", id: "second")
        secondAvatarSize = try container.decodeIfPresent(Double.self, forKey: .secondAvatarSize) ?? Self.defaultAvatarSize
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(firstName, forKey: .firstName)
        try container.encode(firstAvatar, forKey: .firstAvatar)
        try container.encode(firstColor, forKey: .firstColor)
        try container.encodeIfPresent(firstImagePath, forKey: .firstImagePath)
        try container.encode(firstAvatarSize, forKey: .firstAvatarSize)
        try container.encode(secondName, forKey: .secondName)
        try container.encode(secondAvatar, forKey: .secondAvatar)
        try container.encode(secondColor, forKey: .secondColor)
        try container.encodeIfPresent(secondImagePath, forKey: .secondImagePath)
        try container.encode(secondAvatarSize, forKey: .secondAvatarSize)
    }
}

enum AvatarColor: String, CaseIterable, Codable, Identifiable {
    case pink = "Hồng"
    case purple = "Tím"
    case blue = "Xanh"
    case orange = "Cam"
    case green = "Xanh lá"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .pink:
            return .pink
        case .purple:
            return .purple
        case .blue:
            return .blue
        case .orange:
            return .orange
        case .green:
            return .green
        }
    }
}
