// TimelineView.swift
// Mind Reset – full file (Google-Calendar–style create/edit/move)
// --------------------------------------------------
// • Tap empty grid → 1‑hour blue outline + peek‑sheet
// • Drag outline/handle → move/resize before saving
// • Save → outline becomes solid block (title only)
// • Tap solid block → full‑screen editor
// • Long‑press solid block → re‑edit (move/resize)
// • Overlaps layout side‑by‑side
// --------------------------------------------------

import SwiftUI

@available(iOS 16.0, *)
struct TimelineView: View {
    // MARK: – Public API
    let dayDate: Date
    let visibleStartHour: Int
    let visibleEndHour: Int
    @Binding var blocks: [TimelineBlock]
    let showHourLabels: Bool
    let accentColor: RGBAColor
    var onBlocksChange: (([TimelineBlock]) -> Void)? = nil
    var onEdit: (TimelineBlock) -> Void
    var onCreateDraft: (TimelineBlock) -> Void    // new-task callback

    // MARK: – Interaction State
    @State private var previewBlock: TimelineBlock? = nil
    @State private var draftBlock: TimelineBlock? = nil

    @State private var previewLastSnap: Int = 0
    @State private var previewFeedback = UISelectionFeedbackGenerator()
    // MARK: – Layout Constants
    private let hourLabelWidth: CGFloat = 50
    private let hourLabelTrailing: CGFloat = 8
    private let rowHeight: CGFloat = 64
    private let snapInterval: Int = 60       // 1-hour

    // MARK: – Derived Values
    private var totalHours: Int { visibleEndHour - visibleStartHour }
    private var totalMinutes: Int { totalHours * 60 }
    private var px: CGFloat { rowHeight / 60 }
    private var gutter: CGFloat { hourLabelWidth + hourLabelTrailing }
    private var accentUI: Color { accentColor.swiftUIColor }
    
    init(
           dayDate: Date,
           visibleStartHour: Int,
           visibleEndHour: Int,
           blocks: Binding<[TimelineBlock]>,
           accentColor: RGBAColor,
           showHourLabels: Bool = true,
           onBlocksChange: (([TimelineBlock]) -> Void)? = nil,
           onEdit: @escaping (TimelineBlock) -> Void,
           onCreateDraft: @escaping (TimelineBlock) -> Void
       ) {
           self.dayDate          = dayDate
           self.visibleStartHour = visibleStartHour
           self.visibleEndHour   = visibleEndHour
           self._blocks          = blocks
           self.accentColor      = accentColor
           self.showHourLabels   = showHourLabels
           self.onBlocksChange   = onBlocksChange
           self.onEdit           = onEdit
           self.onCreateDraft    = onCreateDraft
       }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // ─── only the *background* gets the drag‐to‐create gesture ───
                // TimelineView.swift – grid now uses a long-press + drag sequence
                Color(.sRGB, white: 0.14)
                    .gesture(
                        LongPressGesture(minimumDuration: 0.2)
                            .sequenced(before: DragGesture(minimumDistance: 0))
                            .onChanged { value in
                                // Only track the *drag* phase, not the initial press
                                guard case .second(true, let drag?) = value else { return }
                                let y = min(max(drag.location.y, 0),
                                            CGFloat(totalMinutes) * px)
                                let startMin = (Int(y/px) / snapInterval) * snapInterval
                                let endMin   = min(startMin + snapInterval, totalMinutes)
                                previewBlock = makeBlock(start: startMin, end: endMin)
                            }
                            .onEnded { value in
                                // Only finalize once the drag ends after the long-press
                                guard case .second(true, let drag?) = value else { return }
                                let y = min(max(drag.location.y, 0),
                                            CGFloat(totalMinutes) * px)
                                let startMin = (Int(y/px) / snapInterval) * snapInterval
                                let endMin   = min(startMin + snapInterval, totalMinutes)
                                let newDraft = makeBlock(start: startMin, end: endMin)

                                // Keep the outline visible and open the sheet
                                previewBlock = newDraft
                                onCreateDraft(newDraft)
                            }
                    )

