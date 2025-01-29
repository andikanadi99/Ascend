//
//  HabitViewModel.swift
//  Mind Reset
//  Manages the fetching and updating of Habit data in Firestore with customizable metrics.
//
//  Created by Andika Yudhatrisna on 1/3/25.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth
import Combine
import SwiftUI

// MARK: - HabitViewModel
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
            .addSnapshotListener { [weak self] (querySnapshot, error) in
                guard let self = self else { return }
                
                if let error = error {
                    print("Error fetching habits: \(error.localizedDescription)")
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to fetch habits."
                    }
                    return
                }
                
                guard let documents = querySnapshot?.documents else {
                    print("No habits found.")
                    DispatchQueue.main.async {
                        self.habits = []
                    }
                    return
                }
                
                self.habits = documents.compactMap { doc in
                    do {
                        let habit = try doc.data(as: Habit.self)
                        return habit
                    } catch {
                        print("Error decoding habit (ID: \(doc.documentID)): \(error.localizedDescription)")
                        return nil
                    }
                }
                
                // Sync localStreaks & localLongestStreaks if they’re behind
                for habit in self.habits {
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
    
    // MARK: - Add New Habit with Completion Handler
    func addHabit(_ habit: Habit, completion: @escaping (Bool) -> Void) {
        guard let userId = Auth.auth().currentUser?.uid else {
            print("No authenticated user; cannot add habit.")
            completion(false)
            return
        }
        
        do {
            // Use FirestoreSwift's Codable conformance to add document
            try db.collection("habits").addDocument(from: habit) { error in
                if let error = error {
                    print("Error adding habit: \(error.localizedDescription)")
                    completion(false)
                } else {
                    // No need to manually fetch; listener will handle it
                    completion(true)
                }
            }
        } catch {
            print("Error encoding habit: \(error.localizedDescription)")
            completion(false)
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
            DispatchQueue.main.async {
                self.errorMessage = "Failed to update habit."
            }
        }
    }
    
    // MARK: - Delete Habit
    func deleteHabit(_ habit: Habit) {
        guard let id = habit.id else {
            print("Cannot delete: Habit has no ID.")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to delete habit (no ID)."
            }
            return
        }
        db.collection("habits").document(id).delete { [weak self] err in
            if let e = err {
                print("Error deleting habit: \(e)")
                DispatchQueue.main.async {
                    self?.errorMessage = "Failed to delete habit."
                }
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
                print("Error awarding points: \(e.localizedDescription)")
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to award points."
                }
            } else {
                print("Points awarded successfully: +\(points)")
            }
        }
    }
    
    // MARK: - Default Habits Setup
    func setupDefaultHabitsIfNeeded(for userId: String) {
        let userRef = db.collection("users").document(userId)
        userRef.getDocument { [weak self] snapshot, err in
            guard let self = self else { return }
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
                self.createDefaultHabits(for: userId)
                
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
            
            // Physical Health & Fitness
            Habit(
                title: "Daily Walk",
                description: "Take a short walk outside to increase overall health and physical well-being.",
                goal: "Promote an active lifestyle and improve physical health.",
                startDate: Date(),
                ownerId: userId,
                metricCategory: .quantity,
                metricType: QuantityMetric.distanceMiles.rawValue,
                targetValue: 1.0,
                dailyRecords: []
            ),
            
            // Learning & Skill Development
            Habit(
                title: "Reading",
                description: "Read for a specific amount of time or pages to improve and learn new things.",
                goal: "Encourage knowledge acquisition and mental stimulation.",
                startDate: Date(),
                ownerId: userId,
                metricCategory: .quantity,
                metricType: QuantityMetric.pagesRead.rawValue,
                targetValue: 20.0,
                dailyRecords: []
            ),
            
            // Creativity & Self-Expression
            Habit(
                title: "Journaling",
                description: "Write down your thoughts and feelings to enhance mindfulness and self-reflection.",
                goal: "Promote self-awareness and personal growth.",
                startDate: Date(),
                ownerId: userId,
                metricCategory: .quantity,
                metricType: QuantityMetric.entriesWritten.rawValue,
                targetValue: 1.0,
                dailyRecords: []
            ),
            
            // Productivity & Organization
            Habit(
                title: "Plan Daily Tasks",
                description: "Plan and organize your daily tasks to ensure efficiency throughout the day.",
                goal: "Increase productivity and manage stress effectively.",
                startDate: Date(),
                ownerId: userId,
                metricCategory: .completion,
                metricType: CompletionMetric.completed.rawValue,
                targetValue: 1.0,
                dailyRecords: []
            ),
            // Mindfulness & Mental Well-being
            Habit(
                title: "Meditation",
                description: "Practice mindfulness through meditation, focus on your breath, or other techniques.",
                goal: "Reduce stress, enhance focus, and promote emotional well-being.",
                startDate: Date(),
                ownerId: userId,
                metricCategory: .time,
                metricType: TimeMetric.minutes.rawValue,
                targetValue: 10.0,
                dailyRecords: []
            )
        ]
        // Add them to Firestore
        for habit in defaultHabits {
            addHabit(habit) { success in
                if success {
                    print("Default habit '\(habit.title)' added successfully.")
                } else {
                    print("Failed to add default habit '\(habit.title)'.")
                }
            }
        }
        
        // Also append them locally to avoid waiting for Firestore listener
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
                // Set longestStreak to the new currentStreak
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
                // Update longestStreak if needed
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
                // Set localLongestStreak to new localStreak
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
            DispatchQueue.main.async {
                self.habits[idx] = oldHabit
                
                // Revert localStreaks
                self.localStreaks[habitId]        = oldHabit.currentStreak
                self.localLongestStreaks[habitId] = oldHabit.longestStreak
                self.errorMessage = "Failed to update habit."
            }
        }
    }
}
