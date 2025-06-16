//
//  WeekView.swift
//  Mind Reset
//

import SwiftUI
import FirebaseFirestore

struct WeekView: View {
    let accentColor: Color

    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var weekViewState: WeekViewState
    @StateObject private var viewModel = WeekViewModel()
    @StateObject private var keyboard = KeyboardObserver()

    // Focus for row editors
    @FocusState private var isDayCardPriorityFocused: Bool
    // Focus for which day card to scroll into view
    @FocusState private var focusedDay: Date?

    // Local UI state
    @State private var isRemoveMode = false
    @State private var editMode = EditMode.inactive
    @State private var weeklyPriorityListHeight: CGFloat = 1
    @State private var hasPreviousUnfinished = false
    


    var body: some View {
        // Compute the seven days for the current week
        let days: [Date] = (0..<7).compactMap { offset in
            Calendar.current.date(
                byAdding: .day,
                value: offset,
                to: weekViewState.currentWeekStart
            )
        }

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {

                    // Week navigation
                    WeekNavigationView(
                        currentWeekStart: $weekViewState.currentWeekStart,
                        accountCreationDate: session.userModel?.createdAt ?? Date(),
                        accentColor: accentColor
                    )
                    .padding(.top, 35)
                    .onChange(of: weekViewState.currentWeekStart) { _ in
                        loadWeekSchedule()
                        updateHasPreviousUnfinished()
                    }

                    // Weekly priorities
                    if viewModel.schedule != nil {
                        let thisWeekStart = WeekViewState.startOfCurrentWeek(Date())
                        let displayedWeekStart = weekViewState.currentWeekStart
                        let isThisWeek = Calendar.current.isDate(
                            thisWeekStart,
                            equalTo: displayedWeekStart,
                            toGranularity: .weekOfYear
                        )
                        let isPastWeek = displayedWeekStart < thisWeekStart

                        WeeklyPrioritiesSection(
                            priorities: viewModel.weeklyPrioritiesBinding,
                            editMode: $editMode,
                            listHeight: $weeklyPriorityListHeight,
                            accentColor: accentColor,
                            isRemoveMode: isRemoveMode,
                            onToggleRemoveMode: { isRemoveMode.toggle() },
                            onMove: viewModel.moveWeeklyPriorities(indices:to:),
                            onCommit: viewModel.updateWeeklySchedule,
                            onDeleteConfirmed: viewModel.deletePriority(_:),
                            addAction: viewModel.addNewPriority,
                            isThisWeek: isThisWeek,
                            isPastWeek: isPastWeek,
                            hasPreviousUnfinished: hasPreviousUnfinished,
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

                    // Separator
                    Divider()
                        .background(Color.white.opacity(0.5))
                        .padding(.vertical, 8)

                    // Seven day cards
                    VStack(spacing: 16) {
                        ForEach(days, id: \.self) { day in
                            DayCardView(
                                accentColor: accentColor,
                                day: day,
                                priorities: viewModel.prioritiesBinding(for: day),
                                priorityFocus: $isDayCardPriorityFocused
                            )
                            .id(day)
                            .environmentObject(viewModel)
                            .focused($focusedDay, equals: day)
                        }
                    }

                    Spacer()
                }
                .padding(.top, -20)
                .padding(.bottom, keyboard.height)
                .animation(.easeOut(duration: 0.25), value: keyboard.height)
                // Scroll to active day card
                .onChange(of: focusedDay) { newDay in
                    guard let d = newDay else { return }
                    withAnimation {
                        proxy.scrollTo(d, anchor: .top)
                    }
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .onAppear {
                loadWeekSchedule()
                updateHasPreviousUnfinished()
            }
        }
    }

    // MARK: – Helpers
    private func loadWeekSchedule() {
        let now = Date()
        let last = UserDefaults.standard.object(forKey: "LastActiveTime") as? Date ?? now
        if now.timeIntervalSince(last) > 1800 {
            weekViewState.currentWeekStart = WeekViewState.startOfCurrentWeek(now)
        }
        UserDefaults.standard.set(now, forKey: "LastActiveTime")

        if let uid = session.userModel?.id {
            viewModel.loadWeeklySchedule(
                for: weekViewState.currentWeekStart,
                userId: uid
            )
        }
    }

    private func updateHasPreviousUnfinished() {
        guard let uid = session.userModel?.id else {
            hasPreviousUnfinished = false
            return
        }

        let thisWeekStart = WeekViewState.startOfCurrentWeek(Date())
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


