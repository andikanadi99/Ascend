//  DayViewModel.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 3/25/25.
//

import SwiftUI
import FirebaseFirestore
import Combine

class DayViewModel: ObservableObject {
    @Published var schedule: DaySchedule?
    
    private let db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    private let decodeQueue = DispatchQueue(label: "day-decoder", qos: .userInitiated)

    private static let isoFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mm a"
        return fmt
    }()

    deinit {
        listenerRegistration?.remove()
    }

    func loadDaySchedule(for date: Date, userId: String) {
        listenerRegistration?.remove()
        let startOfDay = Calendar.current.startOfDay(for: date)
        let docId      = DayViewModel.isoFormatter.string(from: startOfDay)
        let docRef = db
            .collection("users")
            .document(userId)
            .collection("daySchedules")
            .document(docId)

        listenerRegistration = docRef.addSnapshotListener(includeMetadataChanges: false) { [weak self] snapshot, error in
            guard let self = self else { return }
            if let error = error {
                print("Error loading day schedule:", error)
                return
            }
            self.decodeQueue.async {
                if let snap = snapshot, snap.exists,
                   let daySchedule = try? snap.data(as: DaySchedule.self) {
                    DispatchQueue.main.async {
                        self.schedule = daySchedule
                    }
                } else {
                    self.createDefaultDaySchedule(date: startOfDay, userId: userId)
                }
            }
        }
    }

    private func createDefaultDaySchedule(date: Date, userId: String) {
        let storedWake = UserDefaults.standard
            .object(forKey: "DefaultWakeUpTime") as? Date
            ?? Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: date)!
        let storedSleep = UserDefaults.standard
            .object(forKey: "DefaultSleepTime") as? Date
            ?? Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: date)!

        // Note: initialize isCompleted = false
        let defaultPriorities = [
            TodayPriority(
              id: UUID(),
              title: "What matters most today",
              progress: 0.0,
              isCompleted: false
            )
        ]

        let defaultSchedule = DaySchedule(
            id: DayViewModel.isoFormatter.string(from: date),
            userId: userId,
            date: date,
            wakeUpTime: storedWake,
            sleepTime: storedSleep,
            priorities: [],                        // ← leave empty by default
            timeBlocks: generateTimeBlocks(from: storedWake, to: storedSleep)
        )

        do {
            try db
                .collection("users")
                .document(userId)
                .collection("daySchedules")
                .document(defaultSchedule.id!)
                .setData(from: defaultSchedule)
            DispatchQueue.main.async {
                self.schedule = defaultSchedule
            }
        } catch {
            print("Error creating default schedule:", error)
        }
    }

    func updateDaySchedule() {
        guard let schedule = schedule, let docId = schedule.id else { return }
        do {
            try db
                .collection("users")
                .document(schedule.userId)
                .collection("daySchedules")
                .document(docId)
                .setData(from: schedule)
        } catch {
            print("Error updating day schedule:", error)
        }
    }

    func regenerateBlocks() {
        guard var schedule = schedule else { return }
        schedule.timeBlocks = generateTimeBlocks(
          from: schedule.wakeUpTime,
          to: schedule.sleepTime
        )
        self.schedule = schedule
        updateDaySchedule()
    }

    // MARK: – Toggle Completion on a Priority
    func togglePriorityCompletion(_ priorityId: UUID) {
        guard var sched = schedule,
              let idx = sched.priorities.firstIndex(where: { $0.id == priorityId })
        else { return }

        // flip the flag, publish & persist
        sched.priorities[idx].isCompleted.toggle()
        schedule = sched
        updateDaySchedule()
    }

    // MARK: – Reorder priorities
    func movePriorities(indices: IndexSet, to newOffset: Int) {
        guard var sched = schedule else { return }
        sched.priorities.move(fromOffsets: indices, toOffset: newOffset)
        schedule = sched
        updateDaySchedule()
    }

    // MARK: — Helpers
    private func generateTimeBlocks(from start: Date, to end: Date) -> [TimeBlock] {
        var blocks: [TimeBlock] = []
        let cal = Calendar.current

        // If end ≤ start, assume next day
        let correctedEnd: Date = {
            if end <= start {
                return cal.date(byAdding: .day, value: 1, to: end)!
            } else {
                return end
            }
        }()
        
        var current = start
        while current <= correctedEnd {
            let label = DayViewModel.timeFormatter.string(from: current)
            blocks.append(TimeBlock(id: UUID(), time: label, task: ""))
            guard let next = cal.date(byAdding: .hour, value: 1, to: current) else { break }
            current = next
        }
        return blocks
    }


    func copyPreviousDaySchedule(
      to targetDate: Date,
      userId: String,
      completion: @escaping (Bool) -> Void
    ) {
        let cal        = Calendar.current
        let sourceDate = cal.date(byAdding: .day, value: -1, to: targetDate)!
        let sourceId   = DayViewModel.isoFormatter.string(
          from: cal.startOfDay(for: sourceDate)
        )
        let targetId   = DayViewModel.isoFormatter.string(
          from: cal.startOfDay(for: targetDate)
        )

        let sourceRef = db
            .collection("users").document(userId)
            .collection("daySchedules").document(sourceId)

        let targetRef = db
            .collection("users").document(userId)
            .collection("daySchedules").document(targetId)

        sourceRef.getDocument { [weak self] snap, error in
            guard let self = self else { return }
            if let error = error {
                print("Error fetching source schedule:", error)
                return completion(false)
            }
            guard let snap = snap, snap.exists,
                  let sourceSchedule = try? snap.data(as: DaySchedule.self) else {
                print("Source schedule not found.")
                return completion(false)
            }

            // ─────────── Build a brand-new Schedule for “today” ───────────
            //
            // Instead of doing:
            //     var targetSchedule = sourceSchedule
            //     targetSchedule.id = targetId
            //     targetSchedule.date = <today>
            // which simply copies the struct but preserves child‐IDs (so editing one
            // mutates both), we explicitly rebuild each array element with a fresh UUID.

            // 1) Deep‐copy timeBlocks:
            let newTimeBlocks: [TimeBlock] = sourceSchedule.timeBlocks.map { oldBlock in
                TimeBlock(
                    id: UUID(),               // NEW UUID
                    time: oldBlock.time,
                    task: oldBlock.task
                )
            }

            // 2) Deep‐copy priorities:
            let newPriorities: [TodayPriority] = sourceSchedule.priorities.map { oldPriority in
                TodayPriority(
                    id: UUID(),               // NEW UUID
                    title: oldPriority.title,
                    progress: oldPriority.progress,
                    isCompleted: oldPriority.isCompleted
                )
            }

            // 3) Create a brand‐new DaySchedule struct (with today’s ID and date):
            let todayStart = cal.startOfDay(for: targetDate)
            let newSchedule = DaySchedule(
                id: targetId,
                userId: sourceSchedule.userId,
                date: todayStart,
                wakeUpTime: sourceSchedule.wakeUpTime,
                sleepTime: sourceSchedule.sleepTime,
                priorities: newPriorities,
                timeBlocks: newTimeBlocks
            )

            // 4) Immediately publish locally so the UI updates:
            DispatchQueue.main.async {
                self.schedule = newSchedule
            }

            // 5) Persist under a distinct Firestore document (so you don’t overwrite yesterday):
            do {
                try targetRef.setData(from: newSchedule)
                completion(true)
            } catch {
                print("Error saving target schedule:", error)
                completion(false)
            }
        }
    }


    // ────────────────────────────────────────────────────────────
    // MARK: – NEW: Fetch yesterday’s unfinished priorities only
    // ────────────────────────────────────────────────────────────

    /// Retrieves the DaySchedule document for the given date, decodes it,
    /// filters out any TodayPriority where `isCompleted == false`, and
    /// returns that array via the completion handler.
    func fetchUnfinishedPriorities(
        for date: Date,
        userId: String,
        completion: @escaping ([TodayPriority]) -> Void
    ) {
        let calendar = Calendar.current
        let startOfThatDay = calendar.startOfDay(for: date)
        let docId = DayViewModel.isoFormatter.string(from: startOfThatDay)

        let docRef = db
            .collection("users")
            .document(userId)
            .collection("daySchedules")
            .document(docId)

        // Firestore read for that document
        docRef.getDocument { snapshot, error in
            if let error = error {
                print("Error fetching priorities for \(docId):", error.localizedDescription)
                completion([])
                return
            }

            guard let snap = snapshot, snap.exists else {
                // No document means no schedule => no unfinished priorities
                completion([])
                return
            }

            // Decode on our decodeQueue to avoid blocking the main thread
            self.decodeQueue.async {
                do {
                    let daySched = try snap.data(as: DaySchedule.self)
                    // Filter only unfinished (isCompleted == false)
                    let unfinished = daySched.priorities.filter { !$0.isCompleted }
                    DispatchQueue.main.async {
                        completion(unfinished)
                    }
                } catch {
                    print("Decoding error in fetchUnfinishedPriorities:", error.localizedDescription)
                    DispatchQueue.main.async {
                        completion([])
                    }
                }
            }
        }
    }
}
