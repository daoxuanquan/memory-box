//
//  OnboardingCoordinatorView.swift
//  MemoryBox
//

import CloudKit
import SwiftUI
import UIKit

struct RootCoordinatorView: View {
    @State private var showOnboarding = !OnboardingStore.onboardingCompleted
    @State private var joinResult: JoinResultPayload?

    var body: some View {
        Group {
            if showOnboarding {
                OnboardingCoordinatorView {
                    showOnboarding = false
                }
            } else {
                ContentView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .coupleShareDidAccept)) { notification in
            let success = notification.userInfo?["success"] as? Bool ?? false
            let error = notification.userInfo?["error"] as? String
            joinResult = JoinResultPayload(success: success, message: error)
            if success, !OnboardingStore.onboardingCompleted {
                showOnboarding = true
            }
        }
        .sheet(item: $joinResult) { result in
            if result.success {
                JoinResultView(payload: result) {
                    OnboardingStore.save(role: .second)
                    OnboardingStore.complete(membership: .participant, activeDataSource: .sharedInvite)
                    showOnboarding = false
                    joinResult = nil
                } onContinueAlone: {
                    joinResult = nil
                }
            } else {
                SharedImportErrorView(errorCode: .acceptFailed) {
                    OnboardingStore.beginImportSession()
                    showOnboarding = true
                    joinResult = nil
                } onBackToWelcome: {
                    OnboardingStore.abortImportSession()
                    showOnboarding = !OnboardingStore.onboardingCompleted
                    joinResult = nil
                }
            }
        }
    }
}

struct OnboardingCoordinatorView: View {
    let onComplete: () -> Void

    @State private var viewModel = OnboardingCoordinatorViewModel()

    var body: some View {
        ZStack {
            AnimatedLoveBackdrop()
                .ignoresSafeArea()

            VStack(spacing: 18) {
                if viewModel.progressTotal > 0 {
                    OnboardingProgressBar(progress: viewModel.progress)
                        .padding(.top, 16)
                }

                content
                    .frame(maxWidth: 390)
                    .padding(.horizontal, 24)
                    .frame(maxHeight: .infinity)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await viewModel.loadDraftData()
        }
        .sheet(isPresented: Binding(
            get: { viewModel.showICloudSheet },
            set: { viewModel.showICloudSheet = $0 }
        )) {
            ICloudRequiredSheet(message: viewModel.iCloudMessage) {
                viewModel.abortImportAndReturnWelcome()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .coupleShareDidAccept)) { notification in
            let success = notification.userInfo?["success"] as? Bool ?? false
            let error = notification.userInfo?["error"] as? String
            viewModel.handleShareAccept(success: success, error: error)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.step {
        case .welcome:
            WelcomeView(
                onSetupOwn: viewModel.startSetupOwnPath,
                onRestoreOwn: viewModel.startRestoreOwnPath,
                onImportFromLink: viewModel.startImportPath
            )
        case .abandonLocalConfirm:
            LocalDataAbandonConfirmView {
                viewModel.acknowledgeLocalAbandonAndContinueImport()
            } onBack: {
                viewModel.abortImportAndReturnWelcome()
            }
        case .restoreDataLoading(let statusText):
            RestoreDataLoadingView(statusText: statusText)
        case .restoreDataError(let errorCode):
            RestoreDataErrorView(
                errorCode: errorCode,
                onRetry: viewModel.retryRestoreOwnPath,
                onBackToWelcome: viewModel.abortRestoreAndReturnWelcome
            )
        case .joinExplain:
            JoinExplainView(
                isChecking: viewModel.isCheckingJoin,
                onAcceptedCheck: viewModel.checkJoinStatus,
                onBack: viewModel.abortImportAndReturnWelcome
            )
        case .sharedImportLoading(let statusText):
            SharedImportLoadingView(statusText: statusText)
        case .sharedImportError(let errorCode):
            SharedImportErrorView(
                errorCode: errorCode,
                onRetry: viewModel.checkJoinStatus,
                onBackToWelcome: viewModel.abortImportAndReturnWelcome
            )
        case .joinResult(let success, let message):
            JoinResultView(payload: JoinResultPayload(success: success, message: message)) {
                if success {
                    OnboardingStore.complete(membership: .participant, activeDataSource: .sharedInvite)
                    onComplete()
                } else {
                    viewModel.step = .joinExplain
                }
            } onContinueAlone: {
                viewModel.startSetupOwnPath()
            }
        case .profile:
            OnboardingProfileView(role: viewModel.role ?? .first, profile: Binding(
                get: { viewModel.profile },
                set: { viewModel.profile = $0 }
            )) {
                viewModel.persistProfileDraftIfNeeded()
                viewModel.step = .startDate
            } onBack: {
                viewModel.step = .welcome
            }
        case .startDate:
            OnboardingStartDateView(date: Binding(
                get: { viewModel.startDate },
                set: { viewModel.startDate = $0 }
            ), hasStartDate: Binding(
                get: { viewModel.hasStartDate },
                set: { viewModel.hasStartDate = $0 }
            )) {
                viewModel.persistStartDateDraftIfNeeded()
                viewModel.step = .done
            } onBack: {
                viewModel.step = .profile
            }
        case .done:
            OnboardingDoneView {
                viewModel.finishCurrentPath(onComplete: onComplete)
            }
        }
    }

}

struct LocalDataAbandonConfirmView: View {
    let onContinue: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            OnboardingBackButton(action: onBack)
            OnboardingTitle(
                title: "Dữ liệu trên máy này sẽ không dùng nữa",
                subtitle: "App sẽ dùng không gian chia sẻ. Dữ liệu cũ trên máy không được gộp."
            )

            Spacer()

            Button(role: .destructive, action: onContinue) {
                Label("Tiếp tục nhập link", systemImage: "arrow.right")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)

            Button("Quay lại", action: onBack)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .padding(.vertical, 16)
    }
}

struct OnboardingProfileView: View {
    let role: MessageSenderRole
    @Binding var profile: CoupleProfile
    let onContinue: () -> Void
    let onBack: () -> Void

