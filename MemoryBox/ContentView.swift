//
//  ContentView.swift
//  MemoryBox
//

import CoreData
import SwiftUI

struct ContentView: View {
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.light.rawValue
    @State private var selectedTab: AppTab = .home
    @State private var memories: [LoveMemory] = []
    @State private var messages: [LoveMessage] = []
    @State private var specialDays: [SpecialDay] = []
    @State private var profile: CoupleProfile = .empty
    @State private var spaceMembership = MemoryStore.loadSpaceMembership()
    @State private var showInvitePartnerBanner = OnboardingStore.shouldShowInviteBanner(membership: MemoryStore.loadSpaceMembership())
    @State private var relationshipStart = MemoryStore.loadStartDate()
    @State private var hasRelationshipStart = MemoryStore.loadHasStartDate()
    @State private var activeSheet: ActiveSheet?
    @State private var arrivalQueue: [LoveMessage] = []
    @State private var presentedArrivalMessage: LoveMessage?
    @State private var acknowledgedArrivalIDs: Set<UUID> = []

    private var daysTogether: Int {
        guard hasRelationshipStart else { return 0 }
        return Calendar.current.dateComponents([.day], from: relationshipStart.startOfDay, to: Date().startOfDay).day ?? 0
    }

    private var featuredMemory: LoveMemory? {
        memories.first(where: { $0.isFavorite }) ?? memories.sorted { $0.date > $1.date }.first
    }

    private var hasUserContent: Bool {
        !memories.isEmpty || !messages.isEmpty || !specialDays.isEmpty
    }

    private var showSyncingBanner: Bool {
        spaceMembership == .participant && OnboardingStore.activeDataSource == .sharedInvite && !hasUserContent
    }

    private var recentMemories: [LoveMemory] {
        memories.sorted { $0.date > $1.date }
    }

    private var unreadIncomingCount: Int {
        MemoryStore.unreadIncomingMessages(from: messages).count
    }

    private var appAppearance: AppAppearance {
        AppAppearance(rawValue: appearanceRaw) ?? .light
    }

    var body: some View {
        tabContent
            .preferredColorScheme(appAppearance.colorScheme)
            .tint(.pink)
            .sheet(item: $activeSheet, content: sheetContent)
            .overlay {
                if let presentedArrivalMessage {
                    LoveMessageArrivalView(
                        message: presentedArrivalMessage,
                        profile: profile,
                        onOpenConversation: { selectedTab = .letters },
                        onHide: { hideArrival(presentedArrivalMessage) },
                        onAcknowledge: { acknowledgeArrival(presentedArrivalMessage) }
                    )
                    .transition(.opacity)
                    .zIndex(10)
                }
            }
            .task {
                await reloadFromStore()
            }
            .task {
                await LoveNotificationScheduler.refresh(
                    specialDays: specialDays,
                    relationshipStart: relationshipStart,
                    hasRelationshipStart: hasRelationshipStart
                )
            }
            .task {
                await listenForRemoteStoreChanges()
            }
            .task {
                await listenForMemoryStoreChanges()
            }
    }

    private var tabContent: some View {
        TabView(selection: $selectedTab) {
            homeTab
            timelineTab
            lettersTab
            daysTab
        }
    }

    private var homeTab: some View {
        HomeView(
            daysTogether: daysTogether,
            relationshipStart: relationshipStart,
            hasRelationshipStart: hasRelationshipStart,
            profile: profile,
            memoryCount: memories.count,
            favoriteCount: memories.filter(\.isFavorite).count,
            featuredMemory: featuredMemory,
            recentMemories: recentMemories,
            upcomingDay: nextSpecialDay,
            upcomingDays: upcomingSpecialDays,
            hasUserContent: hasUserContent,
            showInvitePartnerBanner: showInvitePartnerBanner,
            showSyncingBanner: showSyncingBanner,
            onAddMemory: showAddMemory,
            onInvitePartner: showSettings,
            onDismissInvitePartnerBanner: dismissInvitePartnerBanner,
            onOpenSettings: showSettings,
            onEditProfile: showEditProfile,
            onSetRelationshipStart: saveRelationshipStart,
            onUpdateMemory: updateMemory,
            onDeleteMemory: deleteMemory
        )
        .tabItem { Label("Trang chủ", systemImage: "house.fill") }
        .tag(AppTab.home)
    }

