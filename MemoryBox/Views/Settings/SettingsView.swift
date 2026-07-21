//
//  SettingsView.swift
//  MemoryBox
//

import CloudKit
import SwiftUI
import UIKit
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var preparedShare: PreparedShare?
    @State private var isPreparingShare = false
    @State private var shareErrorText: String?
    @State private var iCloudStatusText = "Đang kiểm tra..."
    @State private var notificationStatusText = "Đang kiểm tra..."
    @State private var isUsingSharedSpace = false
    @State private var selectedAppIcon: AppIconChoice = .dragonBulliesPig

    var body: some View {
        NavigationStack {
            Form {
                Section("Đồng bộ cặp đôi") {
                    LabeledContent("iCloud", value: iCloudStatusText)
                    LabeledContent("Thông báo", value: notificationStatusText)

                    Button {
                        prepareShare()
                    } label: {
                        HStack {
                            Label("Mời ai đó chia sẻ dữ liệu", systemImage: "person.badge.plus")
                            if isPreparingShare {
                                Spacer()
                                ProgressView()
                            }
                        }
                    }
                    .disabled(isUsingSharedSpace || isPreparingShare)

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

                Section("Icon ứng dụng") {
                    Picker("Chọn icon", selection: $selectedAppIcon) {
                        ForEach(AppIconChoice.allCases) { choice in
                            Text(choice.title).tag(choice)
                        }
                    }
                    .pickerStyle(.inline)
                    .onChange(of: selectedAppIcon) { _, choice in
                        AppIconManager.setIcon(choice)
                        MemoryStore.save(appIcon: choice)
                    }

                    Text("Lựa chọn icon sẽ đồng bộ qua iCloud để thiết bị của cả hai người cùng đổi.")
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
            .sheet(item: $preparedShare) { prepared in
                ShareInviteSheet(share: prepared.share)
            }
            .alert("Không tạo được link chia sẻ", isPresented: shareErrorBinding) {
                Button("Đóng", role: .cancel) { shareErrorText = nil }
            } message: {
                Text(shareErrorText ?? "")
            }
            .task {
                let syncedChoice = MemoryStore.loadAppIconChoice()
                selectedAppIcon = syncedChoice
                AppIconManager.setIcon(syncedChoice)
                refreshShareState()
                await refreshCloudStatus()
                await refreshNotificationPermission(requestIfNeeded: false)
            }
        }
    }

    private var shareHelpText: String {
        if isUsingSharedSpace {
            return "Thiết bị này đang dùng không gian MemoryBox được chia sẻ qua CloudKit."
        }

        return "Người được mời cần đăng nhập iCloud, cài MemoryBox và chấp nhận link mời. Sau đó dữ liệu trong không gian chung sẽ đồng bộ qua CloudKit."
    }

    private var shareErrorBinding: Binding<Bool> {
        Binding(
            get: { shareErrorText != nil },
            set: { if !$0 { shareErrorText = nil } }
        )
    }

    private func prepareShare() {
        MemoryLog.share("SettingsView: bấm nút 'Mời ai đó chia sẻ' (isUsingSharedSpace=\(isUsingSharedSpace))")
        guard !isPreparingShare else { return }
        isPreparingShare = true
        MemoryStore.prepareCoupleShare { share, container, error in
            isPreparingShare = false
            if let share, let container {
                MemoryLog.share("SettingsView: share sẵn sàng -> present controller")
                preparedShare = PreparedShare(share: share, container: container)
            } else {
                let message = error?.localizedDescription ?? "Lỗi không xác định"
                MemoryLog.share("SettingsView: chuẩn bị share thất bại: \(message)")
                shareErrorText = message
            }
        }
    }

    private func refreshShareState() {
        isUsingSharedSpace = MemoryStore.isUsingSharedCoupleSpace()
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

struct PreparedShare: Identifiable {
    let share: CKShare
    let container: CKContainer

    var id: String { share.url?.absoluteString ?? share.recordID.recordName }
}

struct ShareInviteSheet: View {
    @Environment(\.dismiss) private var dismiss
    let share: CKShare
    @State private var didCopy = false

    private var link: URL? { share.url }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.pink)
                    .padding(.top, 24)

                Text("Gửi link này cho người ấy")
                    .font(.title3.bold())

                Text("Người nhận cần đăng nhập iCloud và đã cài MemoryBox. Bấm vào link để tham gia và cùng chỉnh sửa.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                if let link {
                    Text(link.absoluteString)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)

                    Button {
                        UIPasteboard.general.url = link
                        didCopy = true
                    } label: {
                        Label(didCopy ? "Đã sao chép" : "Sao chép link", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                    .padding(.horizontal)

                    ShareLink(item: link) {
                        Label("Chia sẻ qua ứng dụng khác", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .padding(.horizontal)
                } else {
                    Text("Chưa lấy được link chia sẻ. Vui lòng thử lại.")
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .navigationTitle("Mời chia sẻ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Đóng") { dismiss() }
                }
            }
        }
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
