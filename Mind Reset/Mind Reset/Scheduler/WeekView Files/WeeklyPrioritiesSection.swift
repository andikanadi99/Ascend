// WeeklyPrioritiesSection.swift
// Ascento
//
// Created by Andika Yudhatrisna on 5/27/25.

import SwiftUI

/// Section showing the weekly priorities list with drag-to-reorder, inline checkmarks, confirmation on delete, and add/remove buttons.
struct WeeklyPrioritiesSection: View {
    @Binding var priorities: [WeeklyPriority]
    @Binding var editMode: EditMode
    let accentColor: Color
    let isRemoveMode: Bool
    let onToggleRemoveMode: () -> Void
    let onMove: (IndexSet, Int) -> Void
    let onCommit: () -> Void
    let onDelete: (WeeklyPriority) -> Void
    let addAction: () -> Void

    @State private var priorityToDelete: WeeklyPriority? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Weekly Priorities")
                    .font(.headline)
                    .foregroundColor(accentColor)
                Spacer()
            }

            if priorities.isEmpty {
                Text("Please list your priorities for the week")
                    .foregroundColor(Color.white.opacity(0.7))
                    .italic()
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color(.sRGB, white: 0.1, opacity: 1))
                    .cornerRadius(8)
            } else {
                List {
                    ForEach($priorities) { $priority in
                        WeeklyPriorityRowView(
                            title:       $priority.title,
                            isCompleted: $priority.isCompleted,
                            showDelete:  isRemoveMode,
                            onDelete:    { priorityToDelete = priority },
                            accentCyan:  accentColor,
                            onCommit:    onCommit
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
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
        .alert(item: $priorityToDelete) { priority in
            Alert(
                title: Text("Delete Priority"),
                message: Text("Are you sure you want to delete ‘\(priority.title)’?"),
                primaryButton: .destructive(Text("Delete")) {
                    onDelete(priority)
                },
                secondaryButton: .cancel()
            )
        }
    }
}
