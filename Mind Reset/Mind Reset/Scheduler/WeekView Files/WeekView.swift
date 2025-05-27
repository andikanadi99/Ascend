// WeekView.swift
// Mind Reset
//
// Created by Andika Yudhatrisna on 2/6/25.

import SwiftUI
import FirebaseFirestore

struct WeekView: View {
    let accentColor: Color

    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var weekViewState: WeekViewState
    @StateObject private var viewModel = WeekViewModel()

    @FocusState private var isDayCardIntentionFocused: Bool
    @FocusState private var isDayCardTaskFocused: Bool

    @State private var isRemoveMode       = false
    @State private var showWeekCopyAlert = false
    @State private var editMode: EditMode = .inactive

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                copyButton

                WeekNavigationView(
                    currentWeekStart: $weekViewState.currentWeekStart,
                    accountCreationDate: session.userModel?.createdAt ?? Date(),
                    accentColor: accentColor
                )
                .onChange(of: weekViewState.currentWeekStart) { newStart in
                    if let uid = session.userModel?.id {
                        viewModel.loadWeeklySchedule(for: newStart, userId: uid)
                    }
                }

                if viewModel.schedule != nil {
                    WeeklyPrioritiesSection(
                      priorities:         viewModel.weeklyPrioritiesBinding,
                      editMode:           $editMode,
                      accentColor:        accentColor,
                      isRemoveMode:       isRemoveMode,
                      onToggleRemoveMode: { isRemoveMode.toggle() },
                      onMove:             viewModel.moveWeeklyPriorities(indices:to:),
                      onCommit:           viewModel.updateWeeklySchedule,
                      onDelete:           viewModel.deletePriority(_:),
                      addAction:          viewModel.addNewPriority
                    )
                } else {
                    Text("Loading priorities…")
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity, minHeight: 90)
                }

                VStack(spacing: 16) {
                    ForEach(0..<7) { offset in
                        let day = Calendar.current.date(
                            byAdding: .day,
                            value: offset,
                            to: weekViewState.currentWeekStart
                        )!
                        DayCardView(
                            accentColor: accentColor,
                            day: day,
                            toDoItems: viewModel.toDoItemsBinding(for: day),
                            intention: viewModel.intentionBinding(for: day),
                            intentionFocus: $isDayCardIntentionFocused,
                            taskFocus:      $isDayCardTaskFocused
                        )
                        .frame(maxWidth: .infinity)
                    }
                }

                Spacer()
            }
            .padding()
            .padding(.top, -20)
        }
        .onAppear(perform: loadSchedule)
    }

    private var copyButton: some View {
        HStack {
            Spacer()
            Button("Copy from Previous Week") { showWeekCopyAlert = true }
                .font(.headline)
                .foregroundColor(accentColor)
                .padding(.horizontal, 16)
                .background(Color.black)
                .cornerRadius(8)
            Spacer()
        }
        .alert(isPresented: $showWeekCopyAlert) {
            Alert(
                title: Text("Confirm Copy"),
                message: Text("Are you sure you want to copy the previous week's schedule?"),
                primaryButton: .destructive(Text("Copy")) {
                    if let uid = session.userModel?.id {
                        viewModel.copyPreviousWeek(to: weekViewState.currentWeekStart, userId: uid)
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

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
