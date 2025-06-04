//  MonthlyPrioritiesSection.swift
//  Mind Reset
//
//  Shows a reorderable, check‐off list of monthly priorities plus
//  Add / Remove controls and a confirmation prompt on delete.
//  Updated 30 May 2025.
//

import SwiftUI

struct MonthlyPrioritiesSection: View {
    // ─────────── Inputs ────────────────────────────────
    @Binding var priorities: [MonthlyPriority]
    @Binding var editMode:   EditMode

    let accentColor:       Color
    let isRemoveMode:      Bool
    let isThisMonth:       Bool                     // ← NEW: is the displayed month the calendar’s current month?
    let hasPreviousUnfinished: Bool                 // ← NEW: whether last month has unfinished
    let onToggleRemoveMode: () -> Void
    let onToggle:         (UUID) -> Void   // toggle completion
    let onMove:           (IndexSet, Int) -> Void
    let onCommit:         () -> Void
    let onDelete:         (MonthlyPriority) -> Void
    let addAction:        () -> Void
    let importAction:     () -> Void       // ← NEW: import unfinished

    // ── Local state for a combined set of alerts ─────────────────
    @State private var monthAlert: MonthViewAlert? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ── Header ───────────────────────────────────────
            Text("Monthly Priorities")
                .font(.headline)
                .foregroundColor(accentColor)

            // ── List or placeholder ───────────────────────────
            if priorities.isEmpty {
                Text("Please list your priorities for the month")
                    .foregroundColor(.white.opacity(0.7))
                    .italic()
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color(.sRGB, white: 0.1, opacity: 1))
                    .cornerRadius(8)
            } else {
                List {
                    ForEach(priorities) { pr in
                        let bindings = binding(for: pr)

                        MonthlyPriorityRowView(
                            title:       bindings.title,
                            isCompleted: bindings.isCompleted,
                            onToggle: {
                                if !isThisMonth {
                                    // Prompt before toggling a past‐month priority
                                    monthAlert = .confirmTogglePast(pr)
                                } else {
                                    onToggle(pr.id)
                                    onCommit()
                                }
                            },
                            showDelete:  isRemoveMode,
                            onDelete: {
                                if !isThisMonth {
                                    // Prompt before deleting a past‐month priority
                                    monthAlert = .confirmDeletePast(pr)
                                } else {
                                    // Prompt before deleting a this‐month priority
                                    monthAlert = .confirmDeleteThisMonth(pr)
                                }
                            },
                            accentCyan:  accentColor,
                            onCommit:    onCommit,
                            isPastMonth: !isThisMonth      
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .listRowSeparator(.hidden)
                    }
                    .onMove(perform: onMove)
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: CGFloat(priorities.count) * 90)
                .environment(\.editMode, $editMode)
                .padding(.bottom, 20)
            }

            // ── Add / Remove buttons ─────────────────────────
            HStack {
                Button("Add Priority") {
                    if !isThisMonth {
                        monthAlert = .confirmAddPast
                    } else {
                        addAction()
                    }
                }
                .font(.headline)
                .foregroundColor(accentColor)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.black)
                .cornerRadius(8)

                Spacer()

                if !priorities.isEmpty {
                    Button(isRemoveMode ? "Done" : "Remove Priority") {
                        onToggleRemoveMode()
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

            // ── Import Unfinished from Last Month ──────────────────
            if isThisMonth && hasPreviousUnfinished {
                HStack {
                    Button(action: importAction) {
                        Text("Import Unfinished from Last Month")
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
        .padding()                                     // card padding
        .background(Color.gray.opacity(0.3))           // grey card bg
        .cornerRadius(12)

        // ── Single alert for all cases ─────────────────────────────
        .alert(item: $monthAlert) { alertCase in
            switch alertCase {
            case .confirmDeleteThisMonth(let pr):
                return Alert(
                    title: Text("Delete Priority"),
                    message: Text("Are you sure you want to delete “\(pr.title)”?"),
                    primaryButton: .destructive(Text("Delete")) {
                        onDelete(pr)
                        onCommit()
                    },
                    secondaryButton: .cancel()
                )

            case .confirmTogglePast(let pr):
                return Alert(
                    title: Text("Editing Past Month"),
                    message: Text("""
                    You’re about to change the completion status \
                    of a priority from a previous month. Continue?
                    """),
                    primaryButton: .destructive(Text("Yes")) {
                        onToggle(pr.id)
                        onCommit()
                    },
                    secondaryButton: .cancel()
                )

            case .confirmDeletePast(let pr):
                return Alert(
                    title: Text("Delete From Past Month"),
                    message: Text("""
                    You’re about to delete a priority from a previous \
                    month. Continue?
                    """),
                    primaryButton: .destructive(Text("Delete")) {
                        onDelete(pr)
                        onCommit()
                    },
                    secondaryButton: .cancel()
                )

            case .confirmAddPast:
                return Alert(
                    title: Text("Adding to Past Month"),
                    message: Text("""
                    You’re adding a new priority into a previous month, \
                    which changes historical data. Continue?
                    """),
                    primaryButton: .default(Text("Yes")) {
                        addAction()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    // ────────────────────────────────────────────────────────────────────────────────
    // MARK: – helper for array bindings
    // ────────────────────────────────────────────────────────────────────────────────
    private func binding(for pr: MonthlyPriority)
      -> (title: Binding<String>, isCompleted: Binding<Bool>) {
        guard let idx = priorities.firstIndex(where: { $0.id == pr.id }) else {
            fatalError("Priority not found")
        }
        return (
            Binding(
                get: { priorities[idx].title },
                set: { priorities[idx].title = $0 }
            ),
            Binding(
                get: { priorities[idx].isCompleted },
                set: { priorities[idx].isCompleted = $0 }
            )
        )
    }

    // ────────────────────────────────────────────────────────────────────────────────
    // MARK: – Alert cases for MonthlyPrioritiesSection
    // ────────────────────────────────────────────────────────────────────────────────
    enum MonthViewAlert: Identifiable {
        case confirmDeleteThisMonth(MonthlyPriority)
        case confirmTogglePast(MonthlyPriority)
        case confirmDeletePast(MonthlyPriority)
        case confirmAddPast

        var id: String {
            switch self {
            case .confirmDeleteThisMonth(let p):
                return "confirmDeleteThisMonth-\(p.id)"
            case .confirmTogglePast(let p):
                return "confirmTogglePast-\(p.id)"
            case .confirmDeletePast(let p):
                return "confirmDeletePast-\(p.id)"
            case .confirmAddPast:
                return "confirmAddPast"
            }
        }
    }
}
