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

    private var sortedMemories: [LoveMemory] {
        filteredMemories.sorted { $0.date > $1.date }
    }

    private var filteredMemories: [LoveMemory] {
        guard let selectedKind else { return memories }
        return memories.filter { $0.displayKind == selectedKind }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                kindFilterBar

                if sortedMemories.isEmpty {
                    EmptyActionView(
                        icon: "photo.badge.plus",
                        title: selectedKind == nil ? "Chưa có kỷ niệm" : "Chưa có mục này",
                        message: selectedKind == nil ? "Tạo kỷ niệm đầu tiên bằng ảnh, ngày và kiểu kỷ niệm." : "Đổi bộ lọc hoặc thêm kỷ niệm mới cho nhóm này.",
                        actionTitle: "Thêm",
                        action: { showingAddMemory = true }
                    )
                    .padding(.top, 70)
                } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 14)], spacing: 14) {
                        ForEach(Array(sortedMemories.enumerated()), id: \.element.id) { index, memory in
                            NavigationLink {
                                MemoryDetailView(memory: memory, onUpdate: onUpdate)
                            } label: {
                                MemoryPhotoCard(memory: memory, style: .grid, rotatesImages: index < 2)
                            }
                            .buttonStyle(.plain)
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

                                Button(role: .destructive) {
                                    deleteMemory(id: memory.id)
                                } label: {
                                    Label("Xóa", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .background(AppTheme.background)
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
            .padding(.horizontal, 16)
            .padding(.top, 12)
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
    @State private var showingEditor = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                ZStack(alignment: .bottomLeading) {
                    MemoryVisual(memory: memory)
                        .frame(height: 320)

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
                .frame(height: 320)
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
            .padding(20)
        }
        .background(AppTheme.background)
        .navigationTitle("Chi tiết")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if onUpdate != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingEditor = true
                    } label: {
                        Image(systemName: "pencil")
                    }
                }
            }
        }
        .sheet(isPresented: $showingEditor) {
            MemoryEditorView(mode: .edit(memory)) { updatedMemory in
                onUpdate?(updatedMemory)
            }
        }
    }
}
