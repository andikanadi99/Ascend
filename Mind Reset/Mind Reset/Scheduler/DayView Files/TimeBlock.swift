// TimelineView.swift
// Mind Reset
//
// A vertical 1-day timeline grid showing only the specified hour window,
// where users can long-press and drag to create or preview a time block.

import SwiftUI

/// A single block on the timeline.
struct TimelineBlock: Identifiable, Hashable {
    let id: UUID
    var start: Date
    var end: Date
    var title: String?           // optional title
    var color: Color?            // optional custom color
    var isAllDay: Bool = false   // all‑day flag
    var description: String?     // optional description
}

/// A timeline view for one day, showing only hours from `visibleStartHour` to `visibleEndHour`.
@available(iOS 16.0, *)
struct TimelineView: View {
    // MARK: — Public API
    let visibleStartHour: Int   // inclusive start (0–23)
    let visibleEndHour: Int     // exclusive end (1–24)
    let blocks: [TimelineBlock]
    let accentColor: Color
    let onCreate: (TimelineBlock) -> Void

    // MARK: — Internal state
    @GestureState private var dragLocation: CGPoint? = nil
    @State private var newBlock: TimelineBlock? = nil

    // MARK: — Layout constants
    private let hourLabelWidth: CGFloat = 50
    private let hourLabelTrailing: CGFloat = 8
    private let rowHeight: CGFloat = 64
    private let snapInterval = 30  // minutes

    private var totalHours: Int { visibleEndHour - visibleStartHour }
    private var totalMinutes: Int { totalHours * 60 }
    private var gutterWidth: CGFloat { hourLabelWidth + hourLabelTrailing }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let pxPerMinute = rowHeight / 60

            ScrollView(.vertical, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    // — Background —
                    Color(.sRGB, white: 0.14, opacity: 1)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // — Hour grid —
                    backgroundGrid(rowHeight: rowHeight)

                    // — Vertical guide line —
                    Rectangle()
                        .fill(Color(.systemGray3))
                        .frame(width: 0.5, height: CGFloat(totalHours) * rowHeight)
                        .offset(x: gutterWidth)

                    // — Render existing blocks —
                    ForEach(blocks) { block in
                        blockView(
                            block,
                            fullWidth: width,
                            pxPerMinute: pxPerMinute,
                            fillColor: block.color ?? accentColor
                        )
                    }

                    // — Render new‑block preview —
                    if let nb = newBlock {
                        blockView(
                            nb,
                            fullWidth: width,
                            pxPerMinute: pxPerMinute,
                            fillColor: accentColor.opacity(0.4)
                        )
                    }
                }
                .frame(width: width, height: CGFloat(totalHours) * rowHeight)
            }
            .gesture(
                LongPressGesture(minimumDuration: 0.2)
                    .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
                    .updating($dragLocation) { value, state, _ in
                        if case .second(_, let drag?) = value {
                            state = drag.location
                        }
                    }
                    .onChanged { value in
                        guard case .second(true, let drag?) = value else { return }
                        let minuteAtY   = minute(at: drag.location.y, pxPerMinute: pxPerMinute)
                        let snappedStart = snap(minute: minuteAtY)
                        let snappedEnd   = min(snappedStart + snapInterval, totalMinutes)
                        let startDate = dateFrom(minutes: snappedStart + visibleStartHour * 60)
                        let endDate   = dateFrom(minutes: snappedEnd   + visibleStartHour * 60)

                        newBlock = TimelineBlock(
                            id:    UUID(),
                            start: startDate,
                            end:   endDate
                        )
                    }
                    .onEnded { _ in
                        if let nb = newBlock {
                            onCreate(nb)
                        }
                        newBlock = nil
                    }
            )
        }
    }

    // MARK: — Background grid builder

    @ViewBuilder
    private func backgroundGrid(rowHeight: CGFloat) -> some View {
        VStack(spacing: 0) {
            ForEach(visibleStartHour ..< visibleEndHour, id: \.self) { hour in
                HStack(spacing: 0) {
                    Text(hourLabel(hour))
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(Color(.systemGray))
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
            }
        }
    }

    // MARK: — Block rendering

    private func blockView(
        _ block: TimelineBlock,
        fullWidth width: CGFloat,
        pxPerMinute: CGFloat,
        fillColor: Color
    ) -> some View {
        let yStart     = positionY(for: block.start, pxPerMinute: pxPerMinute)
        let yEnd       = positionY(for: block.end,   pxPerMinute: pxPerMinute)
        let blockHeight = max(yEnd - yStart,
                              pxPerMinute * CGFloat(snapInterval))

        let blockWidth = width - gutterWidth
        let xPosition = gutterWidth + blockWidth / 2

        return RoundedRectangle(cornerRadius: 6)
            .fill(fillColor)
            .frame(width: blockWidth, height: blockHeight)
            .position(x: xPosition, y: yStart + blockHeight/2)
    }

    // MARK: — Coordinate conversion

    private func positionY(for date: Date, pxPerMinute: CGFloat) -> CGFloat {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let totalFromStart = (comps.hour ?? 0 - visibleStartHour) * 60 + (comps.minute ?? 0)
        return CGFloat(totalFromStart) * pxPerMinute
    }

    private func minute(at y: CGFloat, pxPerMinute: CGFloat) -> Int {
        let raw = Int(y / pxPerMinute)
        return min(max(raw, 0), totalMinutes)
    }

    private func dateFrom(minutes: Int) -> Date {
        let dayStart = Calendar.current.startOfDay(for: Date())
        return Calendar.current.date(
            byAdding: .minute,
            value: minutes,
            to: dayStart
        )!
    }

    private func snap(minute: Int) -> Int {
        (minute / snapInterval) * snapInterval
    }

    // MARK: — Hour formatter

    private func hourLabel(_ hour: Int) -> String {
        let h = hour % 24
        let df = DateFormatter()
        df.dateFormat = "h a"
        let date = Calendar.current.date(
            bySettingHour: h,
            minute: 0,
            second: 0,
            of: Date()
        )!
        return df.string(from: date)
    }
}


