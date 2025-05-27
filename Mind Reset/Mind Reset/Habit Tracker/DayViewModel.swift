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

        // in DayViewModel.createDefaultDaySchedule(...)
        let defaultSchedule = DaySchedule(
            id: DayViewModel.isoFormatter.string(from: date),
            userId: userId,
            date: date,
            wakeUpTime: storedWake,
            sleepTime: storedSleep,
            priorities: [],                        // ← no default priorities
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

        // Determine actual end‐of‐schedule date:
        // If `end` is <= `start`, assume it’s on the next calendar day.
        let correctedEnd: Date = {
            if end <= start {
                // add 1 day to the original end
                return cal.date(byAdding: .day, value: 1, to: end)!
            } else {
                return end
            }
        }()
        
        var current = start
        while current <= correctedEnd {
            let label = DayViewModel.timeFormatter.string(from: current)
            blocks.append(TimeBlock(id: UUID(), time: label, task: ""))
            // advance one hour
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
        let cal       = Calendar.current
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

            var targetSchedule = sourceSchedule
            targetSchedule.id = targetId
            targetSchedule.date = cal.startOfDay(for: targetDate)

            do {
                try targetRef.setData(from: targetSchedule)
                DispatchQueue.main.async { self.schedule = targetSchedule }
                completion(true)
            } catch {
                print("Error saving target schedule:", error)
                completion(false)
            }
        }
    }
}
