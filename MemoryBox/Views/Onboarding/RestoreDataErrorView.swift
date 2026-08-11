//
//  RestoreDataErrorView.swift
//  MemoryBox
//

import SwiftUI

struct RestoreDataErrorView: View {
    let errorCode: RestoreDataErrorCode
    let onRetry: () -> Void
    let onBackToWelcome: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.orange)

            VStack(spacing: 8) {
                Text("Không tải được dữ liệu cũ")
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
