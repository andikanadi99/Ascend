// MonthViewModel.swift
// Mind Reset
//
// Optimised: background-queue decoding, shared Firestore, static formatters.
// Created by Andika Yudhatrisna on 3/27/25.

import Foundation
import FirebaseFirestore
import Combine
import FirebaseAuth

class MonthViewModel: ObservableObject {
    @Published var schedule: MonthSchedule?
    
    /// Holds each day’s array of TodayPriorities
    @Published var dayPriorityStorage: [Date:[TodayPriority]] = [:]
    /// Quick lookup of done/total for colouring the calendar
    @Published var dayPriorityStatus: [Date:(done: Int, total: Int)] = [:]

    private var cancellables = Set<AnyCancellable>()
    private let db = Firestore.firestore()
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Call this when you load the month schedule
    func loadMonthSchedule(for month: Date, userId: String) {
        // ← your existing month‐schedule loading…
        // then for each day in that month, fetch the DaySchedule document:

        let days = generateDays(in: month)
        for day in days {
            let key = Calendar.current.startOfDay(for: day)
            let docId = dateFormatter.string(from: key)
            db.collection("users")
              .document(userId)
              .collection("daySchedules")
              .document(docId)
              .getDocument(as: DaySchedule.self) { result in
                  DispatchQueue.main.async {
                    switch result {
                    case .success(let daySched):
                      self.dayPriorityStorage[key] = daySched.priorities
                      let done = daySched.priorities.filter { $0.isCompleted }.count
                      self.dayPriorityStatus[key] = (done: done, total: daySched.priorities.count)

                    case .failure:
                      // no doc ⇒ no priorities
                      self.dayPriorityStorage[key] = []
                      self.dayPriorityStatus[key] = (done: 0, total: 0)
                    }
                  }
              }
        }
    }

    /// Call this from your popup’s “Save” closure
    func saveDayPriorities(for date: Date, newPriorities: [TodayPriority]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let key = Calendar.current.startOfDay(for: date)
        let docId = dateFormatter.string(from: key)

        // Persist to Firestore
        try? db.collection("users")
            .document(uid)
            .collection("daySchedules")
            .document(docId)
            .setData(from: DaySchedule(
                id: docId,
                userId: uid,
                date: key,
                wakeUpTime: Date(),     // you’ll override only priorities
                sleepTime: Date(),
                priorities: newPriorities,
                timeBlocks: []
            ), merge: true)

        // Update local storage and status
        DispatchQueue.main.async {
            self.dayPriorityStorage[key] = newPriorities
            let done = newPriorities.filter { $0.isCompleted }.count
            self.dayPriorityStatus[key] = (done: done, total: newPriorities.count)
        }
    }
    
    //  Add this inside your MonthViewModel class
    //-----------------------------------------------------------------
    /// Persists the entire month document and refreshes the per-day status cache.
    func updateMonthSchedule() {
        guard let sched = schedule else { return }

        do {
            try db.collection("users")
                  .document(sched.userId)
                  .collection("monthSchedules")
                  .document(sched.yearMonth)
                  .setData(from: sched, merge: true)
        } catch {
            print("🔥 MonthSchedule save failed:", error)
        }

        // Recompute the coloured-calendar dictionary
        var dict: [Date:(done:Int,total:Int)] = [:]
        let cal = Calendar.current
        for (key, list) in sched.dailyPrioritiesByDay {          // <- adjust if your field is named differently
            if let date = dateFormatter.date(from: key) {
                let done  = list.filter(\.isCompleted).count
                dict[cal.startOfDay(for: date)] = (done, list.count)
            }
        }
        dayPriorityStatus = dict
    }


    // MARK: – Helpers

    private func generateDays(in month: Date) -> [Date] {
        var days: [Date] = []
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: month) else { return days }
        var cursor = interval.start
        while cursor < interval.end {
            days.append(cursor)
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }
        return days
    }
}
