import SwiftUI
import UserNotifications

struct NotificationPreferencesView: View {
    // Persist toggles
    @AppStorage("dailyNotificationsEnabled") private var dailyNotificationsEnabled: Bool = true
    @AppStorage("weeklyNotificationsEnabled") private var weeklyNotificationsEnabled: Bool = true

    // Persist chosen times (we store full Dates; we only care about the time components)
    @AppStorage("dailyNotificationTime") private var dailyNotificationTime: Date = defaultDailyNotificationTime()
    @AppStorage("weeklyNotificationTime") private var weeklyNotificationTime: Date = defaultWeeklyNotificationTime()

    private let accentCyan = Color(red: 0, green: 1, blue: 1)

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    // ─── Daily Reminders ─────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        Toggle(isOn: $dailyNotificationsEnabled) {
                            VStack(alignment: .leading) {
                                Text("Daily Reminders")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("Receive a daily reminder to check your tasks.")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .toggleStyle(SwitchToggleStyle(tint: accentCyan))

                        if dailyNotificationsEnabled {
                            DatePicker(
                                "Reminder Time",
                                selection: $dailyNotificationTime,
                                displayedComponents: .hourAndMinute
                            )
                            .labelsHidden()
                            .datePickerStyle(WheelDatePickerStyle())
                            .accentColor(accentCyan)

                            Text("Next daily reminder: \(formattedDateTime(nextDailyNotification()))")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))

                            Button("Test Now") {
                                triggerTestDaily()
                            }
                            .buttonStyle(PrimaryButtonStyle(color: accentCyan))
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)

                    // ─── Weekly Summary ─────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
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
                            DatePicker(
                                "Summary Time",
                                selection: $weeklyNotificationTime,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .labelsHidden()
                            .datePickerStyle(WheelDatePickerStyle())
                            .accentColor(accentCyan)

                            Text("Next weekly summary: \(formattedDateTime(nextWeeklyNotification()))")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))

                            Button("Test Now") {
                                triggerTestWeekly()
                            }
                            .buttonStyle(PrimaryButtonStyle(color: accentCyan))
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.2))
                    .cornerRadius(12)

                    Spacer()
                }
                .padding()
            }
        }
        .navigationTitle("Notifications")
        .preferredColorScheme(.dark)
        .onAppear {
            requestNotificationPermission()
            updateDailyNotification()
            updateWeeklyNotification()
        }
        .onChange(of: dailyNotificationsEnabled) { _ in updateDailyNotification() }
        .onChange(of: dailyNotificationTime)    { _ in updateDailyNotification() }
        .onChange(of: weeklyNotificationsEnabled){ _ in updateWeeklyNotification() }
        .onChange(of: weeklyNotificationTime)   { _ in updateWeeklyNotification() }
    }

    // MARK: - Request Permission
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if !granted {
                print("⚠️ Notifications permission denied")
            }
        }
    }

    // MARK: - Daily Scheduling
    private func updateDailyNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily_reminder"])

        guard dailyNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Daily Reminder"
        content.body  = "Don't forget to review your tasks for today!"
        content.sound = .default

        let comps = Calendar.current.dateComponents([.hour, .minute], from: dailyNotificationTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let request = UNNotificationRequest(
            identifier: "daily_reminder",
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error = error {
                print("Error scheduling daily reminder:", error)
            }
        }
    }

    // MARK: - Weekly Scheduling
    private func updateWeeklyNotification() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["weekly_summary"])

        guard weeklyNotificationsEnabled else { return }

        let content = UNMutableNotificationContent()
        content.title = "Weekly Summary"
        content.body  = "Here's your weekly habit summary!"
        content.sound = .default

        let comps = Calendar.current.dateComponents([.weekday, .hour, .minute], from: weeklyNotificationTime)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)

        let request = UNNotificationRequest(
            identifier: "weekly_summary",
            content: content,
            trigger: trigger
        )
        center.add(request) { error in
            if let error = error {
                print("Error scheduling weekly summary:", error)
            }
        }
    }

    // MARK: - Test Notifications
    private func triggerTestDaily() {
        let content = UNMutableNotificationContent()
        content.title = "Test Daily Reminder"
        content.body  = "This is a test of your daily reminder!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "test_daily", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    private func triggerTestWeekly() {
        let content = UNMutableNotificationContent()
        content.title = "Test Weekly Summary"
        content.body  = "This is a test of your weekly summary!"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(identifier: "test_weekly", content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Helpers
    private func formattedDateTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f.string(from: date)
    }

    private func nextDailyNotification() -> Date {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.hour, .minute], from: dailyNotificationTime)
        guard let today = cal.date(bySettingHour: comps.hour!, minute: comps.minute!, second: 0, of: now) else {
            return now
        }
        return (today > now) ? today : cal.date(byAdding: .day, value: 1, to: today)!
    }

    private func nextWeeklyNotification() -> Date {
        let cal = Calendar.current
        let now = Date()
        let comps = cal.dateComponents([.weekday, .hour, .minute], from: weeklyNotificationTime)
        return cal.nextDate(after: now, matching: comps, matchingPolicy: .nextTimePreservingSmallerComponents) ?? now
    }
}

// MARK: - Default Times

fileprivate func defaultDailyNotificationTime() -> Date {
    var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
    comps.hour = 9
    comps.minute = 0
    comps.second = 0
    return Calendar.current.date(from: comps)!
}

fileprivate func defaultWeeklyNotificationTime() -> Date {
    let cal = Calendar.current
    let now = Date()
    let nextSunday = cal.nextDate(after: now, matching: DateComponents(weekday: 1), matchingPolicy: .nextTime) ?? now
    var comps = cal.dateComponents([.year, .month, .day], from: nextSunday)
    comps.hour = 10
    comps.minute = 0
    comps.second = 0
    return cal.date(from: comps)!
}

// MARK: - Button Style

private struct PrimaryButtonStyle: ButtonStyle {
    let color: Color
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(configuration.isPressed ? 0.7 : 1))
            .cornerRadius(8)
    }
}

