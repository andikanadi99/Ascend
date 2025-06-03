//  DayCardView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 5/27/25.
//

import SwiftUI
import Foundation   // ensures TodayPriority is visible

struct DayCardView: View {
    // ─── injected ──────────────────────────────────────────────
    let accentColor: Color
    let day: Date
    @Binding var priorities: [TodayPriority]          // priorities for that day
    let priorityFocus: FocusState<Bool>.Binding       // shared focus from WeekView

    // ─── local ui state ────────────────────────────────────────
    @State private var isRemoveMode = false
    @State private var pendingDelete: TodayPriority?  // for “delete” confirmation
    @State private var pastDayAlert: DayCardAlert?    // for “past-day editing” confirmation
    @State private var pendingToggle: TodayPriority?  // store priority to toggle after confirm

    // palette
    private let accentCyan = Color(red: 0, green: 1, blue: 1)

    // MARK: – body
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            // priorities list or placeholder
            if priorities.isEmpty {
                placeholder
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        // ───── Use 0..<priorities.count instead of priorities.indices ─────
                        ForEach(0 ..< priorities.count, id: \.self) { idx in
                            let pr = priorities[idx]
                            let isPast = isPastDay()

                            WeekDayPriorityRowView(
                                title:       $priorities[idx].title,
                                isCompleted: $priorities[idx].isCompleted,
                                focus:       priorityFocus,
                                onToggle: {
                                    if isPast {
                                        pendingToggle = pr
                                        pastDayAlert = .confirmModify(pr)
                                    } else {
                                        priorities[idx].isCompleted.toggle()
                                    }
                                },
                                showDelete:  isRemoveMode,
                                onDelete:    {
                                    if isPast {
                                        pastDayAlert = .confirmDelete(pr)
                                    } else {
                                        pendingDelete = pr
                                    }
                                },
                                accentCyan:  accentCyan,
                                onCommit:    {},
                                isPast:      isPast
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }



                // ─── end of ScrollView
                .frame(maxHeight: CGFloat(max(priorities.count, 1)) * 90)
            }

            // add / remove controls
            HStack {
                Button("Add Priority") {
                    if isPastDay() {
                        pastDayAlert = .confirmAdd
                    } else {
                        addPriority()
                    }
                }
                .font(.headline)
                .foregroundColor(accentCyan)
                .padding(.vertical, 8)
                .padding(.horizontal, 16)
                .background(Color.black)
                .cornerRadius(8)

                Spacer()

                if !priorities.isEmpty {
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
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
        // ───── Alerts ─────
        .alert(item: $pendingDelete) { pr in
            Alert(
                title: Text("Delete Priority"),
                message: Text("Delete “\(pr.title)”?"),
                primaryButton: .destructive(Text("Delete")) {
                    delete(pr)
                },
                secondaryButton: .cancel()
            )
        }
        .alert(item: $pastDayAlert) { alertCase in
            switch alertCase {
            case .confirmModify(let pr):
                return Alert(
                    title: Text("Editing Past Day"),
                    message: Text("You’re changing a priority from a previous day. Continue?"),
                    primaryButton: .destructive(Text("Yes")) {
                        if let idx = priorities.firstIndex(where: { $0.id == pr.id }) {
                            priorities[idx].isCompleted.toggle()
                        }
                    },
                    secondaryButton: .cancel()
                )

            case .confirmDelete(let pr):
                return Alert(
                    title: Text("Deleting From Past Day"),
                    message: Text("You’re deleting a priority from a previous day. Continue?"),
                    primaryButton: .destructive(Text("Delete")) {
                        delete(pr)
                    },
                    secondaryButton: .cancel()
                )

            case .confirmAdd:
                return Alert(
                    title: Text("Adding to Past Day"),
                    message: Text("You’re adding a priority to a previous day. Continue?"),
                    primaryButton: .default(Text("Yes")) {
                        addPriority()
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    // MARK: – helpers
    private func isPastDay() -> Bool {
        let today = Calendar.current.startOfDay(for: Date())
        return Calendar.current.startOfDay(for: day) < today
    }

    private func addPriority() {
        priorities.append(
            TodayPriority(id: UUID(),
                          title: "New Priority",
                          progress: 0,
                          isCompleted: false)
        )
        isRemoveMode = false
    }

    private func delete(_ pr: TodayPriority) {
        priorities.removeAll { $0.id == pr.id }
        if priorities.isEmpty { isRemoveMode = false }
    }

    // placeholder shown when the list is empty
    private var placeholder: some View {
        Text("Please list priorities for this day")
            .foregroundColor(.white.opacity(0.7))
            .italic()
            .frame(maxWidth: .infinity, minHeight: 90)
            .background(Color(.sRGB, white: 0.1, opacity: 1))
            .cornerRadius(8)
    }

    private var header: some View {
        VStack(alignment: .leading) {
            Text(dayOfWeek).font(.headline).foregroundColor(.white)
            Text(formattedDate).font(.caption).foregroundColor(.white.opacity(0.7))
        }
        .padding(.bottom, 4)
    }

    private var dayOfWeek: String {
        let f = DateFormatter(); f.dateFormat = "EEEE"; return f.string(from: day)
    }
    private var formattedDate: String {
        let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: day)
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: – Alert cases for DayCardView
// ─────────────────────────────────────────────────────────────────────────────
enum DayCardAlert: Identifiable {
    case confirmModify(TodayPriority)
    case confirmDelete(TodayPriority)
    case confirmAdd

    var id: String {
        switch self {
        case .confirmModify(let p):
            return "confirmModify-\(p.id)"
        case .confirmDelete(let p):
            return "confirmDelete-\(p.id)"
        case .confirmAdd:
            return "confirmAdd"
        }
    }
}
