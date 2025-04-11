//
//  WeekViewState.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 4/11/25.
//


import SwiftUI

class WeekViewState: ObservableObject {
    @Published var currentWeekStart: Date
    
    init() {
        // By default, initialize to the start of the current week
        let now = Date()
        self.currentWeekStart = WeekViewState.startOfCurrentWeek(now)
    }
    
    static func startOfCurrentWeek(_ date: Date) -> Date {
        var calendar = Calendar.current
        calendar.firstWeekday = 1 // Sunday
        let comps = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return calendar.date(from: comps) ?? date
    }
}
