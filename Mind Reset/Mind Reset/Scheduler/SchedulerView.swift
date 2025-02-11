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
                        .padding(.top)
                    
                    // Updated tab header with a small divider
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
                            // Use the account creation date from the user model.
                            if let accountCreationDate = session.userModel?.createdAt {
                                MonthView(accentColor: .accentColor, accountCreationDate: accountCreationDate)
                            } else {
                                // Fallback in case the user model is not available.
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
    // For demonstration, we use some sample time blocks.
    @State private var tasks: [TimeBlock] = [
        TimeBlock(time: "7:00 AM", task: "Morning Meditation"),
        TimeBlock(time: "8:00 AM", task: "Breakfast & Planning"),
        TimeBlock(time: "9:00 AM", task: "Focused Work"),
        TimeBlock(time: "12:00 PM", task: "Lunch Break"),
        TimeBlock(time: "1:00 PM", task: "Reading"),
        TimeBlock(time: "6:00 PM", task: "Evening Walk")
    ]
    
    // Today's date string
    private var todayString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: Date())
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header with the day name and date
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Daily Intentions")
                    .font(.title2)
                    .foregroundColor(.white)
                Text(todayString)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            // List of time blocks (each could be tapped to add/edit tasks)
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
                        // Action to edit the task or add a reminder.
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

struct TimeBlock: Identifiable {
    let id = UUID()
    var time: String
    var task: String
}

// MARK: - Week View ("Your Weekly Blueprint")
struct WeekView: View {
    let accentColor: Color
    
    // Sample daily routines and a simple trend array.
    @State private var dailyIntentions: [String: String] = [
        "Sun": "Rest & Reflect",
        "Mon": "Morning Meditation",
        "Tue": "Focused Work",
        "Wed": "Exercise & Read",
        "Thu": "Creative Session",
        "Fri": "Networking",
        "Sat": "Family Time"
    ]
    @State private var trendData: [CGFloat] = [1, 2, 3, 2, 4, 3, 5]
    
    // For the routine setup panel
    @State private var wakeUpTime: Date = Date()
    @State private var sleepTime: Date = Date()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header: Mental Inventory & Routine Setup
            VStack(alignment: .leading, spacing: 8) {
                Text("Your Weekly Blueprint")
                    .font(.title2)
                    .foregroundColor(.white)
                Text("List your key intentions for the week:")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                TextField("e.g. Be mindful in meetings, practice gratitude", text: .constant(""))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.trailing)
                
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
                        // Generate a suggested routine.
                    }
                    .buttonStyle(RoutineButtonStyle(accentColor: accentColor))
                    
                    Button("Change Time") {
                        // Allow manual entry.
                    }
                    .buttonStyle(RoutineButtonStyle(accentColor: accentColor))
                }
            }
            
            // Daily summary cards for each day.
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
            
            // Consistency trend mini graph
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
    @State private var yearlyGoal: Int = 12
    @State private var currentProgress: Int = 5
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your Mindful Month")
                .font(.title2)
                .foregroundColor(.white)
            
            // Full calendar view: pass the accountCreationDate to restrict navigation.
            CalendarView(currentMonth: $currentMonth, accountCreationDate: accountCreationDate)
                .frame(height: 300)
            
            // Yearly goal section.
            VStack(alignment: .leading, spacing: 8) {
                Text("Yearly Goal: Complete \(yearlyGoal) mindful activities")
                    .foregroundColor(.white)
                    .font(.headline)
                ProgressView(value: Float(currentProgress), total: Float(yearlyGoal))
                    .progressViewStyle(LinearProgressViewStyle(tint: accentColor))
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Calendar View
struct CalendarView: View {
    @Binding var currentMonth: Date
    let accountCreationDate: Date
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        VStack {
            // Month header with navigation.
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
                
                Text(monthYearString(from: currentMonth))
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
            
            // Calendar grid.
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(generateDays(), id: \.self) { date in
                    Text(dayString(from: date))
                        .font(.caption2)
                        .frame(maxWidth: .infinity, minHeight: 30)
                        .foregroundColor(.white)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // Helper function to check if the user can go back.
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
    
    private func generateDays() -> [Date] {
        var dates: [Date] = []
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else { return dates }
        var date = calendar.startOfDay(for: monthInterval.start)
        while date < monthInterval.end {
            dates.append(date)
            guard let next = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = next
        }
        return dates
    }
}

// MARK: - Preview
struct SchedulerView_Previews: PreviewProvider {
    static var previews: some View {
        SchedulerView()
            .environmentObject(SessionStore()) // Make sure to provide your session object.
    }
}
