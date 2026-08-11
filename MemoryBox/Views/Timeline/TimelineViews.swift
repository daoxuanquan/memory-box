//
//  TimelineViews.swift
//  MemoryBox
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

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
    @State private var visibleHeroImagePath: String?
    @State private var selectedImagePath: String?

    private var imagePaths: [String] {
        memory.imagePaths.isEmpty ? memory.imagePath.map { [$0] } ?? [] : memory.imagePaths
    }

    private var currentHeroImagePath: String? {
        visibleHeroImagePath ?? imagePaths.first
    }

    private var heroAspectRatio: CGFloat {
        guard let currentHeroImagePath,
              let ratio = ImageFileStore.displayAspectRatio(for: currentHeroImagePath),
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
                        MemoryVisual(memory: memory, imagePathOverride: currentHeroImagePath)
                            .id(currentHeroImagePath ?? "empty-\(memory.id.uuidString)")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .transition(.opacity.combined(with: .scale(scale: 1.02)))

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
                    .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .onTapGesture {
                        if let currentHeroImagePath {
                            selectedImagePath = currentHeroImagePath
                        }
                    }

                    if imagePaths.count > 1 {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(imagePaths, id: \.self) { path in
                                    StoredImageView(imagePath: path)
                                        .frame(width: 92, height: 92)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                .stroke(path == currentHeroImagePath ? Color.pink : Color.white.opacity(0.65), lineWidth: path == currentHeroImagePath ? 3 : 1)
                                        )
                                        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                        .onTapGesture {
                                            withAnimation(.easeInOut(duration: 0.24)) {
                                                visibleHeroImagePath = path
                                            }
                                            selectedImagePath = path
                                        }
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
        .task(id: imagePaths) {
            await rotateHeroImagesIfNeeded()
        }
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
        .fullScreenCover(item: imageSelection) { selection in
            MemoryImageViewer(
                imagePaths: imagePaths,
                initialImagePath: selection.path
            )
        }
    }

    private var imageSelection: Binding<MemoryImageSelection?> {
        Binding {
            selectedImagePath.map(MemoryImageSelection.init(path:))
        } set: { selection in
            selectedImagePath = selection?.path
        }
    }

    @MainActor
    private func rotateHeroImagesIfNeeded() async {
        visibleHeroImagePath = imagePaths.first
        guard imagePaths.count > 1 else { return }

        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }

            let nextPath = randomImagePath(excluding: visibleHeroImagePath)
            withAnimation(.easeInOut(duration: 0.35)) {
                visibleHeroImagePath = nextPath
            }
        }
    }

    private func randomImagePath(excluding currentPath: String?) -> String? {
        let candidates = imagePaths.filter { $0 != currentPath }
        return (candidates.isEmpty ? imagePaths : candidates).randomElement()
    }
}

struct MemoryImageSelection: Identifiable {
    let path: String

    var id: String { path }
}

struct MemoryImageViewer: View {
    @Environment(\.dismiss) private var dismiss
    let imagePaths: [String]
    let initialImagePath: String
    @State private var selectedImagePath: String

    init(imagePaths: [String], initialImagePath: String) {
        self.imagePaths = imagePaths
        self.initialImagePath = initialImagePath
        self._selectedImagePath = State(initialValue: initialImagePath)
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                TabView(selection: $selectedImagePath) {
                    ForEach(imagePaths, id: \.self) { path in
                        ZoomableStoredImageView(imagePath: path)
                            .tag(path)
                            .ignoresSafeArea()
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .background(Color.black.ignoresSafeArea())

                if imagePaths.count > 1 {
                    imageThumbnailStrip
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .foregroundStyle(.white)
                    .accessibilityLabel("Đóng ảnh")
                }

                ToolbarItem(placement: .topBarTrailing) {
                    #if canImport(UIKit)
                    ShareLink(item: ImageFileStore.shareURL(for: selectedImagePath)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .foregroundStyle(.white)
                    .accessibilityLabel("Chia sẻ ảnh")
                    #endif
                }
            }
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }

    private var imageThumbnailStrip: some View {
        VStack(spacing: 10) {
            Text("\(selectedImageIndex + 1) / \(imagePaths.count)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(0.86))

            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(imagePaths, id: \.self) { path in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedImagePath = path
                                }
                            } label: {
                                StoredImageView(imagePath: path)
                                    .frame(width: 58, height: 58)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(path == selectedImagePath ? Color.white : Color.white.opacity(0.32), lineWidth: path == selectedImagePath ? 3 : 1)
                                    )
                                    .opacity(path == selectedImagePath ? 1 : 0.62)
                            }
                            .buttonStyle(.plain)
                            .id(path)
                            .accessibilityLabel(path == selectedImagePath ? "Ảnh đang xem" : "Xem ảnh")
                        }
                    }
                    .padding(.horizontal, 18)
                }
                .onAppear {
                    proxy.scrollTo(selectedImagePath, anchor: .center)
                }
                .onChange(of: selectedImagePath) { _, newPath in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(newPath, anchor: .center)
                    }
                }
            }
        }
        .padding(.top, 12)
        .padding(.bottom, 22)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.72), .black.opacity(0.92)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea(edges: .bottom)
        )
    }

    private var selectedImageIndex: Int {
        imagePaths.firstIndex(of: selectedImagePath) ?? 0
    }
}

struct ZoomableStoredImageView: View {
    let imagePath: String

    var body: some View {
        #if canImport(UIKit)
        if let image = ImageFileStore.uiImage(for: imagePath) {
            ZoomableUIImageView(image: image)
        } else {
            Color.black
        }
        #else
        Color.black
        #endif
    }
}

#if canImport(UIKit)
struct ZoomableUIImageView: UIViewRepresentable {
    let image: UIImage

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        let imageView = UIImageView(image: image)

        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 5
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.backgroundColor = .black
        scrollView.addSubview(imageView)

        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        context.coordinator.imageView = imageView

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])

        let doubleTap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)

        return scrollView
    }

    func updateUIView(_ scrollView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView = gesture.view as? UIScrollView else { return }

            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                scrollView.setZoomScale(2.5, animated: true)
            }
        }
    }
}
#endif
