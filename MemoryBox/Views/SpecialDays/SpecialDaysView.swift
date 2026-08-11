//
//  SpecialDaysView.swift
//  MemoryBox
//

import SwiftUI

struct SpecialDaysView: View {
    enum DayScope: String, CaseIterable, Identifiable {
        case current = "Hiện tại"
        case past = "Quá khứ"

        var id: String { rawValue }
    }

    @Binding var specialDays: [SpecialDay]
    let onAddDay: () -> Void
    let onChange: () -> Void
    let onUpdate: (SpecialDay) -> Void
    @State private var editingDay: SpecialDay?
    @State private var isShowingLunarCalendar = false
    @State private var selectedScope: DayScope = .current

    private var sortedDays: [SpecialDay] {
        filteredDays.sorted {
            if selectedScope == .past {
                return $0.date > $1.date
            }

            return $0.nextOccurrence < $1.nextOccurrence
        }
    }

    private var filteredDays: [SpecialDay] {
        switch selectedScope {
        case .current:
            return specialDays.filter { !$0.isPastSingleEvent }
        case .past:
            return specialDays.filter(\.isPastSingleEvent)
        }
    }

    private var emptyTitle: String {
        selectedScope == .current ? "Chưa có ngày" : "Chưa có ngày đã qua"
    }

    private var emptyMessage: String {
        selectedScope == .current ? "Thêm những mốc cần nhớ." : "Các sự kiện một lần đã qua sẽ nằm ở đây."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedLoveBackdrop()
                    .ignoresSafeArea()

                ScrollView {
                    LazyVStack(spacing: 14) {
                        LunarSolarCalendarEntryCard {
                            isShowingLunarCalendar = true
                        }

                        Picker("Nhóm ngày", selection: $selectedScope) {
                            ForEach(DayScope.allCases) { scope in
                                Text(scope.rawValue).tag(scope)
                            }
                        }
                        .pickerStyle(.segmented)

                        if sortedDays.isEmpty {
                            EmptyActionView(
                                icon: "calendar.badge.plus",
                                title: emptyTitle,
                                message: emptyMessage,
                                actionTitle: "Thêm",
                                action: onAddDay
                            )
                            .background {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.ultraThinMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(Color.white.opacity(0.48), lineWidth: 1)
                                    )
                            }
                        } else {
                            ForEach(sortedDays) { day in
                                SpecialDayListCard(
                                    day: day,
                                    onEdit: { editingDay = day },
                                    onDelete: { deleteDay(day) }
                                )
                            }
                        }
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Ngày đặc biệt")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onAddDay) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(item: $editingDay) { day in
                SpecialDayEditorView(mode: .edit(day)) { updatedDay in
                    onUpdate(updatedDay)
                }
            }
            .sheet(isPresented: $isShowingLunarCalendar) {
                LunarSolarCalendarView()
            }
        }
    }

    private func deleteDay(at offsets: IndexSet) {
        let idsToRemove = offsets.map { sortedDays[$0].id }
        specialDays.removeAll { idsToRemove.contains($0.id) }
        onChange()
    }

    private func deleteDay(_ day: SpecialDay) {
        specialDays.removeAll { $0.id == day.id }
        onChange()
    }
}

struct LunarSolarCalendarEntryCard: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: "calendar")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.92), Color.pink.opacity(0.78)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text("Lịch âm dương")
                        .font(.headline)
                        .foregroundStyle(.primary)

                    Text("Xem ngày dương và ngày âm tương ứng")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 10)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .stroke(Color.white.opacity(0.56), lineWidth: 1)
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Mở lịch âm dương")
    }
}

struct LunarSolarCalendarView: View {
    enum DisplayMode: String, CaseIterable, Identifiable {
        case day = "Ngày"
        case year = "Năm"

        var id: String { rawValue }
    }

    @Environment(\.dismiss) private var dismiss
    @State private var selectedDate = Date()
    @State private var displayMode: DisplayMode = .day

    private var solarDateText: String {
        selectedDate.vietnameseSolarDateText
    }

    private var lunarDateText: String {
        selectedDate.fullLunarDateText
    }

    private var selectedYear: Int {
        Calendar.current.component(.year, from: selectedDate)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Picker("Chế độ xem", selection: $displayMode) {
                        ForEach(DisplayMode.allCases) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)

                    if displayMode == .day {
                        dailyCalendarContent
                    } else {
                        YearCalendarView(year: selectedYear, selectedDate: $selectedDate)
                    }
                }
                .padding(20)
            }
            .background(AnimatedLoveBackdrop().ignoresSafeArea())
            .navigationTitle("Lịch âm dương")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Xong") { dismiss() }
                }
            }
        }
    }

    private var dailyCalendarContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            MonthlyCalendarView(selectedDate: $selectedDate)

            VStack(alignment: .leading, spacing: 12) {
                LunarSolarCalendarInfoRow(
                    icon: "sun.max.fill",
                    title: "Dương lịch",
                    value: solarDateText,
                    color: .orange
                )

                LunarSolarCalendarInfoRow(
                    icon: "moon.stars.fill",
                    title: "Âm lịch",
                    value: lunarDateText,
                    color: .blue
                )
            }
            .padding(16)
            .background(.white.opacity(0.58))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Color.white.opacity(0.58), lineWidth: 1)
            )
        }
    }
}