    private var timelineTab: some View {
        TimelineView(memories: $memories, onChange: saveMemories, onUpdate: updateMemory)
            .tabItem { Label("Kỷ niệm", systemImage: "photo.on.rectangle.angled") }
            .tag(AppTab.timeline)
    }

    private var lettersTab: some View {
        LettersView(
            messages: $messages,
            profile: profile,
            onCompose: {},
            onReload: { Task { await reloadMessages() } }
        )
        .tabItem {
            Label("Tin nhắn", systemImage: "heart.text.square.fill")
        }
        .badge(unreadIncomingCount)
        .tag(AppTab.letters)
    }

    private var daysTab: some View {
        SpecialDaysView(specialDays: $specialDays, onAddDay: showAddSpecialDay, onChange: saveSpecialDays, onUpdate: updateSpecialDay)
            .tabItem { Label("Ngày", systemImage: "calendar.circle.fill") }
            .tag(AppTab.days)
    }

    private var nextSpecialDay: SpecialDay? {
        upcomingSpecialDays.first
    }

    private var upcomingSpecialDays: [SpecialDay] {
        specialDays
            .filter { !$0.isPastSingleEvent }
            .map { day -> (SpecialDay, Date) in
                let nextDate = day.nextOccurrence
                return (day, nextDate)
            }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    @ViewBuilder
    private func sheetContent(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .memory:
            MemoryEditorView(mode: .add, onSave: saveMemory)
        case .specialDay:
            SpecialDayEditorView(mode: .add, onSave: saveSpecialDay)
        case .profile(let person):
            EditProfileView(profile: profile, person: person, onSave: saveProfile)
        case .settings:
            SettingsView()
        }
    }

    private func showAddMemory() {
        activeSheet = .memory
    }

    private func showAddSpecialDay() {
        activeSheet = .specialDay
    }

    private func showSettings() {
        activeSheet = .settings
    }

    private func showEditProfile(_ person: ProfilePerson) {
        activeSheet = .profile(person)
    }

    private func saveProfile(_ newProfile: CoupleProfile) {
        profile = newProfile
        MemoryStore.save(profile: newProfile)
    }

    private func saveRelationshipStart(_ newDate: Date) {
        relationshipStart = newDate
        hasRelationshipStart = true
        MemoryStore.save(startDate: newDate, isSet: true)
        refreshNotificationSchedule()
    }

    private func saveMemory(_ memory: LoveMemory) {
        memories.insert(memory, at: 0)
        MemoryStore.save(memories: memories)
        Task { memories = await MemoryStore.loadMemories() }
    }

    private func saveMemories() {
        MemoryStore.save(memories: memories)
        Task { memories = await MemoryStore.loadMemories() }
    }

    private func updateMemory(_ memory: LoveMemory) {
        guard let index = memories.firstIndex(where: { $0.id == memory.id }) else { return }
        memories[index] = memory
        MemoryStore.save(memories: memories)
        Task { memories = await MemoryStore.loadMemories() }
    }

    private func deleteMemory(id: UUID) {
        memories.removeAll { $0.id == id }
        MemoryStore.save(memories: memories)
        Task { memories = await MemoryStore.loadMemories() }
    }

    private func saveSpecialDay(_ day: SpecialDay) {
        specialDays.append(day)
        specialDays = specialDays.sorted { first, second in
            first.date < second.date
        }
        MemoryStore.save(specialDays: specialDays)
        refreshNotificationSchedule()
    }

    private func saveSpecialDays() {
        MemoryStore.save(specialDays: specialDays)
        refreshNotificationSchedule()
    }

    private func updateSpecialDay(_ day: SpecialDay) {
        guard let index = specialDays.firstIndex(where: { $0.id == day.id }) else { return }
        specialDays[index] = day
        specialDays = specialDays.sorted { first, second in
            first.date < second.date
        }
        MemoryStore.save(specialDays: specialDays)
        refreshNotificationSchedule()
    }

    private func refreshNotificationSchedule() {
        let days = specialDays
        let startDate = relationshipStart
        let startDateIsSet = hasRelationshipStart
        Task {
            await LoveNotificationScheduler.refresh(
                specialDays: days,
                relationshipStart: startDate,
                hasRelationshipStart: startDateIsSet
            )
        }
    }

