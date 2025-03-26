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
                
                // "Today's Top Priority" box
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
                    if viewModel.schedule != nil {
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
    
    // Week navigation state.
    @State private var currentWeekStart: Date = {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Week starts on Sunday
        let now = Date()
        let components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)
        return calendar.date(from: components) ?? now
    }()
    
    // Sample daily routines keyed by abbreviated weekday.
    @State private var dailyIntentions: [String: String] = [
        "Sun": "Rest & Reflect",
        "Mon": "Morning Meditation",
        "Tue": "Focused Work",
        "Wed": "Exercise & Read",
        "Thu": "Creative Session",
        "Fri": "Networking",
        "Sat": "Family Time"
    ]
    
    // A dictionary to hold each day’s to‑do list.
    @State private var dailyToDoLists: [String: [ToDoItem]] = [
        "Sun": [ToDoItem(id: UUID(), title: "Journal", isCompleted: false)],
        "Mon": [ToDoItem(id: UUID(), title: "Plan Day", isCompleted: false)],
        "Tue": [ToDoItem(id: UUID(), title: "Deep Work Session", isCompleted: false)],
        "Wed": [ToDoItem(id: UUID(), title: "Workout", isCompleted: false)],
        "Thu": [ToDoItem(id: UUID(), title: "Write Ideas", isCompleted: false)],
        "Fri": [ToDoItem(id: UUID(), title: "Catch Up", isCompleted: false)],
        "Sat": [ToDoItem(id: UUID(), title: "Family Time", isCompleted: false)]
    ]
    
    @State private var weeklyPriorities: [WeeklyPriority] = [
        WeeklyPriority(id: UUID(), title: "Weekly Goals", progress: 0.5)
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Weekly Priorities")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                    Spacer()
                    Button(action: {
                        weeklyPriorities.append(WeeklyPriority(id: UUID(), title: "New Priority", progress: 0))
                    }) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.accentColor)
                    }
                }
                ForEach($weeklyPriorities) { $priority in
                    HStack {
                        TextEditor(text: $priority.title)
                            .padding(8)
                            .frame(minHeight: 50)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)  // For iOS 16+
                            .cornerRadius(8)
                            .fixedSize(horizontal: false, vertical: true)
                        if weeklyPriorities.count > 1 {
                            Button(action: {
                                if let index = weeklyPriorities.firstIndex(where: { $0.id == priority.id }) {
                                    weeklyPriorities.remove(at: index)
                                }
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.3))
            .cornerRadius(8)
            // Week Navigation Header.
            WeekNavigationView(currentWeekStart: $currentWeekStart, accountCreationDate: session.userModel?.createdAt ?? Date())
            
            // Vertical scroll view for the full week.
            ScrollView(.vertical, showsIndicators: true) {
                VStack(spacing: 16) {
                    ForEach(weekDays(for: currentWeekStart), id: \.self) { day in
                        DayCardView(
                            day: day,
                            toDoItems: Binding(
                                get: { dailyToDoLists[shortDayKey(from: day)] ?? [] },
                                set: { dailyToDoLists[shortDayKey(from: day)] = $0 }
                            ),
                            intention: Binding(
                                get: { dailyIntentions[shortDayKey(from: day)] ?? "" },
                                set: { dailyIntentions[shortDayKey(from: day)] = $0 }
                            )
                        )
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal)
            }
            Spacer()
        }
        .padding()
    }
    
    // Helper: Compute the seven days of the week starting from currentWeekStart.
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
    
    // Helper: Returns abbreviated weekday key (e.g. "Sun") from a date.
    private func shortDayKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
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
                .frame(minHeight: 50) // Default minimal height; expands as needed.
                .background(.black)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)  // For iOS 16+
                .cornerRadius(8)
                
            
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
                    TextEditor(text: $item.title)
                        .padding(8)
                        .frame(minHeight: 50) // Default minimal height; expands as needed.
                        .background(.black)
                        .foregroundColor(.white)
                        .scrollContentBackground(.hidden)  // For iOS 16+
                        .cornerRadius(8)
                    Button(action: {
                        toDoItems.removeAll { $0.id == item.id }
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
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
    // Dynamic list for monthly priorities – default to one priority; user can add more.
    @State private var monthlyPriorities: [MonthlyPriority] = [
        MonthlyPriority(id: UUID(), title: "Write 5 blog posts", progress: 0.5)
    ]
    
    // State for the selected day to show a summary.
    @State private var selectedDay: Date? = nil
    @State private var showDaySummary: Bool = false
    
    // For demonstration, sample data for day completion percentages.
    @State private var dayCompletion: [Date: Double] = [:]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Dynamic Monthly Priorities Box.
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Monthly Priorities")
                        .font(.headline)
                        .foregroundColor(.accentColor)
                    Spacer()
                    Button(action: {
                        monthlyPriorities.append(MonthlyPriority(id: UUID(), title: "New Priority", progress: 0))
                    }) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.accentColor)
                    }
                }
                ForEach($monthlyPriorities) { $priority in
                    HStack {
                        TextEditor(text: $priority.title)
                            .padding(8)
                            .frame(minHeight: 50)
                            .background(Color.black)
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)  // For iOS 16+
                            .cornerRadius(8)
                            .fixedSize(horizontal: false, vertical: true)
                        if monthlyPriorities.count > 1 {
                            Button(action: {
                                if let index = monthlyPriorities.firstIndex(where: { $0.id == priority.id }) {
                                    monthlyPriorities.remove(at: index)
                                }
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.3))
            .cornerRadius(8)
            
            // Calendar view – navigation is restricted by the accountCreationDate.
            CalendarView(currentMonth: $currentMonth, accountCreationDate: accountCreationDate, dayCompletion: dayCompletion) { day in
                if day <= Date() {
                    selectedDay = day
                    showDaySummary = true
                }
            }
            .frame(height: 300)
            .onAppear {
                let calendar = Calendar.current
                for day in generateDemoDays(for: currentMonth) {
                    dayCompletion[day] = Double.random(in: 0...1)
                }
            }
            
            Spacer()
        }
        .padding()
        // Overlay a small pop-up summary in the center.
        .overlay(
            Group {
                if showDaySummary, let day = selectedDay {
                    VStack {
                        DaySummaryView(day: day, completionPercentage: dayCompletion[day] ?? 0)
                            .cornerRadius(12)
                        Button("Close Summary") {
                            withAnimation {
                                showDaySummary = false
                            }
                        }
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.gray)
                        .cornerRadius(8)
                    }
                    .frame(maxWidth: 300)
                    .padding()
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(12)
                    .transition(.opacity)
                }
            }
        )
    }
    
    // Helper for demo: generate all days for the current month (ignoring placeholders)
    private func generateDemoDays(for month: Date) -> [Date] {
        var dates: [Date] = []
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return dates }
        var date = calendar.startOfDay(for: monthInterval.start)
        while date < monthInterval.end {
            dates.append(date)
            if let next = calendar.date(byAdding: .day, value: 1, to: date) {
                date = next
            } else { break }
        }
        return dates
    }
}

