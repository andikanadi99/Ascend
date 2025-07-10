//
//  ColumnDraggableBlockView.swift
//  Ascento
//
//  Created by Andika Yudhatrisna on 7/9/25.
//


import SwiftUI

@available(iOS 16.0,*)
struct ColumnDraggableBlockView: View {
    let block: TimelineBlock
    let visibleStartHour: Int
    let rowHeight: CGFloat
    let columnWidth: CGFloat
    let accent: RGBAColor

    // Callbacks
    let onPreview: (TimelineBlock?) -> Void
    let onCommit: (TimelineBlock) -> Void
    let onEdit: (TimelineBlock) -> Void
    let onCreateDraft: (TimelineBlock) -> Void

    // Interaction state
    @State private var isEditing = false
    @State private var origStart: Date?
    @State private var origEnd:   Date?
    @GestureState private var dragDY: CGFloat = 0

    private var snap: Int      { 60 }
    private var px: CGFloat    { rowHeight / 60 }
    private var accentUI: Color { accent.swiftUIColor }

    var body: some View {
        let height = max(CGFloat(block.durationMinutes) * px,
                         px * CGFloat(snap))
        let yPos   = yPos(block.start) + height/2

        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(accentUI)
            if let title = block.title {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(6)
            }
        }
        .frame(width: columnWidth, height: height)
        .position(x: columnWidth/2, y: yPos + dragDY)
        .gesture(dragGesture)
        .highPriorityGesture(
          TapGesture().onEnded { onEdit(block) }
        )
    }

    private var dragGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.3)
          .onEnded { _ in
            isEditing = true
            origStart = block.start
            origEnd   = block.end
          }
        .sequenced(before: DragGesture())
        .updating($dragDY) { value, state, _ in
            guard case .second(true, let drag?) = value else { return }
            state = drag.translation.height
        }
        .onEnded { value in
            guard case .second(true, let drag?) = value,
                  let s0 = origStart, let e0 = origEnd else { return }
            let deltaMinutes = Double(drag.translation.height)/px
            let rawStart     = s0.addingTimeInterval(deltaMinutes*60)
            let dur          = e0.timeIntervalSince(s0)
            let snappedStart = roundToQuarter(rawStart)
            let snappedEnd   = snappedStart.addingTimeInterval(dur)
            withTransaction(Transaction(animation: nil)) {
                onCommit(TimelineBlock(
                    id:    block.id,
                    start: snappedStart,
                    end:   snappedEnd,
                    title: block.title,
                    color: accentUI,
                    isAllDay: block.isAllDay
                ))
            }
            onPreview(nil)
            isEditing = false
        }
    }

    private func roundToQuarter(_ date: Date) -> Date {
        let step: TimeInterval = 15*60
        let t = date.timeIntervalSince1970
        let r = (t/step).rounded() * step
        return Date(timeIntervalSince1970: r)
    }

    private func yPos(_ d: Date) -> CGFloat {
        let cal = Calendar.current
        let mins = (cal.component(.hour, from: d)-visibleStartHour)*60
                 + cal.component(.minute, from: d)
        return CGFloat(mins)*px
    }
}
