//
//  WeekView.swift
//  Mind Reset
//

import SwiftUI
import FirebaseFirestore

struct WeekView: View {
    let accentColor: Color

    @EnvironmentObject private var session:       SessionStore
    @EnvironmentObject private var weekViewState: WeekViewState
    @StateObject  private var viewModel = WeekViewModel()

    // Single focus state for all DayCard priority editors
    @FocusState private var isDayCardPriorityFocused: Bool

    // Local UI state
    @State private var isRemoveMode       = false
    @State private var showWeekCopyAlert  = false
    @State private var editMode: EditMode = .inactive

    // 🚩 dynamic height for the weekly priorities List
    @State private var weeklyPriorityListHeight: CGFloat = 1

    // Track unfinished items from the previous week
    @State private var hasPreviousUnfinished = false

    // ─────────────────────────────────────────
    // MARK: – Body
    // ─────────────────────────────────────────
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // ─── Week nav bar ───
                WeekNavigationView(
                    currentWeekStart: $weekViewState.currentWeekStart,
                    accountCreationDate: session.userModel?.createdAt ?? Date(),
                    accentColor: accentColor
                )
                .onChange(of: weekViewState.currentWeekStart) { _ in
                    if let uid = session.userModel?.id {
                        viewModel.loadWeeklySchedule(
                            for: weekViewState.currentWeekStart,
                            userId: uid
                        )
                    }
                    updateHasPreviousUnfinished()
                }

                // ─── Weekly priorities section ───
                if viewModel.schedule != nil {
                    let thisWeekStart      = WeekViewState.startOfCurrentWeek(Date())
                    let displayedWeekStart = weekViewState.currentWeekStart
                    let isThisWeek = Calendar.current.isDate(
                        thisWeekStart,
                        equalTo: displayedWeekStart,
                        toGranularity: .weekOfYear
                    )
                    let isPastWeek = displayedWeekStart < thisWeekStart

                    WeeklyPrioritiesSection(
                        priorities:             viewModel.weeklyPrioritiesBinding,
                        editMode:               $editMode,
                        listHeight:             $weeklyPriorityListHeight,
                        accentColor:            accentColor,
                        isRemoveMode:           isRemoveMode,
                        onToggleRemoveMode:     { isRemoveMode.toggle() },
                        onMove:                 viewModel.moveWeeklyPriorities(indices:to:),
                        onCommit:               viewModel.updateWeeklySchedule,
                        onDeleteConfirmed:      viewModel.deletePriority(_:),
                        addAction:              viewModel.addNewPriority,
                        isThisWeek:             isThisWeek,
                        isPastWeek:             isPastWeek,
                        hasPreviousUnfinished:  hasPreviousUnfinished,
                        importAction: {
                            viewModel.importUnfinishedFromLastWeek(
                                to: displayedWeekStart,
                                userId: session.userModel?.id ?? ""
                            )
                        }
                    )
                } else {
                    Text("Loading priorities…")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 90)
                }

                // ─── Seven day cards ───
                VStack(spacing: 16) {
                    let days: [Date] = (0..<7).compactMap { offset in
                        Calendar.current.date(
                            byAdding: .day,
                            value: offset,
                            to: weekViewState.currentWeekStart
                        )
                    }
                    ForEach(days, id: \.self) { day in
                        DayCardView(
                            accentColor:   accentColor,
                            day:           day,
                            priorities:    viewModel.prioritiesBinding(for: day),
                            priorityFocus: $isDayCardPriorityFocused
                        )
                        .environmentObject(viewModel)   // 👈 inject the WeekViewModel
                        .frame(maxWidth: .infinity)
                    }
                }

                Spacer()
            }
            .padding()
            .padding(.top, -20)
        }
        // Dismiss keyboard as soon as a scroll/drag begins
        .scrollDismissesKeyboard(.immediately)
        .onAppear {
            loadSchedule()
            DispatchQueue.main.async { updateHasPreviousUnfinished() }
        }
    }

    // ─────────────────────────────────────────
    // MARK: – Helpers
    // ─────────────────────────────────────────
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

    private func updateHasPreviousUnfinished() {
        guard let uid = session.userModel?.id else { hasPreviousUnfinished = false; return }

        let thisWeekStart      = WeekViewState.startOfCurrentWeek(Date())
        let displayedWeekStart = weekViewState.currentWeekStart
        let isThisWeek = Calendar.current.isDate(
            thisWeekStart,
            equalTo: displayedWeekStart,
            toGranularity: .weekOfYear
        )

        if isThisWeek {
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
}
