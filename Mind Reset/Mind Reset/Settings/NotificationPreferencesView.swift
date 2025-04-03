import SwiftUI

struct NotificationPreferencesView: View {
    // Persist toggles
    @AppStorage("dailyNotificationsEnabled") private var dailyNotificationsEnabled: Bool = true
    @AppStorage("weeklyNotificationsEnabled") private var weeklyNotificationsEnabled: Bool = true

    // Persist chosen times (we store full Dates; we only care about the time components)
    @AppStorage("dailyNotificationTime") private var dailyNotificationTime: Date = defaultDailyNotificationTime()
    @AppStorage("weeklyNotificationTime") private var weeklyNotificationTime: Date = defaultWeeklyNotificationTime()

    // Customize your accent color
    private let accentCyan = Color(red: 0, green: 1, blue: 1)

    var body: some View {
        NavigationView {
            ZStack {
                Color.black.ignoresSafeArea()
                // Wrap the content in a vertical ScrollView
                ScrollView {
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 20) {
                            // Daily Notification Section
                            Toggle(isOn: $dailyNotificationsEnabled) {
                                VStack(alignment: .leading) {
                                    Text("Daily Reminders")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Receive daily reminders to check your habits and complete your tasks.")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: accentCyan))
                            
                            if dailyNotificationsEnabled {
                                DatePicker("Select Reminder Time", selection: $dailyNotificationTime, displayedComponents: .hourAndMinute)
                                    .labelsHidden()
                                    .datePickerStyle(WheelDatePickerStyle())
                                    .accentColor(accentCyan)
                                Text("Next daily reminder: \(formattedDateTime(nextDailyNotification()))")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            // Weekly Notification Section
                            Toggle(isOn: $weeklyNotificationsEnabled) {
                                VStack(alignment: .leading) {
                                    Text("Weekly Summary")
                                        .font(.headline)
                                        .foregroundColor(.white)
                                    Text("Get a weekly summary of your habit progress.")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            .toggleStyle(SwitchToggleStyle(tint: accentCyan))
                            
                            if weeklyNotificationsEnabled {
                                DatePicker("Select Weekly Summary Time", selection: $weeklyNotificationTime, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .datePickerStyle(WheelDatePickerStyle())
                                    .accentColor(accentCyan)
                                Text("Next weekly summary: \(formattedDateTime(nextWeeklyNotification()))")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding()
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                        
                        Spacer()
                    }
                    .padding() // Outer padding for the VStack
                }
            }
        }
        
    }
    
    // MARK: - Helper Functions
    
    // Format date and time in a medium style.
    private func formattedDateTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Compute the next daily notification.
    private func nextDailyNotification() -> Date {
        let calendar = Calendar.current
        let now = Date()
        // Extract the time components from the stored dailyNotificationTime.
        let timeComponents = calendar.dateComponents([.hour, .minute, .second], from: dailyNotificationTime)
        if let todayNotification = calendar.date(bySettingHour: timeComponents.hour ?? 9,
                                                   minute: timeComponents.minute ?? 0,
                                                   second: timeComponents.second ?? 0,
                                                   of: now) {
            // If today's notification time hasn't passed yet, return it; otherwise, tomorrow's.
            if todayNotification > now {
                return todayNotification
            } else {
                return calendar.date(byAdding: .day, value: 1, to: todayNotification) ?? todayNotification
            }
        }
        return now
    }
    
    // Compute the next weekly notification.
    private func nextWeeklyNotification() -> Date {
        let calendar = Calendar.current
        let now = Date()
        // Use the stored weeklyNotificationTime as a reference.
        let components = calendar.dateComponents([.weekday, .hour, .minute, .second], from: weeklyNotificationTime)
        if let nextDate = calendar.nextDate(after: now, matching: components, matchingPolicy: .nextTimePreservingSmallerComponents) {
            return nextDate
        }
        return now
    }
}

// MARK: - Default Times

func defaultDailyNotificationTime() -> Date {
    let calendar = Calendar.current
    let now = Date()
    var components = calendar.dateComponents([.year, .month, .day], from: now)
    // Default daily reminder time: 9:00 AM.
    components.hour = 9
    components.minute = 0
    components.second = 0
    return calendar.date(from: components) ?? now
}

func defaultWeeklyNotificationTime() -> Date {
    let calendar = Calendar.current
    let now = Date()
    // Default weekly summary time: next Sunday at 10:00 AM.
    let nextSunday = calendar.nextDate(after: now, matching: DateComponents(weekday: 1), matchingPolicy: .nextTime) ?? now
    var components = calendar.dateComponents([.year, .month, .day], from: nextSunday)
    components.hour = 10
    components.minute = 0
    components.second = 0
    return calendar.date(from: components) ?? now
}

struct NotificationPreferencesView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationPreferencesView()
    }
}
