//  WeeklyPrioritiesSection.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 5/27/25.
//

import SwiftUI

/// Section showing the weekly priorities list with drag-to-reorder, inline checkmarks,
/// confirmation on delete, and fixed Add/Remove-Done buttons below (so they never scroll away).
struct WeeklyPrioritiesSection: View {
    // ─────────── Inputs ────────────────────────────────
    @Binding var priorities: [WeeklyPriority]
    @Binding var editMode: EditMode
    let accentColor: Color
    let isRemoveMode: Bool
    let onToggleRemoveMode: () -> Void
    let onMove: (IndexSet, Int) -> Void
    let onCommit: () -> Void
    let onDelete: (WeeklyPriority) -> Void
    let addAction: () -> Void

    // ─── Week context ────────────────────────────
    /// True if the displayed week is the current calendar week.
    let isThisWeek: Bool
    /// True if the displayed week’s start date is strictly before this week’s start.
    let isPastWeek: Bool
    /// True if there are any unfinished priorities in last week.
    let hasPreviousUnfinished: Bool
    /// Action to import last week’s unfinished priorities into this week.
    let importAction: () -> Void
    // ────────────────────────────────────────────────────

    // Single enum for all confirmation alerts
    @State private var weekAlert: WeekViewAlert? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ───── Header ─────
            HStack {
                Text("Weekly Priorities")
                    .font(.headline)
                    .foregroundColor(accentColor)
                Spacer()
            }

            // ───── Empty placeholder or List of rows ─────
            if priorities.isEmpty {
                Text("Please list your priorities for the week")
                    .foregroundColor(Color.white.opacity(0.7))
                    .italic()
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color(.sRGB, white: 0.1, opacity: 1))
                    .cornerRadius(8)
            } else {
                // ───── The scrolling list itself ─────
                List {
                    ForEach($priorities, id: \.id) { $priority in
                        WeeklyPriorityRowView(
                            title:       $priority.title,
                            isCompleted: $priority.isCompleted,
                            onToggle: {
                                if isPastWeek {
                                    weekAlert = .confirmModifyPastWeek(priority)
                                } else {
                                    priority.isCompleted.toggle()
                                    onCommit()
                                }
                            },
                            showDelete:  isRemoveMode,
                            onDelete: {
                                if isPastWeek {
                                    weekAlert = .confirmDeletePastWeek(priority)
                                } else {
                                    weekAlert = .confirmDeleteThisWeek(priority)
                                }
                            },
                            accentCyan:  accentColor,
                            onCommit:    onCommit,
                            isPastWeek:  isPastWeek
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowSeparator(.hidden)
                    }
                    .onMove(perform: onMove)
                }
                .listStyle(PlainListStyle())
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .listSectionSeparator(.hidden)
                .environment(\.editMode, $editMode)
                .frame(minHeight: CGFloat(priorities.count) * 90)
                .padding(.bottom, 20)
            }

            // ───── Fixed “Add / Remove-Done” HStack below the list ─────
            HStack {
                Button(action: addAction) {
                    Text("Add Priority")
                }
                .font(.headline)
                .foregroundColor(accentColor)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.black)
                .cornerRadius(8)

                Spacer()

                if priorities.count > 0 {
                    Button(action: onToggleRemoveMode) {
                        Text(isRemoveMode ? "Done" : "Remove Priority")
                    }
                    .font(.headline)
                    .foregroundColor(.red)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.black)
                    .cornerRadius(8)
                }
            }
            .padding(.top, 8)

            // ───── “Import Unfinished from Last Week” (below the buttons) ─────
            if isThisWeek && hasPreviousUnfinished {
                HStack {
                    Button(action: importAction) {
                        Text("Import Unfinished from Last Week")
                            .font(.headline)
                            .foregroundColor(.orange)
                            .underline()
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)

        // ───── Single alert for all cases ─────
        .alert(item: $weekAlert) { alertCase in
            switch alertCase {
            case .confirmDeleteThisWeek(let pr):
                return Alert(
                    title: Text("Delete Priority"),
                    message: Text("Are you sure you want to delete ‘\(pr.title)’?"),
                    primaryButton: .destructive(Text("Delete")) {
                        onDelete(pr)
                    },
                    secondaryButton: .cancel()
                )

            case .confirmModifyPastWeek(let pr):
                return Alert(
                    title: Text("Editing Past Week"),
                    message: Text("This will change a priority from a previous week. Continue?"),
                    primaryButton: .destructive(Text("Yes")) {
                        if let idx = priorities.firstIndex(where: { $0.id == pr.id }) {
                            priorities[idx].isCompleted.toggle()
                            onCommit()
                        }
                    },
                    secondaryButton: .cancel()
                )

            case .confirmDeletePastWeek(let pr):
                return Alert(
                    title: Text("Delete From Past Week"),
                    message: Text("This will delete a priority from a previous week. Continue?"),
                    primaryButton: .destructive(Text("Delete")) {
                        onDelete(pr)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Alert cases for WeeklyPrioritiesSection
// ─────────────────────────────────────────────────────────────────────────────
enum WeekViewAlert: Identifiable {
    case confirmDeleteThisWeek(WeeklyPriority)
    case confirmModifyPastWeek(WeeklyPriority)
    case confirmDeletePastWeek(WeeklyPriority)

    var id: String {
        switch self {
        case .confirmDeleteThisWeek(let p):
            return "confirmDeleteThisWeek-\(p.id)"
        case .confirmModifyPastWeek(let p):
            return "confirmModifyPastWeek-\(p.id)"
        case .confirmDeletePastWeek(let p):
            return "confirmDeletePastWeek-\(p.id)"
        }
    }
}
