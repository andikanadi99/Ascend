//
//  HabitViewModel.swift
//  Mind Reset
//  Manages the fetching and updating of Habit data in Firestore.
//

import Foundation
import FirebaseFirestore
import Combine
import FirebaseAuth           // only if you want to guard ownerId == currentUser?.uid

class HabitViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var habits: [Habit] = []
    
    // MARK: - Firestore & Cancellations
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?

    // Optional for Combine
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Scoring System Constants
    private let dailyCompletionPoint = 1
    private let weeklyStreakBonus    = 10
    private let monthlyStreakBonus   = 50
    private let yearlyStreakBonus    = 100

    // MARK: - Date Formatter
    /// A simple date-only formatter (YYYY-MM-DD) used to compare lastReset with today's date.
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    // MARK: - Lifecycle
    init() {
        // Optionally perform an initial fetch, or nothing.
        // e.g. fetchHabits(for: someUserId) ...
    }

    deinit {
        listenerRegistration?.remove()
    }

    // MARK: - Fetch Habits
    /// Listens (in real-time) for habits in Firestore that belong to the given userId.
    func fetchHabits(for userId: String) {
        // If there's an existing listener, remove it before adding a new one
        listenerRegistration?.remove()

        listenerRegistration = db.collection("habits")
            .whereField("ownerId", isEqualTo: userId)
            .order(by: "startDate", descending: true)
            .addSnapshotListener { [weak self] querySnapshot, error in
                guard let self = self else { return }
                if let error = error {
                    print("Error fetching habits: \(error)")
                    return
                }
                // Convert the snapshot into an array of Habit
                self.habits = querySnapshot?.documents.compactMap { doc in
                    try? doc.data(as: Habit.self)
                } ?? []
            }
    }

    // MARK: - Add New Habit
    /// Creates a new habit in Firestore. Must have `habit.ownerId` == the user's UID.
    func addHabit(_ habit: Habit) {
        // Optional check that the habit.ownerId matches the current user (if you wish):
        /*
        guard let currentUid = Auth.auth().currentUser?.uid,
              habit.ownerId == currentUid else {
            print("Refusing to add Habit, because ownerId != current user's UID.")
            return
        }
        */

        do {
            // The `from: habit` uses Firestore's Codable support
            _ = try db.collection("habits").addDocument(from: habit)
            print("Added habit titled '\(habit.title)' for user: \(habit.ownerId)")
        } catch {
            print("Error adding habit: \(error.localizedDescription)")
        }
    }

    // MARK: - Update Existing Habit
    /// Overwrites habit data in Firestore.
    func updateHabit(_ habit: Habit) {
        guard let id = habit.id else {
            print("updateHabit: No ID found on Habit. Skipping.")
            return
        }
        // Optional check that the habit.ownerId matches the current user:
        /*
        guard let currentUid = Auth.auth().currentUser?.uid,
              habit.ownerId == currentUid else {
            print("Refusing to update Habit, because ownerId != current user's UID.")
            return
        }
        */

        do {
            try db.collection("habits").document(id).setData(from: habit)
            print("Updated habit ID: \(id) titled '\(habit.title)'")
        } catch {
            print("Error updating habit: \(error.localizedDescription)")
        }
    }

    // MARK: - Delete Habit
    /// Deletes a habit from Firestore and removes it locally.
    func deleteHabit(_ habit: Habit) {
        guard let id = habit.id else {
            print("deleteHabit: Habit ID is nil; cannot delete.")
            return
        }
        db.collection("habits").document(id).delete { [weak self] error in
            if let err = error {
                print("Error deleting habit: \(err)")
            } else {
                print("Successfully deleted habit with ID: \(id)")
                DispatchQueue.main.async {
                    // Remove from local array
                    self?.habits.removeAll { $0.id == id }
                }
            }
        }
    }

    // MARK: - Award Points
    /// Adds `points` to a user's totalPoints in the "users" collection.
    func awardPointsToUser(userId: String, points: Int) {
        let userRef = db.collection("users").document(userId)
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                // Try to get the user doc
                let userSnap = try transaction.getDocument(userRef)
                let currentPoints = userSnap.data()?["totalPoints"] as? Int ?? 0
                // Add the new points
                transaction.updateData(["totalPoints": currentPoints + points], forDocument: userRef)
            } catch {
                if let errPointer = errorPointer {
                    errPointer.pointee = error as NSError
                }
                return nil
            }
            return nil
        }) { (result, error) in
            if let err = error {
                print("Error awarding points: \(err)")
            } else {
                print("Points awarded successfully: +\(points)")
            }
        }
    }

    // MARK: - Default Habits Setup
    /// Checks if the user doc has `defaultHabitsCreated == true`. If not, it creates the 3 standard defaults.
    func setupDefaultHabitsIfNeeded(for userId: String) {
        let userRef = db.collection("users").document(userId)
        userRef.getDocument { [weak self] docSnapshot, error in
            if let error = error {
                print("Error fetching user doc: \(error)")
                return
            }
            guard let doc = docSnapshot, doc.exists else {
                print("No user doc found for \(userId); can't set up default habits.")
                return
            }
            let data = doc.data() ?? [:]
            let defaultsCreated = data["defaultHabitsCreated"] as? Bool ?? false

            if !defaultsCreated {
                print("No default habits yet; creating defaults for \(userId)...")
                self?.createDefaultHabits(for: userId)

                // Mark the user doc so we do not re-create next time
                userRef.updateData(["defaultHabitsCreated": true]) { err in
                    if let e = err {
                        print("Error updating defaultHabitsCreated: \(e)")
                    } else {
                        print("Default habits set for user: \(userId)")
                    }
                }
            } else {
                print("Default habits already exist for user \(userId); doing nothing.")
            }
        }
    }

    /// Creates the 3 standard default habits for a user’s first time.
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
                  ownerId: userId)
        ]

        for newHabit in defaultHabits {
            addHabit(newHabit)
        }
    }

    // MARK: - Daily Reset
    /// Clears `isCompletedToday` if a new calendar day has started.
    func dailyResetIfNeeded() {
        let todayStr = dateFormatter.string(from: Date())
        for var habit in habits {
            let lastResetStr = habit.lastReset == nil
                ? ""
                : dateFormatter.string(from: habit.lastReset!)

            if lastResetStr != todayStr {
                habit.isCompletedToday = false
                habit.lastReset        = Date()
                updateHabit(habit)
            }
        }
    }

    // MARK: - Toggle Completion
    /// Toggles the habit's completion status for the day, updates Firestore, and handles streak logic.
    func toggleHabitCompletion(_ habit: Habit, userId: String) {
        var updatedHabit = habit
        let todayStr = dateFormatter.string(from: Date())
        let lastResetStr = updatedHabit.lastReset == nil
            ? ""
            : dateFormatter.string(from: updatedHabit.lastReset!)

        if updatedHabit.isCompletedToday {
            // Unmark as done
            updatedHabit.isCompletedToday = false
            updatedHabit.currentStreak = max(updatedHabit.currentStreak - 1, 0)
            updatedHabit.lastReset = nil
        } else {
            // Mark as done
            if lastResetStr != todayStr {
                updatedHabit.currentStreak += 1
                updatedHabit.lastReset = Date()

                // Possibly update longest streak
                if updatedHabit.currentStreak > updatedHabit.longestStreak {
                    updatedHabit.longestStreak = updatedHabit.currentStreak
                }
            }
            updatedHabit.isCompletedToday = true
        }

        // Write changes to Firestore
        updateHabit(updatedHabit)

        // If newly marked as done, handle awarding points
        if updatedHabit.isCompletedToday {
            var totalPoints = dailyCompletionPoint + updatedHabit.currentStreak
            if updatedHabit.currentStreak == 7   { totalPoints += weeklyStreakBonus }
            if updatedHabit.currentStreak == 30  { totalPoints += monthlyStreakBonus }
            if updatedHabit.currentStreak == 365 { totalPoints += yearlyStreakBonus }

            awardPointsToUser(userId: userId, points: totalPoints)
        }
    }
}
