//
//  LettersView.swift
//  MemoryBox
//

import SwiftUI

struct LettersView: View {
    @Binding var messages: [LoveMessage]
    let profile: CoupleProfile
    let onCompose: () -> Void
    let onReload: () -> Void

    @State private var replyTarget: LoveMessage?
    @State private var editingMessage: LoveMessage?
    @State private var fullscreenImage: IdentifiableImageData?
    @State private var showingComposer = false

    private var myRole: MessageSenderRole {
        MemoryStore.currentSenderRole()
    }

    private var partnerRole: MessageSenderRole {
        myRole == .first ? .second : .first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedLoveBackdrop()
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    partnerHeader

                    if messages.isEmpty {
                        emptyState
                    } else {
                        messageList
                    }

                    composeBar
                }
            }
            .navigationTitle("Tin nhắn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: openComposer) {
                        Image(systemName: "heart.text.square.fill")
                    }
                }
            }
            .sheet(isPresented: $showingComposer, onDismiss: {
                editingMessage = nil
                replyTarget = nil
            }) {
                MessageComposerView(
                    profile: profile,
                    replyTo: replyTarget,
                    editingMessage: editingMessage,
                    onSend: handleSend
                )
            }
            .fullScreenCover(item: $fullscreenImage) { item in
                MessageImageViewer(imageData: item.data)
            }
        }
    }

    private var partnerHeader: some View {
        HStack(spacing: 14) {
            MessageAvatarView(profile: profile, role: partnerRole, size: 52)

            VStack(alignment: .leading, spacing: 4) {
                Text(partnerName)
                    .font(.headline)

                Text("Hộp thư yêu thương của hai bạn")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text("\(messages.count)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.pink)
                Text("tin nhắn")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(.ultraThinMaterial)
    }

    private var emptyState: some View {
        VStack {
            Spacer()
            EmptyActionView(
                icon: "heart.text.square.fill",
                title: "Chưa có tin nhắn",
                message: "Gửi lời yêu thương đầu tiên để người ấy nhận được popup đặc biệt khi mở app.",
                actionTitle: "Viết tin nhắn",
                action: openComposer
            )
            Spacer()
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(messages) { message in
                        LoveMessageBubble(
                            message: message,
                            profile: profile,
                            isMine: message.senderRole == myRole,
                            replyMessage: messages.first { $0.id == message.replyToID },
                            onReply: { replyTarget = message; openComposer() },
                            onReact: { reaction in
                                MemoryStore.setLoveMessageReaction(id: message.id, reaction: reaction)
                                onReload()
                            },
                            onEdit: {
                                replyTarget = nil
                                editingMessage = message
                                openComposer()
                            },
                            onDelete: {
                                MemoryStore.deleteLoveMessage(id: message.id)
                                onReload()
                            },
                            onImageTap: { data in
                                fullscreenImage = IdentifiableImageData(data: data)
                            }
                        )
                        .id(message.id)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private var composeBar: some View {
        Button(action: openComposer) {
            HStack(spacing: 12) {
                Image(systemName: "heart.fill")
                    .foregroundStyle(.pink)

                Text("Viết lời yêu thương...")
                    .foregroundStyle(.secondary)

                Spacer()

                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.pink)
                    .clipShape(Circle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
        .buttonStyle(.plain)
    }

    private var partnerName: String {
        switch partnerRole {
        case .first:
            return profile.firstName.trimmed.isEmpty ? "Người thứ nhất" : profile.firstName
        case .second:
            return profile.secondName.trimmed.isEmpty ? "Người thứ hai" : profile.secondName
        }
    }

    private func openComposer() {
        showingComposer = true
        onCompose()
    }

    private func handleSend(_ draft: LoveMessageDraft) {
        if let editingMessage {
            MemoryStore.updateLoveMessage(
                id: editingMessage.id,
                message: draft.message,
                mood: draft.mood,
                imageData: draft.imageData
            )
            self.editingMessage = nil
        } else {
            MemoryStore.sendLoveMessage(draft)
            replyTarget = nil
        }
        onReload()
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        guard let last = messages.last else { return }
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo(last.id, anchor: .bottom)
        }
    }
}

struct LoveMessageBubble: View {
    let message: LoveMessage
    let profile: CoupleProfile
    let isMine: Bool
    let replyMessage: LoveMessage?
    let onReply: () -> Void
    let onReact: (MessageReaction) -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onImageTap: (Data) -> Void

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if isMine { Spacer(minLength: 36) }

            if !isMine {
                MessageAvatarView(profile: profile, role: message.senderRole, size: 34)
            }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 6) {
                if let replyMessage {
                    replyPreview(replyMessage)
                }

                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 6) {
                        Image(systemName: message.mood.icon)
                            .font(.caption2)
                        Text(message.mood.rawValue)
                            .font(.caption2.weight(.bold))
                    }
                    .foregroundStyle(isMine ? .white.opacity(0.9) : message.mood.color)

                    if message.hasImage, let data = message.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: 220, maxHeight: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .onTapGesture { onImageTap(data) }
                    }

                    if message.hasText {
                        Text(message.message)
                            .font(.body)
                            .foregroundStyle(isMine ? .white : .primary)
                            .lineSpacing(4)
                    }

                    if let reaction = message.reaction {
                        Text(reaction.emoji)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.85))
                            .clipShape(Capsule())
                    }
                }
                .padding(14)
                .background {
                    if isMine {
                        LinearGradient(
                            colors: [.pink, .purple.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    } else {
                        Color.white.opacity(0.88)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .contextMenu {
                    Button {
                        onReply()
                    } label: {
                        Label("Trả lời", systemImage: "arrowshape.turn.up.left.fill")
                    }

                    Menu("Cảm xúc") {
                        ForEach(MessageReaction.allCases) { reaction in
                            Button(reaction.emoji) {
                                onReact(reaction)
                            }
                        }
                    }

                    if message.hasText {
                        Button {
                            UIPasteboard.general.string = message.message
                        } label: {
                            Label("Sao chép", systemImage: "doc.on.doc")
                        }
                    }

                    if isMine {
                        Button {
                            onEdit()
                        } label: {
                            Label("Sửa", systemImage: "pencil")
                        }

                        Button(role: .destructive) {
                            onDelete()
                        } label: {
                            Label("Xóa", systemImage: "trash")
                        }
                    }
                }

                HStack(spacing: 8) {
                    Text(message.sentAt, style: .time)
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    if isMine {
                        Text(message.isRead ? "Đã xem" : "Đã gửi")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(message.isRead ? .green : .secondary)
                    }
                }
            }

            if isMine {
                MessageAvatarView(profile: profile, role: message.senderRole, size: 34)
            }

            if !isMine { Spacer(minLength: 36) }
        }
    }

    @ViewBuilder
    private func replyPreview(_ reply: LoveMessage) -> some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(isMine ? Color.white.opacity(0.8) : Color.pink)
                .frame(width: 3)

            Text(reply.message.trimmed.isEmpty ? "Ảnh yêu thương" : reply.message)
                .font(.caption2)
                .foregroundStyle(isMine ? .white.opacity(0.85) : .secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 4)
    }
}

struct IdentifiableImageData: Identifiable {
    let id = UUID()
    let data: Data
}

struct MessageImageViewer: View {
    let imageData: Data
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFit()
                    .padding()
            }

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }
                .padding()
                Spacer()
            }
        }
    }
}
