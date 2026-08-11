//
//  CoupleDataRoutingService.swift
//  MemoryBox
//

import CoreData

/// Central routing gate for couple data. Import sessions are shared-only;
/// restore sessions are private-only. There is no private/shared fallback here.
enum CoupleDataRoutingService {
    static func activeStore() -> NSPersistentStore? {
        if OnboardingStore.importSessionActive || OnboardingStore.activeDataSource == .sharedInvite {
            if OnboardingStore.importSessionActive && OnboardingStore.activeDataSource != .sharedInvite {
                MemoryLog.share("CoupleDataRoutingService: import session forced sharedInvite routing")
                OnboardingStore.save(activeDataSource: .sharedInvite)
            }
            return PersistenceController.shared.sharedPersistentStore
        }

        if OnboardingStore.restoreSessionActive || OnboardingStore.activeDataSource == .ownPrivate {
            return PersistenceController.shared.privatePersistentStore
        }

        return PersistenceController.shared.privatePersistentStore
    }
}
