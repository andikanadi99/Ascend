//
//  HabitViewModel.swift
//  Mind Reset
//  Habit model for the habit tracker on the app.
//  Created by Andika Yudhatrisna on 12/1/24.
//

import Foundation
import FirebaseFirestore
import Combine

class HabitViewModel: ObservableObject {
    @Published var habits: [Habit] = []
    private var db = Firestore.firestore()
    private var listenerRegistration: ListenerRegistration?
    
    // MARK: - Scoring System Constants
    private let dailyCompletionPoint = 1
    private let weeklyStreakBonus = 10
    private let monthlyStreakBonus = 50
    private let yearlyStreakBonus = 100 // Example value
    
    // MARK: - Date Formatter
    // Ensures only day, month, year are compared
    private var dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd" // Adjust as needed
        return formatter
    }()
    
    // MARK: - Fetch Habits
    func fetchHabits(for userId: String) {
        listenerRegistration = db.collection("habits")
            .whereField("ownerId", isEqualTo: userId)
            .order(by: "startDate", descending: true)
            .addSnapshotListener { [weak self] (querySnapshot, error) in
                if let error = error {
                    print("Error fetching habits: \(error)")
                    return
                }
                self?.habits = querySnapshot?.documents.compactMap { document in
                    try? document.data(as: Habit.self)
                } ?? []
            }
    }

    // MARK: - Add New Habit
    func addHabit(_ habit: Habit) {
        do {
            _ = try db.collection("habits").addDocument(from: habit)
        } catch {
            print("Error adding habit: \(error)")
        }
    }

    // MARK: - Update Existing Habit
    func updateHabit(_ habit: Habit) {
        guard let id = habit.id else { return }
        do {
            try db.collection("habits").document(id).setData(from: habit)
        } catch {
            print("Error updating habit: \(error)")
        }
    }

    // MARK: - Delete Habit
    func deleteHabit(_ habit: Habit) {
        guard let id = habit.id else {
            print("Habit ID is nil, cannot delete.")
            return
        }
        db.collection("habits").document(id).delete { [weak self] error in
            if let error = error {
                print("Error deleting habit: \(error)")
            } else {
                print("Successfully deleted habit with ID: \(id)")
                DispatchQueue.main.async {
                    self?.habits.removeAll { $0.id == id }
                }
            }
        }
    }

    // MARK: - Award Points
    func awardPointsToUser(userId: String, points: Int) {
        let userRef = db.collection("users").document(userId)
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            do {
                let userSnapshot = try transaction.getDocument(userRef)
                let currentPoints = userSnapshot.data()?["totalPoints"] as? Int ?? 0
                transaction.updateData(["totalPoints": currentPoints + points], forDocument: userRef)
            } catch {
                if let errPointer = errorPointer {
                    errPointer.pointee = error as NSError
                }
                return nil
            }
            return nil
        }) { (result, error) in
            if let error = error {
                print("Error awarding points: \(error)")
            } else {
                print("Points awarded successfully.")
            }
        }
    }

    // MARK: - Default Habits Setup

    /// Checks the user doc for `defaultHabitsCreated`.
    /// If false, inserts default habits and sets it to true.
    func setupDefaultHabitsIfNeeded(for userId: String) {
        let userRef = db.collection("users").document(userId)

        userRef.getDocument { [weak self] document, error in
            if let error = error {
                print("Error fetching user doc: \(error)")
                return
            }
            guard let doc = document, doc.exists else {
                print("No user doc found; cannot set up default habits.")
                return
            }
            let data = doc.data()
            let defaultsCreated = data?["defaultHabitsCreated"] as? Bool ?? false

            if !defaultsCreated {
                // Insert the 3 default habits
                self?.createDefaultHabits(for: userId)

                // Update `defaultHabitsCreated` to true
                userRef.updateData(["defaultHabitsCreated": true]) { updateError in
                    if let e = updateError {
                        print("Error updating user doc with defaultHabitsCreated: \(e)")
                    } else {
                        print("defaultHabitsCreated set to true for user: \(userId)")
                    }
                }
            } else {
                print("Default habits already created for user: \(userId). Doing nothing.")
            }
        }
    }

    /// Inserts the three standard default habits for a new user.
    private func createDefaultHabits(for userId: String) {
        let defaultHabits = [
            Habit(
                id: nil,
                title: "Meditation",
                description: "Spend 10 minutes meditating",
                startDate: Date(),
                ownerId: userId,
                isCompletedToday: false,
                lastReset: nil,
                points: 0,
                currentStreak: 0,
                longestStreak: 0,
                weeklyStreakBadge: false,
                monthlyStreakBadge: false,
                yearlyStreakBadge: false
            ),
            Habit(
                id: nil,
                title: "Exercise",
                description: "Do some physical activity",
                startDate: Date(),
                ownerId: userId,
                isCompletedToday: false,
                lastReset: nil,
                points: 0,
                currentStreak: 0,
                longestStreak: 0,
                weeklyStreakBadge: false,
                monthlyStreakBadge: false,
                yearlyStreakBadge: false
            ),
            Habit(
                id: nil,
                title: "Journaling",
                description: "Write down your thoughts",
                startDate: Date(),
                ownerId: userId,
                isCompletedToday: false,
                lastReset: nil,
                points: 0,
                currentStreak: 0,
                longestStreak: 0,
                weeklyStreakBadge: false,
                monthlyStreakBadge: false,
                yearlyStreakBadge: false
            )
        ]
        for habit in defaultHabits {
            addHabit(habit)
        }
    }

    // MARK: - Daily Reset
    /// Resets the `isCompletedToday` flag for all habits if a new day has started.
    func dailyResetIfNeeded() {
        let todayString = dateFormatter.string(from: Date())

        // For each habit that’s loaded, check if we need to reset
        for habit in habits {
            // Compare lastReset to today’s date
            let habitLastResetString = habit.lastReset == nil
                ? ""
                : dateFormatter.string(from: habit.lastReset!)

            // If we haven't reset this habit today
            if habitLastResetString != todayString {
                // Make a copy
                var updatedHabit = habit
                updatedHabit.isCompletedToday = false
                updatedHabit.lastReset = Date()
                // Update in Firestore
                updateHabit(updatedHabit)
            }
        }
    }

    // MARK: - Toggle Habit Completion
    /// Toggles the completion status of a habit for today and updates points and streaks accordingly.
    /// - Parameters:
    ///   - habit: The habit to toggle.
    ///   - userId: The ID of the current user.
    func toggleHabitCompletion(_ habit: Habit, userId: String) {
        var updatedHabit = habit
        let todayString = dateFormatter.string(from: Date())

        // Handle unmarking habit as done
        if updatedHabit.isCompletedToday {
            updatedHabit.isCompletedToday = false
            updatedHabit.currentStreak = max(updatedHabit.currentStreak - 1, 0) // Decrement streak by 1
            updatedHabit.lastReset = nil // Reset the last reset date for the day
        } else {
            // Handle marking habit as done
            let habitLastResetString = updatedHabit.lastReset == nil
                ? ""
                : dateFormatter.string(from: updatedHabit.lastReset!)

            if habitLastResetString != todayString {
                updatedHabit.currentStreak += 1 // Increment streak by 1
                updatedHabit.lastReset = Date() // Set last reset date to today
            }

            updatedHabit.isCompletedToday = true
        }

        // Update habit in Firestore
        updateHabit(updatedHabit)

        // Handle points only when marking as done
        if updatedHabit.isCompletedToday {
            var totalAwardedPoints = dailyCompletionPoint + updatedHabit.currentStreak
            if updatedHabit.currentStreak == 7 {
                totalAwardedPoints += weeklyStreakBonus
            }
            if updatedHabit.currentStreak == 30 {
                totalAwardedPoints += monthlyStreakBonus
            }
            if updatedHabit.currentStreak == 365 {
                totalAwardedPoints += yearlyStreakBonus
            }
            awardPointsToUser(userId: userId, points: totalAwardedPoints)
        }
    }

    
    // MARK: - Deinit
    deinit {
        listenerRegistration?.remove()
    }
}
