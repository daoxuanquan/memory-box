//
//  LoveMessageArrivalView.swift
//  MemoryBox
//

import SwiftUI

struct LoveMessageArrivalView: View {
    let message: LoveMessage
    let profile: CoupleProfile
    let onOpenConversation: () -> Void
    let onHide: () -> Void
    let onAcknowledge: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var phase: ArrivalPhase = .invite
    @State private var petalRotation = false

    private enum ArrivalPhase {
        case invite
        case blooming
        case revealed
    }

    private var senderRole: MessageSenderRole {
        message.senderRole
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.25).ignoresSafeArea())
                .onTapGesture { }

            Group {
                switch phase {
                case .invite:
                    inviteCard
                case .blooming:
                    bloomStage
                case .revealed:
                    messageCard
                }
            }
            .padding(24)
            .animation(.spring(response: 0.55, dampingFraction: 0.8), value: phase)
        }
    }

    private var inviteCard: some View {
        VStack(spacing: 18) {
            MessageAvatarView(profile: profile, role: senderRole, size: 72)

            Image(systemName: "envelope.heart.fill")
                .font(.system(size: 42))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.pink, .purple.opacity(0.85)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .pink.opacity(0.3), radius: 12, y: 6)

            VStack(spacing: 8) {
                Text("Bạn có một tin nhắn")
                    .font(.title3.weight(.semibold))

                Text("được gửi từ \(senderName)")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            HStack(spacing: 12) {
                Button("Ẩn") {
                    onHide()
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                Button("Đọc") {
                    startReading()
                }
                .buttonStyle(.borderedProminent)
                .tint(.pink)
            }
            .padding(.top, 4)
        }
        .padding(28)
        .frame(maxWidth: 360)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        .transition(.scale.combined(with: .opacity))
    }

    @ViewBuilder
    private var bloomStage: some View {
        VStack(spacing: 18) {
            ZStack {
                ForEach(0..<8, id: \.self) { index in
                    Image(systemName: "heart.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.pink.opacity(0.75))
                        .offset(y: -72)
                        .rotationEffect(.degrees(Double(index) * 45 + (petalRotation ? 8 : -8)))
                        .opacity(0.95)
                        .scaleEffect(1)
                }

                Image(systemName: "heart.circle.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.pink, .purple.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(1.08)
                    .shadow(color: .pink.opacity(0.35), radius: 18, y: 8)
            }
            .frame(height: 180)

            Text("Đang mở tin nhắn từ \(senderName)...")
                .font(.headline)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
    }

    private var messageCard: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                MessageAvatarView(profile: profile, role: senderRole, size: 64)

                Text(senderName)
                    .font(.title3.weight(.semibold))

                Label(message.mood.rawValue, systemImage: message.mood.icon)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(message.mood.color)
            }
            .padding(.top, 24)
            .padding(.horizontal, 22)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if message.hasImage, let data = message.imageData, let uiImage = UIImage(data: data) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFill()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }

                    if message.hasText {
                        Text(message.message)
                            .font(.body)
                            .foregroundStyle(.primary)
                            .lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .fill(Color.pink.opacity(0.08))
                )
                .padding(.horizontal, 22)
                .padding(.vertical, 16)
            }
            .frame(maxHeight: 320)

            VStack(spacing: 16) {
                HStack(spacing: 10) {
                    ForEach(MessageReaction.allCases) { reaction in
                        Button {
                            MemoryStore.setLoveMessageReaction(id: message.id, reaction: reaction)
                        } label: {
                            Text(reaction.emoji)
                                .font(.title3)
                                .frame(width: 42, height: 42)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack(spacing: 12) {
                    Button("Mở hội thoại") {
                        onOpenConversation()
                        onAcknowledge()
                    }
                    .buttonStyle(.bordered)

                    Button("Đã đọc") {
                        onAcknowledge()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.pink)
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: 360)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
        .transition(.scale.combined(with: .opacity))
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.pink.opacity(0.10),
                                Color.purple.opacity(0.06)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
    }

    private var senderName: String {
        switch senderRole {
        case .first:
            return profile.firstName.trimmed.isEmpty ? "Người thứ nhất" : profile.firstName
        case .second:
            return profile.secondName.trimmed.isEmpty ? "Người thứ hai" : profile.secondName
        }
    }

    private func startReading() {
        if reduceMotion {
            withAnimation {
                phase = .revealed
            }
            return
        }

        withAnimation(.spring(response: 0.7, dampingFraction: 0.72)) {
            phase = .blooming
            petalRotation = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.spring(response: 0.65, dampingFraction: 0.78)) {
                phase = .revealed
            }
        }
    }
}

struct MessageAvatarView: View {
    let profile: CoupleProfile
    let role: MessageSenderRole
    let size: CGFloat

    var body: some View {
        Group {
            if let image = avatarImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: symbolName)
                    .font(.system(size: size * 0.34, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(color)
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .overlay(Circle().stroke(.white.opacity(0.8), lineWidth: 2))
        .shadow(color: color.opacity(0.28), radius: 10, y: 5)
    }

    private var avatarImage: UIImage? {
        switch role {
        case .first:
            return profile.firstImageData.flatMap(UIImage.init(data:))
        case .second:
            return profile.secondImageData.flatMap(UIImage.init(data:))
        }
    }

    private var symbolName: String {
        role == .first ? profile.firstAvatar : profile.secondAvatar
    }

    private var color: Color {
        role == .first ? profile.firstColor.color : profile.secondColor.color
    }
}
