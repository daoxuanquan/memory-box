//
//  OnboardingStore.swift
//  MemoryBox
//

import Foundation

enum OnboardingChoice: String {
    case setupOwn
    case restoreOwn
    case importFromLink
}

enum RestorePhase: String {
    case idle
    case probing
    case syncingFromCloud
    case ready
    case failed
}

enum ImportPhase: String {
    case idle
    case awaitingAccept
    case accepting
    case probingSharedZone
    case hydratingSharedData
    case sharedReady
    case failed
}

enum OnboardingStore {
    static let completedKey = "memoryBox.onboardingCompleted"
    static let choiceKey = "memoryBox.onboardingChoice"
    static let activeDataSourceKey = "memoryBox.activeDataSource"
    static let restoreSessionActiveKey = "memoryBox.restoreSessionActive"
    static let restorePhaseKey = "memoryBox.restorePhase"
    static let importSessionActiveKey = "memoryBox.importSessionActive"
    static let importPhaseKey = "memoryBox.importPhase"
    static let acknowledgedLocalAbandonKey = "memoryBox.acknowledgedLocalAbandon"
    static let abandonedLocalDataAtKey = "memoryBox.abandonedLocalDataAt"
    static let inviteBannerDismissedAtKey = "memoryBox.inviteBannerDismissedAt"
    static let pendingMyRoleKey = "memoryBox.pendingMyRole"
    private static let inviteBannerDismissalDuration: TimeInterval = 7 * 24 * 60 * 60

    static var onboardingCompleted: Bool {
        MemoryStore.loadOnboardingCompleted()
    }

    static var activeDataSource: ActiveDataSource {
        if let rawValue = UserDefaults.standard.string(forKey: activeDataSourceKey),
           let source = ActiveDataSource(rawValue: rawValue) {
            return source
        }

        guard PersistenceController.isBootstrapped else { return .ownPrivate }
        return MemoryStore.isUsingSharedCoupleSpaceHeuristic() ? .sharedInvite : .ownPrivate
    }

    static func save(choice: OnboardingChoice) {
        UserDefaults.standard.set(choice.rawValue, forKey: choiceKey)
    }

    static func save(activeDataSource: ActiveDataSource) {
        UserDefaults.standard.set(activeDataSource.rawValue, forKey: activeDataSourceKey)
        guard PersistenceController.isBootstrapped else { return }
        if OnboardingStore.restoreSessionActive { return }
        if activeDataSource == .ownPrivate || MemoryStore.hasSharedCoupleSpace() {
            MemoryStore.save(activeDataSource: activeDataSource)
        }
    }

    static func markLocalDataAbandoned() {
        UserDefaults.standard.set(Date(), forKey: abandonedLocalDataAtKey)
        UserDefaults.standard.set(true, forKey: acknowledgedLocalAbandonKey)
    }

    static var importSessionActive: Bool {
        UserDefaults.standard.bool(forKey: importSessionActiveKey)
    }

    static var restoreSessionActive: Bool {
        UserDefaults.standard.bool(forKey: restoreSessionActiveKey)
    }

    static var restorePhase: RestorePhase {
        if let rawValue = UserDefaults.standard.string(forKey: restorePhaseKey),
           let phase = RestorePhase(rawValue: rawValue) {
            return phase
        }
        return .idle
    }

    static func beginRestoreSession() {
        save(choice: .restoreOwn)
        abortImportSession(switchToPrivate: false)
        UserDefaults.standard.set(true, forKey: restoreSessionActiveKey)
        UserDefaults.standard.set(RestorePhase.probing.rawValue, forKey: restorePhaseKey)
        save(activeDataSource: .ownPrivate)
    }

    static func update(restorePhase: RestorePhase) {
        UserDefaults.standard.set(restorePhase.rawValue, forKey: restorePhaseKey)
    }

    static func abortRestoreSession() {
        UserDefaults.standard.set(false, forKey: restoreSessionActiveKey)
        UserDefaults.standard.set(RestorePhase.idle.rawValue, forKey: restorePhaseKey)
    }

    static func finishRestoreSession() {
        UserDefaults.standard.set(false, forKey: restoreSessionActiveKey)
        UserDefaults.standard.set(RestorePhase.ready.rawValue, forKey: restorePhaseKey)
        save(activeDataSource: .ownPrivate)
    }

    static var importPhase: ImportPhase {
        if let rawValue = UserDefaults.standard.string(forKey: importPhaseKey),
           let phase = ImportPhase(rawValue: rawValue) {
            return phase
        }
        return .idle
    }

    static func beginImportSession() {
        save(choice: .importFromLink)
        abortRestoreSession()
        UserDefaults.standard.set(true, forKey: importSessionActiveKey)
        UserDefaults.standard.set(ImportPhase.awaitingAccept.rawValue, forKey: importPhaseKey)
        save(activeDataSource: .sharedInvite)
    }

    static func update(importPhase: ImportPhase) {
        UserDefaults.standard.set(importPhase.rawValue, forKey: importPhaseKey)
    }

    static func abortImportSession(switchToPrivate: Bool = true) {
        UserDefaults.standard.set(false, forKey: importSessionActiveKey)
        UserDefaults.standard.set(ImportPhase.idle.rawValue, forKey: importPhaseKey)
        if switchToPrivate {
            save(activeDataSource: .ownPrivate)
        }
    }

    static func finishImportSession() {
        UserDefaults.standard.set(false, forKey: importSessionActiveKey)
        UserDefaults.standard.set(ImportPhase.sharedReady.rawValue, forKey: importPhaseKey)
        save(activeDataSource: .sharedInvite)
    }

    static func shouldShowInviteBanner(membership: SpaceMembership) -> Bool {
        guard membership == .ownLocal else { return false }
        guard let dismissedAt = UserDefaults.standard.object(forKey: inviteBannerDismissedAtKey) as? Date else {
            return true
        }
        return Date().timeIntervalSince(dismissedAt) >= inviteBannerDismissalDuration
    }

    static func dismissInviteBanner() {
        UserDefaults.standard.set(Date(), forKey: inviteBannerDismissedAtKey)
    }

    static func complete(membership: SpaceMembership, activeDataSource: ActiveDataSource) {
        if activeDataSource == .sharedInvite {
            abortRestoreSession()
            finishImportSession()
        } else {
            abortRestoreSession()
            abortImportSession()
        }
        save(activeDataSource: activeDataSource)
        MemoryStore.save(spaceMembership: membership)
        MemoryStore.save(onboardingCompleted: true)
        OnboardingStore.flushPendingRoleToStoreIfNeeded()
    }

    static func save(role: MessageSenderRole) {
        UserDefaults.standard.set(role.rawValue, forKey: pendingMyRoleKey)
        guard onboardingCompleted else { return }
        MemoryStore.save(myRole: role)
    }

    static func pendingRole() -> MessageSenderRole? {
        guard let raw = UserDefaults.standard.string(forKey: pendingMyRoleKey) else { return nil }
        return MessageSenderRole(rawValue: raw)
    }

    static func flushPendingRoleToStoreIfNeeded() {
        guard onboardingCompleted, let role = pendingRole() else { return }
        MemoryStore.save(myRole: role)
    }

    static func currentRole() -> MessageSenderRole? {
        MemoryStore.loadMyRole()
    }
}
