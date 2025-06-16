//  WeekViewModel.swift
//  Mind Reset
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
final class WeekViewModel: ObservableObject {

    // ───────── WEEK-LEVEL MODEL ─────────
    @Published var schedule: WeeklySchedule?
    @Published var errorMessage: String?

    // ───────── PER-DAY PRIORITIES ───────
    @Published var dayPriorityStorage: [Date:[TodayPriority]] = [:]   // key = start-of-day
    @Published var dayPriorityStatus : [Date:(done: Int, total: Int)] = [:]

    // ───────── Firestore plumbing ───────
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let decodeQ  = DispatchQueue(label: "week-decode", qos: .userInitiated)

    /// ID formatter shared with DaySchedule
    static let iso: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    deinit { listener?.remove() }

    // MARK: – LOAD WEEK + 7 DAYS
    func loadWeeklySchedule(for startOfWeek: Date, userId uid: String) {
        listener?.remove()

        let weekStart = Calendar.current.startOfDay(for: startOfWeek)
        let docID     = Self.iso.string(from: weekStart)

        let ref = db.collection("users")
                    .document(uid)
                    .collection("weekSchedules")
                    .document(docID)

        listener = ref.addSnapshotListener(includeMetadataChanges: false) { [weak self] snap, err in
            guard let self else { return }

            if let err {
                DispatchQueue.main.async { self.errorMessage = err.localizedDescription }
                return
            }
            guard let snap, snap.exists else {
                self.createDefaultWeekSchedule(startOfWeek: weekStart, userId: uid)
                return
            }

            self.decodeQ.async {
                guard let model = try? snap.data(as: WeeklySchedule.self) else { return }
                Task { @MainActor in
                    self.schedule = model
                    self.fetchSevenDaySchedules(from: weekStart, uid: uid)
                }
            }
        }
    }

    // MARK: – SAVE ENTIRE WEEK DOC
    func updateWeeklySchedule() {
        guard let s = schedule, let id = s.id else { return }
        try? db.collection("users")
              .document(s.userId)
              .collection("weekSchedules")
              .document(id)
              .setData(from: s, merge: true)
    }

    // MARK: – FETCH UNFINISHED WEEKLY PRIORITIES
    func fetchUnfinishedWeeklyPriorities(
        for weekStart: Date,
        userId: String,
        completion: @escaping ([WeeklyPriority]) -> Void
    ) {
        let docID = Self.iso.string(from: Calendar.current.startOfDay(for: weekStart))
        db.collection("users")
          .document(userId)
          .collection("weekSchedules")
          .document(docID)
          .getDocument { snap, err in
              if let err {
                  print("⚠️ fetchUnfinishedWeeklyPriorities:", err)
                  DispatchQueue.main.async { completion([]) }
                  return
              }
              guard let snap, snap.exists,
                    let sched = try? snap.data(as: WeeklySchedule.self) else {
                  DispatchQueue.main.async { completion([]) }
                  return
              }
              let unfinished = sched.weeklyPriorities.filter { !$0.isCompleted }
              DispatchQueue.main.async { completion(unfinished) }
          }
    }

    // MARK: – PATCH-ONLY DAY PRIORITY SAVE
    func updateDayPriorities(date: Date,
                             priorities: [TodayPriority],
                             userId: String) {
        let docID = Self.iso.string(from: Calendar.current.startOfDay(for: date))
        db.collection("users")
          .document(userId)
          .collection("daySchedules")
          .document(docID)
          .updateData([
              "priorities": priorities.map { $0.asDictionary }
          ]) { err in
              if let err { print("⚠️ Day patch failed:", err) }
          }
    }

    // MARK: – IMPORT UNFINISHED FROM LAST WEEK
    func importUnfinishedFromLastWeek(to currentWeekStart: Date, userId: String) {
        let cal = Calendar.current
        let lastWeekStart = cal.startOfDay(
            for: cal.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart)!
        )

