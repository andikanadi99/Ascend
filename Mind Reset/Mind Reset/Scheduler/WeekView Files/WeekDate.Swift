//
//  WeekDate.Swift
//  Ascento
//
//  Created by Andika Yudhatrisna on 7/10/25.
//


import Foundation

extension Date {
    /// Finds the Monday (or whichever your locale’s firstWeekday is) of the week containing this date.
    func startOfWeek() -> Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: self)!.start
    }

    /// “Mon 8” or “Tue 14” etc.
    var weekdayTitle: String {
        formatted(.dateTime.weekday(.abbreviated).day())
    }
}
