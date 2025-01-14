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
    
    // MARK: - Local Streak Dictionaries
    // Key: habitID, Value: local "currentStreak" or "longestStreak"
    @Published var localStreaks: [String: Int] = [:]
    @Published var localLongestStreaks: [String: Int] = [:]

    // MARK: - Firestore & Listener
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?

    // For Combine (optional)
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
        // Optionally do nothing until user logs in
    }

    deinit {
        listenerRegistration?.remove()
    }

    // MARK: - Fetch Habits
    func fetchHabits(for userId: String) {
        // Remove any previous listener
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

                let fetched: [Habit] = querySnapshot?.documents.compactMap { doc in
                    try? doc.data(as: Habit.self)
                } ?? []

                // Update local array
                self.habits = fetched

                // Sync localStreaks & localLongestStreaks if they’re behind
                for habit in fetched {
                    guard let habitID = habit.id else { continue }

                    // currentStreak
                    let localCurrent = self.localStreaks[habitID] ?? 0
                    if habit.currentStreak > localCurrent {
                        self.localStreaks[habitID] = habit.currentStreak
                    }

                    // longestStreak
                    let localLongest = self.localLongestStreaks[habitID] ?? 0
                    if habit.longestStreak > localLongest {
                        self.localLongestStreaks[habitID] = habit.longestStreak
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
                    self?.localStreaks.removeValue(forKey: id)
                    self?.localLongestStreaks.removeValue(forKey: id)
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

                // Mark defaultHabitsCreated = true in Firestore
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
        // Add them to Firestore
        for habit in defaultHabits {
            addHabit(habit)
        }

        // Also show them immediately in the local array so there's no delay.
        DispatchQueue.main.async {
            self.habits.append(contentsOf: defaultHabits)
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

                if let id = habit.id {
                    localStreaks[id]        = habit.currentStreak
                    localLongestStreaks[id] = habit.longestStreak
                }
            }
        }
    }

    // MARK: - Toggle Completion (LocalStreak + LocalLongestStreak + Optimistic)
    func toggleHabitCompletion(_ habit: Habit, userId: String) {
        guard
            let idx = habits.firstIndex(where: { $0.id == habit.id }),
            let habitId = habit.id
        else { return }

        let oldHabit = habits[idx]
        var updated  = habit

        // Decide if marking or unmarking
        if updated.isCompletedToday {
            // Unmark
            updated.isCompletedToday = false

            // currentStreak
            updated.currentStreak = max(updated.currentStreak - 1, 0)

            // If the user's longestStreak was directly 'tied' to currentStreak,
            // we reduce it if applicable:
            if updated.currentStreak < updated.longestStreak,
               oldHabit.currentStreak == oldHabit.longestStreak {
                // Subtract by 1, or set to updated.currentStreak
                updated.longestStreak = updated.currentStreak
            }

            updated.lastReset = nil
        } else {
            // Mark as done
            let todayStr = dateFormatter.string(from: Date())
            let lastResetStr = updated.lastReset == nil
                ? ""
                : dateFormatter.string(from: updated.lastReset!)

            if lastResetStr != todayStr {
                updated.currentStreak += 1
                // Possibly update longestStreak if needed
                if updated.currentStreak > updated.longestStreak {
                    updated.longestStreak = updated.currentStreak
                }
                updated.lastReset = Date()
            }
            updated.isCompletedToday = true
        }

        // 1) Update localStreaks & localLongestStreaks immediately
        let localVal = localStreaks[habitId] ?? habit.currentStreak
        let localLongestVal = localLongestStreaks[habitId] ?? habit.longestStreak

        if habit.isCompletedToday {
            // We are unmarking
            localStreaks[habitId] = max(localVal - 1, 0)

            // If oldHabit was "equal" => reduce localLongest
            if oldHabit.currentStreak == oldHabit.longestStreak,
               (localStreaks[habitId] ?? 0) < (localLongestVal)
            {
                // Subtract or set to new localStreak
                localLongestStreaks[habitId] = localStreaks[habitId] ?? 0
            }

        } else {
            // We are marking as done
            localStreaks[habitId] = localVal + 1

            // If new currentStreak > localLongestVal => update
            if (localStreaks[habitId] ?? 0) > localLongestVal {
                localLongestStreaks[habitId] = (localStreaks[habitId] ?? 0)
            }
        }

        // 2) Optimistic update of main array
        habits[idx] = updated

        // 3) Write to Firestore
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

            // Revert localStreaks
            localStreaks[habitId]        = oldHabit.currentStreak
            localLongestStreaks[habitId] = oldHabit.longestStreak
        }
    }
}
