//
//  MonthlyPrioritiesSection.swift
//  Mind Reset
//
//  Shows a reorderable, check-off list of monthly priorities plus
//  Add / Remove controls and a confirmation prompt on delete.
//  Updated 29 May 2025.
//

import SwiftUI

struct MonthlyPrioritiesSection: View {
    @Binding var priorities: [MonthlyPriority]
    @Binding var editMode:   EditMode

    let accentColor:   Color
    let isRemoveMode:  Bool
    let onToggleRemoveMode: () -> Void
    let onToggle:      (UUID) -> Void
    let onMove:        (IndexSet, Int) -> Void
    let onCommit:      () -> Void
    let onDelete:      (MonthlyPriority) -> Void   // bubbles up to MonthView
    let addAction:     () -> Void

    @State private var priorityToDelete: MonthlyPriority?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // ── header ───────────────────────────────────────
            Text("Monthly Priorities")
                .font(.headline)
                .foregroundColor(accentColor)

            // ── list / placeholder ───────────────────────────
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
                            onToggle:    { onToggle(pr.id) },
                            showDelete:  isRemoveMode,
                            onDelete:    { priorityToDelete = pr },
                            accentCyan:  accentColor,
                            onCommit:    onCommit
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(.init(top: 4, leading: 0,
                                             bottom: 4, trailing: 0))
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

            // ── buttons ──────────────────────────────────────
            HStack {
                Button("Add Priority", action: addAction)
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
        }
        .padding()                                     // card padding
        .background(Color.gray.opacity(0.3))           // <-- grey card bg
        .cornerRadius(12)
        .alert(item: $priorityToDelete) { pr in
            Alert(
                title: Text("Delete Priority"),
                message: Text("Are you sure you want to delete “\(pr.title)”?"),
                primaryButton: .destructive(Text("Delete")) {
                    onDelete(pr)
                },
                secondaryButton: .cancel()
            )
        }
    }

    // helper for array bindings
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
}

