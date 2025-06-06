//
//  MonthlyPrioritiesSection.swift
//  Mind Reset
//
//  Updated 06 Jun 2025
//  • “Import Unfinished from Last Month” is now styled like the other buttons
//    (full-width, black background, 8 pt corner radius).
//  • Tapping it first prompts the user; nothing is imported until they confirm.
//

import SwiftUI

struct MonthlyPrioritiesSection: View {
    // ─────────── Inputs ────────────────────────────────
    @Binding var priorities: [MonthlyPriority]
    @Binding var editMode:   EditMode

    let accentColor:       Color
    let isRemoveMode:      Bool
    let isThisMonth:       Bool
    let hasPreviousUnfinished: Bool
    let onToggleRemoveMode: () -> Void
    let onToggle:         (UUID) -> Void
    let onMove:           (IndexSet, Int) -> Void
    let onCommit:         () -> Void
    let onDelete:         (MonthlyPriority) -> Void
    let addAction:        () -> Void
    let importAction:     () -> Void

    // ── Single source for *all* alerts ────────────────
    @State private var monthAlert: MonthViewAlert? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // ── Header ────────────────────────────────
            Text("Monthly Priorities")
                .font(.headline)
                .foregroundColor(accentColor)

            // ── List or placeholder ───────────────────
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
                                    monthAlert = .confirmTogglePast(pr)
                                } else {
                                    onToggle(pr.id); onCommit()
                                }
                            },
                            showDelete:  isRemoveMode,
                            onDelete: {
                                if !isThisMonth {
                                    monthAlert = .confirmDeletePast(pr)
                                } else {
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

            // ── Add / Remove buttons ───────────────────
            HStack {
                Button("Add Priority") {
                    if !isThisMonth { monthAlert = .confirmAddPast }
                    else            { addAction() }
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

            // ── Import unfinished (full-width & confirmed) ────────────
            if isThisMonth && hasPreviousUnfinished {
                HStack {
                    Button {
                        monthAlert = .confirmImportUnfinished      // prompt first
                    } label: {
                        Text("Import Unfinished from Last Month")
                            .font(.headline)
                            .foregroundColor(.orange)
                            .underline()
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                    }
                    .cornerRadius(8)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(12)

        // ── Single alert handler ───────────────────────
        .alert(item: $monthAlert) { alertCase in
            switch alertCase {

            case .confirmDeleteThisMonth(let pr):
                return Alert(
                    title: Text("Delete Priority"),
                    message: Text("Are you sure you want to delete “\(pr.title)” ?"),
                    primaryButton: .destructive(Text("Delete")) {
                        onDelete(pr); onCommit()
                    },
                    secondaryButton: .cancel()
                )

            case .confirmTogglePast(let pr):
                return Alert(
                    title: Text("Editing Past Month"),
                    message: Text("You’re about to change a past month’s priority. Continue?"),
                    primaryButton: .destructive(Text("Yes")) {
                        onToggle(pr.id); onCommit()
                    },
                    secondaryButton: .cancel()
                )

            case .confirmDeletePast(let pr):
                return Alert(
                    title: Text("Delete From Past Month"),
                    message: Text("You’re about to delete a priority from a past month. Continue?"),
                    primaryButton: .destructive(Text("Delete")) {
                        onDelete(pr); onCommit()
                    },
                    secondaryButton: .cancel()
                )

            case .confirmAddPast:
                return Alert(
                    title: Text("Adding to Past Month"),
                    message: Text("You’re adding a priority to a previous month. Continue?"),
                    primaryButton: .default(Text("Yes")) { addAction() },
                    secondaryButton: .cancel()
                )

            case .confirmImportUnfinished:
                return Alert(
                    title: Text("Import Unfinished?"),
                    message: Text("Copy all unfinished priorities from last month into this month?"),
                    primaryButton: .destructive(Text("Cancel")),
                    secondaryButton: .default(Text("Import")) { importAction() }
                )
            }
        }
    }

    // ─────────────────────────────────────────
    // MARK: – helper for array bindings
    // ─────────────────────────────────────────
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

    // ─────────────────────────────────────────
    // MARK: – Alert enum
    // ─────────────────────────────────────────
    enum MonthViewAlert: Identifiable {
        case confirmDeleteThisMonth(MonthlyPriority)
        case confirmTogglePast(MonthlyPriority)
        case confirmDeletePast(MonthlyPriority)
        case confirmAddPast
        case confirmImportUnfinished                            // NEW

        var id: String {
            switch self {
            case .confirmDeleteThisMonth(let p): return "deleteThis-\(p.id)"
            case .confirmTogglePast(let p):      return "togglePast-\(p.id)"
            case .confirmDeletePast(let p):      return "deletePast-\(p.id)"
            case .confirmAddPast:                return "addPast"
            case .confirmImportUnfinished:       return "importUnfinished"
            }
        }
    }
}
