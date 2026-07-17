//
//  Editors.swift
//  MemoryBox
//

import SwiftUI
import PhotosUI

enum MemoryEditorMode {
    case add
    case edit(LoveMemory)

    var title: String {
        switch self {
        case .add:
            return "Thêm kỷ niệm"
        case .edit:
            return "Sửa kỷ niệm"
        }
    }

    var existingMemory: LoveMemory? {
        switch self {
        case .add:
            return nil
        case .edit(let memory):
            return memory
        }
    }
}

struct MemoryEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var date: Date
    @State private var place: String
    @State private var note: String
    @State private var kind: MemoryKind
    @State private var mood: MemoryMood
    @State private var symbolName: String
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var imagePaths: [String]
    @State private var isFavorite: Bool
    @State private var isEditingMetadata: Bool

    let mode: MemoryEditorMode
    let onSave: (LoveMemory) -> Void

    private let symbols = ["heart.fill", "camera.fill", "gift.fill", "sun.max.fill", "moon.stars.fill", "cup.and.saucer.fill"]

    init(mode: MemoryEditorMode, onSave: @escaping (LoveMemory) -> Void) {
        let memory = mode.existingMemory
        self.mode = mode
        self.onSave = onSave
        self._title = State(initialValue: memory?.title ?? "")
        self._date = State(initialValue: memory?.date ?? Date())
        self._place = State(initialValue: memory?.place ?? "")
        self._note = State(initialValue: memory?.note ?? "")
        self._kind = State(initialValue: memory?.displayKind ?? .date)
        self._mood = State(initialValue: memory?.mood ?? .happy)
        self._symbolName = State(initialValue: memory?.symbolName ?? "heart.fill")
        self._imagePaths = State(initialValue: memory?.imagePaths ?? [])
        self._isFavorite = State(initialValue: memory?.isFavorite ?? false)
        self._isEditingMetadata = State(initialValue: false)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 12, matching: .images) {
                        Label(imagePaths.isEmpty ? "Chọn ảnh" : "Thêm ảnh", systemImage: "photo.badge.plus")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                    }
                    .buttonStyle(.borderedProminent)

                    if !imagePaths.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("\(imagePaths.count) ảnh kỷ niệm")
                                    .font(.subheadline.weight(.semibold))

                                Spacer()

                                Button(role: .destructive) {
                                    imagePaths.removeAll()
                                    place = ""
                                } label: {
                                    Label("Xóa tất cả", systemImage: "trash")
                                }
                                .font(.caption.weight(.semibold))
                                .buttonStyle(.plain)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(imagePaths, id: \.self) { path in
                                        ZStack(alignment: .topTrailing) {
                                            StoredImageView(imagePath: path)
                                                .frame(width: 86, height: 86)
                                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                                            Button(role: .destructive) {
                                                imagePaths.removeAll { $0 == path }
                                            } label: {
                                                Image(systemName: "xmark")
                                                    .font(.caption.bold())
                                                    .foregroundStyle(.white)
                                                    .frame(width: 24, height: 24)
                                                    .background(Color.black.opacity(0.45), in: Circle())
                                            }
                                            .buttonStyle(.plain)
                                            .padding(5)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    TextField("Tên kỷ niệm", text: $title)
                        .font(.headline)
                        .textInputAutocapitalization(.sentences)
                        .padding(.horizontal, 14)
                        .frame(height: 48)
                        .background(.white.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    if !imagePaths.isEmpty || isEditingMetadata {
                        metadataSummary
                    }

                    if isEditingMetadata {
                        DatePicker("Ngày", selection: $date, displayedComponents: .date)
                            .datePickerStyle(.compact)

                        TextField("Địa điểm", text: $place)
                            .textInputAutocapitalization(.words)
                            .padding(.horizontal, 14)
                            .frame(height: 44)
                            .background(.white.opacity(0.72))
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }

                    Picker("Kiểu", selection: $kind) {
                        ForEach(MemoryKind.allCases) { kind in
                            Label(kind.rawValue, systemImage: kind.icon).tag(kind)
                        }
                    }
                    .pickerStyle(.menu)

                    Picker("Tâm trạng", selection: $mood) {
                        ForEach(MemoryMood.allCases) { mood in
                            Text(mood.rawValue).tag(mood)
                        }
                    }
                    .pickerStyle(.segmented)

                    HStack {
                        Picker("Biểu tượng", selection: $symbolName) {
                            ForEach(symbols, id: \.self) { symbol in
                                Label(symbol, systemImage: symbol).tag(symbol)
                            }
                        }
                        .pickerStyle(.menu)

                        Spacer()

                        Toggle(isOn: $isFavorite) {
                            Image(systemName: "heart.fill")
                        }
                        .labelsHidden()
                    }

                    TextEditor(text: $note)
                        .frame(minHeight: 90)
                        .padding(8)
                        .background(.white.opacity(0.72))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(alignment: .topLeading) {
                            if note.trimmed.isEmpty {
                                Text("Ghi chú")
                                    .font(.body)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 16)
                                    .allowsHitTesting(false)
                            }
                        }
                }
                .padding(20)
            }
            .onChange(of: selectedPhotos) { _, newValue in
                Task {
                    let photos = await ImageLoader.photos(from: newValue)
                    let newPaths = photos.compactMap(\.imagePath)
                    imagePaths = (imagePaths + newPaths).uniqued()

                    if let takenDate = photos.compactMap(\.takenDate).first {
                        date = takenDate
                    }
                    if let photoPlace = photos.compactMap(\.place).first(where: { !$0.trimmed.isEmpty }) {
                        place = photoPlace
                    }
                    selectedPhotos.removeAll()
                }
            }
            .background(AnimatedLoveBackdrop().ignoresSafeArea())
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        onSave(
                            LoveMemory(
                                id: mode.existingMemory?.id ?? UUID(),
                                title: finalTitle,
                                date: date,
                                place: place.trimmed,
                                note: note.trimmed,
                                kind: kind,
                                mood: mood,
                                symbolName: symbolName,
                                imagePaths: imagePaths,
                                isFavorite: isFavorite
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
    }

    private var metadataSummary: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "calendar.badge.clock")
                .foregroundStyle(.pink)

            VStack(alignment: .leading, spacing: 4) {
                Text(date.formatted(date: .abbreviated, time: .omitted))
                    .font(.subheadline.weight(.semibold))

                if place.trimmed.isEmpty {
                    Text("Chưa có địa điểm từ ảnh")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text(place)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.78)) {
                    isEditingMetadata.toggle()
                }
            } label: {
                Image(systemName: "pencil")
                    .frame(width: 34, height: 34)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Sửa ngày và địa điểm")
        }
    }

    private var finalTitle: String {
        let trimmedTitle = title.trimmed
        if !trimmedTitle.isEmpty {
            return trimmedTitle
        }

        return "Kỷ niệm \(date.formatted(date: .abbreviated, time: .omitted))"
    }
}

