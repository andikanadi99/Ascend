//
//  WeekCardView.swift
//  Mind Reset
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
    private let accentCyan = Color(red: 0, green: 1, blue: 1)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // ── Header ──────────────────────
            HStack {
                Text(weekLabel)
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.bottom, 4)

            // ── Placeholder or list ─────────
            if weeklyPriorities.isEmpty {
                emptyPlaceholder
            } else {
                priorityList
            }

            // ── Bottom buttons ──────────────
            HStack {
                Button {
                    isPastWeek ? (alert = .confirmAddPast) : addAction()
                } label: {
                    Text("Add Priority")
                        .lineLimit(1)
                        .fixedSize()
                }
                .styledAccent

                Spacer(minLength: 8)

                if !weeklyPriorities.isEmpty {
                    Button {
                        withAnimation { isRemoveMode.toggle() }
                    } label: {
                        Text(isRemoveMode ? "Done" : "Remove Priority")
                            .lineLimit(1)
                            .fixedSize()
                    }
                    .styledRed
                }
            }
            .padding(.top, 4)
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(12)
        .shadow(radius: 2)
        .alert(item: $alert, content: makeAlert)
    }

    // ───────────────────────── Header helpers
    private var weekLabel: String {
        let f = DateFormatter(); f.dateFormat = "MMM d"
        let s = f.string(from: weekStart)
        let e = Calendar.current.date(byAdding: .day, value: 6, to: weekStart)!
        return "\(s) – \(f.string(from: e))"
    }
    private var isPastWeek: Bool {
        let wk0 = Calendar.current.date(
            from: Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear],
                                                  from: Date()))!
        return weekStart < wk0
    }

    // ───────────────────────── Empty state
    private var emptyPlaceholder: some View {
        Text("No priorities this week")
            .foregroundColor(.white.opacity(0.7))
            .italic()
            .padding(.vertical, 20)
            .frame(maxWidth: .infinity)
            .background(Color(.sRGB, white: 0.1, opacity: 1))
            .cornerRadius(8)
    }

    // ───────────────────────── List
    private var priorityList: some View {
        List {
            ForEach(weeklyPriorities) { pr in
                let bind = binding(for: pr)

                WeekRow(
                    title:        bind.title,
                    isCompleted:  bind.isCompleted,
                    showDelete:   isRemoveMode,
                    isPastWeek:   isPastWeek,
                    accentCyan:   accentCyan,
                    onToggle: {
                        isPastWeek
                            ? (alert = .confirmTogglePast(pr))
                            : { onToggle(pr.id); onCommit() }()
                    },
                    onDeleteTap:  { alert = .delete(pr) },
                    onCommit:     onCommit
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
            .onMove(perform: move)
        }
        .id(isRemoveMode)                 // redraw when mode flips
        .listStyle(.plain)
        .scrollDisabled(true)
        .scrollContentBackground(.hidden)
        .environment(\.editMode, $editMode)
        .frame(height: CGFloat(max(weeklyPriorities.count, 1)) * 100)  // ← 100 pt each
        .padding(.bottom, 4)
    }

    // ───────────────────────── Alert builder
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

    // ───────────────────────── Bindings & move
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
    private func move(from off: IndexSet, to new: Int) {
        weeklyPriorities.move(fromOffsets: off, toOffset: new); onCommit()
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Row
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
                .font(.body)
                .padding(.vertical, padV/2)
                .padding(.leading, 4)
                .frame(height: h)
                .background(Color.black)
                .cornerRadius(8)
                .disabled(isPastWeek)
                .opacity(isPastWeek ? 0.6 : 1)
                .onChange(of: title) { _ in onCommit() }
                .overlay(
                    Text(title).font(.body).opacity(0)
                        .background(
                            GeometryReader { g in
                                Color.clear.preference(
                                    key: TextHeightPreferenceKey.self,
                                    value: g.size.height)
                            }
                        )
                )

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
        .onPreferenceChange(TextHeightPreferenceKey.self) { measuredH = $0 }
        .padding(4)
        .background(Color.black)
        .cornerRadius(8)
    }
}

// ─────────────────────────────────────────────────────────
// MARK: – Height probe
// ─────────────────────────────────────────────────────────
private struct TextHeightPreferenceKey: PreferenceKey {
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
// MARK: – Button styling helpers
// ─────────────────────────────────────────────────────────
private extension View {
    var styledAccent: some View {
        self
            .font(.headline)
            .foregroundColor(Color(red: 0, green: 1, blue: 1))
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.black)
            .cornerRadius(8)
    }
    var styledRed: some View {
        self
            .font(.headline)
            .foregroundColor(.red)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.black)
            .cornerRadius(8)
    }
}
