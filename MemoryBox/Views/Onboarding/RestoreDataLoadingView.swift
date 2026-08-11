//
//  RestoreDataLoadingView.swift
//  MemoryBox
//

import SwiftUI

struct RestoreDataLoadingView: View {
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
                Text("Đang tải dữ liệu cũ")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("Kiểm tra máy và iCloud...")
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
