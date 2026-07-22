//
//  HomeComponents.swift
//  MemoryBox
//

import SwiftUI

struct DurationBreakdownView: View {
    let daysTogether: Int

    private var years: Int {
        daysTogether / 365
    }

    private var months: Int {
        (daysTogether % 365) / 30
    }

    private var weeks: Int {
        (daysTogether % 30) / 7
    }

    var body: some View {
        HStack(spacing: 8) {
            DurationUnitPill(value: years, label: "năm")
            DurationUnitPill(value: months, label: "tháng")
            DurationUnitPill(value: weeks, label: "tuần")
        }
    }
}

struct DurationUnitPill: View {
    let value: Int
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Text("\(value)")
                .font(.caption.weight(.bold))
            Text(label)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(.primary)
    }
}

struct LoveDashboardView: View {
    let memoryCount: Int
    let favoriteCount: Int
    let upcomingDay: SpecialDay?
    let hasRelationshipStart: Bool
    let daysTogether: Int
    let onAddMemory: () -> Void
    @State private var glow = false

    private var nudgeText: String {
        if !hasRelationshipStart {
            return "Đặt ngày bắt đầu để câu chuyện có mốc đầu tiên."
        }

        if memoryCount == 0 {
            return "Chọn một tấm ảnh đầu tiên để mở timeline của hai bạn."
        }

        if favoriteCount == 0 {
            return "Đánh dấu một kỷ niệm yêu thích để làm điểm nhấn trên trang chủ."
        }

        if let upcomingDay {
            return "\(upcomingDay.title) đang \(upcomingDay.date.nextAnnualOccurrence().relativeDayText.lowercased())."
        }

        return "Hôm nay thêm một khoảnh khắc nhỏ cũng đủ làm timeline sáng hơn."
    }

    var body: some View {
        VStack(spacing: 16) {
            HStack(spacing: 14) {
                LoveMetricBubble(icon: "photo.on.rectangle.angled", value: "\(memoryCount)", label: "kỷ niệm", glow: glow)
                LoveMetricBubble(icon: "heart.fill", value: "\(favoriteCount)", label: "yêu thích", glow: glow)

                if hasRelationshipStart {
                    LoveMetricBubble(icon: "sparkles", value: "\(max(daysTogether, 0) / 7)", label: "tuần", glow: glow)
                }
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 12) {
                Image(systemName: "quote.bubble.fill")
                    .foregroundStyle(.pink)

                Text(nudgeText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Button(action: onAddMemory) {
                    Image(systemName: "plus")
                        .font(.headline.weight(.bold))
                        .frame(width: 38, height: 38)
                }
                .buttonStyle(.borderedProminent)
                .accessibilityLabel("Thêm kỷ niệm")
            }
        }
        .padding(.vertical, 2)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.9).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }
}

struct LoveMetricBubble: View {
    let icon: String
    let value: String
    let label: String
    let glow: Bool

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.pink)

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)

            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(.white.opacity(glow ? 0.58 : 0.36))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .shadow(color: .pink.opacity(glow ? 0.18 : 0.06), radius: glow ? 14 : 5, y: 6)
    }
}

struct DailyLoveNoteCard: View {
    let profile: CoupleProfile
    let daysTogether: Int
    let hasRelationshipStart: Bool
    @State private var shimmer = false

    private var displayNames: String {
        let first = profile.firstName.trimmed
        let second = profile.secondName.trimmed

        if !first.isEmpty && !second.isEmpty {
            return "\(first) & \(second)"
        } else if !first.isEmpty {
            return first
        } else if !second.isEmpty {
            return second
        } else {
            return "Hai bạn"
        }
    }

