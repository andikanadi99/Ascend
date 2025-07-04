// WeekViewModel.swift
// Mind Reset
//


import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

@MainActor
final class WeekViewModel: ObservableObject {

    // ───────── WEEK-MODEL ─────────
    @Published var schedule: WeeklySchedule?
    @Published var errorMessage: String?

    // ───────── PER-DAY STORAGE ────
    @Published var dayPriorityStorage: [Date:[TodayPriority]] = [:]
    @Published var dayPriorityStatus : [Date:(done: Int, total: Int)] = [:]

    // ───────── Firestore plumbing ─
    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?
    private let decodeQ = DispatchQueue(label: "week-decode", qos: .userInitiated)

    /// yyyy-MM-dd string (anchor docID)
    static let iso: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f
    }()

    deinit { listener?.remove() }

    // MARK: – LOAD / LISTEN / MIGRATE
    @MainActor
    func loadWeeklySchedule(for startOfWeek: Date, userId uid: String) {

        // ── Clean up any previous listener
        listener?.remove()

        // ── Normalise anchor + document IDs
        let weekStart = Calendar.current.startOfDay(for: startOfWeek)
        let docID     = Self.iso.string(from: weekStart)
        let isoKey    = WeeklySchedule.isoYearWeekString(from: weekStart)

        let colRef    = db.collection("users")
                          .document(uid)
                          .collection("weekSchedules")
        let targetRef = colRef.document(docID)

        // ─────────────────────────────────────────────────────────────
        // 1️⃣ LISTEN at the *canonical* anchor for this week
        // ─────────────────────────────────────────────────────────────
        listener = targetRef.addSnapshotListener(includeMetadataChanges: false) { [weak self] snap, err in
            guard let self = self else { return }

            if let err {
                DispatchQueue.main.async { self.errorMessage = err.localizedDescription }
                return
            }

            // ── Case A – Document exists exactly where we expect it ──
            if let snap, snap.exists {
                // Decode on a background queue, repair missing `id`, then publish
                self.decodeQ.async {
                    guard var sched = try? snap.data(as: WeeklySchedule.self) else { return }
                    if sched.id == nil { sched.id = docID }      // auto-repair
                    Task { @MainActor in
                        self.schedule = sched
                        self.fetchSevenDaySchedules(from: weekStart, uid: uid)
                    }
                }
                return
            }

            // ─────────────────────────────────────────────────────────
            // 2️⃣ FALL-BACK SEARCH by `isoYearWeek`  (older misplaced docs)
            // ─────────────────────────────────────────────────────────
            colRef.whereField("isoYearWeek", isEqualTo: isoKey)
                  .getDocuments { qs, _ in
                if let stray = qs?.documents.first,
                   var oldSched = try? stray.data(as: WeeklySchedule.self) {
                    self.migrate(oldDoc: oldSched,
                                 to: targetRef,
                                 weekStart: weekStart,
                                 isoKey: isoKey,
                                 uid: uid)
                    return
                }

                // ─────────────────────────────────────────────────────
                // 3️⃣ LAST-CHANCE ±6-DAY SCAN around the anchor
                // ─────────────────────────────────────────────────────
                Task { @MainActor in
                    for offset in -6...6 where offset != 0 {
                        let candDate = Calendar.current.date(byAdding: .day,
                                                             value: offset,
                                                             to: weekStart)!
                        let candID   = Self.iso.string(from: candDate)
                        do {
                            let straySnap = try await colRef.document(candID).getDocument()
                            if straySnap.exists,
                               var straySched = try? straySnap.data(as: WeeklySchedule.self) {
                                self.migrate(oldDoc: straySched,
                                             to: targetRef,
                                             weekStart: weekStart,
                                             isoKey: isoKey,
                                             uid: uid)
                                return
                            }
                        } catch { /* ignore & continue loop */ }
                    }

                    // ───────────────────────────────────────────────
                    // 4️⃣ Nothing found → create a brand-new week doc
                    // ───────────────────────────────────────────────
                    self.createDefaultWeekSchedule(startOfWeek: weekStart,
                                                   userId: uid) {
                        self.fetchSevenDaySchedules(from: weekStart, uid: uid)
                    }
                }
            }
        }
    }



    /// Handle a live snapshot found at the desired anchor; patches legacy docs.
    private func handleSnapshot(_ snap: DocumentSnapshot,
                                expectedWeekStart: Date,
                                uid: String) {
        decodeQ.async {
            guard var model = try? snap.data(as: WeeklySchedule.self) else { return }

            // Upgrade legacy docs (missing new fields) once
            var needsPatch = false
            if model.anchorWeekday == nil {
                model.anchorWeekday = Calendar.current.firstWeekday
                needsPatch = true
            }
            if model.isoYearWeek == nil {
                model.isoYearWeek = WeeklySchedule.isoYearWeekString(from: expectedWeekStart)
                needsPatch = true
            }
            if needsPatch {
                try? snap.reference.setData(from: model, merge: true)
            }

            Task { @MainActor in
                self.schedule = model
                self.fetchSevenDaySchedules(from: expectedWeekStart, uid: uid)
            }
        }
    }

    /// Copy an old-anchor doc into the new anchor location.
    private func migrate(oldDoc old: WeeklySchedule,
                         to target: DocumentReference,
                         weekStart: Date,
                         isoKey: String,
                         uid: String) {
        var sched = old
        sched.id            = target.documentID
        sched.startOfWeek   = weekStart
        sched.anchorWeekday = Calendar.current.firstWeekday
        sched.isoYearWeek   = isoKey

        try? target.setData(from: sched)
        Task { @MainActor in
            self.schedule = sched
            self.fetchSevenDaySchedules(from: weekStart, uid: uid)
        }
    }

    // MARK: – SAVE ENTIRE WEEK
    func updateWeeklySchedule() {
        guard var s = schedule else { return }

        // 1️⃣ Auto-repair: some older docs were saved without an `id`
        if s.id == nil {
            s.id = Self.iso.string(from: Calendar.current.startOfDay(for: s.startOfWeek))
            schedule = s                       // write back to the @Published copy
        }

        // 2️⃣ Persist
        try? db.collection("users")
              .document(s.userId)
              .collection("weekSchedules")
              .document(s.id!)                 // now guaranteed non-nil
              .setData(from: s, merge: true)
    }


    // MARK: – FETCH UNFINISHED WEEKLY PRIORITIES
    func fetchUnfinishedWeeklyPriorities(for weekStart: Date,
                                         userId: String,
                                         completion: @escaping ([WeeklyPriority])->Void) {
        let docID = Self.iso.string(from: Calendar.current.startOfDay(for: weekStart))
        db.collection("users")
          .document(userId)
          .collection("weekSchedules")
          .document(docID)
          .getDocument { snap, _ in
            guard let snap, snap.exists,
                  let sched = try? snap.data(as: WeeklySchedule.self) else {
                completion([]); return
            }
            completion(sched.weeklyPriorities.filter { !$0.isCompleted })
          }
    }

    // MARK: – PATCH DAY PRIORITIES
    func updateDayPriorities(date: Date,
                             priorities: [TodayPriority],
                             userId: String) {
        let docID = Self.iso.string(from: Calendar.current.startOfDay(for: date))
        db.collection("users")
          .document(userId)
          .collection("daySchedules")
          .document(docID)
          .updateData(["priorities": priorities.map { $0.asDictionary }])
    }

    // MARK: – IMPORT LAST WEEK’S UNFINISHED
    func importUnfinishedFromLastWeek(to currentWeekStart: Date, userId uid: String) {
        let cal = Calendar.current
        let lastWeekStart = cal.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart)!
        fetchUnfinishedWeeklyPriorities(for: lastWeekStart, userId: uid) { [weak self] unfinished in
            guard let self, var s = self.schedule else { return }
            let existing = Set(s.weeklyPriorities.map(\.title))
            var changed = false
            for item in unfinished where !existing.contains(item.title) {
                s.weeklyPriorities.append(
                    WeeklyPriority(id: UUID(),
                                   title: item.title,
                                   progress: 0,
                                   isCompleted: false)
                )
                changed = true
            }
            if changed {
                self.schedule = s
                self.updateWeeklySchedule()
            }
        }
    }

    // MARK: – WEEK-LEVEL CRUD / Bindings
    var weeklyPrioritiesBinding: Binding<[WeeklyPriority]> {
        Binding(
            get: { self.schedule?.weeklyPriorities ?? [] },
            set: { newVal in
                guard var s = self.schedule else { return }
                s.weeklyPriorities = newVal
                self.schedule = s
            })
    }

    func moveWeeklyPriorities(indices: IndexSet, to offs: Int) {
        guard var s = schedule else { return }
        s.weeklyPriorities.move(fromOffsets: indices, toOffset: offs)
        schedule = s; updateWeeklySchedule()
    }
    func toggleWeeklyPriorityCompletion(_ id: UUID) {
        guard var s = schedule,
              let i = s.weeklyPriorities.firstIndex(where: { $0.id == id }) else { return }
        s.weeklyPriorities[i].isCompleted.toggle()
        schedule = s; updateWeeklySchedule()
    }
    func addNewPriority() {
        guard var s = schedule else { return }
        s.weeklyPriorities.append(.init(id: UUID(), title: "New Priority",
                                        progress: 0, isCompleted: false))
        schedule = s; updateWeeklySchedule()
    }
    func deletePriority(_ p: WeeklyPriority) {
        guard var s = schedule,
              let i = s.weeklyPriorities.firstIndex(of: p) else { return }
        s.weeklyPriorities.remove(at: i)
        schedule = s; updateWeeklySchedule()
    }

    // MARK: – DAY-LEVEL Bindings
    func prioritiesBinding(for day: Date) -> Binding<[TodayPriority]> {
        let key = Calendar.current.startOfDay(for: day)
        return Binding(
            get: { self.dayPriorityStorage[key] ?? [] },
            set: { new in
                self.dayPriorityStorage[key] = new
                self.persistDayPriorities(key, new)
            })
    }
    func intentionBinding(for day: Date) -> Binding<String> {
        Binding(
            get: { self.schedule?.dailyIntentions[self.shortKey(for: day)] ?? "" },
            set: { new in
                guard var s = self.schedule else { return }
                s.dailyIntentions[self.shortKey(for: day)] = new
                self.schedule = s
            })
    }

    // MARK: – FETCH 7 DAY DOCS
    private func fetchSevenDaySchedules(from weekStart: Date, uid: String) {
        let cal = Calendar.current
        for offs in 0..<7 {
            if let day = cal.date(byAdding: .day, value: offs, to: weekStart) {
                fetchDaySchedule(for: day, uid: uid)
            }
        }
    }
    private func fetchDaySchedule(for day: Date, uid: String) {
        let key   = Calendar.current.startOfDay(for: day)
        let docID = Self.iso.string(from: key)
        db.collection("users").document(uid)
          .collection("daySchedules").document(docID)
          .getDocument(as: DaySchedule.self) { [weak self] res in
            guard let self else { return }
            let list = (try? res.get().priorities) ?? []
            self.dayPriorityStorage[key] = list
            self.dayPriorityStatus[key]  = (list.filter(\.isCompleted).count, list.count)
          }
    }
    private func persistDayPriorities(_ key: Date, _ list: [TodayPriority]) {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        dayPriorityStatus[key] = (list.filter(\.isCompleted).count, list.count)
        updateDayPriorities(date: key, priorities: list, userId: uid)
    }

    // MARK: – UTILITIES
    private func shortKey(for date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "E"
        return f.string(from: date)
    }

    // MARK: – DEFAULT BLANK WEEK CREATOR
    private func createDefaultWeekSchedule(startOfWeek: Date,
                                           userId uid: String,
                                           completion: @escaping ()->Void) {
        let docID = Self.iso.string(from: startOfWeek)
        let isoKey = WeeklySchedule.isoYearWeekString(from: startOfWeek)

        var intentions = [String:String]()
        var buckets    = [String:[ToDoItem]]()
        let cal = Calendar.current
        for offs in 0..<7 {
            let day = cal.date(byAdding: .day, value: offs, to: startOfWeek)!
            let label = shortKey(for: day)
            intentions[label] = ""
            buckets[label]    = []
        }

        let fresh = WeeklySchedule(
            id:            docID,
            userId:        uid,
            startOfWeek:   startOfWeek,
            anchorWeekday: Calendar.current.firstWeekday,
            weeklyPriorities: [],
            dailyIntentions:  intentions,
            dailyToDoLists:   buckets
        )

        try? db.collection("users")
              .document(uid)
              .collection("weekSchedules")
              .document(docID)
              .setData(from: fresh)

        schedule = fresh
        completion()
    }
}
