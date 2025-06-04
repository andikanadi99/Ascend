//  WeekView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on [DATE].
//

import SwiftUI
import FirebaseFirestore

struct WeekView: View {
    let accentColor: Color

    @EnvironmentObject private var session:      SessionStore
    @EnvironmentObject private var weekViewState: WeekViewState
    @StateObject private var viewModel = WeekViewModel()

    // Single focus state for all DayCardView priority TextEditors
    @FocusState private var isDayCardPriorityFocused: Bool

    // Local UI state
    @State private var isRemoveMode       = false
    @State private var showWeekCopyAlert  = false
    @State private var editMode: EditMode = .inactive

    // ─────────────────────────────────────────────────
    // Track whether last week had any unfinished priorities
    @State private var hasPreviousUnfinished = false

    /// Reloads the “unfinished from last week” flag whenever the week changes or on appear.
    private func updateHasPreviousUnfinished() {
        guard let uid = session.userModel?.id else {
            hasPreviousUnfinished = false
            return
        }
        // Only check if the displayed week is “this” calendar week
        let thisWeekStart = WeekViewState.startOfCurrentWeek(Date())
        let displayedWeekStart = weekViewState.currentWeekStart

        let isThisWeek = Calendar.current.isDate(
            thisWeekStart,
            equalTo: displayedWeekStart,
            toGranularity: .weekOfYear
        )

        if isThisWeek {
            // Compute last week’s start date
            let lastWeekStart = Calendar.current.date(
                byAdding: .weekOfYear,
                value: -1,
                to: displayedWeekStart
            )!
            viewModel.fetchUnfinishedWeeklyPriorities(
                for: lastWeekStart,
                userId: uid
            ) { unfinished in
                hasPreviousUnfinished = !unfinished.isEmpty
            }
        } else {
            hasPreviousUnfinished = false
        }
    }
    // ─────────────────────────────────────────────────

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                WeekNavigationView(
                    currentWeekStart: $weekViewState.currentWeekStart,
                    accountCreationDate: session.userModel?.createdAt ?? Date(),
                    accentColor: accentColor
                )
                .onChange(of: weekViewState.currentWeekStart) { newStart in
                    if let uid = session.userModel?.id {
                        viewModel.loadWeeklySchedule(for: newStart, userId: uid)
                    }
                    updateHasPreviousUnfinished()
                }

                // Weekly priorities at top
                if viewModel.schedule != nil {
                    let thisWeekStart     = WeekViewState.startOfCurrentWeek(Date())
                    let displayedWeekStart = weekViewState.currentWeekStart

                    // True if displayedWeekStart is the same calendar‐week as today
                    let isThisWeek = Calendar.current.isDate(
                        thisWeekStart,
                        equalTo: displayedWeekStart,
                        toGranularity: .weekOfYear
                    )

                    // True if the displayed week is strictly before this week
                    let isPastWeek = displayedWeekStart < thisWeekStart

                    WeeklyPrioritiesSection(
                        priorities:            viewModel.weeklyPrioritiesBinding,
                        editMode:              $editMode,
                        accentColor:           accentColor,
                        isRemoveMode:          isRemoveMode,
                        onToggleRemoveMode:    { isRemoveMode.toggle() },
                        onMove:                viewModel.moveWeeklyPriorities(indices:to:),
                        onCommit:              viewModel.updateWeeklySchedule,
                        onDelete:              viewModel.deletePriority(_:),
                        addAction:             viewModel.addNewPriority,

                        // ─── Pass both flags now ───────────────────────
                        isThisWeek:            isThisWeek,
                        isPastWeek:            isPastWeek,
                        hasPreviousUnfinished: hasPreviousUnfinished,
                        importAction:          {
                                                  viewModel.importUnfinishedFromLastWeek(
                                                      to: displayedWeekStart,
                                                      userId: session.userModel?.id ?? ""
                                                  )
                                              }
                        // ───────────────────────────────────────────
                    )

                } else {
                    Text("Loading priorities…")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 90)
                }

                // Day cards for each of the seven days
                VStack(spacing: 16) {
                    // Build array of Date objects for this week
                    let days: [Date] = (0..<7).compactMap { offset in
                        Calendar.current.date(
                            byAdding: .day,
                            value: offset,
                            to: weekViewState.currentWeekStart
                        )
                    }

                    ForEach(days, id: \.self) { day in
                        DayCardView(
                            accentColor:    accentColor,
                            day:            day,
                            priorities:     viewModel.prioritiesBinding(for: day),
                            priorityFocus:  $isDayCardPriorityFocused
                        )
                        .frame(maxWidth: .infinity)
                    }
                }

                Spacer()
            }
            .padding()
            .padding(.top, -20)
        }
        .onAppear {
            loadSchedule()
            // Defer so that `weekViewState.currentWeekStart` is set
            DispatchQueue.main.async {
                updateHasPreviousUnfinished()
            }
        }
    }


    // Load or refresh this week’s schedule
    private func loadSchedule() {
        let now  = Date()
        let last = UserDefaults.standard.object(forKey: "LastActiveTime") as? Date ?? now
        if now.timeIntervalSince(last) > 1800 {
            weekViewState.currentWeekStart = WeekViewState.startOfCurrentWeek(now)
        }
        UserDefaults.standard.set(now, forKey: "LastActiveTime")
        if let uid = session.userModel?.id {
            viewModel.loadWeeklySchedule(for: weekViewState.currentWeekStart, userId: uid)
        }
    }
}
