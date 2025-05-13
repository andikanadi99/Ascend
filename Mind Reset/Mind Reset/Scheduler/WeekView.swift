//
//  WeekView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 2/6/25.
//

import SwiftUI
import Combine
import UIKit
import FirebaseFirestore

// MARK: - Focusable Fields
private enum Field: Hashable {
    case weeklyPriority(UUID)
    case intention(Date)
    case todo(UUID)
}

extension Color {
  static let accentCyan = Color(red: 0, green: 1, blue: 1)
}
// MARK: - WeekView
struct WeekView: View {
    let accentColor: Color
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var weekViewState: WeekViewState
    @StateObject private var viewModel = WeekViewModel()

    @FocusState private var focusedField: Field?
    @State private var weeklyPriorityToDelete: WeeklyPriority?
    @State private var isRemoveMode = false
    @State private var showWeekCopyAlert = false

    private var schedule: WeeklySchedule? { viewModel.schedule }
    private var bindingPriorities: Binding<[WeeklyPriority]>? {
        guard let sched = schedule else { return nil }
        return Binding<[WeeklyPriority]>(
            get: {
                sched.weeklyPriorities
            },
            set: { newVal in
                var tmp = sched
                tmp.weeklyPriorities = newVal
                viewModel.schedule = tmp
            }
        )
    }

    var body: some View {
           ScrollView(.vertical) {
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
           // attach the keyboard toolbar here
           .toolbar {
               ToolbarItemGroup(placement: .keyboard) {
                   Spacer()
                   Button("Done") {
                       focusedField = nil
                       UIApplication.shared.sendAction(
                           #selector(UIResponder.resignFirstResponder),
                           to: nil, from: nil, for: nil
                       )
                   }
               }
           }
           .navigationTitle("Your Week")
           .navigationBarTitleDisplayMode(.inline)
           .onAppear(perform: loadSchedule)
       }

    // MARK: Copy Button
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

    // MARK: Priorities Section
    private var prioritiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Weekly Priorities")
                    .font(.headline)
                    .foregroundColor(accentColor)
                Spacer()
                Button(action: addNewPriority) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(accentColor)
                }
            }

            if let binding = bindingPriorities {
                ForEach(binding, id: \.id) { $priority in
                    HStack {
                        TextEditor(text: $priority.title)
                            .focused($focusedField, equals: .weeklyPriority(priority.id))
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
                .alert(item: $weeklyPriorityToDelete) { priority in
                    Alert(
                        title: Text("Delete Priority"),
                        message: Text("Are you sure you want to delete this weekly priority?"),
                        primaryButton: .destructive(Text("Delete")) { deletePriority(priority) },
                        secondaryButton: .cancel()
                    )
                }

                HStack {
                    Button {
                        addNewPriority()
                        isRemoveMode = false
                    } label: {
                        Text("Add Priority")
                            .font(.headline)
                            .foregroundColor(accentColor)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.black)
                            .cornerRadius(8)
                    }
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
                Text("Loading weekly priorities…")
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }

    // MARK: Week Navigation
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

    // MARK: Day Cards
    private var dayCards: some View {
        VStack(spacing: 16) {
            ForEach(weekDays(for: weekViewState.currentWeekStart), id: \.self) { day in
                DayCardView(
                    accentColor: accentColor,
                    day: day,
                    toDoItems: bindingForToDoItems(day: day),
                    intention: bindingForIntention(day: day),
                    focusedField: $focusedField
                )
                .frame(maxWidth: .infinity)
            }
        }
    }

    // MARK: Helpers

    private func loadSchedule() {
        let now = Date()
        let lastActive = UserDefaults.standard.object(forKey: "LastActiveTime") as? Date ?? now
        if now.timeIntervalSince(lastActive) > 1800 {
            weekViewState.currentWeekStart = WeekViewState.startOfCurrentWeek(now)
        }
        UserDefaults.standard.set(now, forKey: "LastActiveTime")
        if let uid = session.userModel?.id {
            viewModel.loadWeeklySchedule(for: weekViewState.currentWeekStart, userId: uid)
        }
    }

    private func addNewPriority() {
        guard var sched = schedule else { return }
        sched.weeklyPriorities.append(WeeklyPriority(id: UUID(), title: "New Priority", progress: 0))
        viewModel.schedule = sched
        viewModel.updateWeeklySchedule()
    }

    private func deletePriority(_ p: WeeklyPriority) {
        guard var sched = schedule,
              let idx = sched.weeklyPriorities.firstIndex(where: { $0.id == p.id })
        else { return }
        sched.weeklyPriorities.remove(at: idx)
        viewModel.schedule = sched
        viewModel.updateWeeklySchedule()
    }

    private func weekDays(for start: Date) -> [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: start) }
    }

    private func shortDayKey(from date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "E"; return fmt.string(from: date)
    }

    private func bindingForToDoItems(day: Date) -> Binding<[ToDoItem]> {
        Binding(get: {
            schedule?.dailyToDoLists[shortDayKey(from: day)] ?? []
        }, set: { new in
            guard var sched = schedule else { return }
            sched.dailyToDoLists[shortDayKey(from: day)] = new
            viewModel.schedule = sched
            viewModel.updateWeeklySchedule()
        })
    }

    private func bindingForIntention(day: Date) -> Binding<String> {
        Binding(get: {
            schedule?.dailyIntentions[shortDayKey(from: day)] ?? ""
        }, set: { new in
            guard var sched = schedule else { return }
            sched.dailyIntentions[shortDayKey(from: day)] = new
            viewModel.schedule = sched
            viewModel.updateWeeklySchedule()
        })
    }

    private func copyFromPreviousWeek() {
        let cal = Calendar.current
        guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: weekViewState.currentWeekStart) else { return }
        dbLoadPreviousWeekSchedule(previousWeekStart: prev) { prevSched in
            guard let prevSched = prevSched, var sched = schedule else { return }
            sched.weeklyPriorities = prevSched.weeklyPriorities
            sched.dailyIntentions = prevSched.dailyIntentions
            sched.dailyToDoLists = prevSched.dailyToDoLists
            viewModel.schedule = sched
            viewModel.updateWeeklySchedule()
        }
    }

    private func dbLoadPreviousWeekSchedule(previousWeekStart: Date, completion: @escaping (WeeklySchedule?) -> Void) {
        guard let uid = session.userModel?.id else { completion(nil); return }
        let docId = DateFormatter.localizedString(
            from: previousWeekStart,
            dateStyle: .short,
            timeStyle: .none
        )
        Firestore.firestore()
            .collection("users").document(uid)
            .collection("weekSchedules").document(docId)
            .getDocument { snap, _ in
                guard let snap = snap, snap.exists,
                      let sched = try? snap.data(as: WeeklySchedule.self)
                else { completion(nil); return }
                completion(sched)
            }
    }
}