                gridView
                blocksView(fullWidth: geo.size.width)
//                outlineView(fullWidth: geo.size.width)
            }
            .frame(
                width: geo.size.width,
                height: CGFloat(totalHours) * rowHeight
            )
            .contentShape(Rectangle())
            // ← notice: no .gesture here any more
        }
    }
    // MARK: – Grid Lines
    private var gridView: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                ForEach(visibleStartHour..<visibleEndHour, id: \.self) { h in
                    HStack(spacing: 0) {
                        Text(hourLabel(h))
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.gray)
                            .frame(width: hourLabelWidth, alignment: .trailing)
                            .padding(.trailing, hourLabelTrailing)
                        Rectangle()
                            .fill(Color.clear)
                            .frame(height: rowHeight)
                            .overlay(
                                Rectangle()
                                    .fill(Color(.systemGray3))
                                    .frame(height: 0.5),
                                alignment: .bottom
                            )
                    }
                    .id(h)
                }
            }
            Rectangle()
                .fill(Color(.systemGray3))
                .frame(width: 0.5, height: CGFloat(totalHours) * rowHeight)
                .offset(x: gutter)
        }
    }

    // ─────────────────────────────────────────
    // MARK: – Blocks with overlap layout
    // ─────────────────────────────────────────
    private func blocksView(fullWidth: CGFloat) -> some View {
        let groups = TimelineOverlapLayout.compute(blocks)
        return ForEach(groups) { group in
            GroupColumn(
                blocks:           group.blocks,
                fullWidth:        fullWidth,
                gutter:           gutter,
                px:               px,
                snapInterval:     snapInterval,
                visibleStartHour: visibleStartHour,
                accentColor:      accentColor,
                
                // update the live-preview outline in this view’s state
                onPreview: { previewBlock = $0 },
                
                onCommit: {
                    replaceBlock($0)
                    onBlocksChange?(blocks)
                },
                
                onEdit: onEdit,
                
                // bubble drafts (both new and taps) up to the host
                onCreateDraft: onCreateDraft
            )
        }
    }

    // ─────────────────────────────────────────
    // MARK: – Column of overlapping blocks
    // ─────────────────────────────────────────
    private struct GroupColumn: View {
        let blocks: [TimelineBlock]
        let fullWidth: CGFloat
        let gutter: CGFloat
        let px: CGFloat
        let snapInterval: Int
        let visibleStartHour: Int
        let accentColor: RGBAColor

        // injected closures
        let onPreview: (TimelineBlock?) -> Void
        let onCommit: (TimelineBlock) -> Void
        let onEdit: (TimelineBlock) -> Void
        let onCreateDraft: (TimelineBlock) -> Void

        var body: some View {
            let cols = max(1, blocks.count)
            let colW = (fullWidth - gutter) / CGFloat(cols)

            ForEach(Array(blocks.enumerated()), id: \.offset) { idx, blk in
                DraggableBlockView(
                    block:            blk,
                    visibleStartHour: visibleStartHour,
                    px:               px,
                    gutter:           gutter,
                    snapInterval:     snapInterval,
                    accent:           accentColor,
                    
                    // live-preview on drag
                    onPreview:        onPreview,
                    
                    // commit moves/resizes
                    onCommit:         onCommit,
                    
                    // single-tap: clear outline + re-open modal for editing
                    onSelect: { tappedId in
                            onPreview(nil)
                            if let id = tappedId,
                               let tapped = blocks.first(where: { $0.id == id }) {
                                onEdit(tapped)         // ← full editor now on single‐tap
                            }
                        },
                        onEdit: onEdit            // unchanged (still supports double‐tap)
                )
                .frame(width: colW)
                .offset(x: gutter + colW * CGFloat(idx))
            }
        }
    }


    // MARK: – Live-preview outline


    // ① Add this helper inside TimelineView
    private func snappedMinutes(_ raw: Double) -> Int {
        (Int(raw.rounded()) / snapInterval) * snapInterval
    }
    
    /// Round to the nearest 5 minutes instead of a whole hour
    private func snappedMinutesFine(_ raw: Double) -> Int {
        let step = 5   // minutes
        return (Int(raw.rounded()) / step) * step
    }
    
    private func outlineView(fullWidth: CGFloat) -> some View {
        guard let outline = previewBlock else { return AnyView(EmptyView()) }
        let y0 = yPos(outline.start)
        let y1 = yPos(outline.end)
        let h  = max(y1 - y0, px * CGFloat(snapInterval))
        let w  = fullWidth - gutter
        let centerX = gutter + w / 2

        return AnyView(
            ZStack {
                // 1) Linear animation on shape only
                RoundedRectangle(cornerRadius: 4)
                  .stroke(accentUI, lineWidth: 1)
                  .frame(width: w, height: h)
                  .position(x: centerX, y: y0 + h / 2)
                  .animation(nil, value: previewBlock)

                // 2) Top handle – move start
                ZStack {
                    Circle().fill(accentUI.opacity(0.2)).frame(width: 40, height: 40)
                    Image(systemName: "chevron.compact.up")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(accentUI)
                }
                .position(x: centerX, y: y0)
                .gesture(
                    DragGesture()
                        .onChanged { d in
                            let mins = snappedMinutesFine(Double(d.translation.height) / px)
                            previewBlock = outline.movedBy(mins)
                        }
                )

                // 3) Bottom handle – resize end
                ZStack {
                    Circle().fill(accentUI.opacity(0.2)).frame(width: 40, height: 40)
                    Image(systemName: "chevron.compact.down")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(accentUI)
                }
                .position(x: centerX, y: y0 + h)
                .gesture(
                    DragGesture()
                        .onChanged { d in
                            let mins = snappedMinutesFine(Double(d.translation.height) / px)
                            if let r = outline.resizedBy(mins, minInterval: 5) {
                                previewBlock = r
                            }
                        }
                )
            }
        )
    }



    // MARK: – Helpers
    private func hourLabel(_ h: Int) -> String {
        let df = DateFormatter()
        df.dateFormat = "h a"
        let d = Calendar.current.date(
            bySettingHour: h % 24, minute: 0, second: 0, of: dayDate
        )!
        return df.string(from: d)
    }

    private func yPos(_ d: Date) -> CGFloat {
        let cal = Calendar.current
        let mins = (cal.component(.hour, from: d) - visibleStartHour) * 60
                 + cal.component(.minute, from: d)
        return CGFloat(mins) * px
    }

    private func makeBlock(start s: Int, end e: Int) -> TimelineBlock {
        let base = Calendar.current.startOfDay(for: dayDate)
        let st = Calendar.current.date(
            byAdding: .minute, value: s + visibleStartHour * 60, to: base
        )!
        let en = Calendar.current.date(
            byAdding: .minute, value: e + visibleStartHour * 60, to: base
        )!
        return TimelineBlock(start: st, end: en, title: nil, color: accentUI)
    }

    private func replaceBlock(_ blk: TimelineBlock) {
        if let i = blocks.firstIndex(where: { $0.id == blk.id }) {
            blocks[i] = blk
        } else {
            blocks.append(blk)
        }
    }
}

