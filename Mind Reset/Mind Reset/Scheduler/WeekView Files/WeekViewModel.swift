// WeekViewModel.swift
// Mind Reset
//
// Created by Andika Yudhatrisna on 3/26/25.

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

final class WeekViewModel: ObservableObject {

    @Published var schedule: WeeklySchedule?
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let decodeQ = DispatchQueue(label: "week-decode", qos: .userInitiated)

    private static let iso: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    deinit {
        listener?.remove()
    }

    func loadWeeklySchedule(for startOfWeek: Date, userId: String) {
        listener?.remove()
        let start = Calendar.current.startOfDay(for: startOfWeek)
        let docID = Self.iso.string(from: start)
        let docRef = db.collection("users")
            .document(userId)
            .collection("weekSchedules")
            .document(docID)

        listener = docRef.addSnapshotListener(includeMetadataChanges: false) { [weak self] snap, error in
            guard let self = self else { return }
            if let error = error {
                print("❌ Week snapshot error:", error)
                DispatchQueue.main.async { self.errorMessage = "Failed to fetch weekly schedule." }
                return
            }
            guard let snap, snap.exists else {
                self.createDefaultWeekSchedule(startOfWeek: start, userId: userId)
                return
            }
            self.decodeQ.async {
                guard let decoded = try? snap.data(as: WeeklySchedule.self) else {
                    print("❌ Decode WeeklySchedule failed.")
                    return
                }
                DispatchQueue.main.async {
                    if decoded != self.schedule {
                        self.schedule = decoded
                    }
                }
            }
        }
    }

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

    private func createDefaultWeekSchedule(startOfWeek: Date, userId: String) {
        let docID = Self.iso.string(from: startOfWeek)
        let days = Calendar.current.shortWeekdaySymbols
        var intentions = [String:String]()
        var todoBuckets = [String:[ToDoItem]]()
        for d in days {
            intentions[d] = ""
            todoBuckets[d] = []
        }
        let fresh = WeeklySchedule(
            id: docID,
            userId: userId,
            startOfWeek: startOfWeek,
            weeklyPriorities: [],
            dailyIntentions: intentions,
            dailyToDoLists: todoBuckets
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

    func moveWeeklyPriorities(indices: IndexSet, to newOffset: Int) {
        guard var sched = schedule else { return }
        sched.weeklyPriorities.move(fromOffsets: indices, toOffset: newOffset)
        schedule = sched
        updateWeeklySchedule()
    }

    func toggleWeeklyPriorityCompletion(_ priorityId: UUID) {
        guard var sched = schedule,
              let idx = sched.weeklyPriorities.firstIndex(where: { $0.id == priorityId })
        else { return }
        sched.weeklyPriorities[idx].isCompleted.toggle()
        schedule = sched
        updateWeeklySchedule()
    }

    func addNewPriority() {
        guard var sched = schedule else { return }
        let new = WeeklyPriority(
            id: UUID(),
            title: "New Priority",
            progress: 0,
            isCompleted: false
        )
        sched.weeklyPriorities.append(new)
        schedule = sched
        updateWeeklySchedule()
    }

    func deletePriority(_ p: WeeklyPriority) {
        guard var sched = schedule,
              let idx = sched.weeklyPriorities.firstIndex(where: { $0.id == p.id })
        else { return }
        sched.weeklyPriorities.remove(at: idx)
        schedule = sched
        updateWeeklySchedule()
    }

    var weeklyPrioritiesBinding: Binding<[WeeklyPriority]> {
        Binding(
            get: { self.schedule?.weeklyPriorities ?? [] },
            set: { new in
                guard var s = self.schedule else { return }
                s.weeklyPriorities = new
                self.schedule = s
            }
        )
    }

    func toDoItemsBinding(for day: Date) -> Binding<[ToDoItem]> {
        Binding(
            get: { self.schedule?.dailyToDoLists[self.shortKey(for: day)] ?? [] },
            set: { new in
                guard var s = self.schedule else { return }
                s.dailyToDoLists[self.shortKey(for: day)] = new
                self.schedule = s
            }
        )
    }

    func intentionBinding(for day: Date) -> Binding<String> {
        Binding(
            get: { self.schedule?.dailyIntentions[self.shortKey(for: day)] ?? "" },
            set: { new in
                guard var s = self.schedule else { return }
                s.dailyIntentions[self.shortKey(for: day)] = new
                self.schedule = s
            }
        )
    }

    private func shortKey(for date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "E"; return f.string(from: date)
    }

    func copyPreviousWeek(to date: Date, userId: String) {
        let cal = Calendar.current
        guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: date) else { return }
        let prevID = Self.iso.string(from: cal.startOfDay(for: prev))
        let prevRef = db.collection("users").document(userId)
            .collection("weekSchedules").document(prevID)
        let targetID = Self.iso.string(from: cal.startOfDay(for: date))
        let targetRef = db.collection("users").document(userId)
            .collection("weekSchedules").document(targetID)

        prevRef.getDocument { snap, _ in
            guard let snap = snap, snap.exists,
                  let source = try? snap.data(as: WeeklySchedule.self)
            else { return }
            var target = source
            target.id = targetID
            target.startOfWeek = cal.startOfDay(for: date)
            do {
                try targetRef.setData(from: target)
                DispatchQueue.main.async { self.schedule = target }
            } catch {
                print("❌ Copy previous week error:", error)
            }
        }
    }
}
