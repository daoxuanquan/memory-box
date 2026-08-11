//
//  SettingsView.swift
//  MemoryBox
//

import CloudKit
import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppAppearance.storageKey) private var appearanceRaw = AppAppearance.light.rawValue
    @State private var inviteSheet: ShareInvitePayload?
    @State private var isPreparingShare = false
    @State private var shareErrorText: String?
    @State private var iCloudStatusText = "Đang kiểm tra..."
    @State private var notificationStatusText = "Đang kiểm tra..."
    @State private var spaceMembership = MemoryStore.loadSpaceMembership()
    @State private var selectedAppIcon: AppIconChoice = .dragonBulliesPig
    @State private var iconErrorText: String?
    @State private var showingLeaveConfirmation = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Đồng bộ cặp đôi") {
                    LabeledContent("Trạng thái", value: shareStatusText)
                    LabeledContent("iCloud", value: iCloudStatusText)
                    LabeledContent("Thông báo", value: notificationStatusText)

                    if spaceMembership != .participant {
                        Button {
                            prepareInviteLink()
                        } label: {
                            HStack {
                                Label("Mời người ấy", systemImage: "person.badge.plus")
                                if isPreparingShare {
                                    Spacer()
                                    ProgressView()
                                }
                            }
                        }
                        .disabled(isPreparingShare)
                    } else {
                        Button(role: .destructive) {
                            showingLeaveConfirmation = true
                        } label: {
                            Label("Rời không gian chia sẻ", systemImage: "rectangle.portrait.and.arrow.right")
                        }
                    }

                    Text(shareHelpText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Quyền truy cập") {
                    Button {
                        Task {
                            await refreshNotificationPermission(requestIfNeeded: true)
                        }
                    } label: {
                        Label("Bật thông báo khi có cập nhật", systemImage: "bell.badge")
                    }

                    Text("Khi CloudKit import dữ liệu mới từ người kia, MemoryBox sẽ tải lại dữ liệu và gửi một thông báo cục bộ trên thiết bị này.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Giao diện") {
                    Picker("Chế độ hiển thị", selection: $appearanceRaw) {
                        ForEach(AppAppearance.allCases) { mode in
                            Label(mode.title, systemImage: mode.icon)
                                .tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)

                    Text("App luôn dùng chế độ bạn chọn, không theo cài đặt Sáng/Tối của iPhone.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Icon ứng dụng") {
                    HStack(spacing: 20) {
                        ForEach(AppIconChoice.allCases) { choice in
                            AppIconOptionRow(
                                imageName: choice.previewImageName,
                                isSelected: selectedAppIcon == choice
                            ) {
                                Task {
                                    await selectAppIcon(choice)
                                }
                            }
                            .accessibilityLabel(choice.title)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.vertical, 4)

                    Text("Lựa chọn sẽ đồng bộ qua iCloud.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Cài đặt")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") {
                        dismiss()
                    }
                }
            }
            .sheet(item: $inviteSheet) { payload in
                ShareInviteSheet(share: payload.share, container: payload.container)
            }
            .alert("Không tạo được link chia sẻ", isPresented: shareErrorBinding) {
                Button("Đóng", role: .cancel) { shareErrorText = nil }
            } message: {
                Text(shareErrorText ?? "")
            }
            .alert("Không đổi được icon", isPresented: iconErrorBinding) {
                Button("Đóng", role: .cancel) { iconErrorText = nil }
            } message: {
                Text(iconErrorText ?? "")
            }
            .alert("Rời không gian chia sẻ?", isPresented: $showingLeaveConfirmation) {
                Button("Hủy", role: .cancel) { }
                Button("Rời", role: .destructive) {
                    OnboardingStore.save(activeDataSource: .ownPrivate)
                    MemoryStore.save(spaceMembership: .ownLocal)
                    spaceMembership = .ownLocal
                    NotificationCenter.default.post(name: .memoryStoreDidChange, object: nil)
                }
            } message: {
                Text("MemoryBox sẽ quay về dữ liệu riêng trên máy này. Dữ liệu shared không bị gộp trong bản MVP.")
            }
            .task {
                let syncedChoice = MemoryStore.loadAppIconChoice()
                selectedAppIcon = syncedChoice
                _ = await AppIconManager.setIcon(syncedChoice)
                refreshShareState()
                await refreshCloudStatus()
                await refreshNotificationPermission(requestIfNeeded: false)
            }
        }
    }

    private var iconErrorBinding: Binding<Bool> {
        Binding(
            get: { iconErrorText != nil },
            set: { if !$0 { iconErrorText = nil } }
        )
    }

    private func selectAppIcon(_ choice: AppIconChoice) async {
        let previousChoice = selectedAppIcon
        selectedAppIcon = choice

        let result = await AppIconManager.setIcon(choice)
        switch result {
        case .success:
            MemoryStore.save(appIcon: choice)
        case .failure(let error):
            selectedAppIcon = previousChoice
            iconErrorText = error.localizedDescription
        }
    }

    private var shareHelpText: String {
        if spaceMembership == .participant {
            return "Thiết bị này đã tham gia không gian MemoryBox được chia sẻ. Dữ liệu sẽ đồng bộ qua iCloud."
        }

        return "Tạo link mời để gửi cho người ấy. Khi họ mở link và chấp nhận, hai máy sẽ đồng bộ dữ liệu qua iCloud."
    }

    private var shareStatusText: String {
        switch spaceMembership {
        case .ownLocal:
            return "Dữ liệu trên máy này"
        case .ownSharedPendingPartner, .owner:
            return "Đang chờ người ấy tham gia"
        case .participant:
            return "Đã tham gia không gian chia sẻ"
        }
    }

    private func prepareInviteLink() {
        guard !isPreparingShare else { return }
        isPreparingShare = true

        Task {
            let container = CKContainer(identifier: PersistenceController.cloudKitContainerIdentifier)
            do {
                let status = try await container.accountStatus()
                guard status == .available else {
                    isPreparingShare = false
                    shareErrorText = "MemoryBox cần iCloud đã đăng nhập để tạo link mời."
                    return
                }
            } catch {
                isPreparingShare = false
                shareErrorText = "Không kiểm tra được iCloud: \(error.localizedDescription)"
                return
            }

            MemoryStore.prepareCoupleShare { share, container, error in
                Task { @MainActor in
                    isPreparingShare = false
                    if let share, let container {
                        MemoryStore.save(spaceMembership: .ownSharedPendingPartner)
                        spaceMembership = .ownSharedPendingPartner
                        inviteSheet = ShareInvitePayload(share: share, container: container)
                    } else {
                        shareErrorText = error?.localizedDescription ?? "Không tạo được link mời."
                    }
                }
            }
        }
    }

    private var shareErrorBinding: Binding<Bool> {
        Binding(
            get: { shareErrorText != nil },
            set: { if !$0 { shareErrorText = nil } }
        )
    }

    private func refreshShareState() {
        spaceMembership = MemoryStore.loadSpaceMembership()
    }

    private func refreshCloudStatus() async {
        let container = CKContainer(identifier: PersistenceController.cloudKitContainerIdentifier)
        do {
            let status = try await container.accountStatus()
            iCloudStatusText = status.displayText
            MemoryLog.share("SettingsView: iCloud accountStatus=\(status.displayText)")
        } catch {
            iCloudStatusText = "Không kiểm tra được"
            MemoryLog.share("SettingsView: accountStatus lỗi: \(error.localizedDescription)")
        }
    }

    private func refreshNotificationPermission(requestIfNeeded: Bool) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()

        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            notificationStatusText = "Đã bật"
        case .denied:
            notificationStatusText = "Đang tắt"
        case .notDetermined:
            if requestIfNeeded {
                let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
                notificationStatusText = granted ? "Đã bật" : "Đang tắt"
            } else {
                notificationStatusText = "Chưa hỏi quyền"
            }
        @unknown default:
            notificationStatusText = "Không xác định"
        }
    }
}

private struct AppIconOptionRow: View {
    let imageName: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? Color.pink : Color.secondary.opacity(0.25), lineWidth: isSelected ? 2.5 : 1)
                    )
                    .shadow(color: isSelected ? Color.pink.opacity(0.28) : .clear, radius: 8, y: 3)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? Color.pink : Color.secondary.opacity(0.55))
                    .accessibilityLabel(isSelected ? "Đã chọn" : "Chưa chọn")
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private extension CKAccountStatus {
    var displayText: String {
        switch self {
        case .available:
            return "Sẵn sàng"
        case .couldNotDetermine:
            return "Không xác định"
        case .noAccount:
            return "Chưa đăng nhập"
        case .restricted:
            return "Bị giới hạn"
        case .temporarilyUnavailable:
            return "Tạm thời không sẵn sàng"
        @unknown default:
            return "Không xác định"
        }
    }
}

#Preview {
    SettingsView()
}
