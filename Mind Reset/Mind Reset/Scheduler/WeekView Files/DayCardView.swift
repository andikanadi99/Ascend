//
//  DayCardView.swift
//  Mind Reset
//

import SwiftUI
import Foundation

struct DayCardView: View {
    // injected
    let accentColor: Color
    let day: Date
    @Binding var priorities: [TodayPriority]
    let priorityFocus: FocusState<Bool>.Binding

    @EnvironmentObject private var weekVM: WeekViewModel
    @EnvironmentObject private var session: SessionStore

    // local UI
    @State private var isRemoveMode = false
    @State private var dayAlert: DayCardAlert?
    @State private var pendingToggle: TodayPriority?
    @State private var listHeight: CGFloat = 1       // dynamic list height

    private let accentCyan = Color(red: 0, green: 1, blue: 1)

    // ─────────────────────────────────────────
    // MARK: – Body
    // ─────────────────────────────────────────
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            header

            // priorities list or placeholder
            if priorities.isEmpty {
                placeholder
            } else {
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
                                        pendingToggle = pr
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
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(minHeight: max(listHeight, CGFloat(priorities.count) * 60))
                .onPreferenceChange(DayCardListHeightKey.self) { listHeight = $0 }
            }

            controls
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        .alert(item: $dayAlert, content: buildAlert)
    }

    // ─────────────────────────────────────────
    // MARK: – Controls row
    // ─────────────────────────────────────────
    private var controls: some View {
        HStack {
            Button("Add Priority") {
                if isPastDay() {
                    dayAlert = .confirmAddPast
                } else {
                    addPriority()
                }
            }
            .font(.headline)
            .foregroundColor(accentCyan)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.black)
            .cornerRadius(8)

            Spacer()

            if !priorities.isEmpty {
                Button(isRemoveMode ? "Done" : "Remove Priority") {
                    isRemoveMode.toggle()
                }
                .font(.headline)
                .foregroundColor(.red)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.black)
                .cornerRadius(8)
            }
        }
    }

    // ─────────────────────────────────────────
    // MARK: – Helper methods
    // ─────────────────────────────────────────
    private func isPastDay() -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return Calendar.current.startOfDay(for: day) < today
    }

    private func addPriority() {
        priorities.append(
            TodayPriority(id: UUID(), title: "New Priority",
                          progress: 0, isCompleted: false)
        )
        isRemoveMode = false
        savePatch()
    }

    private func delete(_ pr: TodayPriority) {
        priorities.removeAll { $0.id == pr.id }
        if priorities.isEmpty { isRemoveMode = false }
        savePatch()
    }

    /// Persist only the priorities array via WeekViewModel
    private func savePatch() {
        guard let uid = session.userModel?.id else { return }
        weekVM.updateDayPriorities(date: day,
                                   priorities: priorities,
                                   userId: uid)
    }

    // Placeholder shown when list empty
    private var placeholder: some View {
        Text("Please list priorities for this day")
            .foregroundColor(.white.opacity(0.7))
            .italic()
            .frame(maxWidth: .infinity, minHeight: 90)
            .background(Color(.sRGB, white: 0.1, opacity: 1))
            .cornerRadius(8)
    }

    // Header with weekday name + date
    private var header: some View {
        VStack(alignment: .leading) {
            Text(dayOfWeek)
                .font(.headline)
                .foregroundColor(.white)
            Text(formattedDate)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .padding(.bottom, 4)
    }

    private var dayOfWeek: String {
        let f = DateFormatter(); f.dateFormat = "EEEE"
        return f.string(from: day)
    }
    private var formattedDate: String {
        let f = DateFormatter(); f.dateFormat = "M/d"
        return f.string(from: day)
    }

    // Unified alert builder
    private func buildAlert(for alert: DayCardAlert) -> Alert {
        switch alert {
        case .confirmDeleteCurrent(let p):
            return Alert(
                title: Text("Delete Priority"),
                message: Text("Delete “\(p.title)”?"),
                primaryButton: .destructive(Text("Delete")) { delete(p) },
                secondaryButton: .cancel()
            )

        case .confirmModifyPast(let p):
            return Alert(
                title: Text("Editing Past Day"),
                message: Text("You’re changing a priority from a previous day. Continue?"),
                primaryButton: .destructive(Text("Yes")) {
                    if let idx = priorities.firstIndex(where: { $0.id == p.id }) {
                        priorities[idx].isCompleted.toggle()
                        savePatch()
                    }
                },
                secondaryButton: .cancel()
            )

        case .confirmDeletePast(let p):
            return Alert(
                title: Text("Delete From Past Day"),
                message: Text("You’re deleting a priority from a previous day. Continue?"),
                primaryButton: .destructive(Text("Delete")) { delete(p) },
                secondaryButton: .cancel()
            )

        case .confirmAddPast:
            return Alert(
                title: Text("Add To Past Day"),
                message: Text("You’re adding a priority to a previous day. Continue?"),
                primaryButton: .default(Text("Yes")) { addPriority() },
                secondaryButton: .cancel()
            )
        }
    }
}

// ─────────────────────────────────────────
// MARK: – Alert enum
// ─────────────────────────────────────────
enum DayCardAlert: Identifiable {
    case confirmDeleteCurrent(TodayPriority)
    case confirmModifyPast(TodayPriority)
    case confirmDeletePast(TodayPriority)
    case confirmAddPast

    var id: String {
        switch self {
        case .confirmDeleteCurrent(let p): return "deleteCurrent-\(p.id)"
        case .confirmModifyPast(let p):   return "modifyPast-\(p.id)"
        case .confirmDeletePast(let p):   return "deletePast-\(p.id)"
        case .confirmAddPast:             return "addPast"
        }
    }
}