    private var note: String {
        let seed = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        let notes = [
            "\(displayNames), hôm nay hãy giữ lại một điều nhỏ khiến cả hai thấy được yêu thương.",
            "Một câu hỏi dịu dàng cho hôm nay: điều gì làm hai bạn mỉm cười khi nghĩ về nhau?",
            "Tình yêu đẹp hơn khi có ký ức. Hôm nay chỉ cần một tấm ảnh hoặc một lời nhắn thật lòng.",
            "Nếu ngày hôm nay bình thường, hãy làm nó đặc biệt bằng một khoảnh khắc chỉ hai bạn hiểu.",
            hasRelationshipStart ? "\(daysTogether) ngày đã đi qua. Hãy thêm một điều nhỏ để ngày hôm nay cũng có dấu vết." : "Một câu chuyện đẹp nên có mốc đầu tiên. Hãy bắt đầu bằng một ký ức thật gần."
        ]

        return notes[seed % notes.count]
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.pink.opacity(0.95), .purple.opacity(0.68), .orange.opacity(0.55)],
                            startPoint: shimmer ? .topTrailing : .topLeading,
                            endPoint: shimmer ? .bottomLeading : .bottomTrailing
                        )
                    )

                Image(systemName: "heart.text.square.fill")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 52, height: 52)
            .shadow(color: .pink.opacity(shimmer ? 0.28 : 0.14), radius: shimmer ? 18 : 9, y: 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("Lời nhắn hôm nay")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.pink)
                    .textCase(.uppercase)

                Text(note)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.56))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.78), lineWidth: 1)
                )
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.4).repeatForever(autoreverses: true)) {
                shimmer = true
            }
        }
    }
}

struct MemoryInsightCard: View {
    let memories: [LoveMemory]
    let favoriteCount: Int
    let hasRelationshipStart: Bool
    let daysTogether: Int

    private var monthMemories: [LoveMemory] {
        memories.filter { Calendar.current.isDate($0.date, equalTo: Date(), toGranularity: .month) }
    }

    private var photoCount: Int {
        memories.filter { !$0.imagePaths.isEmpty }.count
    }

    private var dominantMood: MemoryMood? {
        Dictionary(grouping: memories, by: \.mood)
            .max { first, second in first.value.count < second.value.count }?
            .key
    }

    private var insightText: String {
        if memories.isEmpty {
            return "Chưa có dữ liệu để đọc nhịp kỷ niệm. Thêm vài khoảnh khắc, app sẽ bắt đầu gợi ý đẹp hơn."
        }

        if let dominantMood {
            return "Timeline đang nghiêng về cảm giác \(dominantMood.rawValue.lowercased()). Đây là màu cảm xúc xuất hiện nhiều nhất trong những kỷ niệm đã lưu."
        }

        return "Timeline đã có chất liệu riêng. Tiếp tục lưu ảnh, nơi chốn và lời nhắn để câu chuyện rõ nét hơn."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("Insight", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3), spacing: 10) {
                InsightMetricTile(icon: "calendar", value: "\(monthMemories.count)", label: "tháng này", tint: .pink)
                InsightMetricTile(icon: "photo.fill", value: "\(photoCount)", label: "có ảnh", tint: .orange)
                InsightMetricTile(icon: "heart.fill", value: "\(favoriteCount)", label: "đã ghim", tint: .purple)
            }

            if hasRelationshipStart {
                ProgressView(value: min(Double(daysTogether % 100) / 100.0, 1.0))
                    .tint(.pink)

                Text("Còn \(100 - (daysTogether % 100)) ngày nữa tới mốc tròn 100 ngày tiếp theo.")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Text(insightText)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.56), lineWidth: 1)
                )
        }
    }
}

struct InsightMetricTile: View {
    let icon: String
    let value: String
    let label: String
    let tint: Color

