//
//  SpecialDaysView.swift
//  MemoryBox
//

import SwiftUI

struct SpecialDaysView: View {
    @Binding var specialDays: [SpecialDay]
    let onAddDay: () -> Void
    let onChange: () -> Void
    let onUpdate: (SpecialDay) -> Void
    @State private var editingDay: SpecialDay?

    private var sortedDays: [SpecialDay] {
        specialDays.sorted { $0.date.nextAnnualOccurrence() < $1.date.nextAnnualOccurrence() }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedLoveBackdrop()
                    .ignoresSafeArea()

                if sortedDays.isEmpty {
                    EmptyActionView(
                        icon: "calendar.badge.plus",
                        title: "Chưa có ngày",
                        message: "Thêm những mốc cần nhớ.",
                        actionTitle: "Thêm",
                        action: onAddDay
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(sortedDays) { day in
                                SpecialDayListCard(
                                    day: day,
                                    onEdit: { editingDay = day },
                                    onDelete: { deleteDay(day) }
                                )
                            }
                        }
                        .padding(20)
                    }
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

struct SpecialDayListCard: View {
    let day: SpecialDay
    let onEdit: () -> Void
    let onDelete: () -> Void

    private var nextDate: Date {
        day.date.nextAnnualOccurrence()
    }

    private var daysUntil: Int {
        Calendar.current.dateComponents([.day], from: Date().startOfDay, to: nextDate.startOfDay).day ?? 0
    }

    private var counterText: String {
        daysUntil == 0 ? "Hôm nay" : "\(daysUntil)"
    }

    private var counterCaption: String {
        daysUntil == 0 ? "đến rồi" : "ngày nữa"
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

                    Text("Hằng năm")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.62), in: Capsule())
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 54), spacing: 5)], alignment: .leading, spacing: 5) {
                    ForEach(["1 tháng", "7 ngày", "3 ngày", "1 ngày"], id: \.self) { reminder in
                        Text(reminder)
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

            Text(day.date.nextAnnualOccurrence().relativeDayText)
                .font(.caption.weight(.bold))
                .foregroundStyle(.pink)
                .lineLimit(1)
        }
    }
}


