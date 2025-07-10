//  DayViewModel.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 3/25/25.
//

import SwiftUI
import FirebaseFirestore
import FirebaseAuth
import Combine

class DayViewModel: ObservableObject {
    @Published var scheduleMeta: DaySchedule?      // wake/sleep/priorities
    @Published var blocks: [TimelineBlock] = []    // draggable blocks
    
    @Published var isLoadingDay = false
    private var metaDidRespond   = false
    private var blocksDidRespond = false
    
    private let db = Firestore.firestore()
    private var metaListener:   ListenerRegistration?
    private var blocksListener: ListenerRegistration?
    
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
        metaListener?.remove()
        blocksListener?.remove()
    }

    func loadDay(for date: Date, userId: String) {
        clearLocalState()

        let dayId  = DayViewModel.isoFormatter.string(
                       from: Calendar.current.startOfDay(for: date))
        let dayDoc = db.collection("users").document(userId)
                       .collection("days").document(dayId)

        // META listener
        metaListener?.remove()
        metaListener = dayDoc.addSnapshotListener { [weak self] snap, err in
            guard let self = self else { return }
            if let err = err {
                print("meta listen:", err)
                return
            }
            self.decodeQueue.async {
                if let d = snap, d.exists,
                   let meta = try? d.data(as: DaySchedule.self) {
                    // 1) Found an existing schedule in Firestore
                    DispatchQueue.main.async {
                        self.scheduleMeta     = meta
                        self.metaDidRespond   = true
                        self.tryFinishLoading()
                    }
                } else {
                    // 2) No doc → create default, then treat that as “response”
                    self.createDefaultMeta(for: date, userId: userId)
                    DispatchQueue.main.async {
                        self.metaDidRespond   = true
                        self.tryFinishLoading()
                    }
                }
            }
        }


        // BLOCKS listener
        blocksListener?.remove()
            blocksListener = dayDoc.collection("blocks")
              .addSnapshotListener { [weak self] snap, _ in
                guard let self = self else { return }
                self.decodeQueue.async {
                  let arr = snap?.documents.compactMap {
                    try? $0.data(as: TimelineBlock.self)
                  } ?? []
                  DispatchQueue.main.async {
                    self.blocks = arr.sorted { $0.start < $1.start }
                    self.blocksDidRespond = true    // mark we got blocks (even if empty)
                    self.tryFinishLoading()
                  }
                }
              }
      }
    private func tryFinishLoading() {
        // once we've heard back from both listeners, stop loading
        if metaDidRespond && blocksDidRespond {
          isLoadingDay = false
          // no need to reset the flags here unless you reload again
        }
      }
    
    private var metaLoaded  = false
      private var blocksLoaded = false

      private func finishLoadingIfReady() {
        // Called once per listener callback
        if scheduleMeta != nil { metaLoaded = true }
        if !blocks.isEmpty   { blocksLoaded = true }
        if metaLoaded && blocksLoaded {
          isLoadingDay = false
          // reset flags for next load
          metaLoaded = false
          blocksLoaded = false
        }
      }
    
    func clearLocalState() {
        DispatchQueue.main.async {
          self.scheduleMeta = nil
          self.blocks       = []
          self.isLoadingDay = true
          // reset our “we’ve heard back” flags
          self.metaDidRespond   = false
          self.blocksDidRespond = false
        }
      }

    // REPLACE the placeholder section inside createDefaultMeta
    private func createDefaultMeta(for date: Date, userId: String) {
        let startOfDay = Calendar.current.startOfDay(for: date)
        let dayId      = DayViewModel.isoFormatter.string(from: startOfDay)

        // Default wake/sleep pulled from UserDefaults (or fallbacks)
        let storedWake = UserDefaults.standard
            .object(forKey: "DefaultWakeUpTime") as? Date
            ?? Calendar.current.date(bySettingHour: 7, minute: 0, second: 0, of: date)!
        let storedSleep = UserDefaults.standard
            .object(forKey: "DefaultSleepTime") as? Date
            ?? Calendar.current.date(bySettingHour: 22, minute: 0, second: 0, of: date)!

        // Build a DaySchedule _without_ an ID so Firestore's @DocumentID stays nil
        let meta = DaySchedule(
                id:         dayId,          // ← pass the string ID directly
                userId:     userId,
                date:       startOfDay,
                wakeUpTime: storedWake,
                sleepTime:  storedSleep,
                priorities: [],
                timeBlocks: []
            )

        do {
               // Firestore will ignore @DocumentID on writes, so no conflict
               try db
                 .collection("users").document(userId)
                 .collection("days").document(dayId)
                 .setData(from: meta)

               DispatchQueue.main.async {
                   self.scheduleMeta = meta
               }
           } catch {
               print("Error creating default day meta:", error)
           }
       }



    func pushMeta() {
        guard let meta = scheduleMeta, let id = meta.id else { return }
        do {
            try db.collection("users").document(meta.userId)
                .collection("days").document(id)
                .setData(from: meta)
        } catch { print("pushMeta error:", error) }
    }


    // MARK: – Toggle Completion on a Priority
    func togglePriorityCompletion(_ id: UUID) {
        guard var sched = scheduleMeta,
              let idx = sched.priorities.firstIndex(where: { $0.id == id }) else { return }

        let nowCompleted = !sched.priorities[idx].isCompleted
        sched.priorities[idx].isCompleted = nowCompleted
        sched.priorities[idx].progress    = nowCompleted ? 1.0 : 0.0

        scheduleMeta = sched
        pushMeta()   // ← replaces updateDaySchedule()
    }

    // ─────────────────────────────────────────────────────────
    // MARK: – Timeline integration
    // ─────────────────────────────────────────────────────────
    /// Formatter for converting a TimelineBlock’s start Date
    /// into our “HH:mm” labels.
    private static let timelineFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm"
        return fmt
    }()


    // MARK: – Reorder priorities
    func movePriorities(indices: IndexSet, to newOffset: Int) {
        guard var sched = scheduleMeta else { return }
        sched.priorities.move(fromOffsets: indices, toOffset: newOffset)
        scheduleMeta = sched
        pushMeta()
    }

    // MARK: — Helpers
    func deleteAllBlocks(for date: Date, userId: String, completion: @escaping () -> Void = {}) {
        let dayId = DayViewModel.isoFormatter.string(
                      from: Calendar.current.startOfDay(for: date))
        let coll  = db.collection("users")
                       .document(userId)
                       .collection("days")
                       .document(dayId)
                       .collection("blocks")

        coll.getDocuments { [weak self] snap, err in
            guard let self = self else { completion(); return }
            if let err = err {
                print("deleteAllBlocks:", err); completion(); return
            }
            let batch = self.db.batch()
            snap?.documents.forEach { batch.deleteDocument($0.reference) }
            batch.commit { _ in
                DispatchQueue.main.async { self.blocks = [] }
                completion()
            }
        }
    }

    @MainActor
    func replaceBlocks(_ newBlocks: [TimelineBlock], for date: Date) {
        // 1) Normalize date to midnight
        let key = Calendar.current.startOfDay(for: date)

        // 2) Ensure we have a signed-in user
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // 3) Build Firestore collection reference for that day’s blocks
        let dayID = Self.isoFormatter.string(from: key)
        let colRef = db
            .collection("users")
            .document(uid)
            .collection("days")
            .document(dayID)
            .collection("blocks")

        // 4) Upsert each block document
        for blk in newBlocks {
            try? colRef.document(blk.id.uuidString).setData(from: blk)
        }

        // 5) Remove any Firestore docs no longer in newBlocks
        colRef.getDocuments { snapshot, _ in
            snapshot?.documents.forEach { doc in
                if !newBlocks.contains(where: { $0.id.uuidString == doc.documentID }) {
                    doc.reference.delete()
                }
            }
        }

        // 6) Update published `blocks` so SwiftUI refreshes immediately
        DispatchQueue.main.async {
            self.blocks = newBlocks
        }
    }


    func copyPreviousDayBlocks(
        to targetDate: Date,
        userId: String,
        completion: @escaping (_ added: Int) -> Void = { _ in }
    ) {
        let cal        = Calendar.current
        let sourceDate = cal.date(byAdding: .day, value: -1, to: targetDate)!
        let sourceId   = DayViewModel.isoFormatter.string(
                           from: cal.startOfDay(for: sourceDate))
        let targetId   = DayViewModel.isoFormatter.string(
                           from: cal.startOfDay(for: targetDate))

        let sourceColl = self.db.collection("users").document(userId)
                           .collection("days").document(sourceId)
                           .collection("blocks")
        let targetColl = self.db.collection("users").document(userId)
                           .collection("days").document(targetId)
                           .collection("blocks")

        sourceColl.getDocuments { [weak self] sourceSnap, error in
            guard let self = self else { completion(0); return }
            guard let sourceDocs = sourceSnap?.documents else {
                completion(0); return
            }

            targetColl.getDocuments { [weak self] targetSnap, _ in
                guard let self = self else { completion(0); return }
                let existingIDs = Set(targetSnap?.documents.map { $0.documentID } ?? [])
                let batch = self.db.batch()      // ← explicit self.db
                var addedCount = 0

                for doc in sourceDocs {
                    let id = doc.documentID
                    if existingIDs.contains(id) { continue }
                    if let block = try? doc.data(as: TimelineBlock.self) {
                        let ref = targetColl.document(id)
                        do {
                            try batch.setData(from: block, forDocument: ref)
                            addedCount += 1
                        } catch {
                            print("Batch setData error:", error)
                        }
                    }
                }

                batch.commit { err in
                    if let err = err {
                        print("Batch commit error:", err)
                    }
                    completion(addedCount)
                }
            }
        }
    }

    
    func upsertBlock(_ block: TimelineBlock) {
        guard let meta = scheduleMeta, let dayId = meta.id else { return }
        let ref = db.collection("users").document(meta.userId)
                    .collection("days").document(dayId)
                    .collection("blocks").document(block.id.uuidString)
        try? ref.setData(from: block)
    }

    func deleteBlock(id: UUID) {
        guard let meta = scheduleMeta, let dayId = meta.id else { return }
        db.collection("users").document(meta.userId)
          .collection("days").document(dayId)
          .collection("blocks").document(id.uuidString)
          .delete(completion: nil)
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

        let docRef = db.collection("users").document(userId)
            .collection("days").document(docId)

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
