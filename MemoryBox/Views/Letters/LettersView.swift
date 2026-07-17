//
//  LettersView.swift
//  MemoryBox
//

import SwiftUI

struct LettersView: View {
    @Binding var letters: [LoveLetter]
    let onAddLetter: () -> Void
    let onChange: () -> Void
    let onUpdate: (LoveLetter) -> Void
    @State private var editingLetter: LoveLetter?

    private var sortedLetters: [LoveLetter] {
        letters.sorted { $0.date > $1.date }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AnimatedLoveBackdrop()
                    .ignoresSafeArea()

                if sortedLetters.isEmpty {
                    EmptyActionView(
                        icon: "envelope.badge",
                        title: "Chưa có thư",
                        message: "Viết và lưu lại lời muốn nói.",
                        actionTitle: "Viết",
                        action: onAddLetter
                    )
                } else {
                    ScrollView {
                        LazyVStack(spacing: 14) {
                            ForEach(sortedLetters) { letter in
                                LoveLetterCard(
                                    letter: letter,
                                    onEdit: { editingLetter = letter },
                                    onDelete: { deleteLetter(letter) }
                                )
                            }
                        }
                        .padding(20)
                    }
                }
            }
            .navigationTitle("Thư yêu thương")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onAddLetter) {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
            .sheet(item: $editingLetter) { letter in
                LetterEditorView(mode: .edit(letter)) { updatedLetter in
                    onUpdate(updatedLetter)
                }
            }
        }
    }

    private func deleteLetter(at offsets: IndexSet) {
        let idsToRemove = offsets.map { sortedLetters[$0].id }
        letters.removeAll { idsToRemove.contains($0.id) }
        onChange()
    }

    private func deleteLetter(_ letter: LoveLetter) {
        letters.removeAll { $0.id == letter.id }
        onChange()
    }
}

struct LoveLetterCard: View {
    let letter: LoveLetter
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "envelope.open.fill")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 42, height: 42)
                    .background(
                        LinearGradient(
                            colors: [.pink, .purple.opacity(0.72)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: Circle()
                    )

                VStack(alignment: .leading, spacing: 5) {
                    Text(letter.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(2)

                    Text(letter.date.pastRelativeText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.pink)
                }

                Spacer(minLength: 8)

                HStack(spacing: 4) {
                    Button(action: onEdit) {
                        Image(systemName: "pencil")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Sửa thư")

                    Button(role: .destructive, action: onDelete) {
                        Image(systemName: "trash")
                            .frame(width: 30, height: 30)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Xoá thư")
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            }

            Text(letter.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineSpacing(4)
                .lineLimit(4)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(.white.opacity(0.58), lineWidth: 1)
                )
        }
    }
}