struct MonthlyPriority: Identifiable {
    let id: UUID
    var title: String
    var progress: Double  // Value between 0 and 1
}

// MARK: - Calendar View
struct CalendarView: View {
    @Binding var currentMonth: Date
    let accountCreationDate: Date
    var dayCompletion: [Date: Double] = [:]
    var onDaySelected: (Date) -> Void = { _ in }
    
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        VStack {
            // Month header with navigation and overall completion percentage.
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
            
            // Calendar grid with placeholders.
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(generateDays(), id: \.self) { date in
                    if let date = date {
                        if date > Date() {
                            Text(dayString(from: date))
                                .font(.caption2)
                                .frame(maxWidth: .infinity, minHeight: 30)
                                .foregroundColor(.white)
                                .background(Color.gray)
                                .cornerRadius(4)
                        } else {
                            let completion = dayCompletion[date] ?? 0
                            let bgColor: Color = {
                                if completion >= 0.8 {
                                    return Color.green.opacity(0.6)
                                } else if completion >= 0.5 {
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
    
    private func computeAverageCompletion() -> Double {
        let days = generateDays().compactMap { $0 }
        guard !days.isEmpty else { return 0 }
        let total = days.reduce(0) { (sum, day) -> Double in
            return sum + (dayCompletion[day] ?? 0)
        }
        return total / Double(days.count)
    }
}

// MARK: - Day Summary View
struct DaySummaryView: View {
    let day: Date
    let completionPercentage: Double
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(spacing: 16) {
            Text("Summary for \(formattedDate(day))")
                .font(.headline)
                .foregroundColor(.white)
            Text("Completion: \(Int(completionPercentage * 100))%")
                .font(.title)
                .foregroundColor(completionPercentage >= 0.8 ? .green : (completionPercentage >= 0.5 ? .yellow : .red))
            Text("Habits: Finished 3 / 5")
                .foregroundColor(.white)
            Button("Close Summary") {
                presentationMode.wrappedValue.dismiss()
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
        .background(Color.black)
        .cornerRadius(12)
        .shadow(radius: 10)
    }
    
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Preview
struct SchedulerView_Previews: PreviewProvider {
    static var previews: some View {
        SchedulerView()
            .environmentObject(SessionStore()) // Ensure your SessionStore is provided.
    }
}
