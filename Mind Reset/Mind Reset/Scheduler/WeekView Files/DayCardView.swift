//
//  DayCardView.swift
//  Mind Reset
//
//  Updated 06 Jun 2025 – unified to a single alert, so prompts appear for
//  *all* add / delete actions regardless of date.
//

import SwiftUI
import Foundation   // ensures TodayPriority is visible

struct DayCardView: View {
    // ─── injected ──────────────────────────────────────────────
    let accentColor: Color
    let day: Date
    @Binding var priorities: [TodayPriority]          // priorities for that day
    let priorityFocus: FocusState<Bool>.Binding       // shared focus from WeekView

    // ─── local ui state ────────────────────────────────────────
    @State private var isRemoveMode = false
    @State private var dayAlert: DayCardAlert?        // ← unified alert state
    @State private var pendingToggle: TodayPriority?  // store priority to toggle after confirm

    // palette
    private let accentCyan = Color(red: 0, green: 1, blue: 1)

    // ─────────────────────────────────────────
    // MARK: – body
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
                        // iterate by index so Binding<$priority> works
                        ForEach(0 ..< priorities.count, id: \.self) { idx in
                            let pr = priorities[idx]
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
                                    }
                                },
                                showDelete:  isRemoveMode,
                                onDelete: {
                                    if isPast {
                                        dayAlert = .confirmDeletePast(pr)
                                    } else {
                                        dayAlert = .confirmDeleteCurrent(pr)
                                    }
                                },
                                accentCyan:  accentCyan,
                                onCommit:    {},
                                isPast:      isPast
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: CGFloat(max(priorities.count, 1)) * 90)
            }

            // add / remove controls
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
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)

        // ───── Single .alert handles ALL cases ─────
        .alert(item: $dayAlert) { alertCase in
            switch alertCase {

            case .confirmDeleteCurrent(let pr):
                return Alert(
                    title: Text("Delete Priority"),
                    message: Text("Delete “\(pr.title)” ?"),
                    primaryButton: .destructive(Text("Delete")) { delete(pr) },
                    secondaryButton: .cancel()
                )

            case .confirmModifyPast(let pr):
                return Alert(
                    title: Text("Editing Past Day"),
                    message: Text("You’re changing a priority from a previous day. Continue?"),
                    primaryButton: .destructive(Text("Yes")) {
                        if let idx = priorities.firstIndex(where: { $0.id == pr.id }) {
                            priorities[idx].isCompleted.toggle()
                        }
                    },
                    secondaryButton: .cancel()
                )

            case .confirmDeletePast(let pr):
                return Alert(
                    title: Text("Deleting From Past Day"),
                    message: Text("You’re deleting a priority from a previous day. Continue?"),
                    primaryButton: .destructive(Text("Delete")) { delete(pr) },
                    secondaryButton: .cancel()
                )

            case .confirmAddPast:
                return Alert(
                    title: Text("Adding to Past Day"),
                    message: Text("You’re adding a priority to a previous day. Continue?"),
                    primaryButton: .default(Text("Yes")) { addPriority() },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    // ─────────────────────────────────────────
    // MARK: – helpers
    // ─────────────────────────────────────────
    private func isPastDay() -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return Calendar.current.startOfDay(for: day) < today
    }

    private func addPriority() {
        priorities.append(
            TodayPriority(id: UUID(), title: "New Priority", progress: 0, isCompleted: false)
        )
        isRemoveMode = false
    }

    private func delete(_ pr: TodayPriority) {
        priorities.removeAll { $0.id == pr.id }
        if priorities.isEmpty { isRemoveMode = false }
    }

    // placeholder when list empty
    private var placeholder: some View {
        Text("Please list priorities for this day")
            .foregroundColor(.white.opacity(0.7))
            .italic()
            .frame(maxWidth: .infinity, minHeight: 90)
            .background(Color(.sRGB, white: 0.1, opacity: 1))
            .cornerRadius(8)
    }

    private var header: some View {
        VStack(alignment: .leading) {
            Text(dayOfWeek).font(.headline).foregroundColor(.white)
            Text(formattedDate).font(.caption).foregroundColor(.white.opacity(0.7))
        }
        .padding(.bottom, 4)
    }

    private var dayOfWeek: String {
        let f = DateFormatter(); f.dateFormat = "EEEE"; return f.string(from: day)
    }
    private var formattedDate: String {
        let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: day)
    }
}

// ─────────────────────────────────────────────
// MARK: – Unified alert enum
// ─────────────────────────────────────────────
enum DayCardAlert: Identifiable {
    case confirmDeleteCurrent(TodayPriority)   // today / future
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
