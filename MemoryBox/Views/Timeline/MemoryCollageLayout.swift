//
//  MemoryCollageLayout.swift
//  MemoryBox
//

import SwiftUI

struct MemoryCollagePlacement: Identifiable {
    let id: UUID
    let memory: LoveMemory
    let index: Int
    let frame: CGRect

    init(memory: LoveMemory, index: Int, frame: CGRect) {
        self.id = memory.id
        self.memory = memory
        self.index = index
        self.frame = frame
    }
}

struct MemoryCollageLayoutResult {
    let placements: [MemoryCollagePlacement]
    let totalHeight: CGFloat
}

enum MemoryCollagePlanner {
    static let spacing: CGFloat = 12
    private static let minTileHeight: CGFloat = 128
    private static let maxTileHeightRatio: CGFloat = 1.35

    static func layout(memories: [LoveMemory], containerWidth: CGFloat) -> MemoryCollageLayoutResult {
        guard containerWidth > 0, !memories.isEmpty else {
            return MemoryCollageLayoutResult(placements: [], totalHeight: 0)
        }

        let columnWidth = (containerWidth - spacing) / 2
        var placements: [MemoryCollagePlacement] = []
        var columnHeights: [CGFloat] = [0, 0]

        for (index, memory) in memories.enumerated() {
            let isWide = index % 5 == 0
            let width = isWide ? containerWidth : columnWidth
            let height = tileHeight(for: memory, width: width, index: index)

            let x: CGFloat
            let y: CGFloat

            if isWide {
                x = 0
                y = max(columnHeights[0], columnHeights[1])
            } else {
                let column = columnHeights[0] <= columnHeights[1] ? 0 : 1
                x = CGFloat(column) * (columnWidth + spacing)
                y = columnHeights[column]
            }

            placements.append(
                MemoryCollagePlacement(
                    memory: memory,
                    index: index,
                    frame: CGRect(x: x, y: y, width: width, height: height)
                )
            )

            let nextHeight = y + height + spacing
            if isWide {
                columnHeights = [nextHeight, nextHeight]
            } else {
                let column = columnHeights[0] <= columnHeights[1] ? 0 : 1
                columnHeights[column] = nextHeight
            }
        }

        let totalHeight = max(columnHeights[0], columnHeights[1])
        let adjustedTotalHeight = totalHeight > 0 ? totalHeight - spacing : 0
        return MemoryCollageLayoutResult(placements: placements, totalHeight: max(adjustedTotalHeight, 0))
    }

    private static func tileHeight(for memory: LoveMemory, width: CGFloat, index: Int) -> CGFloat {
        let patternScale = patternHeightScale(for: index)
        let patternHeight = minTileHeight * patternScale
        let imagePath = memory.imagePaths.first ?? memory.imagePath

        guard let imagePath,
              let aspectRatio = ImageFileStore.displayAspectRatio(for: imagePath),
              aspectRatio > 0 else {
            return patternHeight
        }

        let naturalHeight = width / aspectRatio
        let maxHeight = max(patternHeight, width * maxTileHeightRatio)
        return min(max(naturalHeight, minTileHeight), maxHeight)
    }

    private static func patternHeightScale(for index: Int) -> CGFloat {
        switch index % 5 {
        case 0:
            return 1.15
        case 1:
            return 1.28
        case 2:
            return 0.96
        case 3:
            return 1.12
        default:
            return 1.02
        }
    }
}

private struct MemoryMosaicLayout: Layout {
    let placements: [CGRect]

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 0
        let height = placements.map { $0.maxY }.max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for index in subviews.indices where index < placements.count {
            let frame = placements[index]
            subviews[index].place(
                at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
                anchor: .topLeading,
                proposal: ProposedViewSize(width: frame.width, height: frame.height)
            )
        }
    }
}

struct MemoryCollageGrid<Cell: View>: View {
    let memories: [LoveMemory]
    let containerWidth: CGFloat
    @ViewBuilder let cell: (LoveMemory, Int, CGSize) -> Cell

    private var layout: MemoryCollageLayoutResult {
        MemoryCollagePlanner.layout(memories: memories, containerWidth: containerWidth)
    }

    var body: some View {
        let frames = layout.placements.map(\.frame)

        MemoryMosaicLayout(placements: frames) {
            ForEach(layout.placements) { placement in
                cell(
                    placement.memory,
                    placement.index,
                    CGSize(width: placement.frame.width, height: placement.frame.height)
                )
            }
        }
        .frame(width: containerWidth, alignment: .topLeading)
    }
}
