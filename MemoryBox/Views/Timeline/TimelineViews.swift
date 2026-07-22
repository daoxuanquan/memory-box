//
//  TimelineViews.swift
//  MemoryBox
//

import SwiftUI

struct TimelineView: View {
    @Binding var memories: [LoveMemory]
    let onChange: () -> Void
    let onUpdate: (LoveMemory) -> Void
    @State private var showingAddMemory = false
    @State private var editingMemory: LoveMemory?
    @State private var selectedKind: MemoryKind?
    @State private var collageContainerWidth: CGFloat = 0

    private var sortedMemories: [LoveMemory] {
        filteredMemories.sorted { $0.date > $1.date }
    }

    private var filteredMemories: [LoveMemory] {
        guard let selectedKind else { return memories }
        return memories.filter { $0.displayKind == selectedKind }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedLoveBackdrop()
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        kindFilterBar

                        if sortedMemories.isEmpty {
                            EmptyActionView(
                                icon: "photo.badge.plus",
                                title: selectedKind == nil ? "Chưa có kỷ niệm" : "Chưa có mục này",
                                message: selectedKind == nil ? "Tạo kỷ niệm đầu tiên bằng ảnh, ngày và kiểu kỷ niệm." : "Đổi bộ lọc hoặc thêm kỷ niệm mới cho nhóm này.",
                                actionTitle: "Thêm",
                                action: { showingAddMemory = true }
                            )
                            .padding(.top, 54)
                        } else if collageContainerWidth > 0 {
                            MemoryCollageGrid(
                                memories: sortedMemories,
                                containerWidth: collageContainerWidth
                            ) { memory, index, size in
                                memoryCollageCell(memory: memory, index: index, size: size)
                            }
                        }
                    }
                    .onGeometryChange(for: CGFloat.self) { proxy in
                        proxy.size.width
                    } action: { newWidth in
                        collageContainerWidth = newWidth
                    }
                }
                .appScrollMargins()
            }
            .navigationTitle("Timeline")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddMemory = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddMemory) {
                MemoryEditorView(mode: .add) { memory in
                    memories.insert(memory, at: 0)
                    onChange()
                }
            }
            .sheet(item: $editingMemory) { memory in
                MemoryEditorView(mode: .edit(memory)) { updatedMemory in
                    onUpdate(updatedMemory)
                }
            }
        }
    }

    private var kindFilterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                KindFilterChip(title: "Tất cả", icon: "square.grid.2x2.fill", isSelected: selectedKind == nil) {
                    selectedKind = nil
                }

                ForEach(MemoryKind.allCases) { kind in
                    KindFilterChip(title: kind.rawValue, icon: kind.icon, isSelected: selectedKind == kind) {
                        selectedKind = kind
                    }
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private func memoryCollageCell(memory: LoveMemory, index: Int, size: CGSize) -> some View {
        NavigationLink {
            MemoryDetailView(
                memory: memory,
                onUpdate: onUpdate,
                onDelete: { deleteMemory(id: memory.id) }
            )
        } label: {
            MemoryPhotoCard(memory: memory, style: .collage, rotatesImages: index < 2)
        }
        .buttonStyle(.plain)
        .frame(width: size.width, height: size.height, alignment: .top)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .contextMenu {
            Button {
                editingMemory = memory
            } label: {
                Label("Sửa", systemImage: "pencil")
            }

            Button {
                toggleFavorite(memory)
            } label: {
                Label("Yêu thích", systemImage: "heart.fill")
            }
        }
    }

    private func deleteMemory(id: UUID) {
        memories.removeAll { $0.id == id }
        onChange()
    }

    private func toggleFavorite(_ memory: LoveMemory) {
        guard let index = memories.firstIndex(where: { $0.id == memory.id }) else { return }
        memories[index].isFavorite.toggle()
        onChange()
    }
}

struct MemoryDetailView: View {
    let memory: LoveMemory
    var onUpdate: ((LoveMemory) -> Void)?
    var onDelete: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var showingEditor = false
    @State private var showingDeleteConfirmation = false

    private var heroImagePath: String? {
        memory.imagePaths.first ?? memory.imagePath
    }

    private var heroAspectRatio: CGFloat {
        guard let heroImagePath,
              let ratio = ImageFileStore.displayAspectRatio(for: heroImagePath),
              ratio > 0 else {
            return 4 / 3
        }
        return ratio
    }

    var body: some View {
        ZStack {
            AnimatedLoveBackdrop()
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ZStack(alignment: .bottomLeading) {
                        MemoryVisual(memory: memory)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        LinearGradient(
                            colors: [.clear, .black.opacity(0.68)],
                            startPoint: .center,
                            endPoint: .bottom
                        )

                        VStack(alignment: .leading, spacing: 8) {
                            Text(memory.title)
                                .font(.title.bold())
                                .foregroundStyle(.white)

                            Label(memory.date.formatted(date: .long, time: .omitted), systemImage: "calendar")
                                .font(.subheadline)
                                .foregroundStyle(.white.opacity(0.86))
                        }
                        .padding(18)
                    }
                    .aspectRatio(heroAspectRatio, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                    if memory.imagePaths.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(memory.imagePaths, id: \.self) { path in
                                    StoredImageView(imagePath: path)
                                        .frame(width: 92, height: 92)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                }
                            }
                        }
                    }

                    HStack(spacing: 8) {
                        InfoPill(icon: memory.displayKind.icon, text: memory.displayKind.rawValue)
                        if !memory.place.trimmed.isEmpty {
                            InfoPill(icon: "mappin.and.ellipse", text: memory.place)
                        }
                    }

                    InfoPill(icon: memory.mood.icon, text: memory.mood.rawValue)

                    if !memory.note.trimmed.isEmpty {
                        Text(memory.note)
                            .font(.body)
                            .lineSpacing(5)
                            .foregroundStyle(.primary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
        }
        .navigationTitle("Chi tiết")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                if onUpdate != nil {
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .accessibilityLabel("Sửa kỷ niệm")
                }

                if onDelete != nil {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                    .accessibilityLabel("Xóa kỷ niệm")
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            MemoryEditorView(mode: .edit(memory)) { updatedMemory in
                onUpdate?(updatedMemory)
            }
        }
        .alert("Xóa kỷ niệm?", isPresented: $showingDeleteConfirmation) {
            Button("Hủy", role: .cancel) { }
            Button("Xóa", role: .destructive) {
                onDelete?()
                dismiss()
            }
        } message: {
            Text("Kỷ niệm này sẽ bị xóa khỏi timeline của hai bạn.")
        }
    }
}
