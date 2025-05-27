//
//  WeekNavigationView.swift
//  Ascento
//
//  Created by Andika Yudhatrisna on 5/27/25.
//


import SwiftUI

struct WeekNavigationView: View {
    @Binding var currentWeekStart: Date
    let accountCreationDate: Date
    let accentColor: Color

    var body: some View {
        HStack {
            Button { goBack() } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(canGoBack ? .white : .gray)
            }
            Spacer()
            Text(weekRangeString())
                .font(.headline)
                .foregroundColor(isCurrentWeek ? accentColor : .white)
            Spacer()
            Button { goForward() } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }

    private var isCurrentWeek: Bool {
        Calendar.current.isDate(currentWeekStart,
                                equalTo: Date(),
                                toGranularity: .weekOfYear)
    }

    private var canGoBack: Bool {
        let prev = Calendar.current.date(byAdding: .weekOfYear,
                                         value: -1,
                                         to: currentWeekStart)!
        return prev >= startOfWeek(for: accountCreationDate)
    }

    private func goBack() {
        guard canGoBack,
              let prev = Calendar.current.date(byAdding: .weekOfYear,
                                               value: -1,
                                               to: currentWeekStart)
        else { return }
        currentWeekStart = prev
    }

    private func goForward() {
        if let next = Calendar.current.date(byAdding: .weekOfYear,
                                            value: 1,
                                            to: currentWeekStart) {
            currentWeekStart = next
        }
    }

    private func weekRangeString() -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear],
                                       from: currentWeekStart)
        let start = cal.date(from: comps)!
        let end   = cal.date(byAdding: .day, value: 6, to: start)!
        let fmt   = DateFormatter(); fmt.dateFormat = "M/d"
        return "Week of \(fmt.string(from: start)) – \(fmt.string(from: end))"
    }

    private func startOfWeek(for date: Date) -> Date {
        var cal = Calendar.current; cal.firstWeekday = 1
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear],
                                       from: date)
        return cal.date(from: comps)!
    }
}
