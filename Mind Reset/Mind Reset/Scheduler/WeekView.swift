//
//  WeekView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 2/6/25.
//


import SwiftUI
import FirebaseFirestore
import UIKit

// Global accent used across sub‑views.
extension Color {
    static let accentCyan = Color(red: 0, green: 1, blue: 1)
}

// ───────────────────────────────────────────────
// MARK: ‑ Week View (“Your Mindful Week”)
// ───────────────────────────────────────────────
struct WeekView: View {
    // injected
    let accentColor: Color

    // environment / view‑models
    @EnvironmentObject private var session: SessionStore
    @EnvironmentObject private var weekViewState: WeekViewState
    @StateObject private var viewModel = WeekViewModel()

    // three keyboard‑focus flags
    @FocusState private var isWeekPriorityFocused:     Bool
    @FocusState private var isDayCardIntentionFocused: Bool
    @FocusState private var isDayCardTaskFocused:      Bool

    // local UI state
    @State private var weeklyPriorityToDelete: WeeklyPriority?
    @State private var isRemoveMode          = false
    @State private var showWeekCopyAlert     = false

    // convenience
    private var schedule: WeeklySchedule? { viewModel.schedule }

    private var bindingPriorities: Binding<[WeeklyPriority]>? {
        guard let s = schedule else { return nil }
        return Binding(
            get: { s.weeklyPriorities },
            set: { new in
                var tmp = s; tmp.weeklyPriorities = new
                viewModel.schedule = tmp
            }
        )
    }

