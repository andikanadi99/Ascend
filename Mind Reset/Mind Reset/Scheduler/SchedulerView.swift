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

    let accentCyan = Color(red: 0, green: 1, blue: 1)

    // Array of new greeting messages.
    private let greetings = [
        "Welcome back! Let’s make today productive.",
        "Welcome back! Every moment counts.",
        "Welcome back! Focus on your progress.",
        "Welcome back! Today is a new chance to excel.",
        "Welcome back! Keep pushing forward."
    ]

    // Productivity & encouragement quotes.
    private let quotes = [
        "Small daily steps lead to big achievements.",
        "Discipline is choosing between what you want now and what you want most.",
        "Focus on consistency, not perfection.",
        "Make progress one day at a time.",
        "You don’t have to be extreme—just consistent.",
        "Productivity grows when you prioritize and persist.",
        "Success is a few simple disciplines practiced every day.",
        "Every little victory counts toward the bigger goal.",
        "A focused mind can conquer any goal.",
        "Every day is a chance to improve."
    ]

    private var dailyGreeting: String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return greetings[(dayOfYear - 1) % greetings.count]
    }

    private var dailyQuote: String {
        let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 1
        return quotes[(dayOfYear - 1) % quotes.count]
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack {
                // Top banner
                VStack(alignment: .leading, spacing: 8) {
                    Text(dailyGreeting)
                        .font(.title).fontWeight(.heavy)
                        .foregroundColor(.white)
                        .shadow(color: .white.opacity(0.8), radius: 4)

                    Text(dailyQuote)
                        .font(.subheadline)
                        .foregroundColor(accentCyan)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.top, 30)
                .padding(.bottom, 20)

                // Segmented picker
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
                        .frame(height: 4)
                        .padding(.horizontal, 10)
                }

                // Content area
                Group {
                        switch selectedTab {
                        case .day:
                            DayView()
                        case .week:
                            WeekView(accentColor: accentCyan)
                            .environmentObject(session)
                        case .month:
                            if let accountCreationDate = session.userModel?.createdAt {
                                MonthView(accentColor: accentCyan, accountCreationDate: accountCreationDate)
                            } else {
                                MonthView(accentColor: accentCyan, accountCreationDate: Date())
                            }
                        }
                    }
                    .padding()

                Spacer()
            }
        }
    }
}


// MARK: - Scheduler Tab Options
enum SchedulerTab: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
}

// MARK: - Preview
struct SchedulerView_Previews: PreviewProvider {
    static var previews: some View {
        SchedulerView()
            .environmentObject(SessionStore())
    }
}
