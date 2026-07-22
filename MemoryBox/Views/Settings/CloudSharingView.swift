//
//  CloudSharingView.swift
//  MemoryBox
//

import CloudKit
import SwiftUI
import UIKit

struct ShareInvitePayload: Identifiable {
    let share: CKShare
    let container: CKContainer

    var id: String { share.recordID.recordName }
}

struct ShareInviteSheet: View {
    @Environment(\.dismiss) private var dismiss
    let share: CKShare
    let container: CKContainer

    @State private var inviteURL: URL?
    @State private var isLoadingLink = false
    @State private var didCopy = false
    @State private var loadError: String?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "link.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.pink)
                    .padding(.top, 24)

                Text("Gửi link cho người ấy")
                    .font(.title3.bold())

                Text("Người nhận bấm link → mở MemoryBox → chấp nhận mời. Sau đó hai bạn cùng xem và chỉnh sửa kỷ niệm, tin nhắn, ngày đặc biệt qua iCloud.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Group {
                    if isLoadingLink {
                        ProgressView("Đang lấy link iCloud...")
                            .padding()
                    } else if let inviteURL {
                        linkSection(inviteURL)
                    } else {
                        VStack(spacing: 12) {
                            Text(loadError ?? "Chưa lấy được link. Hãy thử lại sau vài giây.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)

                            Button("Thử lại") {
                                Task { await loadInviteURL() }
                            }
                            .buttonStyle(.bordered)
                        }
                        .padding(.horizontal)
                    }
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
            .task {
                await loadInviteURL()
            }
        }
    }

    @ViewBuilder
    private func linkSection(_ link: URL) -> some View {
        Text(link.absoluteString)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .lineLimit(3)
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
            Label(didCopy ? "Đã sao chép link" : "Sao chép link", systemImage: didCopy ? "checkmark" : "doc.on.doc")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(.pink)
        .padding(.horizontal)

        ShareLink(item: link, subject: Text("Mời vào MemoryBox"), message: Text("Mở link này để cùng nhau dùng MemoryBox nhé!")) {
            Label("Gửi qua iMessage / Zalo...", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .padding(.horizontal)

        Text("Người nhận cần đã cài MemoryBox và đăng nhập iCloud.")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }

    private func loadInviteURL() async {
        isLoadingLink = true
        loadError = nil
        defer { isLoadingLink = false }

        if let url = share.url {
            inviteURL = url
            return
        }

        if let url = await MemoryStore.fetchCoupleShareURL(share: share, container: container) {
            inviteURL = url
        } else {
            loadError = "iCloud chưa trả về link. Đợi vài giây rồi bấm Thử lại."
        }
    }
}
