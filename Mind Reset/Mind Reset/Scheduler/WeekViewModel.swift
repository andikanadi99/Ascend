//
//  WeekViewModel.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 3/26/25.
//

import SwiftUI
import Firebase
import FirebaseFirestore

class WeekViewModel: ObservableObject {
    @Published var schedule: WeeklySchedule?
    
    private let db = Firestore.firestore()
    
    // We'll store a doc with an ID like "2025-03-23" (the startOfWeek),
    // or "year-14" for (2025 week #14), whichever you prefer.
    func loadWeeklySchedule(for startOfWeek: Date, userId: String) {
        let docId = isoWeekString(from: startOfWeek)
        
        db.collection("users")
            .document(userId)
            .collection("weekSchedules")
            .document(docId)
            .getDocument { [weak self] snapshot, error in
                if let error = error {
                    print("Error loading weekly schedule: \(error)")
                    return
                }
                
                if let snapshot = snapshot, snapshot.exists {
                    // decode existing doc
                    do {
                        let schedule = try snapshot.data(as: WeeklySchedule.self)
                        DispatchQueue.main.async {
                            self?.schedule = schedule
                        }
                    } catch {
                        print("Error decoding WeeklySchedule: \(error)")
                    }
                } else {
                    // create a default doc
                    self?.createDefaultWeekSchedule(startOfWeek: startOfWeek, userId: userId)
                }
            }
    }
    
    private func createDefaultWeekSchedule(startOfWeek: Date, userId: String) {
        let docId = isoWeekString(from: startOfWeek)
        // Create default daily intentions for each day
        let days = ["Sun","Mon","Tue","Wed","Thu","Fri","Sat"]
        var defaultIntentions: [String: String] = [:]
        var defaultToDoLists: [String: [ToDoItem]] = [:]
        
        for day in days {
            defaultIntentions[day] = ""
            defaultToDoLists[day] = []
        }
        
        let newSchedule = WeeklySchedule(
            id: docId,
            userId: userId,
            startOfWeek: startOfWeek,
            weeklyPriorities: [
                WeeklyPriority(id: UUID(), title: "Weekly Goals", progress: 0.0)
            ],
            dailyIntentions: defaultIntentions,
            dailyToDoLists: defaultToDoLists
        )
        
        do {
            try db.collection("users")
                .document(userId)
                .collection("weekSchedules")
                .document(docId)
                .setData(from: newSchedule)
            
            DispatchQueue.main.async {
                self.schedule = newSchedule
            }
        } catch {
            print("Error creating default weekly schedule: \(error)")
        }
    }
    
    func updateWeeklySchedule() {
        guard let schedule = schedule, let docId = schedule.id else { return }
        
        do {
            try db.collection("users")
                .document(schedule.userId)
                .collection("weekSchedules")
                .document(docId)
                .setData(from: schedule)
        } catch {
            print("Error updating weekly schedule: \(error)")
        }
    }
    
    // Example: if you want an ID like "2025-Week14" or "2025-03-23"
    private func isoWeekString(from date: Date) -> String {
        // For simplicity, let's do "yyyy-MM-dd" of the startOfWeek
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