struct MonthlyCalendarView: View {
    @Binding var selectedDate: Date

    private var calendar: Calendar {
        Calendar.current
    }

    private var monthDate: Date {
        let components = calendar.dateComponents([.year, .month], from: selectedDate)
        return calendar.date(from: DateComponents(year: components.year, month: components.month, day: 1)) ?? selectedDate
    }

    private var monthTitle: String {
        "\(monthDate.vietnameseMonthText) \(calendar.component(.year, from: monthDate))"
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    moveMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tháng trước")

                Spacer()

                Text(monthTitle)
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    moveMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Tháng sau")
            }

            CalendarMonthGrid(
                year: calendar.component(.year, from: monthDate),
                month: calendar.component(.month, from: monthDate),
                selectedDate: $selectedDate,
                cellHeight: 44,
                dayFontSize: 16,
                lunarFontSize: 10,
                showsWeekdayHeader: true
            )
        }
        .padding(14)
        .background(.white.opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.58), lineWidth: 1)
        )
    }

    private func moveMonth(by value: Int) {
        guard let newDate = calendar.date(byAdding: .month, value: value, to: selectedDate) else {
            return
        }

        selectedDate = newDate
    }
}

struct LunarSolarCalendarInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 38, height: 38)
                .background(color.gradient, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)
            }
        }
    }
}

struct YearCalendarView: View {
    let year: Int
    @Binding var selectedDate: Date

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Button {
                    moveYear(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Năm trước")

                Spacer()

                Text("Năm \(year)")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()

                Button {
                    moveYear(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Năm sau")
            }
            .padding(.horizontal, 4)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(1...12, id: \.self) { month in
                    MonthCalendarCard(year: year, month: month, selectedDate: $selectedDate)
                }
            }
        }
    }

    private func moveYear(by value: Int) {
        guard let newDate = Calendar.current.date(byAdding: .year, value: value, to: selectedDate) else {
            return
        }

        selectedDate = newDate
    }
}

struct MonthCalendarCard: View {
    let year: Int
    let month: Int
    @Binding var selectedDate: Date

    private var monthTitle: String {
        "Tháng \(month)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthTitle)
                .font(.caption.weight(.bold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            CalendarMonthGrid(year: year, month: month, selectedDate: $selectedDate)
        }
        .padding(10)
        .background(.white.opacity(0.66))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.white.opacity(0.58), lineWidth: 1)
        )
    }
}

struct CalendarMonthGrid: View {
    let year: Int
    let month: Int
    @Binding var selectedDate: Date
    var cellHeight: CGFloat = 30
    var dayFontSize: CGFloat = 10
    var lunarFontSize: CGFloat = 7
    var showsWeekdayHeader = false

    private let calendar = Calendar.current
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)
    private let weekdays = ["T2", "T3", "T4", "T5", "T6", "T7", "CN"]

    private var monthDate: Date {
        calendar.date(from: DateComponents(year: year, month: month, day: 1)) ?? Date()
    }

    private var leadingEmptyDays: Int {
        let weekday = calendar.component(.weekday, from: monthDate)
        return (weekday + 5) % 7
    }

    private var dates: [Date] {
        guard let range = calendar.range(of: .day, in: .month, for: monthDate) else {
            return []
        }

        return range.compactMap { day in
            calendar.date(from: DateComponents(year: year, month: month, day: day))
        }
    }

    var body: some View {
        LazyVGrid(columns: columns, spacing: 3) {
            if showsWeekdayHeader {
                ForEach(weekdays, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 18)
                }
            }

            ForEach(0..<leadingEmptyDays, id: \.self) { _ in
                Color.clear
                    .frame(height: cellHeight)
            }

            ForEach(dates, id: \.self) { date in
                MonthDayCell(
                    date: date,
                    isSelected: date.startOfDay == selectedDate.startOfDay,
                    isToday: date.startOfDay == Date().startOfDay,
                    cellHeight: cellHeight,
                    dayFontSize: dayFontSize,
                    lunarFontSize: lunarFontSize
                ) {
                    selectedDate = date
                }
            }
        }
    }
}