        fetchUnfinishedWeeklyPriorities(for: lastWeekStart,
                                        userId: userId) { [weak self] unfinished in
            guard let self, var sched = self.schedule else { return }
            let existing = Set(sched.weeklyPriorities.map(\.title))
            var didChange = false

            for item in unfinished where !existing.contains(item.title) {
                sched.weeklyPriorities.append(
                    WeeklyPriority(id: UUID(),
                                   title: item.title,
                                   progress: 0,
                                   isCompleted: false)
                )
                didChange = true
            }
            if didChange {
                Task { @MainActor in
                    self.schedule = sched
                    self.updateWeeklySchedule()
                }
            }
        }
    }

    // MARK: – WEEK-LEVEL CRUD (titles)
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
    func moveWeeklyPriorities(indices: IndexSet, to newOffset: Int) {
        guard var s = schedule else { return }
        s.weeklyPriorities.move(fromOffsets: indices, toOffset: newOffset)
        schedule = s
        updateWeeklySchedule()
    }
    func toggleWeeklyPriorityCompletion(_ id: UUID) {
        guard var s = schedule,
              let idx = s.weeklyPriorities.firstIndex(where: { $0.id == id }) else { return }
        s.weeklyPriorities[idx].isCompleted.toggle()
        schedule = s
        updateWeeklySchedule()
    }
    func addNewPriority() {
        guard var s = schedule else { return }
        s.weeklyPriorities.append(
            WeeklyPriority(id: UUID(), title: "New Priority",
                           progress: 0, isCompleted: false)
        )
        schedule = s
        updateWeeklySchedule()
    }
    func deletePriority(_ p: WeeklyPriority) {
        guard var s = schedule,
              let idx = s.weeklyPriorities.firstIndex(where: { $0.id == p.id }) else { return }
        s.weeklyPriorities.remove(at: idx)
        schedule = s
        updateWeeklySchedule()
    }

    // MARK: – DAY-LEVEL BINDINGS
    func prioritiesBinding(for day: Date) -> Binding<[TodayPriority]> {
        let key = Calendar.current.startOfDay(for: day)
        return Binding(
            get: { self.dayPriorityStorage[key] ?? [] },
            set: { new in
                self.dayPriorityStorage[key] = new
                self.persistDayPriorities(key, new)
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

    // MARK: – FETCH SEVEN DAY DOCS
    private func fetchSevenDaySchedules(from weekStart: Date, uid: String) {
        let cal = Calendar.current
        for offset in 0..<7 {
            if let day = cal.date(byAdding: .day, value: offset, to: weekStart) {
                fetchDaySchedule(for: day, uid: uid)
            }
        }
    }
    private func fetchDaySchedule(for day: Date, uid: String) {
        let key   = Calendar.current.startOfDay(for: day)
        let docID = Self.iso.string(from: key)

        db.collection("users").document(uid)
          .collection("daySchedules").document(docID)
          .getDocument(as: DaySchedule.self) { [weak self] result in
              guard let self else { return }
              let list = (try? result.get().priorities) ?? []
              DispatchQueue.main.async {
                  self.dayPriorityStorage[key] = list
                  self.dayPriorityStatus[key]  = (
                      list.filter(\.isCompleted).count,
                      list.count
                  )
              }
          }
    }

    private func persistDayPriorities(_ key: Date, _ list: [TodayPriority]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        DispatchQueue.main.async {
            self.dayPriorityStatus[key] = (list.filter(\.isCompleted).count, list.count)
        }
        updateDayPriorities(date: key, priorities: list, userId: uid)
    }

    // MARK: – COPY PREVIOUS WEEK
    func copyPreviousWeek(to date: Date, userId: String) {
        let cal = Calendar.current
        guard let prev = cal.date(byAdding: .weekOfYear, value: -1, to: date) else { return }

        let prevID   = Self.iso.string(from: cal.startOfDay(for: prev))
        let targetID = Self.iso.string(from: cal.startOfDay(for: date))

        let prevRef = db.collection("users")
                        .document(userId)
                        .collection("weekSchedules")
                        .document(prevID)

        let targetRef = db.collection("users")
                          .document(userId)
                          .collection("weekSchedules")
                          .document(targetID)

        prevRef.getDocument { snap, _ in
            guard let snap, snap.exists,
                  var source = try? snap.data(as: WeeklySchedule.self) else { return }
            source.id = targetID
            source.startOfWeek = cal.startOfDay(for: date)
            try? targetRef.setData(from: source)
            Task { @MainActor in self.schedule = source }
        }
    }

    // MARK: – UTILITIES & DEFAULT SEED
    private func shortKey(for date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "E"
        return f.string(from: date)
    }

    private func createDefaultWeekSchedule(startOfWeek: Date, userId: String) {
        let docID = Self.iso.string(from: startOfWeek)
        let days  = Calendar.current.shortWeekdaySymbols

        var intentions  = [String:String]()
        var todoBuckets = [String:[ToDoItem]]()        // assume ToDoItem exists
        for d in days {
            intentions[d]  = ""
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

        try? db.collection("users").document(userId)
              .collection("weekSchedules").document(docID)
              .setData(from: fresh)

        self.schedule = fresh
    }
}