    // ─────────────────────────────────────────
    // MARK: ‑ Body
    // ─────────────────────────────────────────
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                copyButton
                prioritiesSection
                weekNavigation
                dayCards
                Spacer()
            }
            .padding()
            .padding(.top, -20)
        }
        //  ‑ No `.toolbar` or `NavigationStack` here – SchedulerView handles both.
        .onAppear(perform: loadSchedule)
    }

    // ───────────────────────── sections ─────────────────────────
    /// Copy‑previous‑week button
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
                primaryButton: .destructive(Text("Copy")) { copyFromPreviousWeek() },
                secondaryButton: .cancel()
            )
        }
    }

    /// Weekly priorities list
    private var prioritiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Weekly Priorities")
                    .font(.headline)
                    .foregroundColor(accentColor)
                Spacer()
                Button { addNewPriority() } label: {
                    Image(systemName: "plus.circle")
                        .foregroundColor(accentColor)
                }
            }

            if let binding = bindingPriorities {
                ForEach(binding, id: \.id) { $priority in
                    HStack {
                        TextEditor(text: $priority.title)
                            .focused($isWeekPriorityFocused)
                            .padding(8)
                            .frame(minHeight: 50)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .cornerRadius(8)
                            .onChange(of: priority.title) { _ in
                                viewModel.updateWeeklySchedule()
                            }

                        if binding.wrappedValue.count > 1 && isRemoveMode {
                            Button { weeklyPriorityToDelete = priority } label: {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
                .alert(item: $weeklyPriorityToDelete) { p in
                    Alert(
                        title: Text("Delete Priority"),
                        message: Text("Delete “\(p.title)” ?"),
                        primaryButton: .destructive(Text("Delete")) { deletePriority(p) },
                        secondaryButton: .cancel()
                    )
                }

                // add / remove buttons
                HStack {
                    Button("Add Priority") {
                        addNewPriority()
                        isRemoveMode = false
                    }
                    .font(.headline)
                    .foregroundColor(accentColor)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.black)
                    .cornerRadius(8)

                    Spacer()

                    if binding.wrappedValue.count > 1 {
                        Button(isRemoveMode ? "Done" : "Remove Priority") {
                            isRemoveMode.toggle()
                        }
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.black)
                        .cornerRadius(8)
                    }
                }
                .padding(.top, 8)
            } else {
                Text("Loading weekly priorities…").foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }

    /// Navigation row: “Week of …”
    private var weekNavigation: some View {
        WeekNavigationView(
            currentWeekStart: $weekViewState.currentWeekStart,
            accountCreationDate: session.userModel?.createdAt ?? Date()
        )
        .onChange(of: weekViewState.currentWeekStart) { newStart in
            if let uid = session.userModel?.id {
                viewModel.loadWeeklySchedule(for: newStart, userId: uid)
            }
        }
    }

    /// Seven DayCardViews
    private var dayCards: some View {
        VStack(spacing: 16) {
            ForEach(weekDays(for: weekViewState.currentWeekStart), id: \.self) { day in
                DayCardView(
                    accentColor: accentColor,
                    day: day,
                    toDoItems: bindingForToDoItems(day: day),
                    intention: bindingForIntention(day: day),
                    intentionFocus: $isDayCardIntentionFocused,
                    taskFocus:      $isDayCardTaskFocused
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    // ─────────────────────────────────────────
    // MARK: ‑ Helper methods
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

    private func addNewPriority() {
        guard var sched = schedule else { return }
        sched.weeklyPriorities.append(.init(id: UUID(), title: "New Priority", progress: 0))
        viewModel.schedule = sched
        viewModel.updateWeeklySchedule()
    }

    private func deletePriority(_ p: WeeklyPriority) {
        guard var sched = schedule,
              let idx   = sched.weeklyPriorities.firstIndex(where: { $0.id == p.id }) else { return }
        sched.weeklyPriorities.remove(at: idx)
        viewModel.schedule = sched
        viewModel.updateWeeklySchedule()
    }

    private func weekDays(for start: Date) -> [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }

    private func shortDayKey(from date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "E"; return f.string(from: date)
    }

    private func bindingForToDoItems(day: Date) -> Binding<[ToDoItem]> {
        Binding(
            get: { schedule?.dailyToDoLists[shortDayKey(from: day)] ?? [] },
            set: { new in
                guard var sched = schedule else { return }
                sched.dailyToDoLists[shortDayKey(from: day)] = new
                viewModel.schedule = sched
                viewModel.updateWeeklySchedule()
            }
        )
    }

    private func bindingForIntention(day: Date) -> Binding<String> {
        Binding(
            get: { schedule?.dailyIntentions[shortDayKey(from: day)] ?? "" },
            set: { new in
                guard var sched = schedule else { return }
                sched.dailyIntentions[shortDayKey(from: day)] = new
                viewModel.schedule = sched
                viewModel.updateWeeklySchedule()
            }
        )
    }

    // Firestore copy‑week helper
    private func copyFromPreviousWeek() {
        guard let prev = Calendar.current.date(byAdding: .weekOfYear,
                                               value: -1,
                                               to: weekViewState.currentWeekStart) else { return }
        dbLoadPreviousWeekSchedule(previousWeekStart: prev) { prevSched in
            guard let prevSched = prevSched, var sched = schedule else { return }
            sched.weeklyPriorities = prevSched.weeklyPriorities
            sched.dailyIntentions  = prevSched.dailyIntentions
            sched.dailyToDoLists   = prevSched.dailyToDoLists
            viewModel.schedule = sched
            viewModel.updateWeeklySchedule()
        }
    }

    private func dbLoadPreviousWeekSchedule(previousWeekStart: Date,
                                            completion: @escaping (WeeklySchedule?) -> Void) {
        guard let uid = session.userModel?.id else { completion(nil); return }
        let docId = DateFormatter.localizedString(from: previousWeekStart,
                                                  dateStyle: .short,
                                                  timeStyle: .none)
        Firestore.firestore()
            .collection("users").document(uid)
            .collection("weekSchedules").document(docId)
            .getDocument { snap, _ in
                guard let snap = snap, snap.exists,
                      let sched = try? snap.data(as: WeeklySchedule.self) else {
                    completion(nil); return
                }
                completion(sched)
            }
    }
}

// ───────────────────────────────────────────
// MARK: ‑ WeekNavigationView (unchanged)
// ───────────────────────────────────────────
struct WeekNavigationView: View {
    @Binding var currentWeekStart: Date
    let accountCreationDate: Date

    var body: some View {
        HStack {
            Button {
                if canGoBack(),
                   let prev = Calendar.current.date(byAdding: .weekOfYear,
                                                    value: -1,
                                                    to: currentWeekStart) {
                    currentWeekStart = prev
                }
            } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(canGoBack() ? .white : .gray)
            }

            Spacer()

            Text(weekRangeString())
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            Button {
                if let nxt = Calendar.current.date(byAdding: .weekOfYear,
                                                   value: 1,
                                                   to: currentWeekStart) {
                    currentWeekStart = nxt
                }
            } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }

    private func weekRangeString() -> String {
        let cal = Calendar.current
        guard let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear],
                                                            from: currentWeekStart)) else { return "" }
        let end = Calendar.current.date(byAdding: .day, value: 6, to: start) ?? start
        let fmt = DateFormatter(); fmt.dateFormat = "M/d"
        return "Week of \(fmt.string(from: start)) – \(fmt.string(from: end))"
    }

    private func canGoBack() -> Bool {
        guard let prev = Calendar.current.date(byAdding: .weekOfYear,
                                               value: -1,
                                               to: currentWeekStart) else { return false }
        return prev >= startOfWeek(for: accountCreationDate)
    }

    private func startOfWeek(for date: Date) -> Date {
        var cal = Calendar.current; cal.firstWeekday = 1
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? date
    }
}

// ───────────────────────────────────────────
// MARK: ‑ DayCardView & ToDoListView
// ───────────────────────────────────────────
private struct DayCardView: View {
    let accentColor: Color
    let day: Date
    @Binding var toDoItems: [ToDoItem]
    @Binding var intention: String
    let intentionFocus: FocusState<Bool>.Binding
    let taskFocus:      FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading) {
                Text(dayOfWeekString(from: day)).font(.headline).foregroundColor(.white)
                Text(formattedDate(from: day)).font(.caption).foregroundColor(.white.opacity(0.7))
            }
            .padding(.bottom, 4)

            TextEditor(text: $intention)
                .focused(intentionFocus)
                .padding(8)
                .frame(minHeight: 50)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(8)

            ToDoListView(
                accentColor: accentColor,
                toDoItems: $toDoItems,
                taskFocus: taskFocus
            )
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }

    private func dayOfWeekString(from date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEEE"; return f.string(from: date)
    }
    private func formattedDate(from date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: date)
    }
}