// MARK: – DraggableBlockView
@available(iOS 16.0, *)
private struct DraggableBlockView: View {
    let block: TimelineBlock
    let visibleStartHour: Int
    let px: CGFloat
    let gutter: CGFloat
    let snapInterval: Int
    let accent: RGBAColor
    let onPreview: (TimelineBlock?) -> Void
    let onCommit: (TimelineBlock) -> Void
    let onSelect: (UUID?) -> Void
    let onEdit: (TimelineBlock) -> Void

    @State private var isEditing = false
    @State private var isResizing = false
    @State private var origStart: Date?
    @State private var origEnd:   Date?
    @GestureState private var dragDY: CGFloat = 0

    private var accentUI: Color { accent.swiftUIColor }

    var body: some View {
        // ───── Geometry constants ─────
        let height = max(CGFloat(block.durationMinutes) * px,
                         px * CGFloat(snapInterval))
        let width  = UIScreen.main.bounds.width - gutter
        let yPos   = yPos(block.start) + height / 2

        // ───── Main block UI ─────
        ZStack(alignment: .bottom) {
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(block.color.swiftUIColor)
                if let title = block.title {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(8)
                }
            }
            .frame(width: width, height: height)
            .scaleEffect(isEditing ? 1.05 : 1)
            .animation(.spring(), value: isEditing)
            // ← Removed the bottom resize handle entirely
        }
        // visual offset during drag only
        .position(x: width / 2, y: yPos + dragDY)
        .animation(nil, value: dragDY)

