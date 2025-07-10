//
//  WeeklyDayColumnView.swift
//  Ascento
//
//  Created by Andika Yudhatrisna on 7/9/25.
//


import SwiftUI

@available(iOS 16.0,*)
struct WeeklyDayColumnView: View {
    let date: Date
    @Binding var blocks: [TimelineBlock]
    let visibleStartHour: Int
    let visibleEndHour:   Int
    let rowHeight:        CGFloat
    let columnWidth:      CGFloat
    let accentColor:      RGBAColor

    let onBlocksChange: ( [TimelineBlock] ) -> Void
    let onEdit:         ( TimelineBlock ) -> Void
    let onCreateDraft:  ( TimelineBlock ) -> Void

    private var totalHours: Int { visibleEndHour - visibleStartHour }
    private var totalHeight: CGFloat { CGFloat(totalHours)*rowHeight }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Background + drag‐to‐create
                Color(.sRGB, white: 0.14)
                  .gesture(draftGesture(in: geo.size.height))

                // Grid lines
                HorizontalGridLinesView(
                    rowCount: totalHours,
                    rowHeight: rowHeight
                )

                // Blocks
                ForEach(WeekOverlapLayout.compute(blocks)) { group in
                    let cols = max(1, group.blocks.count)
                    let w    = columnWidth/CGFloat(cols)
                    ForEach(Array(group.blocks.enumerated()), id: \.offset) { idx, blk in
                        ColumnDraggableBlockView(
                            block:            blk,
                            visibleStartHour: visibleStartHour,
                            rowHeight:        rowHeight,
                            columnWidth:      w,
                            accent:           accentColor,
                            onPreview:        { _ in },
                            onCommit:         { b in replace(b) },
                            onEdit:           onEdit,
                            onCreateDraft:    onCreateDraft
                        )
                        .offset(x: w*CGFloat(idx))
                    }
                }
            }
            .frame(width: columnWidth, height: totalHeight)
        }
    }

    private func draftGesture(in totalPx: CGFloat) -> some Gesture {
        LongPressGesture(minimumDuration: 0.2)
        .sequenced(before: DragGesture(minimumDistance: 0))
        .onChanged { value in
            guard case .second(true, let drag?) = value else { return }
            let y = min(max(drag.location.y,0), totalPx)
            let startMin = (Int(y/rowHeight)*60)
            let endMin   = min(startMin+60, (visibleEndHour-visibleStartHour)*60)
            let newBlk = makeBlock(start: startMin,end:endMin)
            onCreateDraft(newBlk)
        }
    }

    private func replace(_ blk: TimelineBlock) {
        if let i = blocks.firstIndex(where:{ $0.id==blk.id }) {
            blocks[i]=blk
        } else {
            blocks.append(blk)
        }
        onBlocksChange(blocks)
    }

    private func makeBlock(start s:Int,end e:Int) -> TimelineBlock {
        let base = Calendar.current.startOfDay(for: date)
        let st = Calendar.current.date(
            byAdding:.minute, value: s + visibleStartHour*60, to: base)!
        let en = Calendar.current.date(
            byAdding:.minute, value: e + visibleStartHour*60, to: base)!
        return TimelineBlock(start: st,end: en,title:nil,color:accentColor.swiftUIColor)
    }
}
