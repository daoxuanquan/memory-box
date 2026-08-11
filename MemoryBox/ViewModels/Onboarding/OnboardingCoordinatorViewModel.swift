//
//  OnboardingCoordinatorViewModel.swift
//  MemoryBox
//

import CloudKit
import Foundation
import Observation

@MainActor
@Observable
final class OnboardingCoordinatorViewModel {
    var path: OnboardingPath?
    var step: OnboardingStep = .welcome
    var role: MessageSenderRole?
    var profile = CoupleProfile.empty
    var startDate = Date()
    var hasStartDate = false
    var showICloudSheet = false
    var iCloudMessage = "Cần iCloud đã đăng nhập để đồng bộ với người ấy."
    var isCheckingJoin = false

    var finalMembership: SpaceMembership {
        switch path {
        case .setupOwn, .restoreOwn, .none:
            return .ownLocal
        case .importFromLink:
            return .participant
        }
    }

    var progressTotal: Int {
        switch path {
        case .setupOwn:
            return 3
        case .restoreOwn:
            return 2
        case .importFromLink:
            return 2
        case .none:
            return 0
        }
    }

    var progressIndex: Int {
        switch step {
        case .welcome:
            return 0
        case .abandonLocalConfirm, .joinExplain, .restoreDataLoading:
            return 1
        case .restoreDataError, .sharedImportLoading, .sharedImportError, .joinResult:
            return 2
        case .profile:
            return 1
        case .startDate:
            return 2
        case .done:
            return progressTotal
        }
    }

    var progress: Double {
        guard progressTotal > 0 else { return 0 }
        return Double(progressIndex) / Double(progressTotal)
    }

    func loadDraftData() async {
        profile = await MemoryStore.loadProfile()
        startDate = MemoryStore.loadStartDate()
        hasStartDate = MemoryStore.loadHasStartDate()
    }

    func startSetupOwnPath() {
        path = .setupOwn
        OnboardingStore.abortRestoreSession()
        OnboardingStore.abortImportSession()
        OnboardingStore.save(choice: .setupOwn)
        OnboardingStore.save(activeDataSource: .ownPrivate)
        MemoryStore.save(spaceMembership: .ownLocal)
        OnboardingStore.save(role: .first)
        role = .first
        MemoryStore.ensurePrivateCoupleSpace()
        step = .profile
    }

    func startRestoreOwnPath() {
        path = .restoreOwn
        OnboardingStore.beginRestoreSession()
        step = .restoreDataLoading("Đang tìm dữ liệu trên máy...")
        Task { await probePrivateDataForRestore() }
    }

    func retryRestoreOwnPath() {
        startRestoreOwnPath()
    }

    func abortRestoreAndReturnWelcome() {
        path = nil
        OnboardingStore.abortRestoreSession()
        step = .welcome
    }

    func startImportPath() {
        path = .importFromLink
        if MemoryStore.hasLocalCoupleData() {
            step = .abandonLocalConfirm
        } else {
            Task { await continueImportAfterICloudCheck() }
        }
    }

    func acknowledgeLocalAbandonAndContinueImport() {
        OnboardingStore.markLocalDataAbandoned()
        Task { await continueImportAfterICloudCheck() }
    }

    func checkJoinStatus() {
        guard !isCheckingJoin else { return }
        isCheckingJoin = true
        OnboardingStore.update(importPhase: .accepting)
        step = .sharedImportLoading("Đang xác nhận lời mời...")

        Task {
            OnboardingStore.update(importPhase: .probingSharedZone)
            step = .sharedImportLoading("Đang tìm không gian chia sẻ...")

            let deadline = Date().addingTimeInterval(45)
            while Date() < deadline {
                MemoryStore.reconcileAfterCloudSync()
                if MemoryStore.hasSharedCoupleSpaceOnly() {
                    OnboardingStore.update(importPhase: .hydratingSharedData)
                    step = .sharedImportLoading("Đang đồng bộ dữ liệu từ iCloud...")
                    OnboardingStore.finishImportSession()
                    MemoryStore.save(spaceMembership: .participant)
                    OnboardingStore.save(role: .second)
                    role = .second
                    isCheckingJoin = false
                    step = .joinResult(true, nil)
                    return
                }

                try? await Task.sleep(nanoseconds: 1_000_000_000)
            }

            OnboardingStore.update(importPhase: .failed)
            isCheckingJoin = false
            step = .sharedImportError(.sharedZoneNotFound)
        }
    }

    func abortImportAndReturnWelcome() {
        path = nil
        isCheckingJoin = false
        OnboardingStore.abortImportSession()
        step = .welcome
    }

    func handleShareAccept(success: Bool, error: String?) {
        if success {
            path = .importFromLink
            OnboardingStore.beginImportSession()
            checkJoinStatus()
        } else {
            OnboardingStore.update(importPhase: .failed)
            step = .sharedImportError(error == nil ? .acceptFailed : .acceptFailed)
        }
    }

    func finishCurrentPath(onComplete: () -> Void) {
        OnboardingStore.save(role: finalMembership == .participant ? .second : .first)
        MemoryStore.save(profile: profile)
        MemoryStore.save(startDate: startDate, isSet: hasStartDate)
        OnboardingStore.complete(
            membership: finalMembership,
            activeDataSource: finalMembership == .participant ? .sharedInvite : .ownPrivate
        )
        onComplete()
    }

    private func probePrivateDataForRestore() async {
        OnboardingStore.update(restorePhase: .probing)
        if MemoryStore.hasPrivateCoupleDataOnly() {
            finishRestoreProbe()
            return
        }

        let container = CKContainer(identifier: PersistenceController.cloudKitContainerIdentifier)
        do {
            let status = try await container.accountStatus()
            guard status == .available else {
                OnboardingStore.update(restorePhase: .failed)
                step = .restoreDataError(.icloudUnavailable)
                return
            }
        } catch {
            OnboardingStore.update(restorePhase: .failed)
            step = .restoreDataError(.storeError)
            return
        }

        OnboardingStore.update(restorePhase: .syncingFromCloud)
        step = .restoreDataLoading("Đang đồng bộ từ iCloud...")

        let deadline = Date().addingTimeInterval(45)
        while Date() < deadline {
            MemoryStore.reconcileAfterCloudSync()
            if MemoryStore.hasPrivateCoupleDataOnly() {
                finishRestoreProbe()
                return
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        OnboardingStore.update(restorePhase: .failed)
        step = .restoreDataError(.restoreNotFound)
    }

    private func finishRestoreProbe() {
        OnboardingStore.finishRestoreSession()
        MemoryStore.save(spaceMembership: .ownLocal)
        OnboardingStore.save(role: .first)
        role = .first
        MemoryStore.save(onboardingCompleted: true)
        step = .done
    }

    private func continueImportAfterICloudCheck() async {
        let container = CKContainer(identifier: PersistenceController.cloudKitContainerIdentifier)
        do {
            let status = try await container.accountStatus()
            guard status == .available else {
                iCloudMessage = "MemoryBox cần iCloud đã đăng nhập để nhập dữ liệu từ link mời. Bạn vẫn có thể quay lại Welcome và chọn tự thiết lập dữ liệu."
                OnboardingStore.abortImportSession()
                showICloudSheet = true
                return
            }
            OnboardingStore.beginImportSession()
            step = .joinExplain
        } catch {
            iCloudMessage = "Không kiểm tra được iCloud: \(error.localizedDescription)"
            OnboardingStore.abortImportSession()
            showICloudSheet = true
        }
    }
}
