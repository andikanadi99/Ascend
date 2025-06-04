//  WeekCardView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 06/04/2024.
//

import SwiftUI

/// A single card showing exactly one week’s “weekly priorities.”
/// It uses the same style as DayCardView (headers, dynamic TextEditor height, etc.)
struct WeekCardView: View {
    let accentColor: Color
    let weekStart:   Date

    /// Bound to your array of WeeklyPriority for this week
    @Binding var weeklyPriorities: [WeeklyPriority]

    /// Shared SwiftUI EditMode for drag‐and‐drop reordering
    @Binding var editMode: EditMode

    /// Puts a red “minus” icon next to each row when true
    @Binding var isRemoveMode: Bool

    /// Called when the user taps the checkmark circle for a priority
    let onToggle: (_ priorityId: UUID) -> Void

    /// Called when the user confirms “delete” on a priority
    let onDelete: (_ priority: WeeklyPriority) -> Void

    /// Called any time you want to persist changes to all weekly priorities
    let onCommit: () -> Void

    /// Called to append a new “New Priority” to this week
    let addAction: () -> Void

    // ─── Internal state for “are we about to delete X?” ─────────────────────
    @State private var activeAlert: WeekAlert?

    /// Color used for checkmarks
    private let accentCyan = Color(red: 0, green: 1, blue: 1)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            // ── If the week has no priorities, show a placeholder ─────────
            if weeklyPriorities.isEmpty {
                Text("No priorities this week")
                    .foregroundColor(.white.opacity(0.7))
                    .italic()
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color(.sRGB, white: 0.1, opacity: 1))
                    .cornerRadius(8)
            }
            // ── Otherwise, show a reorderable list of rows ───────────────
            else {
                List {
                    ForEach(weeklyPriorities) { pr in
                        let bindings = binding(for: pr)
                        MonthlyWeeklyPriorityRowView(
                            title:       bindings.title,
                            isCompleted: bindings.isCompleted,
                            onToggle: {
                                if isPastWeek {
                                    activeAlert = .confirmTogglePast(pr)
                                } else {
                                    onToggle(pr.id)
                                    onCommit()
                                }
                            },
                            showDelete:  isRemoveMode,
                            onDelete: {
                                if isPastWeek {
                                    activeAlert = .confirmDeletePast(pr)
                                } else {
                                    activeAlert = .delete(pr)
                                }
                            },
                            accentCyan:  accentCyan,
                            onCommit:    onCommit,
                            isPastWeek:  isPastWeek
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0,
                                                  bottom: 4, trailing: 0))
                        .listRowSeparator(.hidden)
                    }
                    .onMove(perform: move)
                }
                .listStyle(PlainListStyle())
                .scrollDisabled(true)
                .scrollContentBackground(.hidden)
                .frame(minHeight: CGFloat(weeklyPriorities.count) * 90)
                .environment(\.editMode, $editMode)
                .padding(.bottom, 4)
            }

            // ── “Add / Remove” buttons ─────────────────────────────────────
            HStack {
                Button("Add Priority") {
                    if isPastWeek {
                        activeAlert = .confirmAddPast
                    } else {
                        addAction()
                    }
                }
                .font(.headline)
                .foregroundColor(accentCyan)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.black)
                .cornerRadius(8)

                Spacer()

                if !weeklyPriorities.isEmpty {
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
            .padding(.top, 4)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
        .shadow(radius: 2)

        // Single alert modifier, switching on `activeAlert`
        .alert(item: $activeAlert) { alertCase in
            switch alertCase {
            case .delete(let pr):
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
                    title: Text("Editing Past Week"),
                    message: Text("""
                      You’re about to change the completion status \
                      of a priority from a previous week. Continue?
                      """),
                    primaryButton: .destructive(Text("Yes")) {
                        onToggle(pr.id)
                        onCommit()
                    },
                    secondaryButton: .cancel()
                )

            case .confirmDeletePast(let pr):
                return Alert(
                    title: Text("Delete From Past Week"),
                    message: Text("""
                      You’re about to delete a priority from a previous \
                      week. Continue?
                      """),
                    primaryButton: .destructive(Text("Delete")) {
                        onDelete(pr)
                        onCommit()
                    },
                    secondaryButton: .cancel()
                )

            case .confirmAddPast:
                return Alert(
                    title: Text("Adding to Past Week"),
                    message: Text("""
                      You’re adding a new priority into a previous week, \
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
    private func binding(for pr: WeeklyPriority)
      -> (title: Binding<String>, isCompleted: Binding<Bool>) {
        guard let idx = weeklyPriorities.firstIndex(where: { $0.id == pr.id }) else {
            fatalError("Priority not found")
        }
        return (
            Binding(
                get: { weeklyPriorities[idx].title },
                set: { weeklyPriorities[idx].title = $0 }
            ),
            Binding(
                get: { weeklyPriorities[idx].isCompleted },
                set: { weeklyPriorities[idx].isCompleted = $0 }
            )
        )
    }

    // ────────────────────────────────────────────────────────────────────────────────
    // MARK: – reorder helper
    // ────────────────────────────────────────────────────────────────────────────────
    private func move(from offsets: IndexSet, to newOffset: Int) {
        weeklyPriorities.move(fromOffsets: offsets, toOffset: newOffset)
        onCommit()
    }

    // ────────────────────────────────────────────────────────────────────────────────
    // MARK: – header (“MMM d – MMM d”)
    // ────────────────────────────────────────────────────────────────────────────────
    private var header: some View {
        HStack {
            Text(weekLabel)
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.bottom, 4)
    }

    private var weekLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        let startStr = fmt.string(from: weekStart)
        guard let endDate = Calendar.current.date(
                byAdding: .day, value: 6, to: weekStart)
        else {
            return startStr
        }
        return "\(startStr) – \(fmt.string(from: endDate))"
    }

    /// True if this week is before the calendar’s current week
    private var isPastWeek: Bool {
        let todayWeekStart = Calendar.current
            .date(from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear],
                                                        from: Date()))!
        return weekStart < todayWeekStart
    }
}

// ───────────────────────────────────────────────────────────────────────────────
// MARK: – A single row inside WeekCardView, styled like DayCardView’s row
// ───────────────────────────────────────────────────────────────────────────────
private struct MonthlyWeeklyPriorityRowView: View {
    @Binding var title:       String
    @Binding var isCompleted: Bool

    let onToggle:   () -> Void
    let showDelete: Bool
    let onDelete:   () -> Void
    let accentCyan: Color
    let onCommit:   () -> Void

    let isPastWeek: Bool

    @State private var measuredHeight: CGFloat = 50

    var body: some View {
        // identical measurement‐based layout as DayCardView’s rows
        let minH: CGFloat = 50
        let vPad: CGFloat = 24
        let h = max(measuredHeight + vPad, minH)

        HStack(spacing: 8) {
            ZStack(alignment: .trailing) {
                // Invisible “probe” for dynamic height
                Text(title)
                    .font(.body)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: TextHeightPreferenceKey.self,
                                value: geo.size.height
                            )
                        }
                    )
                    .opacity(0)

                // Editable TextEditor
                TextEditor(text: $title)
                    .font(.body)
                    .padding(.vertical, vPad/2)
                    .padding(.leading,   4)
                    .padding(.trailing,  40)
                    .frame(height: h)
                    .background(Color.black)
                    .cornerRadius(8)
                    .disabled(isPastWeek) // disable editing for past‐week
                    .opacity(isPastWeek ? 0.6 : 1.0)
                    .onChange(of: title) { _ in onCommit() }

                // Checkmark / “X” for past weeks
                if !showDelete {
                    Button {
                        onToggle()
                        onCommit()
                    } label: {
                        Group {
                            if isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                            } else if isPastWeek {
                                Image(systemName: "xmark.circle.fill")
                            } else {
                                Image(systemName: "circle")
                            }
                        }
                        .font(.title2)
                        .foregroundColor(
                            isCompleted
                                ? accentCyan
                                : (isPastWeek ? .red : .gray)
                        )
                    }
                    .padding(.trailing, 8)
                }
            }
            .onPreferenceChange(TextHeightPreferenceKey.self) {
                measuredHeight = $0
            }

            // Delete button (only if showDelete is true)
            if showDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .padding(.trailing, 8)
            }
        }
        .padding(4)
        .background(Color.black)
        .cornerRadius(8)
    }
}

// ───────────────────────────────────────────────────────────────────────────────
// MARK: – TextHeightPreferenceKey (used inside the row above) ───────────────────
private struct TextHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 50
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// ───────────────────────────────────────────────────────────────────────────────
// MARK: – Single enum for all alert cases
// ───────────────────────────────────────────────────────────────────────────────
private enum WeekAlert: Identifiable {
    case delete(WeeklyPriority)
    case confirmTogglePast(WeeklyPriority)
    case confirmDeletePast(WeeklyPriority)
    case confirmAddPast

    var id: String {
        switch self {
        case .delete(let p):
            return "delete-\(p.id)"
        case .confirmTogglePast(let p):
            return "togglePast-\(p.id)"
        case .confirmDeletePast(let p):
            return "deletePast-\(p.id)"
        case .confirmAddPast:
            return "addPast"
        }
    }
}