    private var name: Binding<String> {
        Binding {
            role == .first ? profile.firstName : profile.secondName
        } set: { value in
            if role == .first {
                profile.firstName = String(value.prefix(40))
            } else {
                profile.secondName = String(value.prefix(40))
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            OnboardingBackButton(action: onBack)
            OnboardingTitle(title: "Hồ sơ của bạn", subtitle: "Thêm tên để người ấy nhận ra bạn.")

            VStack(spacing: 16) {
                Image(systemName: role == .first ? profile.firstAvatar : profile.secondAvatar)
                    .font(.system(size: 50))
                    .foregroundStyle(.white)
                    .frame(width: 108, height: 108)
                    .background((role == .first ? profile.firstColor.color : profile.secondColor.color).gradient, in: Circle())

                TextField("Tên", text: name)
                    .textInputAutocapitalization(.words)
                    .font(.headline)
                    .padding(.horizontal, 14)
                    .frame(height: 48)
                    .background(.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }
            .frame(maxWidth: .infinity)
            .padding(18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer()
            OnboardingPrimaryButton(title: "Tiếp tục", systemImage: "arrow.right", action: onContinue)
            Button("Bỏ qua bước này", action: onContinue)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
        }
        .padding(.vertical, 16)
    }
}

struct OnboardingStartDateView: View {
    @Binding var date: Date
    @Binding var hasStartDate: Bool
    let onContinue: () -> Void
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            OnboardingBackButton(action: onBack)
            OnboardingTitle(title: "Ngày bắt đầu của hai bạn", subtitle: "Chọn mốc đầu tiên để MemoryBox đếm ngày bên nhau.")

            DatePicker("Ngày bắt đầu", selection: $date, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(.pink)
                .padding(16)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            Spacer()
            OnboardingPrimaryButton(title: "Lưu ngày", systemImage: "checkmark", action: {
                hasStartDate = true
                onContinue()
            })
            Button("Để sau") {
                hasStartDate = false
                onContinue()
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 44)
        }
        .padding(.vertical, 16)
    }
}

struct JoinExplainView: View {
    let isChecking: Bool
    let onAcceptedCheck: () -> Void
    let onBack: () -> Void
    @State private var clipboardErrorText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            OnboardingBackButton(action: onBack)
            OnboardingTitle(title: "Nhập từ link được mời", subtitle: "Mở link mời, nhấn Chấp nhận, rồi quay lại đây.")

            Button(action: openClipboardLink) {
                Label("Mở link trong Clipboard", systemImage: "link")
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.bordered)

            Button(action: onAcceptedCheck) {
                HStack {
                    Label("Tôi đã Accept - tiếp tục", systemImage: "checkmark.icloud")
                    if isChecking {
                        Spacer()
                        ProgressView()
                            .tint(.white)
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(.pink)
            .disabled(isChecking)

            Spacer()
        }
        .padding(.vertical, 16)
        .alert("Không mở được link", isPresented: clipboardErrorBinding) {
            Button("Đóng", role: .cancel) { clipboardErrorText = nil }
        } message: {
            Text(clipboardErrorText ?? "")
        }
    }

    private var clipboardErrorBinding: Binding<Bool> {
        Binding(
            get: { clipboardErrorText != nil },
            set: { if !$0 { clipboardErrorText = nil } }
        )
    }

    private func openClipboardLink() {
        let pastedURL = UIPasteboard.general.url
            ?? UIPasteboard.general.string.flatMap { URL(string: $0.trimmed) }

        guard let pastedURL, UIApplication.shared.canOpenURL(pastedURL) else {
            clipboardErrorText = "Clipboard chưa có link mời hợp lệ. Hãy sao chép link người ấy gửi rồi thử lại."
            return
        }

        UIApplication.shared.open(pastedURL)
    }
}

struct SharedImportLoadingView: View {
    let statusText: String

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ZStack {
                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.pink.opacity(0.18))
                ProgressView()
                    .controlSize(.large)
                    .tint(.pink)
            }

            VStack(spacing: 8) {
                Text("Đang tải không gian chia sẻ")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("Vui lòng giữ mạng ổn định.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Text(statusText)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.pink)
                    .multilineTextAlignment(.center)
                    .padding(.top, 6)
            }

            Spacer()
        }
        .padding(.vertical, 16)
    }
}

struct SharedImportErrorView: View {
    let errorCode: SharedImportErrorCode
    let onRetry: () -> Void
    let onBackToWelcome: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("Không tải được không gian chia sẻ")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text(errorCode.message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            OnboardingPrimaryButton(title: "Thử lại", systemImage: "arrow.clockwise", action: onRetry)

            Button(action: onBackToWelcome) {
                Text("Quay lại Welcome")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.bordered)
        }
        .padding(.vertical, 16)
    }
}

struct JoinResultPayload: Identifiable {
    let id = UUID()
    let success: Bool
    let message: String?
}

struct JoinResultView: View {
    let payload: JoinResultPayload
    let onContinue: () -> Void
    let onContinueAlone: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: payload.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(payload.success ? .green : .orange)

