//
//  SchedulerView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 2/6/25.
//

import SwiftUI
import Combine

// MARK: - Main Scheduler View
struct SchedulerView: View {
    @EnvironmentObject var session: SessionStore
    @State private var selectedTab: SchedulerTab = .day
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack {
                    // Title
                    Text("Mindful Routine")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    // Tab header with a small divider
                    VStack(spacing: 4) {
                        Picker("Tabs", selection: $selectedTab) {
                            Text("Day").tag(SchedulerTab.day)
                            Text("Week").tag(SchedulerTab.week)
                            Text("Month").tag(SchedulerTab.month)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .tint(.gray)
                        .background(Color.gray)
                        .cornerRadius(8)
                        .padding(.horizontal, 10)
                        
                        Rectangle()
                            .fill(Color.black)
                            .frame(maxWidth: .infinity)
                            .frame(height: 4)
                            .padding(.horizontal, 10)
                    }
                    
                    // Switch between views based on the selected tab
                    Group {
                        switch selectedTab {
                        case .day:
                            DayView()
                        case .week:
                            WeekView(accentColor: .accentColor)
                        case .month:
                            if let accountCreationDate = session.userModel?.createdAt {
                                MonthView(accentColor: .accentColor, accountCreationDate: accountCreationDate)
                            } else {
                                MonthView(accentColor: .accentColor, accountCreationDate: Date())
                            }
                        }
                    }
                    .padding()
                    
                    Spacer()
                }
            }
            .navigationBarHidden(true)
        }
    }
}

// MARK: - Scheduler Tab Options
enum SchedulerTab: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
}