    var body: some View {
        VStack(spacing: 7) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(tint)

            Text(value)
                .font(.title3.bold())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Text(label)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(.white.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct AnimatedLoveBackdrop: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var drift = false

    private let heartSymbols = ["heart.fill", "sparkles", "heart.circle.fill", "heart.fill", "sparkles"]

    private var gradientColors: [Color] {
        if colorScheme == .dark {
            return [
                Color.pink.opacity(0.16),
                Color.purple.opacity(0.12),
                Color.orange.opacity(0.08),
                Color(red: 0.07, green: 0.07, blue: 0.09)
            ]
        }

        return [
            Color.pink.opacity(0.24),
            Color.orange.opacity(0.16),
            Color.purple.opacity(0.14),
            Color.white.opacity(0.72)
        ]
    }

    private var heartOpacity: Double {
        colorScheme == .dark ? 0.16 : 0.28
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: gradientColors,
                startPoint: drift ? .topTrailing : .topLeading,
                endPoint: drift ? .bottomLeading : .bottomTrailing
            )

            GeometryReader { proxy in
                let width = proxy.size.width
                let height = max(proxy.size.height, 1)

                ForEach(Array(heartSymbols.enumerated()), id: \.offset) { index, symbol in
                    Image(systemName: symbol)
                        .font(.system(size: index.isMultiple(of: 2) ? 30 : 20, weight: .semibold))
                        .foregroundStyle(.white.opacity(heartOpacity))
                        .position(
                            x: width * CGFloat([0.14, 0.34, 0.58, 0.78, 0.9][index]),
                            y: height * CGFloat([0.22, 0.78, 0.34, 0.68, 0.18][index])
                        )
                        .offset(y: drift ? CGFloat(index - 2) * 6 : CGFloat(2 - index) * 6)
                        .rotationEffect(.degrees(drift ? Double(index * 4) : Double(index * -4)))
                }
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 4.8).repeatForever(autoreverses: true)) {
                drift = true
            }
        }
    }
}

struct CoupleProfileCard: View {
    let profile: CoupleProfile
    let onEdit: (ProfilePerson) -> Void
    @State private var heartPulse = false

    var body: some View {
        HStack(spacing: 18) {
            PersonAvatarBlock(
                name: profile.firstName,
                symbolName: profile.firstAvatar,
                color: profile.firstColor.color,
                imagePath: profile.firstImagePath,
                avatarSize: profile.firstAvatarSize,
                placeholderTitle: "Người thứ nhất",
                onUpdate: { onEdit(.first) }
            )

            Image(systemName: "heart.fill")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(Color.pink.opacity(0.65))
                .clipShape(Circle())
                .scaleEffect(heartPulse ? 1.08 : 0.94)
                .shadow(color: .pink.opacity(0.32), radius: heartPulse ? 14 : 8, y: 6)

            PersonAvatarBlock(
                name: profile.secondName,
                symbolName: profile.secondAvatar,
                color: profile.secondColor.color,
                imagePath: profile.secondImagePath,
                avatarSize: profile.secondAvatarSize,
                placeholderTitle: "Người thứ hai",
                onUpdate: { onEdit(.second) }
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.35).repeatForever(autoreverses: true)) {
                heartPulse = true
            }
        }
    }
}

struct PersonAvatarBlock: View {
    let name: String
    let symbolName: String
    let color: Color
    let imagePath: String?
    let avatarSize: Double
    let placeholderTitle: String
    let onUpdate: () -> Void

    private var isMissingProfile: Bool {
        name.trimmed.isEmpty && imagePath == nil
    }

    var body: some View {
        if isMissingProfile {
            Button(action: onUpdate) {
                VStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.plus")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(.pink)
                        .frame(width: avatarSize, height: avatarSize)
                        .background(Color.pink.opacity(0.1))
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 3))

                    Text(placeholderTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(width: 104)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cập nhật \(placeholderTitle)")
        } else {
            Button(action: onUpdate) {
                VStack(spacing: 8) {
                    AvatarView(symbolName: symbolName, color: color, imagePath: imagePath, size: avatarSize)

                    Text(name.trimmed.isEmpty ? "Tên" : name)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(name.trimmed.isEmpty ? .secondary : .primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                        .frame(width: 104)
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cập nhật \(placeholderTitle)")
        }
    }
}

struct AvatarView: View {
    let symbolName: String
    let color: Color
    let imagePath: String?
    let size: CGFloat

    var body: some View {
        ZStack {
            if let imagePath {
                StoredImageView(imagePath: imagePath)
            } else {
                LinearGradient(
                    colors: [color.opacity(0.82), color],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Image(systemName: symbolName)
                    .font(.system(size: size * 0.42, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white, lineWidth: 3))
        .shadow(color: color.opacity(0.28), radius: 8, y: 4)
    }
}

