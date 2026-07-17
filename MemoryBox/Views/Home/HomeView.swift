//
//  HomeView.swift
//  MemoryBox
//

import SwiftUI

struct HomeView: View {
    let daysTogether: Int
    let relationshipStart: Date
    let hasRelationshipStart: Bool
    let profile: CoupleProfile
    let memoryCount: Int
    let favoriteCount: Int
    let featuredMemory: LoveMemory?
    let recentMemories: [LoveMemory]
    let upcomingDay: SpecialDay?
    let upcomingDays: [SpecialDay]
    let hasUserContent: Bool
    let onAddMemory: () -> Void
    let onEditProfile: (ProfilePerson) -> Void
    let onSetRelationshipStart: (Date) -> Void
    let onUpdateMemory: (LoveMemory) -> Void
    @State private var draftRelationshipStart = Date()
    @State private var showingStartDateEditor = false
    @State private var confirmingStartDateChange = false
    @State private var daysScale = 1.0

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedLoveBackdrop()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .center, spacing: 26) {
                        CoupleProfileCard(profile: profile, onEdit: onEditProfile)
                        heroSection
                        DailyLoveNoteCard(
                            profile: profile,
                            daysTogether: max(daysTogether, 0),
                            hasRelationshipStart: hasRelationshipStart
                        )
                        LoveDashboardView(
                            memoryCount: memoryCount,
                            favoriteCount: favoriteCount,
                            upcomingDay: upcomingDay,
                            hasRelationshipStart: hasRelationshipStart,
                            daysTogether: daysTogether,
                            onAddMemory: onAddMemory
                        )

                        if !upcomingDays.isEmpty {
                            UpcomingSpecialDaysPreview(days: Array(upcomingDays.prefix(4)))
                        }

                        if !hasUserContent {
                            SmartStartView(onEditProfile: { onEditProfile(.first) }, onAddMemory: onAddMemory)
                        }

                        if let featuredMemory {
                            NavigationLink {
                                MemoryDetailView(memory: featuredMemory, onUpdate: onUpdateMemory)
                            } label: {
                                FeaturedMemoryCard(memory: featuredMemory)
                            }
                            .buttonStyle(.plain)
                            .frame(maxWidth: .infinity)
                        }

                        if !recentMemories.isEmpty {
                            recentMemoryStrip
                        }

                        MemoryInsightCard(
                            memories: recentMemories,
                            favoriteCount: favoriteCount,
                            hasRelationshipStart: hasRelationshipStart,
                            daysTogether: max(daysTogether, 0)
                        )
                    }
                    .padding(20)
                }
            }
            .navigationTitle("Memory Love")
            .sheet(isPresented: $showingStartDateEditor) {
                relationshipStartEditor
            }
        }
    }

    private var heroSection: some View {
        VStack(spacing: 10) {
            if hasRelationshipStart {
                Text("\(max(daysTogether, 0)) ngày")
                    .font(.system(size: 50, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.78)
                    .lineLimit(1)
                    .scaleEffect(daysScale)
                    .task {
                        await runDaysHeartbeat()
                    }

                Button {
                    openStartDateEditor()
                } label: {
                    Label("Đổi ngày bắt đầu", systemImage: "calendar")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)

                DurationBreakdownView(daysTogether: max(daysTogether, 0))
            } else {
                Text("Chưa đặt ngày bắt đầu")
                    .font(.title2.bold())
                    .foregroundStyle(.primary)

                Button {
                    openStartDateEditor()
                } label: {
                    Label("Đặt ngày yêu nhau", systemImage: "calendar.badge.plus")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    private var relationshipStartEditor: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "calendar.circle.fill")
                    .font(.system(size: 54))
                    .foregroundStyle(.pink)

                DatePicker("Ngày bắt đầu", selection: $draftRelationshipStart, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .tint(.pink)
            }
            .padding(20)
            .background(AnimatedLoveBackdrop().ignoresSafeArea())
            .navigationTitle(hasRelationshipStart ? "Đổi ngày" : "Đặt ngày")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") {
                        showingStartDateEditor = false
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        saveDraftStartDate()
                    }
                }
            }
            .alert("Đổi ngày bắt đầu?", isPresented: $confirmingStartDateChange) {
                Button("Hủy", role: .cancel) { }
                Button("Đổi ngày", role: .destructive) {
                    commitDraftStartDate()
                }
            } message: {
                Text("Việc này sẽ tính lại số ngày yêu nhau trên trang chủ.")
            }
        }
    }

    private func openStartDateEditor() {
        draftRelationshipStart = hasRelationshipStart ? relationshipStart : Date()
        showingStartDateEditor = true
    }

    private func saveDraftStartDate() {
        if hasRelationshipStart && draftRelationshipStart.startOfDay != relationshipStart.startOfDay {
            confirmingStartDateChange = true
        } else {
            commitDraftStartDate()
        }
    }

    private func commitDraftStartDate() {
        onSetRelationshipStart(draftRelationshipStart)
        showingStartDateEditor = false
    }

    @MainActor
    private func runDaysHeartbeat() async {
        while !Task.isCancelled {
            withAnimation(.easeOut(duration: 0.12)) {
                daysScale = 1.08
            }
            try? await Task.sleep(nanoseconds: 130_000_000)

            withAnimation(.easeIn(duration: 0.18)) {
                daysScale = 1.0
            }
            try? await Task.sleep(nanoseconds: 160_000_000)

            withAnimation(.easeOut(duration: 0.10)) {
                daysScale = 1.035
            }
            try? await Task.sleep(nanoseconds: 110_000_000)

            withAnimation(.easeIn(duration: 0.16)) {
                daysScale = 1.0
            }
            try? await Task.sleep(nanoseconds: 1_350_000_000)
        }
    }

    private var quickActions: some View {
        HStack(spacing: 12) {
            Button(action: onAddMemory) {
                Image(systemName: "plus")
                    .font(.title3.weight(.bold))
                    .frame(width: 56, height: 56)
            }
            .buttonStyle(.borderedProminent)
            .accessibilityLabel("Thêm kỷ niệm")

            if let upcomingDay {
                MiniInfoCard(
                    icon: upcomingDay.symbolName,
                    title: upcomingDay.title,
                    subtitle: upcomingDay.date.nextAnnualOccurrence().relativeDayText
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var recentMemoryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(recentMemories.enumerated()), id: \.element.id) { index, memory in
                    NavigationLink {
                        MemoryDetailView(memory: memory, onUpdate: onUpdateMemory)
                    } label: {
                        MemoryPhotoCard(memory: memory, style: .compact, rotatesImages: index < 2)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 2)
        }
    }
}
