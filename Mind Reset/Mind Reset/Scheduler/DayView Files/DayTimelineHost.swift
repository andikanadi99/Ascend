//
//  DayTimelineHost.swift
//  Ascento
//
//  Created by Andika Yudhatrisna on 6/26/25.
//
import SwiftUI

/// A day-specific interactive timeline, showing only the hours from `visibleStartHour` (inclusive)
/// up to `visibleEndHour` (exclusive). Users can long-press and drag to create a time block.
@available(iOS 16.0, *)
struct DayTimelineHost: View {
    /// Inclusive start hour (0–23)
    let visibleStartHour: Int
    /// Exclusive end hour (1–24)
    let visibleEndHour: Int
    /// The date this timeline represents (used by the parent view for context)
    let dayDate: Date
    /// Blocks to render
    let blocks: [TimelineBlock]
    /// Accent color for new-block previews
    let accentColor: Color
    /// Called when the user finishes creating a new block
    let onCreate: (TimelineBlock) -> Void

    /// Fixed height per hour row — must match TimelineView’s rowHeight
    private let rowHeight: CGFloat = 64

    /// Number of full hour-rows to display
    private var rowCount: Int {
        visibleEndHour - visibleStartHour
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            TimelineView(
                visibleStartHour: visibleStartHour,
                visibleEndHour:   visibleEndHour,
                blocks:           blocks,
                accentColor:      accentColor,
                onCreate:         onCreate
            )
            // Make host frame match the grid’s fixed rows
            .frame(height: CGFloat(rowCount) * rowHeight)
            // Match TimelineView’s background color to avoid stripes
            .background(Color(.sRGB, white: 0.14, opacity: 1))
        }
    }
}

#if DEBUG
struct DayTimelineHost_Previews: PreviewProvider {
    static var previews: some View {
        DayTimelineHost(
            visibleStartHour: 7,
            visibleEndHour:   22,
            dayDate:          Date(),
            blocks: [
                .init(id: UUID(),
                      start: Date().addingTimeInterval(14*3600),
                      end:   Date().addingTimeInterval(15*3600),
                      title: "Meeting",
                      color: .blue,
                      description: "Team sync"),
                .init(id: UUID(),
                      start: Date().addingTimeInterval(18*3600),
                      end:   Date().addingTimeInterval(20*3600),
                      title: "Workout",
                      color: .green,
                      description: "Gym")
            ],
            accentColor: .cyan,
            onCreate: { _ in }
        )
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}
#endif


