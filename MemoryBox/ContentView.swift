//
//  ContentView.swift
//  MemoryBox
//

import SwiftUI

struct ContentView: View {
    @State private var selectedTab: AppTab = .home
    @State private var memories: [LoveMemory] = MemoryStore.loadMemories()
    @State private var letters: [LoveLetter] = MemoryStore.loadLetters()
    @State private var specialDays: [SpecialDay] = MemoryStore.loadSpecialDays()
    @State private var profile = MemoryStore.loadProfile()
    @State private var relationshipStart = MemoryStore.loadStartDate()
    @State private var hasRelationshipStart = MemoryStore.loadHasStartDate()
    @State private var activeSheet: ActiveSheet?

    private var daysTogether: Int {
        guard hasRelationshipStart else { return 0 }
        return Calendar.current.dateComponents([.day], from: relationshipStart.startOfDay, to: Date().startOfDay).day ?? 0
    }

    private var featuredMemory: LoveMemory? {
        memories.first(where: { $0.isFavorite }) ?? memories.sorted { $0.date > $1.date }.first
    }

    private var hasUserContent: Bool {
        !memories.isEmpty || !letters.isEmpty || !specialDays.isEmpty
    }

    private var recentMemories: [LoveMemory] {
        memories.sorted { $0.date > $1.date }
    }

    var body: some View {
        tabContent
            .tint(.pink)
            .sheet(item: $activeSheet, content: sheetContent)
            .task {
                await LoveNotificationScheduler.refresh(
                    specialDays: specialDays,
                    relationshipStart: relationshipStart,
                    hasRelationshipStart: hasRelationshipStart
                )
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
            onAddMemory: showAddMemory,
            onEditProfile: showEditProfile,
            onSetRelationshipStart: saveRelationshipStart,
            onUpdateMemory: updateMemory
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
        LettersView(letters: $letters, onAddLetter: showAddLetter, onChange: saveLetters, onUpdate: updateLetter)
            .tabItem { Label("Thư", systemImage: "envelope.fill") }
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
            .map { day -> (SpecialDay, Date) in
                let nextDate = day.date.nextAnnualOccurrence()
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
        case .letter:
            LetterEditorView(mode: .add, onSave: saveLetter)
        case .specialDay:
            SpecialDayEditorView(mode: .add, onSave: saveSpecialDay)
        case .profile(let person):
            EditProfileView(profile: profile, person: person, onSave: saveProfile)
        }
    }

    private func showAddMemory() {
        activeSheet = .memory
    }

    private func showAddLetter() {
        activeSheet = .letter
    }

    private func showAddSpecialDay() {
        activeSheet = .specialDay
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
        memories = MemoryStore.loadMemories()
    }

    private func saveMemories() {
        MemoryStore.save(memories: memories)
        memories = MemoryStore.loadMemories()
    }

    private func updateMemory(_ memory: LoveMemory) {
        guard let index = memories.firstIndex(where: { $0.id == memory.id }) else { return }
        memories[index] = memory
        MemoryStore.save(memories: memories)
        memories = MemoryStore.loadMemories()
    }

    private func saveLetter(_ letter: LoveLetter) {
        letters.insert(letter, at: 0)
        MemoryStore.save(letters: letters)
    }

    private func saveLetters() {
        MemoryStore.save(letters: letters)
    }

    private func updateLetter(_ letter: LoveLetter) {
        guard let index = letters.firstIndex(where: { $0.id == letter.id }) else { return }
        letters[index] = letter
        MemoryStore.save(letters: letters)
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
}

enum ActiveSheet: Identifiable {
    case memory
    case letter
    case specialDay
    case profile(ProfilePerson)

    var id: String {
        switch self {
        case .memory:
            return "memory"
        case .letter:
            return "letter"
        case .specialDay:
            return "specialDay"
        case .profile(let person):
            return "profile-\(person.rawValue)"
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
