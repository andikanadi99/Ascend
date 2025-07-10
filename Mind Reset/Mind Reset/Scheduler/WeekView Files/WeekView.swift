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
    
    private enum WeekMode: String, CaseIterable { case priorities = "Priorities", schedule = "Schedule" }
    @State private var weekMode: WeekMode = .priorities
    
    @State private var hasPreviousUnfinished = false
    
    // ── New: toggle between day-cards list and weekly-timeline ──
    private enum WeekContent: String, CaseIterable {
        case tasks    = "Day List"
        case schedule = "Timeline"
    }
    @State private var contentMode: WeekContent = .tasks


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
                        .environmentObject(weekViewState)          // ⬅️ provide the state object
                        .padding(.top, 35)
                        .onChange(of: weekViewState.currentWeekStart) { _ in
                            loadWeekSchedule()
                            updateHasPreviousUnfinished()
                        }


                    // Weekly priorities
                    if viewModel.schedule != nil {
                        let thisWeekStart = WeekViewState.startOfWeek(for: Date())
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
                    // ─────────── Picker to switch view ───────────
                        Picker("", selection: $contentMode) {
                            ForEach(WeekContent.allCases, id: \.self) { m in
                                Text(m.rawValue).tag(m)
                            }
                        }
                        .pickerStyle(.segmented)
                        .tint(.gray)
                        .background(Color.gray)
                        .cornerRadius(8)
                        .padding(.horizontal, 10)
                        .padding(.top, 4)

                    Group {
                        switch contentMode {
                        case .tasks:
                            tasksListView

                        case .schedule:
                            weeklyTimelineContainer
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
    
    @ViewBuilder
        private var weeklyTimelineContainer: some View {
            WeekListView(
                weekStart:    weekViewState.currentWeekStart,
                blocksPerDay: viewModel.dayTimelineStorage,
                accentColor:  RGBAColor(color: .cyan),
                onEdit:       { blk in viewModel.upsertBlock(blk, for: blk.start) },
                onCreateDraft:{ blk in viewModel.upsertBlock(blk, for: blk.start) },
                onDelete:     { blk in viewModel.deleteBlock(id: blk.id, for: blk.start) }
            )
            .environmentObject(viewModel)
        }


    // ➊ Extract a helper to compute the week’s days:
    private var weekDays: [Date] {
        (0..<7).compactMap { offset in
            Calendar.current.date(
                byAdding: .day,
                value: offset,
                to: weekViewState.currentWeekStart
            )
        }
    }

    // ➋ Now use `weekDays` inside tasksListView:
    private var tasksListView: some View {
        VStack(spacing: 16) {
            ForEach(weekDays, id: \.self) { day in
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
    }


    // MARK: – Helpers
    private func loadWeekSchedule() {
        let now = Date()
        let last = UserDefaults.standard.object(forKey: "LastActiveTime") as? Date ?? now
        if now.timeIntervalSince(last) > 1800 {
            weekViewState.currentWeekStart = WeekViewState.startOfWeek(for: now)
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

        let thisWeekStart = WeekViewState.startOfWeek(for: Date())
        let displayedWeekStart = WeekViewState.startOfWeek(for: weekViewState.currentWeekStart)
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