        // ───── Gestures ─────
        .gesture(
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
                          let start0 = origStart,
                          let end0   = origEnd else { return }

                    // Compute tentative new start
                    let deltaMinutes = Double(drag.translation.height) / px
                    let rawStart  = start0.addingTimeInterval(deltaMinutes * 60)
                    let duration  = end0.timeIntervalSince(start0)

                    // Snap to nearest 15-minute mark
                    let snappedStart = roundDateToQuarterHour(rawStart)
                    let snappedEnd   = snappedStart.addingTimeInterval(duration)

                    // Commit and exit edit in a non-animated transaction
                    withTransaction(Transaction(animation: nil)) {
                        onCommit(
                            TimelineBlock(
                                id:    block.id,
                                start: snappedStart,
                                end:   snappedEnd,
                                title: block.title,
                                color: block.color.swiftUIColor
                            )
                        )
                        finishEdit()
                    }
                }
        )
        // single tap → editor
        .highPriorityGesture(
            TapGesture().onEnded { onEdit(block) }
        )
    }

    private func roundDateToQuarterHour(_ date: Date) -> Date {
        let quarter: TimeInterval = 15 * 60
        let t = date.timeIntervalSince1970
        let rounded = (t / quarter).rounded() * quarter
        return Date(timeIntervalSince1970: rounded)
    }

    // MARK: – Helpers
    private func finishEdit() {
        isEditing = false
        isResizing = false
        onPreview(nil)
        onSelect(nil)
    }

    private func yPos(_ d: Date) -> CGFloat {
        let cal = Calendar.current
        let mins = (cal.component(.hour, from: d) - visibleStartHour) * 60
                 + cal.component(.minute, from: d)
        return CGFloat(mins) * px
    }

    private func snappedMinutes(_ raw: Double) -> Int {
        (Int(raw.rounded()) / snapInterval) * snapInterval
    }
}


// MARK: – Overlap Layout
struct TimelineOverlapLayout {
    struct Group: Identifiable { let id = UUID(); var blocks: [TimelineBlock] }
    static func compute(_ items: [TimelineBlock]) -> [Group] {
        var groups: [Group] = []
        for b in items {
            if let i = groups.firstIndex(where: { g in
                g.blocks.contains { $0.start < b.end && b.start < $0.end }
            }) {
                groups[i].blocks.append(b)
            } else {
                groups.append(Group(blocks: [b]))
            }
        }
        return groups
    }
}


// MARK: – DraftSheet (unused if using CreateTaskModal)
fileprivate struct DraftSheet: View {
    @Binding var block: TimelineBlock?
    @State private var title = ""
    var onClose: (TimelineBlock?) -> Void

    var body: some View {
        VStack(spacing: 12) {
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
            HStack {
                Button("Cancel") { onClose(nil) }
                Spacer()
                Button("Save") {
                    if var b = block {
                        b.title = title.isEmpty ? "Untitled task" : title
                        onClose(b)
                    } else { onClose(nil) }
                }
            }
            .tint(.blue)
        }
        .padding()
        .onAppear { title = block?.title ?? "" }
    }
}

// MARK: – TimelineBlock Helpers
extension TimelineBlock {
    var durationMinutes: Int {
        max(1, Int(end.timeIntervalSince(start) / 60))
    }
    func movedBy(_ minutes: Int) -> TimelineBlock {
        let cal = Calendar.current
        return TimelineBlock(
            id: id,
            start: cal.date(byAdding: .minute, value: minutes, to: start)!,
            end:   cal.date(byAdding: .minute, value: minutes, to: end)!,
            title: title,
            color: color.swiftUIColor,
            isAllDay: isAllDay
        )
    }
    func resizedBy(_ minutes: Int, minInterval: Int) -> TimelineBlock? {
        let cal = Calendar.current
        let newEnd = cal.date(byAdding: .minute, value: minutes, to: end)!
        guard Int(newEnd.timeIntervalSince(start) / 60) >= minInterval else { return nil }
        return TimelineBlock(
            id: id,
            start: start,
            end:   newEnd,
            title: title,
            color: color.swiftUIColor,
            isAllDay: isAllDay
        )
    }
}



