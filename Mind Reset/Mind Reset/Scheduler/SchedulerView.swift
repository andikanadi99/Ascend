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
    // Sample time blocks – later these can come from your task model.
    @State private var tasks: [TimeBlock] = [
        TimeBlock(time: "7:00 AM", task: "Morning Meditation"),
        TimeBlock(time: "8:00 AM", task: "Breakfast & Planning"),
        TimeBlock(time: "9:00 AM", task: "Focused Work"),
        TimeBlock(time: "11:00 AM", task: "Mini-Break (Stretch)"),
        TimeBlock(time: "12:00 PM", task: "Lunch Break"),
        TimeBlock(time: "1:00 PM", task: "Reading"),
        TimeBlock(time: "3:00 PM", task: "Power Nap"),
        TimeBlock(time: "6:00 PM", task: "Evening Walk")
    ]
    
    // “Today’s Top Priority” text.
    @State private var topPriority: String = "Define Your One Thing"
    
    // Today's date string.
    private var todayString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: Date())
    }
    
    var body: some View {
        // Wrap the entire day view in a ScrollView so that the user can scroll.
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // "Today's Top Priority" card.
                VStack(alignment: .leading, spacing: 4) {
                    Text("Today's Top Priority")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.accentColor)
                    TextField("What matters most today?", text: $topPriority)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding()
                .background(Color.gray.opacity(0.3))
                .cornerRadius(8)
                
                // Header with day name and full date.
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Daily Intentions")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text(todayString)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // List of time blocks.
                ForEach(tasks) { block in
                    HStack {
                        Text(block.time)
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 80, alignment: .leading)
                        Text(block.task)
                            .foregroundColor(.white)
                        Spacer()
                        Button(action: {
                            // Action to edit or add a reminder for the task.
                        }) {
                            Image(systemName: "pencil")
                                .foregroundColor(.accentColor)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

struct TimeBlock: Identifiable {
    let id = UUID()
    var time: String
    var task: String
}

// MARK: - Week View ("Your Weekly Blueprint")
struct WeekView: View {
    let accentColor: Color
    
    // Sample weekly key intentions.
    @State private var weeklyPriority: String = "Define 1–2 key intentions for this week"
    
    // Sample daily routines.
    @State private var dailyIntentions: [String: String] = [
        "Sun": "Rest & Reflect",
        "Mon": "Morning Meditation",
        "Tue": "Focused Work",
        "Wed": "Exercise & Read",
        "Thu": "Creative Session",
        "Fri": "Networking",
        "Sat": "Family Time"
    ]
    
    // Dummy trend data for a mini graph.
    @State private var trendData: [CGFloat] = [1, 2, 3, 2, 4, 3, 5]
    
    // Routine setup (wake/sleep times).
    @State private var wakeUpTime: Date = Date()
    @State private var sleepTime: Date = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Top section for weekly priority.
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Weekly Blueprint")
                    .font(.title2)
                    .foregroundColor(.white)
                TextField("Enter your key intention(s) for this week", text: $weeklyPriority)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.trailing)
            }
            .padding()
            .background(Color.gray.opacity(0.3))
            .cornerRadius(8)
            
            // Routine setup panel.
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Wake-Up:")
                        .foregroundColor(.white)
                    DatePicker("", selection: $wakeUpTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .accentColor(accentColor)
                    Spacer()
                    Text("Sleep:")
                        .foregroundColor(.white)
                    DatePicker("", selection: $sleepTime, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .accentColor(accentColor)
                }
                .padding(.vertical, 4)
                
                HStack {
                    Button("Yes") {
                        // Accept the default routine.
                    }
                    .buttonStyle(RoutineButtonStyle(accentColor: accentColor))
                    
                    Button("Random") {
                        // Generate a suggestion based on past routines.
                    }
                    .buttonStyle(RoutineButtonStyle(accentColor: accentColor))
                    
                    Button("Change Time") {
                        // Allow manual time entry.
                    }
                    .buttonStyle(RoutineButtonStyle(accentColor: accentColor))
                }
            }
            .padding()
            .background(Color.gray.opacity(0.3))
            .cornerRadius(8)
            
            // Daily summary cards.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                        VStack(spacing: 8) {
                            Text(day)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(dailyIntentions[day] ?? "")
                                .font(.caption)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .frame(width: 80)
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
            }
            
            // Mini graph for consistency trend.
            Text("Consistency Trend")
                .font(.caption)
                .foregroundColor(.white)
            GeometryReader { geo in
                Path { path in
                    let width = geo.size.width
                    let height = geo.size.height
                    let step = width / CGFloat(max(trendData.count - 1, 1))
                    for (index, value) in trendData.enumerated() {
                        let x = CGFloat(index) * step
                        let y = height - (value / 5 * height)
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(Color.white, lineWidth: 2)
            }
            .frame(height: 100)
            
            Spacer()
        }
        .padding()
    }
}

struct RoutineButtonStyle: ButtonStyle {
    let accentColor: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 6)
            .padding(.horizontal, 12)
            .background(accentColor.opacity(configuration.isPressed ? 0.7 : 1))
            .foregroundColor(.black)
            .cornerRadius(6)
    }
}

// MARK: - Month View ("Your Mindful Month")
struct MonthView: View {
    let accentColor: Color
    let accountCreationDate: Date  // Account creation date from UserModel
    
    @State private var currentMonth: Date = Date()
    // Dynamic list for monthly priorities – defaults to one priority; user can add more.
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
                    // '+' button to add a new priority.
                    Button(action: {
                        monthlyPriorities.append(MonthlyPriority(id: UUID(), title: "New Priority", progress: 0))
                    }) {
                        Image(systemName: "plus.circle")
                            .foregroundColor(.accentColor)
                    }
                }
                ForEach($monthlyPriorities) { $priority in
                    HStack {
                        TextField("Priority", text: $priority.title)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
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
                // Only allow summary for past or current days.
                if day <= Date() {
                    selectedDay = day
                    showDaySummary = true
                }
            }
            .frame(height: 300)
            .onAppear {
                // For demonstration, assign random completion percentages for each day.
                let calendar = Calendar.current
                for day in generateDemoDays(for: currentMonth) {
                    dayCompletion[day] = Double.random(in: 0...1)
                }
            }
            
            Spacer()
        }
        .padding()
        // Instead of a full-screen cover, use an overlay that shows the small summary box
        .overlay(
            Group {
                if showDaySummary, let day = selectedDay {
                    // The overlay is centered on the screen.
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
                    .background(Color.black)
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
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
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
            .padding(.horizontal)
            
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
                            // Future dates are greyed out.
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
                        // Placeholder for empty cells.
                        Text("")
                            .frame(maxWidth: .infinity, minHeight: 30)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
    
    // Only allow going back if the previous month is not before the account's creation month.
    private func canGoBack() -> Bool {
        guard let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) else { return false }
        return prevMonth >= startOfMonth(for: accountCreationDate)
    }
    
    // Returns the start of the month for a given date.
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
    
    // Generate days for the current month including leading empty placeholders.
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
            Text("Habits: Finished 3 / 5") // Placeholder – replace with real data.
                .foregroundColor(.white)
            .padding()
            .foregroundColor(.white)
            .cornerRadius(8)
        }
        .padding()
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
            .environmentObject(SessionStore()) // Provide your session object.
    }
}
