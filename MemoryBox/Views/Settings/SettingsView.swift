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
    @State private var showingCloudShare = false
    @State private var iCloudStatusText = "Đang kiểm tra..."
    @State private var notificationStatusText = "Đang kiểm tra..."
    @State private var isUsingSharedSpace = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Đồng bộ cặp đôi") {
                    LabeledContent("iCloud", value: iCloudStatusText)
                    LabeledContent("Thông báo", value: notificationStatusText)

                    Button {
                        showingCloudShare = true
                    } label: {
                        Label("Mời ai đó chia sẻ dữ liệu", systemImage: "person.badge.plus")
                    }
                    .disabled(isUsingSharedSpace)

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
            .sheet(isPresented: $showingCloudShare) {
                CoupleCloudSharingView()
                    .ignoresSafeArea()
            }
            .task {
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

    private func refreshShareState() {
        isUsingSharedSpace = MemoryStore.isUsingSharedCoupleSpace()
    }

    private func refreshCloudStatus() async {
        let container = CKContainer(identifier: PersistenceController.cloudKitContainerIdentifier)
        do {
            let status = try await container.accountStatus()
            iCloudStatusText = status.displayText
        } catch {
            iCloudStatusText = "Không kiểm tra được"
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

struct CoupleCloudSharingView: UIViewControllerRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller = UICloudSharingController { _, completion in
            MemoryStore.prepareCoupleShare(completion: completion)
        }
        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowPrivate, .allowReadWrite]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) { }

    final class Coordinator: NSObject, UICloudSharingControllerDelegate {
        func itemTitle(for csc: UICloudSharingController) -> String? {
            "MemoryBox của hai người"
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            NotificationCenter.default.post(name: .memoryStoreDidChange, object: nil)
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            NotificationCenter.default.post(name: .memoryStoreDidChange, object: nil)
        }

        func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
            print("MemoryBox CloudKit share failed: \(error.localizedDescription)")
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
