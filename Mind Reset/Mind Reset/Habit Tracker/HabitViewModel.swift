//
//  HabitViewModel.swift
//  Mind Reset
//  Manages the fetching and updating of Habit data in Firestore.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine

class HabitViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var habits: [Habit] = []
    @Published var errorMessage: String? = nil
    
    // MARK: - Local Streak Dictionary
    // Key: habit.id, Value: local 'currentStreak'
    @Published var localStreaks: [String: Int] = [:]

    // MARK: - Firestore & Listener
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?

    // Combine (optional)
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Scoring System Constants
    private let dailyCompletionPoint = 1
    private let weeklyStreakBonus    = 10
    private let monthlyStreakBonus   = 50
    private let yearlyStreakBonus    = 100

    // MARK: - Date Formatter
    private let dateFormatter: DateFormatter = {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        return fmt
    }()

    // MARK: - Lifecycle
    init() {
        // Possibly do nothing until a user ID is known
    }

    deinit {
        listenerRegistration?.remove()
    }

    // MARK: - Fetch Habits
    func fetchHabits(for userId: String) {
        listenerRegistration?.remove()

        listenerRegistration = db.collection("habits")
            .whereField("ownerId", isEqualTo: userId)
            .order(by: "startDate", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                if let err = error {
                    print("Error fetching habits: \(err)")
                    self.errorMessage = "Failed to fetch habits."
                    return
                }
                // Convert snapshot into [Habit]
                let fetched: [Habit] = querySnapshot?.documents.compactMap { doc in
                    try? doc.data(as: Habit.self)
                } ?? []

                // Update local array
                self.habits = fetched

                // For each habit, also sync localStreaks if needed
                for habit in fetched {
                    guard let habitID = habit.id else { continue }
                    // If there's no localStreak, or localStreak is out-of-date,
                    // we can sync from the Firestore-provided habit
                    let currentLocal = self.localStreaks[habitID] ?? 0
                    if habit.currentStreak > currentLocal {
                        // Overwrite the local with the higher official streak
                        self.localStreaks[habitID] = habit.currentStreak
                    }
                    else if habit.currentStreak < currentLocal {
                        // Possibly we had a local increase that isn't reflected in Firestore yet,
                        // so keep the localStreak. (This is optional logic.)
                    }
                }
            }
    }

    // MARK: - Add New Habit
    func addHabit(_ habit: Habit) {
        do {
            _ = try db.collection("habits").addDocument(from: habit)
            print("Habit '\(habit.title)' added for user \(habit.ownerId).")
        } catch {
            print("Error adding habit: \(error.localizedDescription)")
            self.errorMessage = "Failed to add habit."
        }
    }

    // MARK: - Update Existing Habit
    func updateHabit(_ habit: Habit) {
        guard let id = habit.id else { return }
        do {
            try db.collection("habits").document(id).setData(from: habit)
            print("Habit '\(habit.title)' updated (ID: \(id)).")
        } catch {
            print("Error updating habit: \(error.localizedDescription)")
            self.errorMessage = "Failed to update habit."
        }
    }

    // MARK: - Delete Habit
    func deleteHabit(_ habit: Habit) {
        guard let id = habit.id else {
            print("Cannot delete: Habit has no ID.")
            self.errorMessage = "Failed to delete habit (no ID)."
            return
        }
        db.collection("habits").document(id).delete { [weak self] err in
            if let e = err {
                print("Error deleting habit: \(e)")
                self?.errorMessage = "Failed to delete habit."
            } else {
                print("Habit (ID: \(id)) deleted successfully.")
                DispatchQueue.main.async {
                    self?.habits.removeAll { $0.id == id }
                    self?.localStreaks.removeValue(forKey: id) // Also remove local streak
                }
            }
        }
    }

    // MARK: - Award Points
    func awardPointsToUser(userId: String, points: Int) {
        let userRef = db.collection("users").document(userId)
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                let userSnap = try transaction.getDocument(userRef)
                let currentPoints = userSnap.data()?["totalPoints"] as? Int ?? 0
                transaction.updateData(["totalPoints": currentPoints + points], forDocument: userRef)
            } catch {
                if let errPointer = errorPointer {
                    errPointer.pointee = error as NSError
                }
                return nil
            }
            return nil
        }) { (result, error) in
            if let e = error {
                print("Error awarding points: \(e)")
                self.errorMessage = "Failed to award points."
            } else {
                print("Points awarded successfully: +\(points)")
            }
        }
    }

    // MARK: - Default Habits Setup
    func setupDefaultHabitsIfNeeded(for userId: String) {
        let userRef = db.collection("users").document(userId)
        userRef.getDocument { [weak self] snapshot, err in
            if let e = err {
                print("Error fetching user doc: \(e)")
                return
            }
            guard let doc = snapshot, doc.exists else {
                print("No user doc found for \(userId). Skipping default habits.")
                return
            }
            let data = doc.data() ?? [:]
            let defaultsCreated = data["defaultHabitsCreated"] as? Bool ?? false
            if !defaultsCreated {
                print("Creating default habits for user: \(userId).")
                self?.createDefaultHabits(for: userId)

                userRef.updateData(["defaultHabitsCreated": true]) { updateErr in
                    if let ue = updateErr {
                        print("Error updating defaultHabitsCreated: \(ue)")
                    } else {
                        print("Default habits set for user: \(userId).")
                    }
                }
            } else {
                print("Default habits already exist for \(userId). Doing nothing.")
            }
        }
    }

    private func createDefaultHabits(for userId: String) {
        let defaultHabits: [Habit] = [
            Habit(title: "Meditation",
                  description: "Spend 10 minutes meditating",
                  startDate: Date(),
                  ownerId: userId),
            Habit(title: "Exercise",
                  description: "Do some physical activity",
                  startDate: Date(),
                  ownerId: userId),
            Habit(title: "Journaling",
                  description: "Write down your thoughts",
                  startDate: Date(),
                  ownerId: userId),
        ]
        for habit in defaultHabits {
            addHabit(habit)
        }
    }

    // MARK: - Daily Reset
    func dailyResetIfNeeded() {
        let todayString = dateFormatter.string(from: Date())
        for var habit in habits {
            let lastResetString = habit.lastReset == nil
                ? ""
                : dateFormatter.string(from: habit.lastReset!)
            if lastResetString != todayString {
                habit.isCompletedToday = false
                habit.lastReset        = Date()
                updateHabit(habit)

                // Also update localStreaks if you want to unify them
                if let id = habit.id {
                    localStreaks[id] = habit.currentStreak
                }
            }
        }
    }

    // MARK: - Toggle Completion (LocalStreak + Optimistic Update)
    func toggleHabitCompletion(_ habit: Habit, userId: String) {
        guard
            let idx = habits.firstIndex(where: { $0.id == habit.id }),
            let habitId = habit.id
        else { return }

        let oldHabit = habits[idx]
        var updated  = habit

        if updated.isCompletedToday {
            // Unmark as done
            updated.isCompletedToday = false
            updated.currentStreak    = max(updated.currentStreak - 1, 0)
            updated.lastReset        = nil
        } else {
            // Mark as done
            let todayStr = dateFormatter.string(from: Date())
            let lastResetStr = updated.lastReset == nil
                ? ""
                : dateFormatter.string(from: updated.lastReset!)

            if lastResetStr != todayStr {
                updated.currentStreak += 1
                if updated.currentStreak > updated.longestStreak {
                    updated.longestStreak = updated.currentStreak
                }
                updated.lastReset = Date()
            }
            updated.isCompletedToday = true
        }

        // 1) Update localStreaks right away
        let localVal = localStreaks[habitId] ?? habit.currentStreak
        // If unmarking
        if habit.isCompletedToday {
            localStreaks[habitId] = max(localVal - 1, 0)
        } else {
            localStreaks[habitId] = localVal + 1
        }

        // 2) Optimistic update of the main array
        habits[idx] = updated
        
        // 3) Firestore
        do {
            try db.collection("habits").document(habitId).setData(from: updated)
            // If newly done => award points
            if updated.isCompletedToday {
                var totalPoints = dailyCompletionPoint + updated.currentStreak
                if updated.currentStreak == 7   { totalPoints += weeklyStreakBonus }
                if updated.currentStreak == 30  { totalPoints += monthlyStreakBonus }
                if updated.currentStreak == 365 { totalPoints += yearlyStreakBonus }

                awardPointsToUser(userId: userId, points: totalPoints)
            }

        } catch {
            // 4) Revert on failure
            print("Error updating habit in Firestore: \(error.localizedDescription)")
            habits[idx] = oldHabit
            // revert localStreaks too
            if let oldID = oldHabit.id {
                localStreaks[oldID] = oldHabit.currentStreak
            }
        }
    }
}
