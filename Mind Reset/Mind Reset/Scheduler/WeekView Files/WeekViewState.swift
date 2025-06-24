//  WeekViewState.swift
//  Mind Reset
//
//  Keeps track of the user’s “Week begins on” history and computes
//  the correct start-of-week for any date.
//  Created: 11 Apr 2025  –  Updated: 24 Jun 2025

import SwiftUI

// MARK: – App-wide notification keys
extension Notification.Name {
    /// Posted right after the user chooses a different “Week begins on” day.
    static let weekStartChanged = Notification.Name("weekStartChanged")
}

// MARK: – Model for an individual change
private struct WeekStartChange: Codable {
    let date:  Date   // start-of-day when this setting became active
    let index: Int    // 0 = Sun … 6 = Sat
}

final class WeekViewState: ObservableObject {

    // ───── Public, observable state ────
    @Published var currentWeekStart: Date
    @Published var weekOffset: Int = 0          // 0 = this week, -1 = prev …

    // ───── Init ────
    private var observer: NSObjectProtocol?

    init() {

        // 1️⃣ One-time migration: seed history if missing
        Self.migrateLegacyKeysIfNeeded()

        // 2️⃣ Anchor for “this week” based on the **current** preference
        currentWeekStart = Self.startOfWeek(for: Date())

        // 3️⃣ Listen for runtime changes
        observer = NotificationCenter.default.addObserver(
            forName: .weekStartChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.currentWeekStart = Self.startOfWeek(for: Date())
        }
    }

    deinit { if let o = observer { NotificationCenter.default.removeObserver(o) } }

    // ───── API ────
    /// Start-of-week for *date*, using the preference that was active **at that date**.
    static func startOfWeek(for date: Date) -> Date {
        let idx = latestChange(beforeOrOn: date).index        // 0…6
        var cal = Calendar.current;  cal.firstWeekday = idx + 1
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return cal.date(from: comps) ?? date
    }

    /// Anchor one week earlier than *date* (respecting the rule for that earlier week).
    static func previousWeekStart(from date: Date) -> Date {
            let sevenDaysBack = Calendar.current.date(byAdding: .day, value: -7, to: date)!
            return startOfWeek(for: sevenDaysBack)
        }
    static func nextWeekStart(from date: Date) -> Date {
            let sevenDaysAhead = Calendar.current.date(byAdding: .day, value: 7, to: date)!
            return startOfWeek(for: sevenDaysAhead)
        }

    // MARK: – Persistent history
    private static let storeKey = "weekStartChanges"

    /// All recorded changes, sorted ascending by date.
    private static func loadHistory() -> [WeekStartChange] {
        guard let data = UserDefaults.standard.data(forKey: storeKey),
              let arr  = try? JSONDecoder().decode([WeekStartChange].self, from: data)
        else { return [] }
        return arr.sorted { $0.date < $1.date }
    }

    private static func saveHistory(_ arr: [WeekStartChange]) {
        if let data = try? JSONEncoder().encode(arr) {
            UserDefaults.standard.set(data, forKey: storeKey)
        }
    }

    /// Most-recent change whose `date` ≤ *date*.
    private static func latestChange(beforeOrOn date: Date) -> WeekStartChange {
        let day0 = Calendar.current.startOfDay(for: date)
        let hist = loadHistory()
        return hist.last(where: { $0.date <= day0 })
            ?? WeekStartChange(date: .distantPast, index: 0)   // default Sunday
    }

    // ───── Migration from legacy single-value keys ────
    private static func migrateLegacyKeysIfNeeded() {
        if UserDefaults.standard.object(forKey: storeKey) != nil { return }

        let legacy = UserDefaults.standard.integer(forKey: "weekStartIndex") // 0…6
        let seed   = WeekStartChange(date: .distantPast, index: legacy)
        saveHistory([seed])

        // Clean up old keys (optional)
        UserDefaults.standard.removeObject(forKey: "oldWeekStartIndex")
        UserDefaults.standard.removeObject(forKey: "weekStartChangeDate")
    }

    // ───── Called by Settings screen ────
    /// Append a new change and broadcast.
    static func appendChange(newIndex: Int) {
        var hist = loadHistory()
        let today0 = Calendar.current.startOfDay(for: Date())
        hist.append(WeekStartChange(date: today0, index: newIndex))
        saveHistory(hist)
        NotificationCenter.default.post(name: .weekStartChanged, object: nil)
    }
}
