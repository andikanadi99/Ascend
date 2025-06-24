// WeekNavigationView.swift
// Ascento

import SwiftUI


struct WeekNavigationView: View {

    @Binding var currentWeekStart: Date
    let accountCreationDate: Date
    let accentColor: Color

    @EnvironmentObject private var weekViewState: WeekViewState
    private let cal = Calendar.current

    var body: some View {
        HStack {
            Button { goBack() } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(canGoBack ? .white : .gray)
            }
            .disabled(!canGoBack)

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
        .onAppear { updateAnchor() }
    }

    // MARK: – Actions

    private func goBack() {
        weekViewState.weekOffset -= 1
        updateAnchor()
    }

    private func goForward() {
        weekViewState.weekOffset += 1
        updateAnchor()
    }

    /// Recompute `currentWeekStart` from the single source: today + offset weeks.
    private func updateAnchor() {
        let refDate = cal.date(
            byAdding: .weekOfYear,
            value: weekViewState.weekOffset,
            to: Date()
        )!
        currentWeekStart = WeekViewState.startOfWeek(for: refDate)
    }

    // MARK: – Guards

    private var canGoBack: Bool {
        // Compute the candidate for offset-1
        let prevDate = cal.date(
            byAdding: .weekOfYear,
            value: weekViewState.weekOffset - 1,
            to: Date()
        )!
        let prevAnchor = WeekViewState.startOfWeek(for: prevDate)
        let earliest   = WeekViewState.startOfWeek(for: accountCreationDate)
        return prevAnchor >= earliest
    }

    private var isCurrentWeek: Bool {
        cal.isDate(
            currentWeekStart,
            equalTo: Date(),
            toGranularity: .weekOfYear
        )
    }

    // MARK: – Label

    private func weekRangeString() -> String {
        let fmt = DateFormatter(); fmt.dateFormat = "M/d"
        let end = cal.date(byAdding: .day, value: 6, to: currentWeekStart)!
        return "Week of \(fmt.string(from: currentWeekStart)) – \(fmt.string(from: end))"
    }
}
