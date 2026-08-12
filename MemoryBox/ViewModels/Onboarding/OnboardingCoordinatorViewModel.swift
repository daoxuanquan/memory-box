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
        PersistenceController.bootstrapIfNeeded()
        path = .setupOwn
        OnboardingStore.abortRestoreSession()
        OnboardingStore.abortImportSession()
        OnboardingStore.save(choice: .setupOwn)
        OnboardingStore.save(activeDataSource: .ownPrivate)
        OnboardingStore.save(role: .first)
        role = .first
        // Không tạo CoupleSpace / AppSettings ở đây — tránh export shell rỗng lên iCloud.
        step = .profile
    }

    func startRestoreOwnPath() {
        MemoryLog.restore("startRestoreOwnPath: user chọn Tải dữ liệu cũ")
        PersistenceController.bootstrapIfNeeded()
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
        PersistenceController.bootstrapIfNeeded()
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
        PersistenceController.bootstrapIfNeeded()
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
        // Profile / start date are persisted only when the user edits those steps.
        // Do not overwrite AppSettings here — same as memories (not re-saved on Done).
        OnboardingStore.save(role: finalMembership == .participant ? .second : .first)
        OnboardingStore.complete(
            membership: finalMembership,
            activeDataSource: finalMembership == .participant ? .sharedInvite : .ownPrivate
        )
        onComplete()
    }

    func persistProfileDraftIfNeeded() {
        let draftHasContent =
            !profile.firstName.trimmed.isEmpty
            || !profile.secondName.trimmed.isEmpty
            || profile.firstImagePath != nil
            || profile.secondImagePath != nil

        guard draftHasContent else { return }
        MemoryStore.save(profile: profile)
    }

    func persistStartDateDraftIfNeeded() {
        guard hasStartDate else { return }
        MemoryStore.save(startDate: startDate, isSet: true)
    }

    private func probePrivateDataForRestore() async {
        MemoryLog.restore("probePrivateDataForRestore: bắt đầu")
        let probeStartedAt = Date()
        OnboardingStore.update(restorePhase: .probing)
        MemoryStore.logPrivateStoreSnapshot(reason: "restore probe ban đầu")

        if MemoryStore.hasPrivateCoupleDataOnly() {
            MemoryLog.restore("probePrivateDataForRestore: có data local ngay — finish")
            finishRestoreProbe()
            return
        }

        let container = CKContainer(identifier: PersistenceController.cloudKitContainerIdentifier)
        do {
            let status = try await container.accountStatus()
            MemoryLog.restore("probePrivateDataForRestore: iCloud accountStatus=\(status.rawValue)")
            guard status == .available else {
                MemoryLog.restore("probePrivateDataForRestore: iCloud không available → lỗi")
                OnboardingStore.update(restorePhase: .failed)
                step = .restoreDataError(.icloudUnavailable)
                return
            }
        } catch {
            MemoryLog.restore("probePrivateDataForRestore: lỗi kiểm tra iCloud — \(error.localizedDescription)")
            OnboardingStore.update(restorePhase: .failed)
            step = .restoreDataError(.storeError)
            return
        }

        OnboardingStore.update(restorePhase: .syncingFromCloud)
        step = .restoreDataLoading("Đang đồng bộ từ iCloud...")
        MemoryLog.restore("probePrivateDataForRestore: chờ CloudKit import (timeout 120s, batch import có thể đến muộn)")

        let deadline = Date().addingTimeInterval(120)
        var poll = 0
        var lastSeenImportAt = probeStartedAt

        while Date() < deadline {
            poll += 1

            if let importAt = PersistenceController.lastCloudKitImportFinishedAt,
               importAt > lastSeenImportAt {
                lastSeenImportAt = importAt
                MemoryLog.restore("probePrivateDataForRestore: CloudKit import batch mới — tiếp tục chờ")
                step = .restoreDataLoading("Đang đồng bộ từ iCloud...")
            }

            MemoryStore.reconcileAfterCloudSync()
            if MemoryStore.hasPrivateCoupleDataOnly() {
                MemoryLog.restore("probePrivateDataForRestore: có data sau poll #\(poll) — finish")
                finishRestoreProbe()
                return
            }

            let elapsed = Date().timeIntervalSince(probeStartedAt)
            let quietSinceLastImport = Date().timeIntervalSince(lastSeenImportAt)
            // CloudKit thường import nhiều batch: batch đầu có thể rỗng, batch sau mới có kỷ niệm.
            if PersistenceController.lastCloudKitImportFinishedAt != nil,
               elapsed > 60,
               quietSinceLastImport > 45 {
                MemoryLog.restore(
                    "probePrivateDataForRestore: không có import mới \(Int(quietSinceLastImport))s, vẫn không có data"
                )
                MemoryStore.logPrivateStoreSnapshot(reason: "sau import im lặng")
                break
            }

            if poll % 5 == 0 {
                MemoryLog.restore(
                    "probePrivateDataForRestore: poll #\(poll) elapsed=\(Int(elapsed))s quiet=\(Int(quietSinceLastImport))s"
                )
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        MemoryLog.restore("probePrivateDataForRestore: không tìm thấy dữ liệu cũ — restoreNotFound")
        MemoryStore.logPrivateStoreSnapshot(reason: "restore timeout")
        OnboardingStore.update(restorePhase: .failed)
        step = .restoreDataError(.restoreNotFound)
    }

    /// CloudKit import đến muộn (sau khi UI đã báo lỗi) — tự hoàn tất restore nếu data vừa sync xuống.
    func handleLateRestoreDataArrival() {
        guard OnboardingStore.restoreSessionActive else { return }
        guard MemoryStore.hasPrivateCoupleDataOnly() else { return }

        switch step {
        case .restoreDataLoading, .restoreDataError:
            MemoryLog.restore("handleLateRestoreDataArrival: data đến muộn — finish restore")
            finishRestoreProbe()
        default:
            break
        }
    }

    private func finishRestoreProbe() {
        MemoryLog.restore("finishRestoreProbe: restore thành công")
        MemoryStore.logPrivateStoreSnapshot(reason: "restore success")
        OnboardingStore.finishRestoreSession()
        MemoryStore.save(spaceMembership: .ownLocal)
        OnboardingStore.save(role: .first)
        role = .first
        MemoryStore.save(onboardingCompleted: true)
        OnboardingStore.flushPendingRoleToStoreIfNeeded()
        Task {
            await loadDraftData()
            step = .done
        }
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
