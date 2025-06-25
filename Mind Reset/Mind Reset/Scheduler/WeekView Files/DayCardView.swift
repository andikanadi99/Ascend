//  DayCardView.swift
//  Mind Reset
//
//  Scrollable when >4 priorities, smooth spring animation,
//  matches WeekCardView style.
//

import SwiftUI
import Foundation   // TodayPriority

// ─────────────────────────────────────────────────────────
// MARK: – Alerts
// ─────────────────────────────────────────────────────────
enum DayCardAlert: Identifiable {
    case confirmDeleteCurrent(TodayPriority)
    case confirmModifyPast(TodayPriority)
    case confirmDeletePast(TodayPriority)
    case confirmAddPast

    var id: String {
        switch self {
        case .confirmDeleteCurrent(let p): return "delCurr-\(p.id)"
        case .confirmModifyPast(let p):   return "modPast-\(p.id)"
        case .confirmDeletePast(let p):   return "delPast-\(p.id)"
        case .confirmAddPast:             return "addPast"
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – DayCardView
// ─────────────────────────────────────────────────────────
@MainActor
struct DayCardView: View {
    let accentColor: Color
    let day: Date
    @Binding var priorities: [TodayPriority]
    let priorityFocus: FocusState<Bool>.Binding

    @EnvironmentObject private var weekVM:  WeekViewModel
    @EnvironmentObject private var session: SessionStore

    @AppStorage("dateFormatStyle") private var dateFormatStyle: String = "MM/dd/yyyy" // ← new

    @State private var isRemoveMode = false
    @State private var dayAlert: DayCardAlert?
    @State private var listHeight: CGFloat = 0

    // appearance constants
    private let accentCyan     = Color(red: 0, green: 1, blue: 1)
    private let rowHeight: CGFloat     = 110    // approx per-row height
    private let bottomInset: CGFloat   = 16     // spacing under last row
    private let maxVisibleRows         = 4      // scroll after 4 rows

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("\(weekdayString(day)), \(formattedDate(day))")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.bottom, 4)

            // Section title
            Text("Today's Top Priority")
                .font(.headline)
                .foregroundColor(accentCyan)

            // Placeholder if empty
            if priorities.isEmpty {
                Text("Please list priorities for this day")
                    .foregroundColor(.white.opacity(0.7))
                    .italic()
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color(.sRGB, white: 0.1, opacity: 1))
                    .cornerRadius(8)
            } else {
                // ScrollView + LazyVStack for crash-free dynamic layout
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(priorities.indices, id: \.self) { idx in
                            let pr    = priorities[idx]
                            let isPast = isPastDay()

                            WeekDayPriorityRowView(
                                title:       $priorities[idx].title,
                                isCompleted: $priorities[idx].isCompleted,
                                focus:       priorityFocus,
                                onToggle: {
                                    if isPast {
                                        dayAlert = .confirmModifyPast(pr)
                                    } else {
                                        priorities[idx].isCompleted.toggle()
                                        savePatch()
                                    }
                                },
                                showDelete:  isRemoveMode,
                                onDelete: {
                                    dayAlert = isPast
                                        ? .confirmDeletePast(pr)
                                        : .confirmDeleteCurrent(pr)
                                },
                                accentCyan:  accentCyan,
                                onCommit:    savePatch,
                                isPast:      isPast
                            )
                            .padding(.horizontal, 0)
                        }
                        .onMove { from, to in
                            withAnimation(.interactiveSpring(response: 0.3,
                                                             dampingFraction: 0.7)) {
                                priorities.move(fromOffsets: from, toOffset: to)
                                savePatch()
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                // constrain height to either content or maxVisibleRows
                .frame(
                    height: min(
                        CGFloat(priorities.count) * rowHeight + bottomInset,
                        CGFloat(maxVisibleRows) * rowHeight + bottomInset
                    )
                )
                // ensure grows to fit content if fewer rows
                .frame(minHeight: max(listHeight,
                                      CGFloat(priorities.count) * rowHeight))
                .onPreferenceChange(DayCardListHeightKey.self) { listHeight = $0 }
            }

            // Bottom buttons
            HStack(spacing: 12) {
                Button {
                        if isPastDay() {
                            dayAlert = .confirmAddPast
                        } else {
                            addPriority()
                        }
                    } label: {
                        Text("Add Priority")
                            .lineLimit(1)
                            .fixedSize()
                    }
                .styledAccent

                Spacer()

                if !priorities.isEmpty {
                        Button {
                            withAnimation(.easeInOut) { isRemoveMode.toggle() }
                        } label: {
                            Text(isRemoveMode ? "Done" : "Remove Priority")
                                .lineLimit(1)
                                .fixedSize()
                        }
                        .styledRed
                   }
            }
        }
        .padding()
       .frame(maxWidth: .infinity, alignment: .leading)
       .background(Color.gray.opacity(0.3))
       .cornerRadius(12)
       .shadow(radius: 2)
       .alert(item: $dayAlert, content: buildAlert)
    }

    // ───────────────────────────────────────────────
    // MARK: – Helpers
    // ───────────────────────────────────────────────
    private func weekdayString(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = "EEEE"   // full weekday name
        return df.string(from: date)
    }
    private func formattedDate(_ date: Date) -> String {
        let df = DateFormatter()
        df.dateFormat = dateFormatStyle
        return df.string(from: date)
    }

    private func isPastDay() -> Bool {
        let dayStart   = Calendar.current.startOfDay(for: day)
        let todayStart = Calendar.current.startOfDay(for: Date())
        return dayStart < todayStart
    }

    private func addPriority() {
        priorities.append(
            TodayPriority(id: UUID(),
                          title: "New Priority",
                          progress: 0,
                          isCompleted: false)
        )
        savePatch()
    }

    private func savePatch() {
        guard let uid = session.userModel?.id else { return }
        weekVM.updateDayPriorities(
            date: day,
            priorities: priorities,
            userId: uid
        )
    }

    private func buildAlert(for alert: DayCardAlert) -> Alert {
        switch alert {
        case .confirmDeleteCurrent(let p):
            return Alert(
                title: Text("Delete Priority"),
                message: Text("Delete “\(p.title)”?"),
                primaryButton: .destructive(Text("Delete")) { _ = delete(p) },
                secondaryButton: .cancel()
            )
        case .confirmModifyPast(let p):
            return Alert(
                title: Text("Editing Past Day"),
                message: Text("Change a past priority?"),
                primaryButton: .destructive(Text("Yes")) {
                    if let i = priorities.firstIndex(where: { $0.id == p.id }) {
                        priorities[i].isCompleted.toggle()
                        savePatch()
                    }
                },
                secondaryButton: .cancel()
            )
        case .confirmDeletePast(let p):
            return Alert(
                title: Text("Delete From Past Day"),
                message: Text("Permanently delete past priority?"),
                primaryButton: .destructive(Text("Delete")) { _ = delete(p) },
                secondaryButton: .cancel()
            )
        case .confirmAddPast:
            return Alert(
                title: Text("Add To Past Day"),
                message: Text("Add a priority to a previous day?"),
                primaryButton: .default(Text("Yes")) { addPriority() },
                secondaryButton: .cancel()
            )
        }
    }

    private func delete(_ p: TodayPriority) {
        priorities.removeAll { $0.id == p.id }
        savePatch()
    }
}

// ───────────────────────────────────────────────
// MARK: – Button style extensions
// ───────────────────────────────────────────────
private extension View {
    var styledAccent: some View {
        self.font(.headline)
            .foregroundColor(Color(red: 0, green: 1, blue: 1))
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.black)
            .cornerRadius(8)
    }
    var styledRed: some View {
        self.font(.headline)
            .foregroundColor(.red)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.black)
            .cornerRadius(8)
    }
}