struct MonthDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    var cellHeight: CGFloat = 30
    var dayFontSize: CGFloat = 10
    var lunarFontSize: CGFloat = 7
    let action: () -> Void

    private var dayNumber: Int {
        Calendar.current.component(.day, from: date)
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: 1) {
                Text("\(dayNumber)")
                    .font(.system(size: dayFontSize, weight: isSelected || isToday ? .bold : .semibold, design: .rounded))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)

                Text(date.lunarDayText)
                    .font(.system(size: lunarFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(isSelected ? .white.opacity(0.85) : .secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity)
            .frame(height: cellHeight)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.pink)
                } else if isToday {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .stroke(Color.pink.opacity(0.55), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

struct SpecialDayListCard: View {
    let day: SpecialDay
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var nextDate: Date {
        day.nextOccurrence
    }

    private var daysUntil: Int {
        Calendar.current.dateComponents([.day], from: Date().startOfDay, to: nextDate.startOfDay).day ?? 0
    }

    private var counterText: String {
        if daysUntil == 0 {
            return "Hôm nay"
        } else if daysUntil < 0 {
            return "\(abs(daysUntil))"
        } else {
            return "\(daysUntil)"
        }
    }

    private var counterCaption: String {
        if daysUntil == 0 {
            return "đến rồi"
        } else if daysUntil < 0 {
            return "ngày trước"
        } else {
            return "ngày nữa"
        }
    }

    private var lunarDateText: String {
        nextDate.shortLunarDateText
    }

    private var reminderOptions: [SpecialDayReminderOption] {
        day.reminderOptions
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.pink.opacity(0.95), Color.orange.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(color: .pink.opacity(0.24), radius: 12, y: 8)

                Image(systemName: day.symbolName)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 7) {
                Text(day.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                HStack(spacing: 8) {
                    Label(nextDate.relativeDayText, systemImage: "sparkles")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.pink)

                    Text(day.recurrence.rawValue)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.62), in: Capsule())
                }

                Label(lunarDateText, systemImage: "moon.stars.fill")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if !reminderOptions.isEmpty {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 5)], alignment: .leading, spacing: 5) {
                        ForEach(reminderOptions) { option in
                            Text(option.shortTitle)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.pink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 4)
                                .background(Color.pink.opacity(0.1), in: Capsule())
                        }
                    }
                }
            }

            Spacer(minLength: 8)

            VStack(spacing: 8) {
                VStack(spacing: 0) {
                    Text(counterText)
                        .font(.system(size: daysUntil == 0 ? 16 : 28, weight: .bold, design: .rounded))
                        .foregroundStyle(.pink)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)

                    Text(counterCaption)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 72)

                HStack(spacing: 6) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sửa ngày")

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Xoá ngày")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.56), lineWidth: 1)
                )
        }
    }
}

private extension Date {
    var vietnameseSolarDateText: String {
        let components = Calendar.current.dateComponents([.day, .month, .year], from: self)
        guard let day = components.day, let month = components.month, let year = components.year else {
            return ""
        }

        return "Ngày \(day), tháng \(month), năm \(year)"
    }

    var vietnameseMonthText: String {
        let month = Calendar.current.component(.month, from: self)
        return "Tháng \(month)"
    }

    var lunarDayText: String {
        let components = lunarComponents
        guard let day = components.day, let month = components.month else {
            return ""
        }

        return day == 1 ? "\(day)/\(month)" : "\(day)"
    }

    var shortLunarDateText: String {
        let components = lunarComponents
        guard let day = components.day, let month = components.month else {
            return "Âm lịch"
        }

        return "Âm \(day)/\(month)"
    }

    var fullLunarDateText: String {
        let components = lunarComponents
        guard let day = components.day, let month = components.month, let year = components.year else {
            return "Chưa có dữ liệu"
        }

        return "Ngày \(day), tháng \(month), năm \(year)"
    }

    private var lunarComponents: DateComponents {
        Calendar(identifier: .chinese).dateComponents([.day, .month, .year], from: self)
    }
}

struct UpcomingSpecialDaysPreview: View {
    let days: [SpecialDay]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Ngày sắp tới", systemImage: "calendar.circle.fill")
                    .font(.headline)
                    .foregroundStyle(.primary)

                Spacer()
            }

            VStack(spacing: 10) {
                ForEach(days) { day in
                    UpcomingSpecialDayRow(day: day)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.white.opacity(0.48), lineWidth: 1)
                )
        }
    }
}

struct UpcomingSpecialDayRow: View {
    let day: SpecialDay

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: day.symbolName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 34, height: 34)
                .background(
                    LinearGradient(
                        colors: [Color.pink, Color.orange.opacity(0.74)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    in: Circle()
                )

            Text(day.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(day.nextOccurrence.relativeDayText)
                .font(.caption.weight(.bold))
                .foregroundStyle(.pink)
                .lineLimit(1)
        }
    }
}
