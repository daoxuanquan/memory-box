//
//  WelcomeView.swift
//  MemoryBox
//

import SwiftUI

@MainActor
@Observable
final class WelcomeViewModel {
    var title = "Memory Love"
    var subtitle = "Khoảnh khắc của hai bạn"
}

struct WelcomeView: View {
    @State private var viewModel = WelcomeViewModel()
    let onSetupOwn: () -> Void
    let onRestoreOwn: () -> Void
    let onImportFromLink: () -> Void

    var body: some View {
        VStack(spacing: 22) {
            Spacer()

            Image(systemName: "heart.circle.fill")
                .font(.system(size: 72))
                .foregroundStyle(.pink)

            VStack(spacing: 8) {
                Text(viewModel.title)
                    .font(.largeTitle.bold())
                Text(viewModel.subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                OnboardingPrimaryButton(title: "Tự thiết lập dữ liệu", systemImage: "heart.fill", action: onSetupOwn)

                Button(action: onRestoreOwn) {
                    Label("Tải dữ liệu cũ", systemImage: "clock.arrow.circlepath")
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.bordered)

                Button(action: onImportFromLink) {
                    Label("Nhập từ link được mời", systemImage: "link")
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.bordered)
            }

            Text("Tự thiết lập: bắt đầu mới trên máy này, sau đó có thể mời người ấy.\nTải dữ liệu cũ: khôi phục kỷ niệm đã có trên máy / iCloud.\nNhập link: dùng không gian người ấy đã mời.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
    }
}
