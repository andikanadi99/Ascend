//
//  WeeklyPrioritiesSection.swift
//  Mind Reset
//
//  Updated 06 Jun 2025 – adds confirmation before importing unfinished priorities
//

import SwiftUI

/// Section showing the weekly priorities list with drag-to-reorder, inline check-marks,
/// confirmation prompts, fixed Add / Remove-Done buttons, and an optional “Import
/// Unfinished from Last Week” action.
struct WeeklyPrioritiesSection: View {

    // ─────────── Inputs from WeekView ────────────────────────────────
    @Binding var priorities: [WeeklyPriority]
    @Binding var editMode:   EditMode

    let accentColor:       Color
    let isRemoveMode:      Bool
    let onToggleRemoveMode: () -> Void
    let onMove:             (IndexSet, Int) -> Void
    let onCommit:           () -> Void
    let onDelete:           (WeeklyPriority) -> Void
    let addAction:          () -> Void

    // Context about WHICH week we’re showing
    let isThisWeek:             Bool     // true if displayed week == current week
    let isPastWeek:             Bool     // true if displayed week < current week
    let hasPreviousUnfinished:  Bool     // true if last week has any unfinished items
    let importAction:           () -> Void   // perform the import
    // ─────────────────────────────────────────────────────────────────

    /// Single source-of-truth for *all* confirmation alerts in this view
    @State private var weekAlert: WeekViewAlert? = nil

    // ─────────────────────────────────────────
    // MARK: – Body
    // ─────────────────────────────────────────
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // ───── Section header ─────
            HStack {
                Text("Weekly Priorities")
                    .font(.headline)
                    .foregroundColor(accentColor)
                Spacer()
            }

            // ───── Empty placeholder OR scrolling list ─────
            if priorities.isEmpty {
                Text("Please list your priorities for the week")
                    .foregroundColor(.white.opacity(0.7))
                    .italic()
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color(.sRGB, white: 0.1, opacity: 1))
                    .cornerRadius(8)
            } else {
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
                .listStyle(.plain)
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .listSectionSeparator(.hidden)
                .environment(\.editMode, $editMode)
                .frame(minHeight: CGFloat(priorities.count) * 90)
                .padding(.bottom, 20)
            }

            // ───── Fixed Add / Remove-Done buttons ─────
            HStack {
                Button("Add Priority", action: addAction)
                    .font(.headline)
                    .foregroundColor(accentColor)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.black)
                    .cornerRadius(8)

                Spacer()

                if priorities.count > 0 {
                    Button(isRemoveMode ? "Done" : "Remove Priority",
                           action: onToggleRemoveMode)
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.black)
                        .cornerRadius(8)
                }
            }
            .padding(.top, 8)

            // ───── Import unfinished from last week (only for THIS week) ─────
            if isThisWeek && hasPreviousUnfinished {
                HStack {
                    Button {
                        weekAlert = .confirmImportUnfinished     // ← prompt first
                    } label: {
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

        // ───── Single .alert handler ─────
        .alert(item: $weekAlert) { alertCase in
            switch alertCase {
            case .confirmDeleteThisWeek(let pr):
                return Alert(
                    title: Text("Delete Priority"),
                    message: Text("Are you sure you want to delete “\(pr.title)” ?"),
                    primaryButton: .destructive(Text("Delete")) { onDelete(pr) },
                    secondaryButton: .cancel()
                )

            case .confirmModifyPastWeek(let pr):
                return Alert(
                    title: Text("Editing Past Week"),
                    message: Text("This will modify a priority from a previous week. Continue?"),
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
                    message: Text("This will permanently delete that past priority. Continue?"),
                    primaryButton: .destructive(Text("Delete")) { onDelete(pr) },
                    secondaryButton: .cancel()
                )

            case .confirmImportUnfinished:
                return Alert(
                    title: Text("Import Unfinished?"),
                    message: Text("Copy all unfinished priorities from last week into this week?"),
                    primaryButton: .destructive(Text("Cancel")),
                    secondaryButton: .default(Text("Import")) { importAction() }
                )
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────
// MARK: – Alert cases for WeeklyPrioritiesSection
// ─────────────────────────────────────────────────────────────────
enum WeekViewAlert: Identifiable {
    case confirmDeleteThisWeek(WeeklyPriority)
    case confirmModifyPastWeek(WeeklyPriority)
    case confirmDeletePastWeek(WeeklyPriority)
    case confirmImportUnfinished                         // NEW

    var id: String {
        switch self {
        case .confirmDeleteThisWeek(let p):
            return "confirmDeleteThisWeek-\(p.id)"
        case .confirmModifyPastWeek(let p):
            return "confirmModifyPastWeek-\(p.id)"
        case .confirmDeletePastWeek(let p):
            return "confirmDeletePastWeek-\(p.id)"
        case .confirmImportUnfinished:
            return "confirmImportUnfinished"
        }
    }
}
