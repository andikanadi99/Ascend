//
//  WeeklyPrioritiesSection.swift
//  Mind Reset
//
//  List of weekly priorities with drag-to-reorder, auto-expanding rows,
//  delete confirmations, and an import-unfinished confirmation.
//

import SwiftUI

// MARK: – Preference key for List height
private struct WeeklyPriorityListHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value += nextValue() }
}

// MARK: – Alert types
private enum WeeklyPriorityAlert: Identifiable {
    case deleteCurrent(WeeklyPriority)
    case deletePast(WeeklyPriority)

    var id: String {
        switch self {
        case .deleteCurrent(let p): return "deleteCurrent-\(p.id)"
        case .deletePast(let p):    return "deletePast-\(p.id)"
        }
    }
}

// MARK: – Section view
struct WeeklyPrioritiesSection: View {
    // ───── data & state ─────
    @Binding var priorities: [WeeklyPriority]
    @Binding var editMode:   EditMode
    @Binding var listHeight: CGFloat

    @State private var deleteAlert: WeeklyPriorityAlert?
    @State private var showImportAlert = false

    // ───── config / callbacks ─────
    let accentColor:           Color
    let isRemoveMode:          Bool
    let onToggleRemoveMode:    () -> Void
    let onMove:                (IndexSet, Int) -> Void
    let onCommit:              () -> Void
    let onDeleteConfirmed:     (WeeklyPriority) -> Void
    let addAction:             () -> Void

    // extra flags
    let isThisWeek:            Bool
    let isPastWeek:            Bool
    let hasPreviousUnfinished: Bool
    let importAction:          () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Weekly Priorities")
                .font(.headline)
                .foregroundColor(accentColor)

            // ─── list or placeholder ───
            if priorities.isEmpty {
                Text("Add some priorities for this week")
                    .foregroundColor(.white.opacity(0.7))
                    .italic()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color(.sRGB, white: 0.1, opacity: 1))
                    .cornerRadius(8)
            } else {
                List {
                    Section {
                        ForEach($priorities) { $priority in
                            WeeklyPriorityRowView(
                                title:       $priority.title,
                                isCompleted: $priority.isCompleted,
                                onToggle: {
                                    priority.isCompleted.toggle()   // flip the check-mark
                                    onCommit()                      // persist
                                },
                                showDelete:  isRemoveMode,
                                onDelete:    {
                                    deleteAlert = isPastWeek
                                        ? .deletePast(priority)
                                        : .deleteCurrent(priority)
                                },
                                accentCyan:  accentColor,
                                onCommit:    onCommit,
                                isPastWeek:  isPastWeek
                            )
                            .listRowBackground(Color.clear)
                            .listRowInsets(.init(top: 4, leading: 0, bottom: 4, trailing: 0))
                            .listRowSeparator(.hidden)
                            .background(
                                GeometryReader { geo in
                                    Color.clear.preference(
                                        key: WeeklyPriorityListHeightKey.self,
                                        value: geo.size.height + 8
                                    )
                                }
                            )
                        }
                        .onMove(perform: onMove)
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .listRowSeparator(.hidden)
                .listSectionSeparator(.hidden)
                .background(Color.clear)
                .frame(minHeight: max(listHeight,
                                       CGFloat(priorities.count) * 60))
                .onPreferenceChange(WeeklyPriorityListHeightKey.self) {
                    listHeight = $0
                }
                .environment(\.editMode, $editMode)
            }

            // ─── Add / Remove controls ───
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

            // ─── Import unfinished prompt ───
            if isThisWeek && hasPreviousUnfinished {
                HStack {
                    Button {
                        showImportAlert = true         // ask first
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
        // ─── deletion alerts ───
        .alert(item: $deleteAlert) { alert in
            switch alert {
            case .deleteCurrent(let p):
                return Alert(
                    title: Text("Delete Priority"),
                    message: Text("Delete “\(p.title)”?"),
                    primaryButton: .destructive(Text("Delete")) {
                        onDeleteConfirmed(p)
                    },
                    secondaryButton: .cancel()
                )
            case .deletePast(let p):
                return Alert(
                    title: Text("Delete From Past Week"),
                    message: Text("You’re removing a priority from a previous week. Continue?"),
                    primaryButton: .destructive(Text("Delete")) {
                        onDeleteConfirmed(p)
                    },
                    secondaryButton: .cancel()
                )
            }
        }
        // ─── import confirmation alert ───
        .alert("Import unfinished priorities from last week?",
               isPresented: $showImportAlert,
               actions: {
                   Button("Import", role: .destructive) { importAction() }
                   Button("Cancel", role: .cancel) { }
               },
               message: {
                   Text("Any unfinished priorities from last week that don’t match an existing title will be added to this week.")
               })
    }
}