                Text(payload.success ? "Đã tham gia không gian chia sẻ" : "Không tham gia được")
                    .font(.title2.bold())

                Text(payload.success ? "Dữ liệu sẽ đồng bộ qua iCloud." : (payload.message ?? "Hãy thử mở lại link mời."))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                OnboardingPrimaryButton(title: payload.success ? "Vào trang chủ" : "Thử lại", systemImage: "arrow.right", action: onContinue)

                if !payload.success {
                    Button("Tự thiết lập dữ liệu", action: onContinueAlone)
                        .buttonStyle(.bordered)
                }
            }
            .padding(24)
            .navigationTitle("Lời mời")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct OnboardingDoneView: View {
    let onStart: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "heart.circle.fill")
                .font(.system(size: 76))
                .foregroundStyle(.pink)
            Text("Tất cả đã sẵn sàng")
                .font(.title2.bold())
            Spacer()
            OnboardingPrimaryButton(title: "Bắt đầu", systemImage: "arrow.right", action: onStart)
        }
        .padding(.vertical, 16)
    }
}

struct ICloudRequiredSheet: View {
    @Environment(\.dismiss) private var dismiss
    let message: String
    let onLater: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Image(systemName: "icloud.slash.fill")
                    .font(.system(size: 58))
                    .foregroundStyle(.pink)
                Text("Cần iCloud")
                    .font(.title2.bold())
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Mở Cài đặt iCloud") {
                    UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
                Button("Để sau") {
                    dismiss()
                    onLater()
                }
                .buttonStyle(.bordered)
            }
            .padding(24)
        }
    }
}

struct OnboardingTitle: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2.bold())
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}

struct OnboardingPrimaryButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
        }
        .buttonStyle(.borderedProminent)
        .tint(.pink)
    }
}

struct OnboardingBackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .font(.headline)
                .frame(width: 36, height: 36)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Quay lại")
    }
}

struct OnboardingProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.gray.opacity(0.2))
                Capsule().fill(Color.pink)
                    .frame(width: proxy.size.width * max(0, min(progress, 1)))
            }
        }
        .frame(height: 4)
        .frame(maxWidth: 390)
        .padding(.horizontal, 24)
    }
}

private extension MessageSenderRole {
    var title: String {
        switch self {
        case .first:
            return "Người thứ nhất"
        case .second:
            return "Người thứ hai"
        }
    }
}
