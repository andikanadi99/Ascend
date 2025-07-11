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
import SwiftUI  
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

    /// Keeps track of active snapshot listeners for daySchedules documents
    private var priorityListeners: [Date: ListenerRegistration] = [:]


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
            guard let self = self else { return }

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
                id:                   monthID,
                userId:               uid,
                yearMonth:            monthID,
                monthlyPriorities:    [],
                dayCompletions:       [:],
                dailyPrioritiesByDay: [:]
            )
            try? ref.setData(from: fresh)
            self.schedule = fresh
            // no per-day docs yet → caches stay empty
        }
    }


    // ─────────────────────────────────────────────────────────────────────────
    // MARK: – Day-level helpers (for popup)
    // ─────────────────────────────────────────────────────────────────────────
    func patchDayPriorities(_ keyStr: String,
                            uid: String,
                            _ list: [TodayPriority]) {
        let ref = db.collection("users")
                    .document(uid)
                    .collection("daySchedules")
                    .document(keyStr)

        let dictArr = list.map { $0.asDictionary }
        ref.setData(["priorities": dictArr], merge: true)
    }

    func saveDayPriorities(for date: Date,
                           newPriorities: [TodayPriority]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let key    = Calendar.current.startOfDay(for: date)
        let keyStr = Self.isoDay.string(from: key)

        patchDayPriorities(keyStr, uid: uid, newPriorities)

        dayPriorityStorage[key] = newPriorities
        dayPriorityStatus[key]  = (
            newPriorities.filter(\.isCompleted).count,
            newPriorities.count
        )

        if var sched = schedule {
            sched.dailyPrioritiesByDay[keyStr] = newPriorities
            schedule = sched
            updateMonthSchedule()
        }
    }
    
    // MARK: – Convenient Binding for a single day
    func prioritiesBinding(for day: Date) -> Binding<[TodayPriority]> {
        let key = Calendar.current.startOfDay(for: day)

        return Binding(
            get: {                                   // read
                self.dayPriorityStorage[key] ?? []
            },
            set: { newVal in                         // write-back
                self.dayPriorityStorage[key] = newVal
                self.saveDayPriorities(for: day,
                                       newPriorities: newVal)
            }
        )
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

    /// Attaches a live listener per day so DayView edits sync immediately
    private func fetchDaySchedules(for month: Date, uid: String) {
        for day in generateDays(in: month) {
            let key   = Calendar.current.startOfDay(for: day)
            let docID = Self.isoDay.string(from: key)
            let doc   = db.collection("users")
                           .document(uid)
                           .collection("daySchedules")
                           .document(docID)

            // Remove any existing listener for this day
            priorityListeners[key]?.remove()

            // Add real-time snapshot listener (creates doc if missing)
            let listener = doc.addSnapshotListener { [weak self] snap, _ in
                guard let self = self else { return }

                if let snap = snap,
                   snap.exists,
                   let ds = try? snap.data(as: DaySchedule.self) {

                    let done = ds.priorities.filter(\.isCompleted).count
                    self.dayPriorityStorage[key] = ds.priorities
                    self.dayPriorityStatus[key]  = (done, ds.priorities.count)

                } else {
                    // No document yet: treat as empty
                    self.dayPriorityStorage[key] = []
                    self.dayPriorityStatus[key]  = (0, 0)
                }
            }
            priorityListeners[key] = listener
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