    private func reloadFromStore() async {
        async let loadedMemories = MemoryStore.loadMemories()
        async let loadedMessages = MemoryStore.loadLoveMessages()
        async let loadedSpecialDays = MemoryStore.loadSpecialDays()
        async let loadedProfile = MemoryStore.loadProfile()

        memories = await loadedMemories
        messages = await loadedMessages
        specialDays = await loadedSpecialDays
        profile = await loadedProfile
        spaceMembership = MemoryStore.loadSpaceMembership()
        showInvitePartnerBanner = OnboardingStore.shouldShowInviteBanner(membership: spaceMembership)
        relationshipStart = MemoryStore.loadStartDate()
        hasRelationshipStart = MemoryStore.loadHasStartDate()
        _ = await AppIconManager.setIcon(MemoryStore.loadAppIconChoice())
        refreshNotificationSchedule()
        refreshArrivalQueue()
    }

    private func reloadMessages() async {
        messages = await MemoryStore.loadLoveMessages()
        refreshArrivalQueue()
    }

    private func refreshArrivalQueue() {
        let unread = MemoryStore.unreadIncomingMessages(from: messages)
        let pending = unread.filter { !acknowledgedArrivalIDs.contains($0.id) }
        arrivalQueue = pending

        if presentedArrivalMessage == nil {
            presentedArrivalMessage = arrivalQueue.first
        } else if let current = presentedArrivalMessage,
                  !pending.contains(where: { $0.id == current.id }) {
            presentedArrivalMessage = arrivalQueue.first
        }
    }

    private func hideArrival(_ message: LoveMessage) {
        // Ẩn trong phiên hiện tại, vẫn giữ chưa đọc để badge còn hiện.
        acknowledgedArrivalIDs.insert(message.id)
        withAnimation(.easeOut(duration: 0.2)) {
            presentedArrivalMessage = nil
        }

        if let next = arrivalQueue.first(where: { !acknowledgedArrivalIDs.contains($0.id) }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    presentedArrivalMessage = next
                }
            }
        }
    }

    private func acknowledgeArrival(_ message: LoveMessage) {
        MemoryStore.markLoveMessageRead(id: message.id)
        acknowledgedArrivalIDs.insert(message.id)
        presentedArrivalMessage = nil

        Task {
            messages = await MemoryStore.loadLoveMessages()
            if let next = MemoryStore.unreadIncomingMessages(from: messages)
                .first(where: { !acknowledgedArrivalIDs.contains($0.id) }) {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.82)) {
                    presentedArrivalMessage = next
                }
            }
        }
    }

    private func dismissInvitePartnerBanner() {
        OnboardingStore.dismissInviteBanner()
        withAnimation(.easeOut(duration: 0.18)) {
            showInvitePartnerBanner = false
        }
    }

    private func listenForRemoteStoreChanges() async {
        for await _ in NotificationCenter.default.notifications(named: .NSPersistentStoreRemoteChange) {
            MemoryStore.reconcileAfterCloudSync()
            await reloadFromStore()
        }
    }

    private func listenForMemoryStoreChanges() async {
        for await _ in NotificationCenter.default.notifications(named: .memoryStoreDidChange) {
            await reloadFromStore()
        }
    }
}

enum ActiveSheet: Identifiable {
    case memory
    case specialDay
    case profile(ProfilePerson)
    case settings

    var id: String {
        switch self {
        case .memory:
            return "memory"
        case .specialDay:
            return "specialDay"
        case .profile(let person):
            return "profile-\(person.rawValue)"
        case .settings:
            return "settings"
        }
    }
}

enum ProfilePerson: String {
    case first
    case second

    var title: String {
        switch self {
        case .first:
            return "Người thứ nhất"
        case .second:
            return "Người thứ hai"
        }
    }

    var senderRole: MessageSenderRole {
        self == .first ? .first : .second
    }

    var counterpart: ProfilePerson {
        self == .first ? .second : .first
    }
}

enum AppTab: Hashable {
    case home
    case timeline
    case letters
    case days
}

#Preview {
    ContentView()
}
