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
    let showInvitePartnerBanner: Bool
    let showSyncingBanner: Bool
    let onAddMemory: () -> Void
    let onInvitePartner: () -> Void
    let onDismissInvitePartnerBanner: () -> Void
    let onOpenSettings: () -> Void
    let onEditProfile: (ProfilePerson) -> Void
    let onSetRelationshipStart: (Date) -> Void
    let onUpdateMemory: (LoveMemory) -> Void
    let onDeleteMemory: (UUID) -> Void
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
                        if showInvitePartnerBanner {
                            InvitePartnerBanner(onInvite: onInvitePartner, onDismiss: onDismissInvitePartnerBanner)
                        }

                        if showSyncingBanner {
                            CloudSyncingBanner()
                        }

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
                                MemoryDetailView(
                                    memory: featuredMemory,
                                    onUpdate: onUpdateMemory,
                                    onDelete: { onDeleteMemory(featuredMemory.id) }
                                )
                            } label: {
                                FeaturedMemoryCard(memory: featuredMemory)
                            }
                            .buttonStyle(.plain)
                            .padding(.horizontal, AppLayout.featuredMemoryHorizontal - AppLayout.homeHorizontal)
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
                    .appHomeContentPadding()
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("Memory Love")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape.fill")
                    }
                    .accessibilityLabel("Cài đặt")
                }
            }
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
                    subtitle: upcomingDay.nextOccurrence.relativeDayText
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
                        MemoryDetailView(
                            memory: memory,
                            onUpdate: onUpdateMemory,
                            onDelete: { onDeleteMemory(memory.id) }
                        )
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

struct InvitePartnerBanner: View {
    let onInvite: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "heart.circle.fill")
                .font(.title2)
                .foregroundStyle(.pink)
                .frame(width: 40, height: 40)
                .background(Color.pink.opacity(0.1), in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text("Mời người ấy đồng bộ kỷ niệm")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text("Gửi link để cùng dùng một MemoryBox.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button("Mời ngay", action: onInvite)
                .font(.caption.weight(.bold))
                .buttonStyle(.borderedProminent)
                .tint(.pink)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .accessibilityLabel("Ẩn lời nhắc")
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.52), lineWidth: 1)
        )
    }
}

struct CloudSyncingBanner: View {
    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .tint(.pink)

            VStack(alignment: .leading, spacing: 3) {
                Text("Đang đồng bộ dữ liệu từ iCloud")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                Text("Kỷ niệm của hai bạn sẽ hiện sau khi import hoàn tất.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.52), lineWidth: 1)
        )
    }
}