// MARK: - Day View ("Your Daily Intentions")
struct DayView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var viewModel = DayViewModel()
    
    // For date navigation
    @State private var selectedDate: Date = Date()
    
    // Display: "Monday, March 24, 2025"
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: selectedDate)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                //  Today's priority's list
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Today's Top Priority")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        Spacer()
                        Button(action: {
                            // Add a new priority
                            guard var schedule = viewModel.schedule else { return }
                            let newPriority = TodayPriority(id: UUID(), title: "New Priority", progress: 0.0)
                            schedule.priorities.append(newPriority)
                            viewModel.schedule = schedule
                            
                            // Immediately sync with Firestore
                            viewModel.updateDaySchedule()
                        }) {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.accentColor)
                        }
                    }
                    
                    // Show existing priorities
                    if let _ = viewModel.schedule {
                        // Create a binding to the non‑optional priorities array.
                        let prioritiesBinding = Binding<[TodayPriority]>(
                            get: { viewModel.schedule!.priorities },
                            set: { newValue in
                                var updatedSchedule = viewModel.schedule!
                                updatedSchedule.priorities = newValue
                                viewModel.schedule = updatedSchedule
                            }
                        )
                        ForEach(prioritiesBinding) { $priority in
                            HStack {
                                TextEditor(text: $priority.title)
                                    .padding(8)
                                    .frame(minHeight: 50)
                                    .background(Color.black)
                                    .cornerRadius(8)
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .onChange(of: priority.title) { _ in
                                        viewModel.updateDaySchedule()
                                    }
                                
                                // Show delete button if there's more than one priority.
                                if prioritiesBinding.wrappedValue.count > 1 {
                                    Button(action: {
                                        prioritiesBinding.wrappedValue.removeAll { $0.id == priority.id }
                                        viewModel.updateDaySchedule()
                                    }) {
                                        Image(systemName: "minus.circle")
                                            .foregroundColor(.red)
                                    }
                                }
                            }
                        }
                    } else {
                        Text("Loading priorities...")
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.3))
                .cornerRadius(8)

                
                // Date Navigation
                HStack {
                    Button(action: {
                        // Go one day back
                        if let accountCreationDate = session.userModel?.createdAt,
                           let prevDay = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate),
                           prevDay >= accountCreationDate {
                            selectedDate = prevDay
                            if let userId = session.userModel?.id {
                                // Load from Firestore for that day
                                viewModel.loadDaySchedule(for: prevDay, userId: userId)
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(selectedDate > (session.userModel?.createdAt ?? Date()) ? .white : .gray)
                    }
                    
                    Spacer()
                    
                    Text(dateString)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        // Go one day forward
                        if let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
                            selectedDate = nextDay
                            if let userId = session.userModel?.id {
                                viewModel.loadDaySchedule(for: nextDay, userId: userId)
                            }
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.3))
                .cornerRadius(8)
                
                // Wake-up & Sleep Time pickers
                if let schedule = viewModel.schedule {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            // Wake Up
                            VStack(alignment: .leading) {
                                Text("Wake Up Time")
                                    .foregroundColor(.white)
                                
                                DatePicker("", selection: Binding(
                                    get: { schedule.wakeUpTime },
                                    set: { newVal in
                                        var temp = schedule
                                        temp.wakeUpTime = newVal
                                        viewModel.schedule = temp
                                        // Possibly regenerate blocks
                                        viewModel.regenerateBlocks()
                                    }
                                ), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .environment(\.colorScheme, .dark)
                                .padding(4)
                                .background(Color.black)
                                .cornerRadius(4)
                            }
                            
                            Spacer()
                            
                            // Sleep
                            VStack(alignment: .leading) {
                                Text("Sleep Time")
                                    .foregroundColor(.white)
                                
                                DatePicker("", selection: Binding(
                                    get: { schedule.sleepTime },
                                    set: { newVal in
                                        var temp = schedule
                                        temp.sleepTime = newVal
                                        viewModel.schedule = temp
                                        // Possibly regenerate blocks
                                        viewModel.regenerateBlocks()
                                    }
                                ), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .environment(\.colorScheme, .dark)
                                .padding(4)
                                .background(Color.black)
                                .cornerRadius(4)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(8)
                }
                
                // "Your Daily Intentions" header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Daily Intentions")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text(dateString)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Time Blocks
                if viewModel.schedule != nil {
                    let timeBlocksBinding = Binding<[TimeBlock]>(
                        get: { viewModel.schedule!.timeBlocks },
                        set: { newValue in
                            var updatedSchedule = viewModel.schedule!
                            updatedSchedule.timeBlocks = newValue
                            viewModel.schedule = updatedSchedule
                        }
                    )
                    ForEach(timeBlocksBinding) { $block in
                        HStack(alignment: .top, spacing: 8) {
                            // Editable hour
                            TextField("Time", text: $block.time)
                                .font(.caption)
                                .foregroundColor(.white)
                                .frame(width: 80)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(8)
                                .onChange(of: block.time) { _ in
                                    viewModel.updateDaySchedule()
                                }
                            
                            // Editable task with a consistent minimum height.
                            TextEditor(text: $block.task)
                                .font(.caption)
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)  // For iOS 16+
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(8)
                                .frame(minHeight: 50, maxHeight: 80) // Adjust these values as needed.
                                .onChange(of: block.task) { _ in
                                    viewModel.updateDaySchedule()
                                }
                            
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    }

                } else {
                    Text("Loading time blocks...")
                        .foregroundColor(.white)
                }

                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            // On appear, load today's schedule for this user
            if let userId = session.userModel?.id {
                viewModel.loadDaySchedule(for: selectedDate, userId: userId)
            }
        }
    }
}

// MARK: - Week View ("Your Weekly Blueprint")
struct WeekView: View {
    let accentColor: Color
    @EnvironmentObject var session: SessionStore
    
    @StateObject private var viewModel = WeekViewModel()
    
    // Week navigation state
    @State private var currentWeekStart: Date = {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday
        let now = Date()
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return calendar.date(from: components) ?? now
    }()
    
    var body: some View {
        ScrollView { // Wrap everything in a single ScrollView
            VStack(alignment: .leading, spacing: 16) {
                // Weekly Priorities Section
                prioritiesSection
                
                // Week Navigation Header
                WeekNavigationView(
                    currentWeekStart: $currentWeekStart,
                    accountCreationDate: session.userModel?.createdAt ?? Date()
                )
                .onChange(of: currentWeekStart) { newWeekStart in
                    if let userId = session.userModel?.id {
                        viewModel.loadWeeklySchedule(for: newWeekStart, userId: userId)
                    }
                }
                
                // Days of the Week (now not wrapped in its own ScrollView)
                VStack(spacing: 16) {
                    ForEach(weekDays(for: currentWeekStart), id: \.self) { day in
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
            .padding() // Outer padding for the content
        }
        .onAppear {
            if let userId = session.userModel?.id {
                viewModel.loadWeeklySchedule(for: currentWeekStart, userId: userId)
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
                // We'll make a Binding to the array so we can modify and update Firestore
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
                        if bindingPriorities.count > 1 {
                            Button(action: {
                                // remove this priority
                                bindingPriorities.wrappedValue.removeAll { $0.id == priority.id }
                                viewModel.updateWeeklySchedule()
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                            }
                        }
                    }
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
    
    // MARK: - Helper for adding a new priority
    private func addNewPriority() {
        guard var schedule = viewModel.schedule else { return }
        let newPriority = WeeklyPriority(id: UUID(), title: "New Priority", progress: 0.0)
        schedule.weeklyPriorities.append(newPriority)
        viewModel.schedule = schedule
        viewModel.updateWeeklySchedule()
    }
    
    // MARK: - Binding for a day’s ToDoItems
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
    
    // MARK: - Binding for a day’s intention
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
    
    // MARK: - Generate the 7 Days for currentWeekStart
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
    
    // MARK: - Convert Date to "Sun", "Mon", etc.
    private func shortDayKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"  // "Sun", "Mon", ...
        return formatter.string(from: date)
    }
}

struct DayCardView: View {
    let day: Date
    @Binding var toDoItems: [ToDoItem]
    @Binding var intention: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with day name and date.
            VStack(alignment: .leading) {
                Text(dayOfWeekString(from: day))
                    .font(.headline)
                    .foregroundColor(.white)
                Text(formattedDate(from: day))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.bottom, 4)
            
            // Editable intention using TextEditor.
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
                .scrollContentBackground(.hidden)  // For iOS 16+

                
            // To-Do List.
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
                    // Editable intention using TextEditor.
                    HStack() {
                        ZStack(alignment: .topLeading) {
                            TextEditor(text: $item.title)
                                .padding(8)
                                .frame(minHeight: 50)
                                .background(Color.black)
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                                .cornerRadius(8)
                                .overlay(
                                    Group {
                                        if item.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            Text("Enter task...")
                                                .foregroundColor(.gray)
                                                .padding(8)
                    
                                        }
                                    },
                                    alignment: .topLeading
                                )
                        }
                        Button(action: {
                            toDoItems.removeAll { $0.id == item.id }
                        }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }

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
        return "Week of \(formatter.string(from: weekStart))-\(formatter.string(from: weekEnd))"
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

// MARK: - Month View ("Your Mindful Month")
struct MonthView: View {
    let accentColor: Color
    let accountCreationDate: Date  // Account creation date from UserModel

    @State private var currentMonth: Date = Date()
    @State private var selectedDay: Date? = nil
    @State private var showDaySummary: Bool = false

    @StateObject private var viewModel = MonthViewModel()
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var habitVM: HabitViewModel   // Inject the HabitViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Monthly Priorities Section
            prioritiesSection
            
            // Calendar Section
            calendarSection
                .frame(height: 300)
            
            Spacer()
        }
        .padding()
        // Overlay for Day Summary
        .overlay(
            Group {
                if showDaySummary, let day = selectedDay {
                    VStack {
                        // Pass the actual habits via the habitVM binding.
                        DaySummaryView(day: day, habits: $habitVM.habits, onClose: {
                            withAnimation {
                                showDaySummary = false
                            }
                        })
                        .cornerRadius(12)
                    }
                    .frame(maxWidth: 300)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .transition(.opacity)
                }
            }
        )
        .onAppear {
            if let userId = session.userModel?.id {
                viewModel.loadMonthSchedule(for: currentMonth, userId: userId)
                habitVM.fetchHabits(for: userId) // Ensure habits are fetched.
            }
        }
    }
    
    // MARK: - Monthly Priorities Section
    private var prioritiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Monthly Priorities")
                    .font(.headline)
                    .foregroundColor(accentColor)
                Spacer()
                Button(action: {
                    addNewMonthlyPriority()
                }) {
                    Image(systemName: "plus.circle")
                        .foregroundColor(accentColor)
                }
            }
            if let schedule = viewModel.schedule {
                let bindingPriorities = Binding<[MonthlyPriority]>(
                    get: { schedule.monthlyPriorities },
                    set: { newValue in
                        var updatedSchedule = schedule
                        updatedSchedule.monthlyPriorities = newValue
                        viewModel.schedule = updatedSchedule
                        viewModel.updateMonthSchedule()
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
                                viewModel.updateMonthSchedule()
                            }
                        if bindingPriorities.wrappedValue.count > 1 {
                            Button(action: {
                                bindingPriorities.wrappedValue.removeAll { $0.id == priority.id }
                                viewModel.updateMonthSchedule()
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            } else {
                Text("Loading monthly priorities...")
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }
    
    // MARK: - Calendar Section
    private var calendarSection: some View {
        CalendarView(
            currentMonth: $currentMonth,
            accountCreationDate: accountCreationDate,
            onDaySelected: { day in
                if day <= Date() {
                    selectedDay = day
                    showDaySummary = true
                }
            }
        )
        .onChange(of: currentMonth) { newMonth in
            if let userId = session.userModel?.id {
                viewModel.loadMonthSchedule(for: newMonth, userId: userId)
            }
        }
    }
    
    // Convert the schedule's dayCompletions (stored as [String: Double]) into [Date: Double]
    private func dayCompletionMap() -> [Date: Double] {
        guard let schedule = viewModel.schedule else { return [:] }
        var dict: [Date: Double] = [:]
        for (dayKey, fraction) in schedule.dayCompletions {
            if let date = parseDayKey(dayKey) {
                dict[date] = fraction
            }
        }
        return dict
    }
    
    private func parseDayKey(_ key: String) -> Date? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: key)
    }
    
    private func addNewMonthlyPriority() {
        guard var schedule = viewModel.schedule else { return }
        let newPriority = MonthlyPriority(id: UUID(), title: "New Priority", progress: 0.0)
        schedule.monthlyPriorities.append(newPriority)
        viewModel.schedule = schedule
        viewModel.updateMonthSchedule()
    }
}



// MARK: - Calendar View
struct CalendarView: View {
    @Binding var currentMonth: Date
    let accountCreationDate: Date
    var onDaySelected: (Date) -> Void = { _ in }
    
    @EnvironmentObject var habitVM: HabitViewModel  // Use the user's habits
    
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        VStack {
            // Month header with navigation and overall average completion percentage.
            HStack {
                if canGoBack() {
                    Button(action: {
                        if let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) {
                            currentMonth = prevMonth
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                    }
                }
                
                Spacer()
                
                let averageCompletion = computeAverageCompletion()
                Text("\(monthYearString(from: currentMonth)) - (\(Int(averageCompletion * 100))%)")
                    .foregroundColor(.white)
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    if let nextMonth = Calendar.current.date(byAdding: .month, value: 1, to: currentMonth) {
                        currentMonth = nextMonth
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.3))
            .cornerRadius(8)
            
            Spacer()
            
            // Weekday headers.
            HStack {
                ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid.
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(generateDays(), id: \.self) { date in
                    if let date = date {
                        if date > Date() {
                            // Future dates.
                            Text(dayString(from: date))
                                .font(.caption2)
                                .frame(maxWidth: .infinity, minHeight: 30)
                                .foregroundColor(.white)
                                .background(Color.gray)
                                .cornerRadius(4)
                        } else {
                            let normalizedDate = Calendar.current.startOfDay(for: date)
                            let completion = completionForDay(normalizedDate)
                            let bgColor: Color = {
                                if completion == 1.0 {
                                    return Color.green.opacity(0.6)
                                } else if completion > 0 {
                                    return Color.yellow.opacity(0.6)
                                } else {
                                    return Color.red.opacity(0.6)
                                }
                            }()
                            Text(dayString(from: date))
                                .font(.caption2)
                                .frame(maxWidth: .infinity, minHeight: 30)
                                .foregroundColor(.white)
                                .background(bgColor)
                                .cornerRadius(4)
                                .onTapGesture {
                                    onDaySelected(date)
                                }
                        }
                    } else {
                        Text("")
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    /// Computes the fraction of habits completed for a given day.
    private func completionForDay(_ day: Date) -> Double {
        let calendar = Calendar.current
        let normalizedDay = calendar.startOfDay(for: day)
        
        // For any day, count habits that have a record with a value > 0.
        let completed = habitVM.habits.filter { habit in
            habit.dailyRecords.contains { record in
                calendar.isDate(record.date, inSameDayAs: normalizedDay) && ((record.value ?? 0) > 0)
            }
        }.count
        let total = habitVM.habits.count
        return total > 0 ? Double(completed) / Double(total) : 0.0
    }
    
    private func computeAverageCompletion() -> Double {
        let days = generateDays().compactMap { $0 }
        guard !days.isEmpty else { return 0 }
        let total = days.reduce(0) { (sum, day) -> Double in
            return sum + completionForDay(day)
        }
        return total / Double(days.count)
    }
    
    private func canGoBack() -> Bool {
        guard let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) else { return false }
        return prevMonth >= startOfMonth(for: accountCreationDate)
    }
    
    private func startOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }
    
    private func monthYearString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: date)
    }
    
    private func dayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func generateDays() -> [Date?] {
        var days: [Date?] = []
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else { return days }
        let firstDay = calendar.startOfDay(for: monthInterval.start)
        let weekday = calendar.component(.weekday, from: firstDay)
        for _ in 1..<weekday {
            days.append(nil)
        }
        var date = firstDay
        while date < monthInterval.end {
            days.append(date)
            if let next = calendar.date(byAdding: .day, value: 1, to: date) {
                date = next
            } else { break }
        }
        return days
    }
}
// MARK: - Day Summary View
struct DaySummaryView: View {
    let day: Date
    // Use a binding so changes are reflected in the parent view.
    @Binding var habits: [Habit]
    let onClose: () -> Void

    @EnvironmentObject var viewModel: HabitViewModel
    private var calendar: Calendar { Calendar.current }

    // New state properties for the metric input overlay.
    @State private var showMetricInput: Bool = false
    @State private var metricInput: String = ""
    @State private var habitBeingUpdated: Habit? = nil

    // Compute the number of habits completed on the given day.
    private var finishedCount: Int {
        habits.filter { habit in
            calendar.isDateCompleted(habit: habit, for: day)
        }.count
    }
    
    private var totalCount: Int {
        habits.count
    }
    
    var body: some View {
        ZStack {
            VStack(spacing: 16) {
                Text("Summary for \(formattedDate(day))")
                    .font(.headline)
                    .foregroundColor(.white)
                
                // Horizontal Progress Bar Section
                VStack(alignment: .leading, spacing: 4) {
                    ProgressView(value: Double(finishedCount), total: Double(totalCount))
                        .progressViewStyle(LinearProgressViewStyle(tint: progressColor()))
                        .padding(.bottom, 4)
                    Text("Finished \(finishedCount) of \(totalCount) habits")
                        .font(.subheadline)
                        .foregroundColor(progressColor())
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                
                // List of habits with toggles.
                VStack(alignment: .leading, spacing: 8) {
                    ForEach($habits) { $habit in
                        HStack {
                            Toggle(isOn: bindingForHabitCompletion(for: habit)) {
                                Text(habit.title)
                                    .foregroundColor(.white)
                            }
                            .toggleStyle(SwitchToggleStyle(tint: .green))
                        }
                        .padding(.vertical, 4)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                
                // Close Button
                Button("Close Summary") {
                    onClose()
                }
                .font(.headline)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.8))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .padding()
            .background(Color.black)
            .cornerRadius(12)
            .shadow(radius: 10)
            
            // Overlay the metric input if needed.
            if showMetricInput {
                metricInputOverlay
                    .transition(.opacity)
            }
        }
    }
    
    // MARK: - Helper Functions
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    private func progressColor() -> Color {
        if totalCount == 0 { return .red }
        if finishedCount == totalCount {
            return .green
        } else if finishedCount > 0 {
            return .yellow
        } else {
            return .red
        }
    }
    
    // Creates a binding for a habit's completion status for the given day.
    private func bindingForHabitCompletion(for habit: Habit) -> Binding<Bool> {
        Binding<Bool>(
            get: {
                calendar.isDateCompleted(habit: habit, for: day)
            },
            set: { newValue in
                if newValue {
                    // When toggled on, present the metric input overlay.
                    if let index = habits.firstIndex(where: { $0.id == habit.id }) {
                        habitBeingUpdated = habits[index]
                        showMetricInput = true
                    }
                } else {
                    // When toggled off, remove all records for that day.
                    if let index = habits.firstIndex(where: { $0.id == habit.id }) {
                        var updatedHabit = habits[index]
                        updatedHabit.dailyRecords.removeAll { record in
                            calendar.isDate(record.date, inSameDayAs: day)
                        }
                        habits[index] = updatedHabit
                        viewModel.updateHabit(updatedHabit)
                    }
                }
            }
        )
    }
    
    // MARK: - Metric Input Overlay
    private var metricInputOverlay: some View {
        let prompt = metricPrompt()
        return VStack(spacing: 16) {
            Text(prompt)
                .font(.headline)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            TextField("Enter a number", text: $metricInput)
                .keyboardType(.numberPad)
                .padding()
                .background(Color.white.opacity(0.2))
                .cornerRadius(8)
                .foregroundColor(.white)
            if !metricInput.isEmpty {
                if let habit = habitBeingUpdated, habit.metricType.isCompletedMetric() {
                    if metricInput != "0" && metricInput != "1" {
                        Text("Please enter either 0 (No) or 1 (Yes)")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                } else if Int(metricInput) == nil {
                    Text("Please enter a valid number")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
            HStack {
                Button("Cancel") {
                    withAnimation {
                        showMetricInput = false
                        metricInput = ""
                        habitBeingUpdated = nil
                    }
                }
                .foregroundColor(.red)
                Spacer()
                Button("Save") {
                    if let metricValue = Int(metricInput),
                       let habit = habitBeingUpdated,
                       let index = habits.firstIndex(where: { $0.id == habit.id }) {
                        var updatedHabit = habits[index]
                        // Append a new record for this day.
                        updatedHabit.dailyRecords.append(HabitRecord(date: day, value: Double(metricValue)))
                        habits[index] = updatedHabit
                        viewModel.updateHabit(updatedHabit)
                        withAnimation {
                            showMetricInput = false
                            metricInput = ""
                            habitBeingUpdated = nil
                        }
                    }
                }
                .disabled({
                    if let habit = habitBeingUpdated, habit.metricType.isCompletedMetric() {
                        return !(metricInput == "0" || metricInput == "1")
                    } else {
                        return Int(metricInput) == nil
                    }
                }())
                .foregroundColor(.green)
            }
        }
        .padding()
        .frame(width: 300)
        .background(Color.black.opacity(0.9))
        .cornerRadius(12)
        .shadow(radius: 8)
    }
    
    // Helper function for the dynamic metric prompt.
    private func metricPrompt() -> String {
        if let habit = habitBeingUpdated {
            switch habit.metricType {
            case .predefined(let value):
                if value.lowercased().contains("minute") {
                    return "How many minutes did you meditate this day?"
                } else if value.lowercased().contains("miles") {
                    return "How many miles did you run this day?"
                } else if value.lowercased().contains("pages") {
                    return "How many pages did you read this day?"
                } else if value.lowercased().contains("reps") {
                    return "How many reps did you complete this day?"
                } else if value.lowercased().contains("steps") {
                    return "How many steps did you take this day?"
                } else if value.lowercased().contains("calories") {
                    return "How many calories did you burn/consume this day?"
                } else if value.lowercased().contains("hours") {
                    return "How many hours did you sleep this day?"
                } else if value.lowercased().contains("completed") {
                    return "Were you able to complete the task? (Enter 1 for Yes, 0 for No)"
                } else {
                    return "Enter this day's \(value.lowercased()) value:"
                }
            case .custom(let customValue):
                return "Enter this day's \(customValue.lowercased()) value:"
            }
        }
        return "Enter a metric value:"
    }
}

// MARK: - Calendar Extension for Habit Completion Check
extension Calendar {
    func isDateCompleted(habit: Habit, for day: Date) -> Bool {
        return habit.dailyRecords.contains { record in
            self.isDate(record.date, inSameDayAs: day) && ((record.value ?? 0) > 0)
        }
    }
}
// MARK: - Preview
struct SchedulerView_Previews: PreviewProvider {
    static var previews: some View {
        SchedulerView()
            .environmentObject(SessionStore()) // Ensure your SessionStore is provided.
    }
}