enum LetterEditorMode {
    case add
    case edit(LoveLetter)

    var title: String {
        switch self {
        case .add:
            return "Viết thư"
        case .edit:
            return "Sửa thư"
        }
    }

    var existingLetter: LoveLetter? {
        switch self {
        case .add:
            return nil
        case .edit(let letter):
            return letter
        }
    }
}

struct LetterEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var message: String
    @State private var date: Date

    let mode: LetterEditorMode
    let onSave: (LoveLetter) -> Void

    init(mode: LetterEditorMode, onSave: @escaping (LoveLetter) -> Void) {
        let letter = mode.existingLetter
        self.mode = mode
        self.onSave = onSave
        self._title = State(initialValue: letter?.title ?? "")
        self._message = State(initialValue: letter?.message ?? "")
        self._date = State(initialValue: letter?.date ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Lời nhắn") {
                    TextField("Tiêu đề", text: $title)
                    DatePicker("Ngày viết", selection: $date, displayedComponents: .date)
                    TextEditor(text: $message)
                        .frame(minHeight: 180)
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        onSave(
                            LoveLetter(
                                id: mode.existingLetter?.id ?? UUID(),
                                title: title.trimmed,
                                message: message.trimmed,
                                date: date
                            )
                        )
                        dismiss()
                    }
                    .disabled(title.trimmed.isEmpty || message.trimmed.isEmpty)
                }
            }
        }
    }
}

enum SpecialDayEditorMode {
    case add
    case edit(SpecialDay)

    var title: String {
        switch self {
        case .add:
            return "Thêm ngày"
        case .edit:
            return "Sửa ngày"
        }
    }

    var existingDay: SpecialDay? {
        switch self {
        case .add:
            return nil
        case .edit(let day):
            return day
        }
    }
}

