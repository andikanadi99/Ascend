//  WeeklyTimelineGrid.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 7/8/25.
//  Revised 10 Jul 2025 – weekday header is now fixed, columns scroll beneath it.

import SwiftUI

@available(iOS 16.0, *)
struct WeeklyTimelineGrid: View {
    // ─── Inputs ────────────────────────────────────────────────────
    let weekStart: Date
    let visibleStartHour: Int
    let visibleEndHour:   Int
    let blocksPerDay:     [Date:[TimelineBlock]]
    let accentColor:      RGBAColor

    // Call-backs
    let onBlocksChange: (Date,[TimelineBlock])->Void
    let onEdit:         (Date,TimelineBlock)->Void
    let onCreateDraft:  (Date,TimelineBlock)->Void

    // ─── Layout constants ─────────────────────────────────────────
    private let hourLabelWidth:    CGFloat = 50
    private let hourLabelTrailing: CGFloat = 8
    private let rowHeight:         CGFloat = 64
    private let columnWidth:       CGFloat = 180

    private var totalHours : Int     { visibleEndHour - visibleStartHour }
    private var gridHeight : CGFloat { CGFloat(totalHours)*rowHeight }

    // Pre-computed week days
    private var days: [Date] {
        (0..<7).compactMap {
            Calendar.current.date(byAdding: .day, value: $0, to: weekStart)
        }
    }
    private func wday(_ d:Date)->String {
        let df = DateFormatter(); df.locale = .current
        return df.shortWeekdaySymbols[Calendar.current.component(.weekday, from: d)-1]
    }
    // MARK: – Helpers
    private func hourLabel(_ h: Int) -> String {
        let df = DateFormatter()
        df.dateFormat = "h a"
        let d = Calendar.current.date(
            bySettingHour: h % 24,
            minute: 0,
            second: 0,
            of: weekStart
        )!
        return df.string(from: d)
    }

    private func shortWeekday(_ d: Date) -> String {
        let df = DateFormatter()
        df.locale = .current
        df.dateFormat = "E"   // e.g. “Mon”
        return df.string(from: d)
    }

    private func dayNumber(_ d: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "d"   // e.g. “8”
        return df.string(from: d)
    }


    // ─── View body ────────────────────────────────────────────────
    var body: some View {
        GeometryReader { geo in
            // ───────── derived sizes ─────────
            let available  = geo.size.width - hourLabelWidth - hourLabelTrailing
            let col        = max(120,  available / 7)                 // adaptive column width
            let gridHeight = CGFloat(totalHours) * rowHeight
            let calendar   = Calendar.current
            let days       = (0..<7).map { calendar.date(byAdding: .day,
                                                         value: $0,
                                                         to: weekStart)! }

            VStack(spacing: 0) {

                // ─── weekday header row ────────────────────────────────
                HStack(spacing: 0) {
                    Color.clear
                        .frame(width: hourLabelWidth + hourLabelTrailing)   // spacer over hour labels

                    ForEach(days, id: \.self) { day in
                        VStack(spacing: 2) {
                            Text(shortWeekday(day))   // “M”, “T”, …
                                .font(.caption).bold()
                            Text(dayNumber(day))      // “8”, “9”, …
                                .font(.footnote)
                        }
                        .frame(width: col)
                    }
                }
                .padding(.vertical, 4)

                // ─── scrolling timeline grid ───────────────────────────
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {

                        // 1) single hour-label column
                        VStack(spacing: 0) {
                            ForEach(visibleStartHour..<visibleEndHour, id: \.self) { h in
                                HStack(spacing: 0) {
                                    Text(hourLabel(h))
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.gray)
                                        .frame(width: hourLabelWidth, alignment: .trailing)
                                        .padding(.trailing, hourLabelTrailing)

                                    Color.clear.frame(height: rowHeight)
                                }
                                .frame(height: rowHeight)
                            }
                        }
                        .frame(height: gridHeight)

                        // 2) the seven day columns
                        ForEach(days, id: \.self) { day in
                            let key = calendar.startOfDay(for: day)

                            WeeklyDayColumnView(
                                date:             day,
                                blocks:           Binding(
                                    get: { blocksPerDay[key] ?? [] },
                                    set: { onBlocksChange(key, $0) }
                                ),
                                visibleStartHour: visibleStartHour,
                                visibleEndHour:   visibleEndHour,
                                rowHeight:        rowHeight,
                                columnWidth:      col,
                                accentColor:      accentColor,
                                onBlocksChange:   { onBlocksChange(key, $0) },
                                onEdit:           { onEdit(key, $0) },
                                onCreateDraft:    { onCreateDraft(key, $0) }
                            )
                            .frame(width: col, height: gridHeight)
                        }
                    }
                }
                .frame(height: gridHeight)
            }
        }
    }

}
