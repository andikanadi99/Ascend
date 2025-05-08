//
//  WeekViewModel.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 3/26/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth             // if you need the user ID here
import Combine

final class WeekViewModel: ObservableObject {

    // ───────────────────────── Published state
    @Published var schedule: WeeklySchedule?
    @Published var errorMessage: String?

    // ───────────────────────── Firestore plumbing
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // Decoding off‑main
    private let decodeQ = DispatchQueue(label: "week-decode", qos: .userInitiated)

    // Re‑usable ISO formatter (“yyyy‑MM‑dd”)
    private static let iso: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    deinit { listener?.remove() }

    // MARK: – Public API
    func loadWeeklySchedule(for startOfWeek: Date, userId: String) {

        // 1️⃣ Remove any old listener
        listener?.remove()

        // 2️⃣ Canonical doc‑ID for the week (start‑of‑week 00:00)
        let start = Calendar.current.startOfDay(for: startOfWeek)
        let docID = Self.iso.string(from: start)

        let docRef = db.collection("users")
                       .document(userId)
                       .collection("weekSchedules")
                       .document(docID)

        // 3️⃣ Attach listener (decode on background queue)
        listener = docRef.addSnapshotListener(includeMetadataChanges: false) { [weak self] snap, error in
            guard let self else { return }

            // ── Error path
            if let error = error {
                print("❌ Week snapshot error:", error)
                DispatchQueue.main.async { self.errorMessage = "Failed to fetch weekly schedule." }
                return
            }

            // ── No doc?  Create defaults.
            guard let snap, snap.exists else {
                self.createDefaultWeekSchedule(startOfWeek: start, userId: userId)
                return
            }

            // ── Decode off‑main
            self.decodeQ.async {
                guard let decoded = try? snap.data(as: WeeklySchedule.self) else {
                    print("❌ Decode WeeklySchedule failed.")
                    return
                }

                // Publish only if changed (requires Equatable conformance)
                DispatchQueue.main.async {
                    if decoded != self.schedule {
                        self.schedule = decoded
                    }
                }
            }
        }
    }

    // ------------------------------------------------------------------
    /// Persists the current `schedule` back to Firestore.
    func updateWeeklySchedule() {
        guard let schedule, let docID = schedule.id else { return }

        do {
            try db.collection("users")
                  .document(schedule.userId)
                  .collection("weekSchedules")
                  .document(docID)
                  .setData(from: schedule)
        } catch {
            print("❌ Update weekly schedule:", error)
            errorMessage = "Couldn't save weekly schedule."
        }
    }

    // MARK: – Defaults --------------------------------------------------
    private func createDefaultWeekSchedule(startOfWeek: Date, userId: String) {

        let docID = Self.iso.string(from: startOfWeek)

        // Empty intentions / todo‑lists for Sun→Sat
        let days = Calendar.current.shortWeekdaySymbols   // ["Sun","Mon",...]
        var intentions  = [String:String]()
        var todoBuckets = [String:[ToDoItem]]()
        for d in days {
            intentions[d]  = ""
            todoBuckets[d] = []
        }

        let fresh = WeeklySchedule(
            id:             docID,
            userId:         userId,
            startOfWeek:    startOfWeek,
            weeklyPriorities: [WeeklyPriority(id: UUID(),
                                              title: "Weekly Goals",
                                              progress: 0)],
            dailyIntentions:  intentions,
            dailyToDoLists:   todoBuckets
        )

        do {
            try db.collection("users")
                  .document(userId)
                  .collection("weekSchedules")
                  .document(docID)
                  .setData(from: fresh)
            DispatchQueue.main.async { self.schedule = fresh }
        } catch {
            print("❌ Create default week:", error)
        }
    }
}

