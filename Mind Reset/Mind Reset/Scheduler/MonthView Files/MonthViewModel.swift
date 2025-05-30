// MonthViewModel.swift
// Mind Reset
//
// Optimised: background-queue decoding, shared Firestore, static formatters.
// Created by Andika Yudhatrisna on 3/27/25.

import SwiftUI
import FirebaseFirestore

final class MonthViewModel: ObservableObject {

    @Published var schedule: MonthSchedule?
    @Published var errorMessage: String?

    private static let cachedDB: Firestore = {
        Firestore.firestore()
    }()
    private let db = MonthViewModel.cachedDB

    private var listener: ListenerRegistration?
    private let decodeQ = DispatchQueue(label: "month-decoder", qos: .userInitiated)

    private static let monthFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        return f
    }()
    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    deinit { listener?.remove() }

    func loadMonthSchedule(for month: Date, userId: String) {
        listener?.remove()
        let docID  = Self.monthFmt.string(from: month)
        let docRef = db.collection("users")
                       .document(userId)
                       .collection("monthSchedules")
                       .document(docID)

        listener = docRef.addSnapshotListener(includeMetadataChanges: false) { [weak self] snap, err in
            guard let self = self else { return }
            if let err = err {
                print("Error loading month schedule:", err)
                DispatchQueue.main.async { self.errorMessage = "Failed to fetch month schedule." }
                return
            }
            guard let snap = snap, snap.exists else {
                DispatchQueue.main.async {
                    self.createDefaultMonthSchedule(month: month, userId: userId)
                }
                return
            }
            // decode on background queue
            self.decodeQ.async {
                if let sched = try? snap.data(as: MonthSchedule.self) {
                    DispatchQueue.main.async { self.schedule = sched }
                } else {
                    print("❗️Couldn’t decode MonthSchedule \(docID)")
                }
            }
        }
    }

    func updateMonthSchedule() {
        guard let sched = schedule, let id = sched.id else { return }
        do {
            try db.collection("users")
                  .document(sched.userId)
                  .collection("monthSchedules")
                  .document(id)
                  .setData(from: sched)
        } catch {
            print("Error updating month schedule:", error)
            errorMessage = "Failed to save month data."
        }
    }

    private func createDefaultMonthSchedule(month: Date, userId: String) {
        let docID = Self.monthFmt.string(from: month)

        var dayCompletions = [String: Double]()
        for date in generateDates(in: month) {
            dayCompletions[ Self.dayFmt.string(from: date) ] = 0.0
        }

        let newSchedule = MonthSchedule(
            id: docID,
            userId: userId,
            yearMonth: docID,
            monthlyPriorities: []        // ←■■ start empty, not with a placeholder
            ,
            dayCompletions: dayCompletions
        )

        do {
            try db.collection("users")
                  .document(userId)
                  .collection("monthSchedules")
                  .document(docID)
                  .setData(from: newSchedule)
            schedule = newSchedule
        } catch {
            print("Error creating default MonthSchedule:", error)
            errorMessage = "Failed to create month schedule."
        }
    }


    private func generateDates(in month: Date) -> [Date] {
        var dates: [Date] = []
        let cal = Calendar.current
        guard let interval = cal.dateInterval(of: .month, for: month) else { return [] }
        var cursor = cal.startOfDay(for: interval.start)
        while cursor < interval.end {
            dates.append(cursor)
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return dates
    }
}
