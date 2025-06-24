//  WeekCardView.swift
//  Mind Reset
//
//  Styled to match DayCardView (scrollable >4 rows, spring animation,
//  flush-edge rows, identical button & card styling).
//

import SwiftUI

// ─────────────────────────────────────────────────────────
// MARK: – Card for a single week
// ─────────────────────────────────────────────────────────
struct WeekCardView: View {
    let accentColor: Color
    let weekStart:   Date

    @Binding var weeklyPriorities: [WeeklyPriority]
    @Binding var editMode:         EditMode
    @Binding var isRemoveMode:     Bool

    let onToggle:  (_ id: UUID) -> Void
    let onDelete:  (_ p: WeeklyPriority) -> Void
    let onCommit:  () -> Void
    let addAction: () -> Void

    @State private var alert: WeekAlert?

    // ── visual constants (copied from DayCardView) ─────────
    private let accentCyan     = Color(red: 0, green: 1, blue: 1)
    private let perRowHeight: CGFloat = 110
    private let bottomInset:   CGFloat = 16
    private let maxVisibleRows = 4
    
    

    var body: some View {
        VStack(alignment: .center, spacing: 12) {

            // ── Header (same typography) ──────────────────────
            HStack {
                Text(weekLabel)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.bottom, 4)

            // ── Placeholder or list ───────────────────────────
            if weeklyPriorities.isEmpty {
                Text("No priorities this week")
                    .foregroundColor(.white.opacity(0.7))
                    .italic()
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color(.sRGB, white: 0.1, opacity: 1))
                    .cornerRadius(8)
            } else {
                List {
                    ForEach(weeklyPriorities) { pr in
                        let bind = binding(for: pr)

                        WeekRow(
                            title:       bind.title,
                            isCompleted: bind.isCompleted,
                            showDelete:  isRemoveMode,
                            isPastWeek:  isPastWeek,
                            accentCyan:  accentCyan,
                            onToggle: {
                                isPastWeek
                                    ? (alert = .confirmTogglePast(pr))
                                    : { onToggle(pr.id); onCommit() }()
                            },
                            onDeleteTap: { alert = .delete(pr) },
                            onCommit:    onCommit
                        )
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(.init(top: 4, leading: 0, bottom: 4, trailing: 0))
                    }
                    .onMove { from, to in
                        withAnimation(.interactiveSpring(response: 0.3,
                                                         dampingFraction: 0.7)) {
                            weeklyPriorities.move(fromOffsets: from, toOffset: to)
                            onCommit()
                        }
                    }
                }
                .id(isRemoveMode) // force redraw when mode toggles
                .listStyle(.plain)
                .scrollDisabled(weeklyPriorities.count <= maxVisibleRows)   // enable scroll only if needed
                .scrollContentBackground(.hidden)
                .environment(\.editMode, $editMode)
                // height = min(total, maxVisible) + inset
                .frame(
                    height: min(
                        CGFloat(weeklyPriorities.count) * perRowHeight + bottomInset,
                        CGFloat(maxVisibleRows)         * perRowHeight + bottomInset
                    )
                )
            }

            // ── Bottom buttons (identical styling) ────────────
            HStack(spacing: 12) {
                // “Add Priority” (never wraps)
                Button {
                    isPastWeek ? (alert = .confirmAddPast) : addAction()
                } label: {
                    Text("Add Priority")
                        .lineLimit(1)
                        .fixedSize()          // keep on a single line
                }
                .styledAccent

                Spacer()

                // “Remove / Done” (never wraps)
                if !weeklyPriorities.isEmpty {
                    Button {
                        withAnimation(.easeInOut) { isRemoveMode.toggle() }
                    } label: {
                        Text(isRemoveMode ? "Done" : "Remove Priority")
                            .lineLimit(1)
                            .fixedSize()      // keep on a single line
                    }
                    .styledRed
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(12)
        .shadow(radius: 2)
        .alert(item: $alert, content: makeAlert)
    }

    // ───────────────────────── Header helpers
    private var weekLabel: String {
        // read 0…6 from UserDefaults, where 0=Sunday, 1=Monday, …, 6=Saturday
        let idx = UserDefaults.standard.integer(forKey: "weekStartIndex")
        var cal = Calendar.current
        cal.firstWeekday = idx + 1

        let f = DateFormatter()
        f.dateFormat = "MMM d"

        // anchor to the true first day of this week
        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: weekStart)
        guard let anchor = cal.date(from: comps) else { return "" }
        let end = cal.date(byAdding: .day, value: 6, to: anchor)!

        return "\(f.string(from: anchor)) – \(f.string(from: end))"
    }

    private var isPastWeek: Bool {
        // build “start of this week” using the same firstWeekday
        let idx = UserDefaults.standard.integer(forKey: "weekStartIndex")
        var cal = Calendar.current
        cal.firstWeekday = idx + 1

        let comps = cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        guard let todayAnchor = cal.date(from: comps) else { return false }

        return weekStart < todayAnchor
    }

    // ───────────────────────── Alerts
    private func makeAlert(for a: WeekAlert) -> Alert {
        switch a {
        case .delete(let p):
            return Alert(
                title: Text("Delete Priority"),
                message: Text("Delete “\(p.title)”?"),
                primaryButton: .destructive(Text("Delete")) {
                    onDelete(p); onCommit()
                },
                secondaryButton: .cancel()
            )
        case .confirmTogglePast(let p):
            return Alert(
                title: Text("Editing Past Week"),
                message: Text("Change a past week’s priority?"),
                primaryButton: .destructive(Text("Yes")) {
                    onToggle(p.id); onCommit()
                },
                secondaryButton: .cancel()
            )
        case .confirmAddPast:
            return Alert(
                title: Text("Adding to Past Week"),
                message: Text("Add a priority into a previous week?"),
                primaryButton: .default(Text("Yes")) { addAction() },
                secondaryButton: .cancel()
            )
        }
    }

    // ───────────────────────── Bindings & move helper
    private func binding(for p: WeeklyPriority)
      -> (title: Binding<String>, isCompleted: Binding<Bool>) {
        guard let i = weeklyPriorities.firstIndex(where: { $0.id == p.id })
        else { fatalError("Priority not found") }
        return (
            Binding(
                get: { weeklyPriorities[i].title },
                set: { weeklyPriorities[i].title = $0 }
            ),
            Binding(
                get: { weeklyPriorities[i].isCompleted },
                set: { weeklyPriorities[i].isCompleted = $0 }
            )
        )
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Row (visually identical to WeekDayPriorityRowView)
// ─────────────────────────────────────────────────────────
private struct WeekRow: View {
    @Binding var title:       String
    @Binding var isCompleted: Bool

    let showDelete:  Bool
    let isPastWeek:  Bool
    let accentCyan:  Color

    let onToggle:    () -> Void
    let onDeleteTap: () -> Void
    let onCommit:    () -> Void

    @State private var measuredH: CGFloat = 50

    var body: some View {
        let padV: CGFloat = 24, minH: CGFloat = 50
        let h = max(measuredH + padV, minH)

        HStack(spacing: 8) {
            TextEditor(text: $title)
                .scrollContentBackground(.hidden)
                .foregroundColor(.white) 
                .font(.body)
                .padding(.vertical, padV/2)
                .padding(.horizontal, 8)
                .frame(height: h)
                .background(Color.black)
                .cornerRadius(8)
//                .disabled(isPastWeek)
                .opacity(isPastWeek ? 0.6 : 1)
                .onChange(of: title) { _ in onCommit() }
                .overlay(
                    Text(title).font(.body).opacity(0)
                        .background(
                            GeometryReader { g in
                                Color.clear.preference(
                                    key: TextHeightPref.self,
                                    value: g.size.height)
                            }
                        )
                )

            // trailing icon(s)
            if showDelete {
                Button(role: .destructive, action: onDeleteTap) {
                    Image(systemName: "minus.circle")
                }
                .buttonStyle(.borderless)
                .font(.title2)
                .foregroundColor(.red)
            } else {
                Button(action: onToggle) {
                    Image(systemName:
                          isCompleted ? "checkmark.circle.fill"
                          : (isPastWeek ? "xmark.circle.fill" : "circle"))
                }
                .buttonStyle(.borderless)
                .font(.title2)
                .foregroundColor(
                    isCompleted ? accentCyan
                    : (isPastWeek ? .red : .gray)
                )
            }
        }
        .onPreferenceChange(TextHeightPref.self) { measuredH = $0 }
        .padding(4)
        .background(Color.black)
        .cornerRadius(8)
        // NEW → keep the row centred horizontally inside the List / card
        .frame(maxWidth: .infinity, alignment: .center)   // ← add this line
    }
}

// preference key for dynamic height
private struct TextHeightPref: PreferenceKey {
    static var defaultValue: CGFloat = 50
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Alerts
// ─────────────────────────────────────────────────────────
private enum WeekAlert: Identifiable {
    case delete(WeeklyPriority)
    case confirmTogglePast(WeeklyPriority)
    case confirmAddPast

    var id: String {
        switch self {
        case .delete(let p):            return "del-\(p.id)"
        case .confirmTogglePast(let p): return "toggle-\(p.id)"
        case .confirmAddPast:           return "addPast"
        }
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Button styling helpers (same as DayCardView)
// ─────────────────────────────────────────────────────────
private extension View {
    var styledAccent: some View {
        self.font(.headline)
            .foregroundColor(Color(red: 0, green: 1, blue: 1))
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.black)
            .cornerRadius(8)
    }
    var styledRed: some View {
        self.font(.headline)
            .foregroundColor(.red)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.black)
            .cornerRadius(8)
    }
}
