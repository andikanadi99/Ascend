//
//  MonthViewModel.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 3/27/25.
//  Last touched — 2025-06-xx
//
//  Responsibilities
//  ────────────────
//  • Load (or create) the MonthSchedule document for the currently-displayed month
//  • Keep a per-day cache of priorities + completion counts for calendar colours
//  • Expose helpers to persist edits from the popup or the priorities section
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
final class MonthViewModel: ObservableObject {

    // ───── Published state ────────────────────────────────────────────────────
    @Published var schedule: MonthSchedule? {
        didSet { recomputeStatuses() }          // keep calendar colours in sync
    }

    /// Every day’s array of TodayPriority objects (fast lookup for popup)
    @Published var dayPriorityStorage: [Date:[TodayPriority]] = [:]

    /// For quick calendar colouring – number of priorities done / total
    @Published var dayPriorityStatus:  [Date:(done:Int,total:Int)] = [:]


    // ───── Private plumbing ──────────────────────────────────────────────────
    private let db = Firestore.firestore()

    /// yyyy-MM-dd → used for DaySchedule docs
    private static let isoDay: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    /// yyyy-MM → used for MonthSchedule doc id
    static let isoMonth: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM"; return f
    }()


    // ─────────────────────────────────────────────────────────────────────────
    // MARK: – Month-level loading
    // ─────────────────────────────────────────────────────────────────────────
    func loadMonthSchedule(for month: Date, userId uid: String) {
        let monthID = Self.isoMonth.string(from: month)
        let ref = db.collection("users")
                    .document(uid)
                    .collection("monthSchedules")
                    .document(monthID)

        ref.getDocument { [weak self] snap, err in
            guard let self else { return }

            // 1️⃣ if the document exists → decode it
            if let snap, snap.exists,
               let sched = try? snap.data(as: MonthSchedule.self) {
                self.schedule = sched
                // also pre-warm the per-day caches:
                self.fetchDaySchedules(for: month, uid: uid)
                return
            }

            // 2️⃣ otherwise create a blank MonthSchedule so the UI is editable
            let fresh = MonthSchedule(
                id:                    monthID,
                userId:                uid,
                yearMonth:             monthID,
                monthlyPriorities:     [],
                dayCompletions:        [:],        // ← add this line
                dailyPrioritiesByDay:  [:]
            )
            try? ref.setData(from: fresh)
            self.schedule = fresh
            // no per-day docs yet → caches stay empty
        }
    }


    // ─────────────────────────────────────────────────────────────────────────
    // MARK: – Day-level helpers (for popup)
    // ─────────────────────────────────────────────────────────────────────────
    func saveDayPriorities(for date: Date, newPriorities: [TodayPriority]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let key    = Calendar.current.startOfDay(for: date)
        let keyStr = Self.isoDay.string(from: key)

        // ---------- 1. write the DaySchedule document ----------
        try? db.collection("users")
            .document(uid)
            .collection("daySchedules")
            .document(keyStr)
            .setData(from: DaySchedule(
                id:         keyStr,
                userId:     uid,
                date:       key,
                wakeUpTime: Date(),
                sleepTime:  Date(),
                priorities: newPriorities,
                timeBlocks: []
            ), merge: true)

        // ---------- 2. update the per-day caches ----------
        dayPriorityStorage[key] = newPriorities
        dayPriorityStatus[key]  = (newPriorities.filter(\.isCompleted).count,
                                   newPriorities.count)

        // ---------- 3. also patch the MonthSchedule doc ----------
        if var sched = schedule {
            sched.dailyPrioritiesByDay[keyStr] = newPriorities
            schedule = sched                    // triggers recomputeStatuses()
            updateMonthSchedule()               // persist the month doc
        }
    }



    // ─────────────────────────────────────────────────────────────────────────
    // MARK: – Persist the whole month doc (from priorities section)
    // ─────────────────────────────────────────────────────────────────────────
    func updateMonthSchedule() {
        guard let sched = schedule else { return }
        try? db.collection("users")
              .document(sched.userId)
              .collection("monthSchedules")
              .document(sched.yearMonth)
              .setData(from: sched, merge: true)

        // dayPriorityStatus will be refreshed by didSet when `schedule` is reassigned
    }


    // ─────────────────────────────────────────────────────────────────────────
    // MARK: – Private helpers
    // ─────────────────────────────────────────────────────────────────────────
    /// Pull the seven (…31) DaySchedule docs in the given month to warm caches
    private func fetchDaySchedules(for month: Date, uid: String) {
        for day in generateDays(in: month) {
            let key   = Calendar.current.startOfDay(for: day)
            let docID = Self.isoDay.string(from: key)

            db.collection("users")
              .document(uid)
              .collection("daySchedules")
              .document(docID)
              .getDocument(as: DaySchedule.self) { [weak self] result in
                  guard let self else { return }
                  switch result {
                  case .success(let ds):
                      let done = ds.priorities.filter(\.isCompleted).count
                      self.dayPriorityStorage[key] = ds.priorities
                      self.dayPriorityStatus[key]  = (done, ds.priorities.count)
                  case .failure:
                      self.dayPriorityStorage[key] = []
                      self.dayPriorityStatus[key]  = (0,0)
                  }
              }
        }
    }

    /// Re-computes the coloured-calendar dictionary whenever `schedule` changes.
    private func recomputeStatuses() {
        guard let sched = schedule else { return }
        var dict: [Date:(done:Int,total:Int)] = [:]
        let cal = Calendar.current

        for (key, list) in sched.dailyPrioritiesByDay {
            if let date = Self.isoDay.date(from: key) {
                dict[cal.startOfDay(for: date)] =
                    (list.filter(\.isCompleted).count, list.count)
            }
        }
        dayPriorityStatus = dict
    }

    /// All Date values within the month (naïve, but good enough)
    private func generateDays(in month: Date) -> [Date] {
        var out: [Date] = []
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: month) else { return out }
        var cursor = interval.start
        while cursor < interval.end {
            out.append(cursor)
            cursor = cal.date(byAdding: .day, value: 1, to: cursor)!
        }
        return out
    }
}
