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

struct LoveLetter: Identifiable, Codable {
    let id: UUID
    var title: String
    var message: String
    var date: Date

    init(id: UUID = UUID(), title: String, message: String, date: Date) {
        self.id = id
        self.title = title
        self.message = message
        self.date = date
    }
}

struct SpecialDay: Identifiable, Codable {
    let id: UUID
    var title: String
    var date: Date
    var symbolName: String

    init(id: UUID = UUID(), title: String, date: Date, symbolName: String) {
        self.id = id
        self.title = title
        self.date = date
        self.symbolName = symbolName
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
