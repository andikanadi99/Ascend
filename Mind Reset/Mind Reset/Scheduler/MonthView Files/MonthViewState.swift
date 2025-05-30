//
// MonthViewState.swift
// Mind Reset
//
// Created by Andika Yudhatrisna on 4/11/25.
//

import SwiftUI

class MonthViewState: ObservableObject {
    @Published var currentMonth: Date
    
    init() {
        self.currentMonth = MonthViewState.startOfMonth(for: Date())
    }
    
    static func startOfMonth(for date: Date) -> Date {
        let calendar = Calendar.current
        guard let range = calendar.dateInterval(of: .month, for: date) else { return date }
        return range.start
    }
}
