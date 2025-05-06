//
//  MonthViewModel.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 3/27/25.
//

import SwiftUI
import Firebase 
import FirebaseFirestore

class MonthViewModel: ObservableObject {
    @Published var schedule: MonthSchedule?  
    
    private let db = Firestore.firestore()
    
    func loadMonthSchedule(for month: Date, userId: String) {
        let docId = isoMonthString(from: month)  // e.g. "2025-03"
        
        db.collection("users")
            .document(userId)
            .collection("monthSchedules")
            .document(docId)
            .getDocument { [weak self] snapshot, error in
                if let error = error {
                    print("Error loading month schedule: \(error)")
                    return
                }
                
                if let snapshot = snapshot, snapshot.exists {
                    // decode existing doc
                    do {
                        let schedule = try snapshot.data(as: MonthSchedule.self)
                        DispatchQueue.main.async {
                            self?.schedule = schedule
                        }
                    } catch {
                        print("Error decoding MonthSchedule: \(error)")
                    }
                } else {
                    // create a default doc for that month
                    self?.createDefaultMonthSchedule(month: month, userId: userId)
                }
            }
    }
    
    private func createDefaultMonthSchedule(month: Date, userId: String) {
        let docId = isoMonthString(from: month)
        
        // Build a dictionary for each day in the month, defaulting to 0.0 completion
        let dates = generateAllDates(for: month)
        var dayCompletions: [String: Double] = [:]
        for date in dates {
            let key = isoDayString(from: date) // "2025-03-01", etc.
            dayCompletions[key] = 0.0
        }
        
        let newSchedule = MonthSchedule(
            id: docId,
            userId: userId,
            yearMonth: docId,
            monthlyPriorities: [
                MonthlyPriority(id: UUID(), title: "Monthly Goal", progress: 0.0)
            ],
            dayCompletions: dayCompletions
        )
        
        do {
            try db.collection("users")
                .document(userId)
                .collection("monthSchedules")
                .document(docId)
                .setData(from: newSchedule)
            DispatchQueue.main.async {
                self.schedule = newSchedule
            }
        } catch {
            print("Error creating default MonthSchedule: \(error)")
        }
    }
    
    func updateMonthSchedule() {
        guard let schedule = schedule, let docId = schedule.id else { return }
        do {
            try db.collection("users")
                .document(schedule.userId)
                .collection("monthSchedules")
                .document(docId)
                .setData(from: schedule)
        } catch {
            print("Error updating month schedule: \(error)")
        }
    }
    
    // Utility to produce something like "2025-03"
    private func isoMonthString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }
    
    // For each day in that month
    private func generateAllDates(for month: Date) -> [Date] {
        var dates: [Date] = []
        let calendar = Calendar.current
        guard let monthInterval = calendar.dateInterval(of: .month, for: month) else { return dates }
        var date = calendar.startOfDay(for: monthInterval.start)
        while date < monthInterval.end {
            dates.append(date)
            if let next = calendar.date(byAdding: .day, value: 1, to: date) {
                date = next
            } else { break }
        }
        return dates
    }
    
    // Utility to produce "2025-03-01" for each day
    private func isoDayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
