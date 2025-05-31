//
//  WeekViewModel.swift
//  Mind Reset
//
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
    @Published var dayPriorityStorage: [Date:[TodayPriority]] = [:]          // key = start-of-day
    @Published var dayPriorityStatus : [Date:(done:Int,total:Int)] = [:]

    // ───────── Firestore plumbing ───────
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let decodeQ  = DispatchQueue(label: "week-decode", qos: .userInitiated)

    /// yyyy-MM-dd formatter (used for WeekSchedule *and* DaySchedule docs)
    static let iso: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    deinit { listener?.remove() }

    // MARK: – LOAD WEEK  + seven Day docs
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
                self.errorMessage = err.localizedDescription
                return
            }

            guard let snap, snap.exists else {
                // first time ever → seed an empty week
                self.createDefaultWeekSchedule(startOfWeek: weekStart, userId: uid)
                return
            }

            decodeQ.async {
                guard let model = try? snap.data(as: WeeklySchedule.self) else { return }
                Task { @MainActor in
                    self.schedule = model
                    self.fetchSevenDaySchedules(from: weekStart, uid: uid)
                }
            }
        }
    }

    // MARK: – SAVE WEEK
    func updateWeeklySchedule() {
        guard let s = schedule, let id = s.id else { return }
        try? db.collection("users")
              .document(s.userId)
              .collection("weekSchedules")
              .document(id)
              .setData(from: s, merge: true)
    }

    // MARK: – PUBLIC BINDINGS  (WeekView UI)
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

    /// Binding used by each **DayCardView** for its list of priorities
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

    // daily “intention” text
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

    // MARK: – ORIGINAL Week-level helpers (unchanged)
    func moveWeeklyPriorities(indices: IndexSet, to newOffset: Int) {
        guard var sched = schedule else { return }
        sched.weeklyPriorities.move(fromOffsets: indices, toOffset: newOffset)
        schedule = sched
        updateWeeklySchedule()
    }

    func toggleWeeklyPriorityCompletion(_ id: UUID) {
        guard var sched = schedule,
              let idx = sched.weeklyPriorities.firstIndex(where: { $0.id == id })
        else { return }
        sched.weeklyPriorities[idx].isCompleted.toggle()
        schedule = sched
        updateWeeklySchedule()
    }

    func addNewPriority() {
        guard var sched = schedule else { return }
        sched.weeklyPriorities.append(
            WeeklyPriority(id: UUID(), title: "New Priority",
                           progress: 0, isCompleted: false)
        )
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

    // MARK: – DAY-SCHEDULE (fetch & persist)
    private func fetchSevenDaySchedules(from weekStart: Date, uid: String) {
        let cal = Calendar.current
        for offset in 0..<7 {
            let day = cal.date(byAdding: .day, value: offset, to: weekStart)!
            fetchDaySchedule(for: day, uid: uid)
        }
    }

    private func fetchDaySchedule(for day: Date, uid: String) {
        let key   = Calendar.current.startOfDay(for: day)
        let docID = Self.iso.string(from: key)

        db.collection("users")
          .document(uid)
          .collection("daySchedules")
          .document(docID)
          .getDocument(as: DaySchedule.self) { [weak self] result in
              guard let self else { return }
              let list = (try? result.get().priorities) ?? []
              self.dayPriorityStorage[key] = list
              self.dayPriorityStatus[key]  = (list.filter(\.isCompleted).count,
                                              list.count)
          }
    }

    private func persistDayPriorities(_ key: Date, _ list: [TodayPriority]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let docID = Self.iso.string(from: key)

        try? db.collection("users")
              .document(uid)
              .collection("daySchedules")
              .document(docID)
              .setData(from: DaySchedule(
                  id: docID,
                  userId: uid,
                  date: key,
                  wakeUpTime: Date(), sleepTime: Date(),
                  priorities: list,
                  timeBlocks: []
              ), merge: true)

        dayPriorityStatus[key] = (list.filter(\.isCompleted).count, list.count)
    }

    // MARK: – COPY previous week  (unchanged)
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
            guard let snap, snap.exists,
                  var source = try? snap.data(as: WeeklySchedule.self)
            else { return }
            source.id = targetID
            source.startOfWeek = cal.startOfDay(for: date)
            try? targetRef.setData(from: source)
            Task { @MainActor in self.schedule = source }
        }
    }

    // MARK: – UTILITIES
    private func shortKey(for d: Date) -> String {   // "Mon", "Tue", …
        let f = DateFormatter(); f.dateFormat = "E"; return f.string(from: d)
    }

    // MARK: – DEFAULT WEEK CREATION  (moved verbatim from original file)
    private func createDefaultWeekSchedule(startOfWeek: Date, userId: String) {
        let docID = Self.iso.string(from: startOfWeek)
        let days = Calendar.current.shortWeekdaySymbols      // ["Sun", "Mon", …]

        var intentions  = [String:String]()
        var todoBuckets = [String:[ToDoItem]]()
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

        try? db.collection("users")
              .document(userId)
              .collection("weekSchedules")
              .document(docID)
              .setData(from: fresh)

        self.schedule = fresh
    }
}
