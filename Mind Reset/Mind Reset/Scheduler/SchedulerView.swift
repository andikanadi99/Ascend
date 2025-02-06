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
    // For switching between Day, Week, and Month views
    @State private var selectedTab: SchedulerTab = .day
    
    var body: some View {
        NavigationView {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack {
                    // Title
                    Text("Mindful Routine")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.top)
                    
                    // Updated tab header
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
                        
                        // Black divider
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
                            WeekView()
                        case .month:
                            MonthView()
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

// MARK: - Day View
struct DayView: View {
    // Sample time blocks for the day (could be replaced with your task model)
    @State private var tasks: [TimeBlock] = [
        TimeBlock(time: "7:00 AM", task: "Morning Meditation"),
        TimeBlock(time: "8:00 AM", task: "Breakfast & Planning"),
        TimeBlock(time: "9:00 AM", task: "Focused Work"),
        TimeBlock(time: "12:00 PM", task: "Lunch Break"),
        TimeBlock(time: "1:00 PM", task: "Reading"),
        TimeBlock(time: "6:00 PM", task: "Evening Walk")
    ]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Daily Routine")
                .font(.title2)
                .foregroundColor(.white)
            
            // A vertical list of time blocks
            ForEach(tasks) { block in
                HStack {
                    Text(block.time)
                        .font(.caption)
                        .foregroundColor(.white)
                        .frame(width: 80, alignment: .leading)
                    Text(block.task)
                        .foregroundColor(.white)
                    Spacer()
                    // An example button to edit the task.
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

struct TimeBlock: Identifiable {
    let id = UUID()
    var time: String
    var task: String
}

// MARK: - Week View
struct WeekView: View {
    // Sample data: a week of scheduled routines
    @State private var dailyRoutines: [String: String] = [
        "Sun": "Rest & Reflect",
        "Mon": "Morning Meditation",
        "Tue": "Focused Work",
        "Wed": "Exercise & Read",
        "Thu": "Creative Session",
        "Fri": "Networking",
        "Sat": "Family Time"
    ]
    
    // Dummy trend data for a mini graph
    @State private var trendData: [CGFloat] = [1, 2, 3, 2, 4, 3, 5]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Week View")
                .font(.title2)
                .foregroundColor(.white)
            
            // Display the routines for each day in a horizontal scroll.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"], id: \.self) { day in
                        VStack(spacing: 8) {
                            Text(day)
                                .font(.headline)
                                .foregroundColor(.white)
                            Text(dailyRoutines[day] ?? "")
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
            
            // A simple mini graph for trend visualization.
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
                        // Scale value to the view’s height (assumes trendData maximum is 5)
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

// MARK: - Month View
struct MonthView: View {
    // For simplicity, we use the built-in Calendar view style.
    @State private var currentMonth: Date = Date()
    
    // Example yearly goal and progress (e.g., 12 books to read in a year)
    @State private var yearlyGoal: Int = 12
    @State private var currentProgress: Int = 5
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Month View")
                .font(.title2)
                .foregroundColor(.white)
            
            // A placeholder for a calendar view.
            // In a complete app you might integrate a custom calendar component.
            CalendarView(currentMonth: $currentMonth)
                .frame(height: 300)
            
            // Yearly goal section.
            VStack(alignment: .leading) {
                Text("Yearly Goal: Read \(yearlyGoal) Books")
                    .foregroundColor(.white)
                    .font(.headline)
                ProgressView(value: Float(currentProgress), total: Float(yearlyGoal))
                    .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
            }
            .padding()
            .background(Color.gray.opacity(0.2))
            .cornerRadius(8)
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - Simple Calendar View (Placeholder)
// In a production app you might replace this with a full-featured calendar component.
struct CalendarView: View {
    @Binding var currentMonth: Date
    private let columns = Array(repeating: GridItem(.flexible()), count: 7)
    
    var body: some View {
        VStack {
            // Month header with navigation.
            HStack {
                Button(action: {
                    if let prevMonth = Calendar.current.date(byAdding: .month, value: -1, to: currentMonth) {
                        currentMonth = prevMonth
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.white)
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
                }
            }
            .padding(.horizontal)
        }
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
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth) else {
            return dates
        }
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
    }
}
