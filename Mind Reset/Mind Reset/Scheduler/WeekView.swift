//
//  WeekView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 2/6/25.
//

import SwiftUI
import Combine

// MARK: - Main Weekly Blueprint View
struct WeekView: View {
    let accentColor: Color
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var weekViewState: WeekViewState // Shared week state
    @StateObject private var viewModel = WeekViewModel()
    
    // For deletion confirmation for weekly priorities.
    @State private var weeklyPriorityToDelete: WeeklyPriority?
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Weekly Priorities Section
                prioritiesSection
                
                // Week Navigation Header using shared state
                WeekNavigationView(currentWeekStart: $weekViewState.currentWeekStart, accountCreationDate: session.userModel?.createdAt ?? Date())
                    .onChange(of: weekViewState.currentWeekStart) { newWeekStart in
                        if let userId = session.userModel?.id {
                            viewModel.loadWeeklySchedule(for: newWeekStart, userId: userId)
                        }
                    }
                
                // Days of the Week Cards
                VStack(spacing: 16) {
                    ForEach(weekDays(for: weekViewState.currentWeekStart), id: \.self) { day in
                        DayCardView(
                            day: day,
                            toDoItems: bindingForToDoItems(day: day),
                            intention: bindingForIntention(day: day)
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            let now = Date()
            let lastActive = UserDefaults.standard.object(forKey: "LastActiveTime") as? Date ?? now
            if now.timeIntervalSince(lastActive) > 1800 {
                // More than 30 minutes inactivity: reset week to the current week.
                weekViewState.currentWeekStart = WeekViewState.startOfCurrentWeek(now)
            }
            UserDefaults.standard.set(now, forKey: "LastActiveTime")
            
            if let userId = session.userModel?.id {
                viewModel.loadWeeklySchedule(for: weekViewState.currentWeekStart, userId: userId)
            }
        }
    }
    
    // MARK: - Weekly Priorities Section
    private var prioritiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Weekly Priorities")
                    .font(.headline)
                    .foregroundColor(accentColor)
                Spacer()
                Button(action: {
                    addNewPriority()
                }) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(accentColor)
                }
            }
            if let schedule = viewModel.schedule {
                let bindingPriorities = Binding<[WeeklyPriority]>(
                    get: { schedule.weeklyPriorities },
                    set: { newVal in
                        var temp = schedule
                        temp.weeklyPriorities = newVal
                        viewModel.schedule = temp
                    }
                )
                ForEach(bindingPriorities) { $priority in
                    HStack {
                        TextEditor(text: $priority.title)
                            .padding(8)
                            .frame(minHeight: 50)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .cornerRadius(8)
                            .fixedSize(horizontal: false, vertical: true)
                            .onChange(of: priority.title) { _ in
                                viewModel.updateWeeklySchedule()
                            }
                        if bindingPriorities.wrappedValue.count > 1 {
                            Button(action: {
                                weeklyPriorityToDelete = priority
                            }) {
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
                        primaryButton: .destructive(Text("Delete")) {
                            if var schedule = viewModel.schedule,
                               let index = schedule.weeklyPriorities.firstIndex(where: { $0.id == priority.id }) {
                                schedule.weeklyPriorities.remove(at: index)
                                viewModel.schedule = schedule
                                viewModel.updateWeeklySchedule()
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }
            } else {
                Text("Loading weekly priorities...")
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }
    
    private func addNewPriority() {
        guard var schedule = viewModel.schedule else { return }
        let newPriority = WeeklyPriority(id: UUID(), title: "New Priority", progress: 0.0)
        schedule.weeklyPriorities.append(newPriority)
        viewModel.schedule = schedule
        viewModel.updateWeeklySchedule()
    }
    
    // MARK: - Helper Bindings for To-Do Items & Intentions
    private func bindingForToDoItems(day: Date) -> Binding<[ToDoItem]> {
        Binding(
            get: {
                if let schedule = viewModel.schedule {
                    let dayKey = shortDayKey(from: day)
                    return schedule.dailyToDoLists[dayKey] ?? []
                } else {
                    return []
                }
            },
            set: { newValue in
                guard var schedule = viewModel.schedule else { return }
                let dayKey = shortDayKey(from: day)
                schedule.dailyToDoLists[dayKey] = newValue
                viewModel.schedule = schedule
                viewModel.updateWeeklySchedule()
            }
        )
    }
    
    private func bindingForIntention(day: Date) -> Binding<String> {
        Binding(
            get: {
                if let schedule = viewModel.schedule {
                    let dayKey = shortDayKey(from: day)
                    return schedule.dailyIntentions[dayKey] ?? ""
                } else {
                    return ""
                }
            },
            set: { newValue in
                guard var schedule = viewModel.schedule else { return }
                let dayKey = shortDayKey(from: day)
                schedule.dailyIntentions[dayKey] = newValue
                viewModel.schedule = schedule
                viewModel.updateWeeklySchedule()
            }
        )
    }
    
    private func weekDays(for start: Date) -> [Date] {
        var days: [Date] = []
        let calendar = Calendar.current
        for offset in 0..<7 {
            if let day = calendar.date(byAdding: .day, value: offset, to: start) {
                days.append(day)
            }
        }
        return days
    }
    
    private func shortDayKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        return formatter.string(from: date)
    }
}

/////////////////////////////////////////////////////////////////
// MARK: - Week Navigation View
struct WeekNavigationView: View {
    @Binding var currentWeekStart: Date
    let accountCreationDate: Date
    
    var body: some View {
        HStack {
            if canGoBack() {
                Button(action: {
                    if let prevWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) {
                        currentWeekStart = prevWeek
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
                }
            }
            Spacer()
            Text(weekRangeString())
                .foregroundColor(.white)
                .font(.headline)
            Spacer()
            Button(action: {
                if let nextWeek = Calendar.current.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) {
                    currentWeekStart = nextWeek
                }
            }) {
                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }
    
    private func weekRangeString() -> String {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: currentWeekStart)
        guard let weekStart = calendar.date(from: components) else { return "" }
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return "Week of \(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
    }
    
    private func canGoBack() -> Bool {
        guard let prevWeek = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) else { return false }
        return prevWeek >= startOfWeek(for: accountCreationDate)
    }
    
    private func startOfWeek(for date: Date) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 1
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: components) ?? date
    }
}

/////////////////////////////////////////////////////////////////
// MARK: - DayCardView & ToDoListView
struct DayCardView: View {
    let day: Date
    @Binding var toDoItems: [ToDoItem]
    @Binding var intention: String
    
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
                .padding(8)
                .frame(minHeight: 50)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(8)
                .overlay(
                    Group {
                        if intention.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text("Main goal for the day...")
                                .foregroundColor(.gray)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                        }
                    },
                    alignment: .topLeading
                )
                .scrollContentBackground(.hidden)
            
            ToDoListView(toDoItems: $toDoItems)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }
    
    private func dayOfWeekString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: date)
    }
    
    private func formattedDate(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

struct ToDoListView: View {
    @Binding var toDoItems: [ToDoItem]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach($toDoItems) { $item in
                HStack {
                    Button(action: {
                        item.isCompleted.toggle()
                    }) {
                        Image(systemName: item.isCompleted ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(item.isCompleted ? .green : .white)
                    }
                    TextEditor(text: $item.title)
                        .padding(8)
                        .frame(minHeight: 50)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)
                        .cornerRadius(8)
                }
            }
            Button(action: {
                toDoItems.append(ToDoItem(id: UUID(), title: "", isCompleted: false))
            }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Task")
                }
                .foregroundColor(.accentColor)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
    }
}
