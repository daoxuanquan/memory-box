//
//  MessageComposerView.swift
//  MemoryBox
//

import PhotosUI
import SwiftUI

struct MessageComposerView: View {
    @Environment(\.dismiss) private var dismiss

    let profile: CoupleProfile
    let replyTo: LoveMessage?
    let editingMessage: LoveMessage?
    let onSend: (LoveMessageDraft) -> Void

    @State private var message = ""
    @State private var mood: MessageMood = .sweet
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @FocusState private var isMessageFocused: Bool

    private var recipientRole: MessageSenderRole {
        MemoryStore.currentSenderRole() == .first ? .second : .first
    }

    private var canSend: Bool {
        !message.trimmed.isEmpty || imageData != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                themeBackground
                    .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 14) {
                        replyPreview
                        HStack {
                            Text("Gửi tới \(recipientName)")
                                .font(.subheadline.weight(.semibold))

                            Spacer()

                            themePicker
                        }
                        messageCard
                    }
                    .padding(20)
                }
            }
            .navigationTitle(editingMessage == nil ? "Gửi yêu thương" : "Sửa tin nhắn")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button(editingMessage == nil ? "Gửi" : "Lưu") {
                        sendMessage()
                    }
                    .fontWeight(.semibold)
                    .disabled(!canSend)
                }
            }
            .onAppear {
                if let editingMessage {
                    message = editingMessage.message
                    mood = editingMessage.mood == .angry ? .angry : .sweet
                    imageData = editingMessage.imageData
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    isMessageFocused = true
                }
            }
            .onChange(of: selectedPhoto) { _, item in
                Task {
                    guard let data = await ImageLoader.data(from: item) else { return }
                    imageData = ImageFileStore.compressedJPEGData(from: data)
                }
            }
            .animation(.easeInOut(duration: 0.35), value: mood)
        }
    }

    private var themeBackground: some View {
        ZStack {
            LinearGradient(
                colors: mood == .angry
                    ? [
                        Color.red.opacity(0.32),
                        Color.orange.opacity(0.24),
                        Color.black.opacity(0.08),
                        Color.white.opacity(0.72)
                    ]
                    : [
                        Color.pink.opacity(0.27),
                        Color.purple.opacity(0.16),
                        Color.orange.opacity(0.12),
                        Color.white.opacity(0.76)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            GeometryReader { proxy in
                ForEach(0..<6, id: \.self) { index in
                    Image(systemName: mood == .angry ? "flame.fill" : "heart.fill")
                        .font(.system(size: index.isMultiple(of: 2) ? 30 : 20))
                        .foregroundStyle(
                            (mood == .angry ? Color.red : Color.pink)
                                .opacity(index.isMultiple(of: 2) ? 0.18 : 0.12)
                        )
                        .position(
                            x: proxy.size.width * CGFloat([0.12, 0.3, 0.52, 0.72, 0.88, 0.42][index]),
                            y: proxy.size.height * CGFloat([0.18, 0.72, 0.32, 0.82, 0.16, 0.55][index])
                        )
                }
            }
        }
    }

    @ViewBuilder
    private var replyPreview: some View {
        if let replyTo {
            HStack(spacing: 10) {
                Rectangle()
                    .fill(Color.pink)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Trả lời")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.pink)

                    Text(replyTo.message.trimmed.isEmpty ? "Ảnh yêu thương" : replyTo.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()
            }
            .padding(14)
            .background(composerCardBackground)
        }
    }

    private var themePicker: some View {
        Menu {
            Button {
                mood = .sweet
            } label: {
                Label("Ngọt ngào", systemImage: MessageMood.sweet.icon)
            }

            Button {
                mood = .angry
            } label: {
                Label("Giận dữ", systemImage: MessageMood.angry.icon)
            }
        } label: {
            Label(mood == .angry ? "Giận dữ" : "Ngọt ngào", systemImage: mood == .angry ? MessageMood.angry.icon : MessageMood.sweet.icon)
                .font(.caption.weight(.semibold))
                .foregroundStyle(mood == .angry ? Color.red : Color.pink)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background((mood == .angry ? Color.red : Color.pink).opacity(0.12))
                .clipShape(Capsule())
        }
    }

    private var messageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Lời nhắn")
                .font(.subheadline.weight(.semibold))

            ZStack(alignment: .topLeading) {
                if message.trimmed.isEmpty {
                    Text("Viết điều bạn muốn người ấy đọc khi mở app...")
                        .font(.body)
                        .foregroundStyle(.tertiary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 12)
                }

                TextEditor(text: $message)
                    .frame(minHeight: 160)
                    .scrollContentBackground(.hidden)
                    .focused($isMessageFocused)
            }
            .padding(10)
            .background(Color.white.opacity(0.72))
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack {
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(imageData == nil ? "Đính kèm ảnh" : "Đổi ảnh", systemImage: "paperclip")
                        .font(.subheadline.weight(.semibold))
                }

                Spacer()

                Text(mood == .angry ? "Chủ đề giận dữ" : "Chủ đề ngọt ngào")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let imageData, let uiImage = UIImage(data: imageData) {
                ZStack(alignment: .topTrailing) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    Button {
                        self.imageData = nil
                        selectedPhoto = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, .black.opacity(0.45))
                    }
                    .padding(10)
                }
            }
        }
        .padding(16)
        .background(composerCardBackground)
    }

    private var recipientName: String {
        switch recipientRole {
        case .first:
            return profile.firstName.trimmed.isEmpty ? "Người thứ nhất" : profile.firstName
        case .second:
            return profile.secondName.trimmed.isEmpty ? "Người thứ hai" : profile.secondName
        }
    }

    private var composerCardBackground: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(.white.opacity(0.55), lineWidth: 1)
            )
    }

    private func sendMessage() {
        onSend(
            LoveMessageDraft(
                message: message,
                mood: mood,
                imageData: imageData,
                replyToID: replyTo?.id
            )
        )
        dismiss()
    }
}