// MARK: - WeekNavigationView
struct WeekNavigationView: View {
    @Binding var currentWeekStart: Date
    let accountCreationDate: Date

    var body: some View {
        HStack {
            Button {
                if canGoBack(),
                   let prev = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart)
                {
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
                if let nxt = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) {
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
        guard let start = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentWeekStart)) else { return "" }
        let end = cal.date(byAdding: .day, value: 6, to: start) ?? start
        let fmt = DateFormatter(); fmt.dateFormat = "M/d"
        return "Week of \(fmt.string(from: start)) – \(fmt.string(from: end))"
    }

    private func canGoBack() -> Bool {
        guard let prev = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) else { return false }
        return prev >= startOfWeek(for: accountCreationDate)
    }

    private func startOfWeek(for date: Date) -> Date {
        var cal = Calendar.current; cal.firstWeekday = 1
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? date
    }
}

// MARK: - DayCardView & ToDoListView

fileprivate struct DayCardView: View {
    let accentColor: Color
    let day: Date
    @Binding var toDoItems: [ToDoItem]
    @Binding var intention: String
    let focusedField: FocusState<Field?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading) {
                Text(dayOfWeekString(from: day))
                    .font(.headline)
                    .foregroundColor(.white)
                Text(formattedDate(from: day))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.bottom, 4)

            TextEditor(text: $intention)
                .focused(focusedField, equals: .intention(day))
                .padding(8)
                .frame(minHeight: 50)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(8)

            ToDoListView(
                accentColor: accentColor,
                toDoItems: $toDoItems,
                focusedField: focusedField
            )
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }

    private func dayOfWeekString(from date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "EEEE"; return fmt.string(from: date)
    }
    private func formattedDate(from date: Date) -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "M/d"; return fmt.string(from: date)
    }
}

fileprivate struct ToDoListView: View {
    let accentColor: Color
    @Binding var toDoItems: [ToDoItem]
    let focusedField: FocusState<Field?>.Binding
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
                        .focused(focusedField, equals: .todo(item.id))
                        .padding(8)
                        .frame(minHeight: 50)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(8)

                    if isRemoveMode && toDoItems.count > 1 {
                        Button { taskToDelete = item } label: {
                            Image(systemName: "minus.circle")
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            HStack {
                Button {
                    toDoItems.append(ToDoItem(id: UUID(), title: "", isCompleted: false))
                    isRemoveMode = false
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Task")
                    }
                    .foregroundColor(accentColor)
                    .font(.headline)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
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
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
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
                message: Text("Are you sure you want to delete this task?"),
                primaryButton: .destructive(Text("Delete")) {
                    if let idx = toDoItems.firstIndex(where: { $0.id == task.id }) {
                        toDoItems.remove(at: idx)
                    }
                    if toDoItems.count <= 1 { isRemoveMode = false }
                },
                secondaryButton: .cancel()
            )
        }
    }
}