private struct ToDoListView: View {
    let accentColor: Color
    @Binding var toDoItems: [ToDoItem]
    let taskFocus: FocusState<Bool>.Binding

    @State private var taskToDelete: ToDoItem?
    @State private var isRemoveMode = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach($toDoItems) { $item in
                HStack {
                    Button { item.isCompleted.toggle() } label: {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(item.isCompleted ? .green : .white)
                    }

                    TextEditor(text: $item.title)
                        .focused(taskFocus)
                        .padding(8)
                        .frame(minHeight: 50)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(8)

                    if isRemoveMode && toDoItems.count > 1 {
                        Button { taskToDelete = item } label: {
                            Image(systemName: "minus.circle").foregroundColor(.red)
                        }
                    }
                }
            }

            HStack {
                Button {
                    toDoItems.append(ToDoItem(id: UUID(), title: "", isCompleted: false))
                    isRemoveMode = false
                } label: {
                    HStack { Image(systemName: "plus.circle"); Text("Add Task") }
                        .foregroundColor(accentColor)
                        .font(.headline)
                        .padding(.vertical, 8).padding(.horizontal, 16)
                        .background(Color.black)
                        .cornerRadius(8)
                }

                Spacer()

                if toDoItems.count > 1 {
                    Button(isRemoveMode ? "Done" : "Remove Task") {
                        isRemoveMode.toggle()
                    }
                    .font(.headline)
                    .foregroundColor(.red)
                    .padding(.vertical, 8).padding(.horizontal, 16)
                    .background(Color.black)
                    .cornerRadius(8)
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
        .alert(item: $taskToDelete) { task in
            Alert(
                title: Text("Delete Task"),
                message: Text("Delete this task?"),
                primaryButton: .destructive(Text("Delete")) {
                    if let i = toDoItems.firstIndex(where: { $0.id == task.id }) {
                        toDoItems.remove(at: i)
                    }
                    if toDoItems.count <= 1 { isRemoveMode = false }
                },
                secondaryButton: .cancel()
            )
        }
    }
}