struct SpecialDayEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var date: Date
    @State private var symbolName: String

    let mode: SpecialDayEditorMode
    let onSave: (SpecialDay) -> Void
    private let symbols = ["heart.circle.fill", "birthday.cake.fill", "sparkles", "gift.fill", "calendar.circle.fill"]

    init(mode: SpecialDayEditorMode, onSave: @escaping (SpecialDay) -> Void) {
        let day = mode.existingDay
        self.mode = mode
        self.onSave = onSave
        self._title = State(initialValue: day?.title ?? "")
        self._date = State(initialValue: day?.date ?? Date())
        self._symbolName = State(initialValue: day?.symbolName ?? "heart.circle.fill")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Ngày đặc biệt") {
                    TextField("Tên ngày", text: $title)
                    DatePicker("Ngày", selection: $date, displayedComponents: .date)
                    Picker("Biểu tượng", selection: $symbolName) {
                        ForEach(symbols, id: \.self) { symbol in
                            Label(symbol, systemImage: symbol).tag(symbol)
                        }
                    }
                }
            }
            .navigationTitle(mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        onSave(
                            SpecialDay(
                                id: mode.existingDay?.id ?? UUID(),
                                title: title.trimmed,
                                date: date,
                                symbolName: symbolName
                            )
                        )
                        dismiss()
                    }
                    .disabled(title.trimmed.isEmpty)
                }
            }
        }
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: CoupleProfile

    let person: ProfilePerson
    let onSave: (CoupleProfile) -> Void

    private let avatarSymbols = [
        "person.fill",
        "heart.fill",
        "star.fill",
        "sparkles",
        "face.smiling.fill",
        "crown.fill",
        "camera.fill",
        "moon.stars.fill"
    ]

    init(profile: CoupleProfile, person: ProfilePerson, onSave: @escaping (CoupleProfile) -> Void) {
        self._draft = State(initialValue: profile)
        self.person = person
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    profileFields
                }
                .padding(20)
            }
            .background(AnimatedLoveBackdrop().ignoresSafeArea())
            .navigationTitle("Hồ sơ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Hủy") { dismiss() }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Lưu") {
                        onSave(
                            CoupleProfile(
                                firstName: draft.firstName.trimmed,
                                firstAvatar: draft.firstAvatar,
                                firstColor: draft.firstColor,
                                firstImagePath: draft.firstImagePath,
                                firstAvatarSize: draft.firstAvatarSize,
                                secondName: draft.secondName.trimmed,
                                secondAvatar: draft.secondAvatar,
                                secondColor: draft.secondColor,
                                secondImagePath: draft.secondImagePath,
                                secondAvatarSize: draft.secondAvatarSize
                            )
                        )
                        dismiss()
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var profileFields: some View {
        switch person {
        case .first:
            ProfileEditorSection(
                name: $draft.firstName,
                avatar: $draft.firstAvatar,
                color: $draft.firstColor,
                imagePath: $draft.firstImagePath,
                avatarSize: $draft.firstAvatarSize,
                avatarSymbols: avatarSymbols
            )
        case .second:
            ProfileEditorSection(
                name: $draft.secondName,
                avatar: $draft.secondAvatar,
                color: $draft.secondColor,
                imagePath: $draft.secondImagePath,
                avatarSize: $draft.secondAvatarSize,
                avatarSymbols: avatarSymbols
            )
        }
    }
}

struct ProfileEditorSection: View {
    @Binding var name: String
    @Binding var avatar: String
    @Binding var color: AvatarColor
    @Binding var imagePath: String?
    @Binding var avatarSize: Double
    @State private var selectedPhoto: PhotosPickerItem?
    let avatarSymbols: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(spacing: 14) {
                ZStack(alignment: .topTrailing) {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        AvatarView(symbolName: avatar, color: color.color, imagePath: imagePath, size: avatarSize)
                            .overlay(alignment: .bottomTrailing) {
                                Image(systemName: "camera.fill")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                                    .frame(width: 30, height: 30)
                                    .background(color.color)
                                    .clipShape(Circle())
                                    .overlay(Circle().stroke(.white, lineWidth: 2))
                            }
                    }
                    .buttonStyle(.plain)
                    .onChange(of: selectedPhoto) { _, newValue in
                        Task {
                            imagePath = await ImageLoader.imagePath(from: newValue, category: "profiles")
                        }
                    }
                    .animation(.spring(response: 0.3, dampingFraction: 0.78), value: avatarSize)

                    if imagePath != nil {
                        Button(role: .destructive) {
                            imagePath = nil
                        } label: {
                            Image(systemName: "xmark")
                                .font(.caption.bold())
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(Color.black.opacity(0.35))
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Xóa ảnh")
                    }
                }

                TextField("Tên hiển thị", text: $name)
                    .textInputAutocapitalization(.words)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 14)
                    .frame(height: 46)
                    .background(.white.opacity(0.78))
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Kích thước avatar")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int(avatarSize))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                Slider(value: $avatarSize, in: 72...132, step: 2)
                    .tint(color.color)
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Biểu tượng")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                    ForEach(avatarSymbols, id: \.self) { symbol in
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                                avatar = symbol
                            }
                        } label: {
                            Image(systemName: symbol)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(avatar == symbol ? .white : color.color)
                                .frame(maxWidth: .infinity)
                                .frame(height: 46)
                                .background(avatar == symbol ? color.color : .white.opacity(0.78))
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(symbol)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                Text("Màu")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    ForEach(AvatarColor.allCases) { option in
                        Button {
                            withAnimation(.spring(response: 0.28, dampingFraction: 0.74)) {
                                color = option
                            }
                        } label: {
                            Circle()
                                .fill(option.color.gradient)
                                .frame(width: 34, height: 34)
                                .overlay(
                                    Circle()
                                        .stroke(color == option ? Color.primary.opacity(0.55) : Color.white.opacity(0.85), lineWidth: color == option ? 3 : 2)
                                )
                                .overlay {
                                    if color == option {
                                        Image(systemName: "checkmark")
                                            .font(.caption.bold())
                                            .foregroundStyle(.white)
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(option.rawValue)
                    }
                }
            }
        }
        .padding(18)
        .background(.white.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.white.opacity(0.75), lineWidth: 1)
        )
        .shadow(color: color.color.opacity(0.18), radius: 18, y: 10)
    }
}

