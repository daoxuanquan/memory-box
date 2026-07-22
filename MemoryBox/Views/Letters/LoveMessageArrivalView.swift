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
    @State private var themeEffectsAreFloating = false
    @State private var selectedReaction: MessageReaction?
    @State private var reactionBurst: MessageReaction?

    // Bloom animation states
    @State private var bloomProgress: CGFloat = 0
    @State private var envelopeOpen = false
    @State private var centerPulse = false
    @State private var particlesLaunched = false
    @State private var bloomStartedAt = Date()

    private enum ArrivalPhase {
        case invite
        case blooming
        case revealed
    }

    private var senderRole: MessageSenderRole {
        message.senderRole
    }

    private var isAngryTheme: Bool {
        message.mood == .angry
    }

    private var themeColor: Color {
        isAngryTheme ? .red : .pink
    }

    private var bloomSymbols: [String] {
        isAngryTheme
            ? ["flame.fill", "bolt.fill", "exclamationmark.triangle.fill", "flame.fill", "bolt.fill", "flame.fill", "hand.raised.fill", "flame.fill", "bolt.fill", "flame.fill", "exclamationmark.triangle.fill", "flame.fill"]
            : ["heart.fill", "sparkles", "heart.circle.fill", "sparkle", "heart.fill", "star.fill", "heart.fill", "sparkles", "heart.circle.fill", "sparkle", "heart.fill", "moon.stars.fill"]
    }

    var body: some View {
        ZStack {
            arrivalBackground
                .onTapGesture { }

            Group {
                switch phase {
                case .invite:
                    inviteCard
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .scale(scale: 0.86).combined(with: .opacity)
                        ))
                case .blooming:
                    bloomStage
                        .transition(.opacity)
                case .revealed:
                    messageCard
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.82).combined(with: .opacity),
                            removal: .opacity
                        ))
                }
            }
            .padding(24)

            if let reactionBurst {
                ReactionBurstView(reaction: reactionBurst)
                    .allowsHitTesting(false)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .onAppear {
            selectedReaction = message.reaction
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 3.2).repeatForever(autoreverses: true)) {
                themeEffectsAreFloating = true
            }
        }
    }

    @ViewBuilder
    private var arrivalBackground: some View {
        ZStack {
            if phase == .revealed || phase == .blooming {
                LinearGradient(
                    colors: isAngryTheme
                        ? [
                            Color.black.opacity(0.96),
                            Color.red.opacity(0.82),
                            Color.orange.opacity(0.68)
                        ]
                        : [
                            Color.pink.opacity(0.92),
                            Color.purple.opacity(0.72),
                            Color.orange.opacity(0.52),
                            Color.white.opacity(0.92)
                        ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .opacity(phase == .blooming ? Double(bloomProgress) : 1)

                if phase == .revealed {
                    GeometryReader { proxy in
                        ForEach(Array(bloomSymbols.prefix(6).enumerated()), id: \.offset) { index, symbol in
                            Image(systemName: symbol)
                                .font(.system(size: index.isMultiple(of: 2) ? 34 : 22, weight: .semibold))
                                .foregroundStyle(.white.opacity(index.isMultiple(of: 2) ? 0.34 : 0.24))
                                .position(
                                    x: proxy.size.width * CGFloat([0.12, 0.32, 0.58, 0.82, 0.9, 0.42][index]),
                                    y: proxy.size.height * CGFloat([0.16, 0.72, 0.3, 0.8, 0.14, 0.54][index])
                                )
                                .offset(
                                    x: themeEffectsAreFloating ? CGFloat((index % 3) - 1) * 12 : 0,
                                    y: themeEffectsAreFloating ? CGFloat(index.isMultiple(of: 2) ? -20 : 18) : 0
                                )
                                .rotationEffect(.degrees(themeEffectsAreFloating ? Double(index * 6 - 12) : Double(12 - index * 4)))
                        }
                    }
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                }
            } else {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.28).ignoresSafeArea())
            }
        }
        .animation(.easeInOut(duration: 0.8), value: phase)
    }

    private var inviteCard: some View {
        VStack(spacing: 18) {
            MessageAvatarView(profile: profile, role: senderRole, size: 72)

            Image(systemName: "envelope.open.fill")
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
        .fixedSize(horizontal: false, vertical: true)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
    }

    private var bloomStage: some View {
        SwiftUI.TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: false)) { context in
            let elapsed = context.date.timeIntervalSince(bloomStartedAt)
            let spin = elapsed * (isAngryTheme ? 280 : 160)
            let bob = sin(elapsed * (isAngryTheme ? 8 : 4.5))

            ZStack {
                ForEach(Array(bloomSymbols.enumerated()), id: \.offset) { index, symbol in
                    Image(systemName: symbol)
                        .font(.system(size: particleSize(for: index), weight: .semibold))
                        .foregroundStyle(particleColor(for: index))
                        .shadow(color: themeColor.opacity(0.45), radius: 8, y: 2)
                        .offset(particleOffset(for: index, spinDegrees: spin, bob: bob))
                        .rotationEffect(.degrees(particleRotation(for: index, spinDegrees: spin)))
                        .scaleEffect(particlesLaunched ? 1 + CGFloat(bob) * 0.06 : 0.15)
                        .opacity(particlesLaunched ? particleOpacity(for: index) : 0)
                }

                ForEach(0..<3, id: \.self) { ring in
                    Circle()
                        .stroke(
                            themeColor.opacity(0.35 - Double(ring) * 0.08),
                            lineWidth: 2
                        )
                        .frame(width: 70 + CGFloat(ring) * 48)
                        .scaleEffect(bloomProgress * (1.2 + CGFloat(ring) * 0.35) + CGFloat(bob) * 0.04)
                        .opacity(Double(1 - bloomProgress) * (0.8 - Double(ring) * 0.2))
                }

                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    themeColor.opacity(0.55),
                                    themeColor.opacity(0.08),
                                    .clear
                                ],
                                center: .center,
                                startRadius: 4,
                                endRadius: 90
                            )
                        )
                        .frame(width: 180, height: 180)
                        .scaleEffect(centerPulse ? 1.18 : 0.88)
                        .opacity(0.85)

                    Image(systemName: envelopeOpen
                          ? (isAngryTheme ? "flame.fill" : "heart.circle.fill")
                          : "envelope.fill")
                        .font(.system(size: envelopeOpen ? 72 : 54, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: isAngryTheme
                                    ? [.red, .orange, .yellow]
                                    : [.pink, .purple, .orange.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(isAngryTheme ? spin * 0.25 : bob * 8))
                        .scaleEffect(envelopeOpen ? (centerPulse ? 1.14 : 1.0) : 0.92)
                        .offset(y: CGFloat(bob) * (isAngryTheme ? 4 : 6))
                        .shadow(color: themeColor.opacity(0.55), radius: centerPulse ? 28 : 14, y: 8)
                }

                VStack {
                    Spacer()
                    Text(isAngryTheme ? "Đang bung lửa..." : "Đang nở hoa...")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.25), radius: 6, y: 2)
                        .opacity(Double(bloomProgress))
                        .offset(y: -36)
                }
                .frame(maxHeight: 320)
            }
            .frame(maxWidth: .infinity, maxHeight: 360)
        }
    }

    private var messageCard: some View {
        VStack(spacing: 16) {
            VStack(spacing: 10) {
                MessageAvatarView(profile: profile, role: senderRole, size: 56)

                Text(senderName)
                    .font(.title3.weight(.semibold))
            }

            messageBody
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                ForEach(MessageReaction.allCases) { reaction in
                    Button {
                        selectReaction(reaction)
                    } label: {
                        Text(reaction.emoji)
                            .font(.title3)
                            .frame(width: 42, height: 42)
                            .background(
                                selectedReaction == reaction
                                    ? themeColor.opacity(0.22)
                                    : Color(.secondarySystemBackground)
                            )
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        selectedReaction == reaction ? themeColor : .clear,
                                        lineWidth: 2
                                    )
                            )
                            .scaleEffect(selectedReaction == reaction ? 1.12 : 1)
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
                .tint(themeColor)
            }
        }
        .padding(22)
        .frame(maxWidth: 360)
        .fixedSize(horizontal: false, vertical: true)
        .background(cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, y: 12)
    }

    @ViewBuilder
    private var messageBody: some View {
        let body = VStack(alignment: .leading, spacing: 12) {
            if message.hasImage, let data = message.imageData, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            if message.hasText {
                Text(message.message)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(themeColor.opacity(isAngryTheme ? 0.10 : 0.08))
        )

        ViewThatFits(in: .vertical) {
            body

            ScrollView {
                body
            }
            .frame(maxHeight: 240)
        }
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color(.systemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                themeColor.opacity(isAngryTheme ? 0.14 : 0.10),
                                (isAngryTheme ? Color.orange : Color.purple).opacity(0.06)
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

    // MARK: - Particle helpers

    private func particleSize(for index: Int) -> CGFloat {
        CGFloat([18, 26, 22, 30, 20, 28, 24, 32, 18, 26, 22, 28][index % 12])
    }

    private func particleColor(for index: Int) -> Color {
        if isAngryTheme {
            return [Color.red, Color.orange, Color.yellow.opacity(0.9), Color.red.opacity(0.85)][index % 4]
        }
        return [Color.pink, Color.purple.opacity(0.9), Color.white, Color.orange.opacity(0.85)][index % 4]
    }

    private func particleOffset(for index: Int, spinDegrees: Double, bob: Double) -> CGSize {
        let angle = Double(index) / Double(bloomSymbols.count) * 2 * .pi
            + spinDegrees * .pi / 180 * (isAngryTheme ? 0.55 : 0.28)
        let baseRadius: CGFloat = isAngryTheme ? 118 : 108
        let radius = particlesLaunched
            ? baseRadius * bloomProgress + CGFloat(index % 3) * 18 + CGFloat(bob) * 6
            : 8
        let lift: CGFloat = isAngryTheme
            ? CGFloat(bob) * 8
            : -bloomProgress * 36 + CGFloat(bob) * 10
        return CGSize(
            width: CGFloat(cos(angle)) * radius,
            height: CGFloat(sin(angle)) * radius + lift
        )
    }

    private func particleRotation(for index: Int, spinDegrees: Double) -> Double {
        let base = Double(index) * 30
        return particlesLaunched ? base + spinDegrees * (isAngryTheme ? 1.4 : 0.8) : base
    }

    private func particleOpacity(for index: Int) -> Double {
        let fade = max(0, 1 - Double(bloomProgress) * 0.35)
        return fade * (index.isMultiple(of: 2) ? 1 : 0.75)
    }

    // MARK: - Actions

    private func selectReaction(_ reaction: MessageReaction) {
        MemoryStore.setLoveMessageReaction(id: message.id, reaction: reaction)

        withAnimation(.spring(response: 0.35, dampingFraction: 0.55)) {
            selectedReaction = reaction
            reactionBurst = reaction
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.15) {
            withAnimation(.easeOut(duration: 0.25)) {
                reactionBurst = nil
            }
        }
    }

    private func startReading() {
        if reduceMotion {
            withAnimation {
                phase = .revealed
            }
            return
        }

        bloomStartedAt = Date()
        bloomProgress = 0
        envelopeOpen = false
        particlesLaunched = false
        centerPulse = false

        withAnimation(.easeOut(duration: 0.28)) {
            phase = .blooming
        }

        withAnimation(.spring(response: 0.5, dampingFraction: 0.62).delay(0.08)) {
            envelopeOpen = true
            particlesLaunched = true
        }

        withAnimation(.easeOut(duration: 1.5)) {
            bloomProgress = 1
        }

        withAnimation(.easeInOut(duration: isAngryTheme ? 0.32 : 0.5).repeatForever(autoreverses: true)) {
            centerPulse = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) {
            withAnimation(.spring(response: 0.58, dampingFraction: 0.78)) {
                phase = .revealed
            }
        }
    }
}

private struct ReactionBurstView: View {
    let reaction: MessageReaction

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isBursting = false

    private let offsets: [CGSize] = [
        CGSize(width: -92, height: -130),
        CGSize(width: -42, height: -170),
        CGSize(width: 24, height: -155),
        CGSize(width: 84, height: -118),
        CGSize(width: -105, height: -58),
        CGSize(width: 105, height: -48),
        CGSize(width: -58, height: -92),
        CGSize(width: 56, height: -82)
    ]

    var body: some View {
        ZStack {
            ForEach(offsets.indices, id: \.self) { index in
                Text(reaction.emoji)
                    .font(.system(size: index.isMultiple(of: 2) ? 28 : 22))
                    .offset(isBursting && !reduceMotion ? offsets[index] : .zero)
                    .scaleEffect(isBursting ? 1.1 : 0.35)
                    .opacity(isBursting ? 0 : 1)
                    .rotationEffect(.degrees(isBursting ? Double(index * 24 - 72) : 0))
            }

            Text(reaction.emoji)
                .font(.system(size: 64))
                .scaleEffect(isBursting ? 1.35 : 0.5)
                .opacity(isBursting ? 0.2 : 1)
        }
        .onAppear {
            withAnimation(.easeOut(duration: reduceMotion ? 0.35 : 0.9)) {
                isBursting = true
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
