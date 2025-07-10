//
//  WeeklyTimelineView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 7/7/25.
//  Last revised 08 Jul 2025
//

import SwiftUI

@available(iOS 16.0,*)
/// A horizontal week‐timeline composed of seven day columns side by side,
/// now with a day‐of‐week header.
struct WeeklyTimelineView: View {
    // MARK: – Inputs
    /// Start of week (must be a calendar’s startOfDay)
    let weekStart: Date
    /// Visible hours per day
    let visibleStartHour: Int
    let visibleEndHour:   Int
    /// Map from each day (startOfDay) to its blocks
    let blocksPerDay: [Date:[TimelineBlock]]
    /// Accent color for blocks
    let accentColor: RGBAColor

    // MARK: – Callbacks
    /// Called when any day’s blocks array changes
    let onBlocksChange: (Date, [TimelineBlock]) -> Void
    /// Called when the user taps an existing block in a day
    let onEdit:          (Date, TimelineBlock)  -> Void
    /// Called when the user creates a draft in a day
    let onCreateDraft:   (Date, TimelineBlock)  -> Void

    var body: some View {
        WeeklyTimelineGrid(
            weekStart:        weekStart,
            visibleStartHour: visibleStartHour,
            visibleEndHour:   visibleEndHour,
            blocksPerDay:     blocksPerDay,
            accentColor:      accentColor,
            onBlocksChange:   onBlocksChange,
            onEdit:           onEdit,
            onCreateDraft:    onCreateDraft
        )
        // If you ever need to fix the height explicitly:
        // .frame(height: CGFloat(visibleEndHour - visibleStartHour) * 64)
    }
}
