//
//  DayCardView.swift
//  Mind Reset
//

import SwiftUI

struct DayCardView: View {
    // ─── injected ──────────────────────────────────────────────
    let accentColor: Color
    let day: Date
    @Binding var priorities: [TodayPriority]          // priorities for that day
    let priorityFocus: FocusState<Bool>.Binding       // shared focus from WeekView

    // ─── local ui state ────────────────────────────────────────
    @State private var isRemoveMode = false
    @State private var pendingDelete: TodayPriority?  // alerts

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
                        ForEach(priorities.indices, id: \.self) { idx in
                            WeekDayPriorityRowView(
                                title:       $priorities[idx].title,
                                isCompleted: $priorities[idx].isCompleted,
                                focus:       priorityFocus,
                                onToggle:    { priorities[idx].isCompleted.toggle() },
                                showDelete:  isRemoveMode,
                                onDelete:    { pendingDelete = priorities[idx] }, // trigger alert
                                accentCyan:  accentCyan,
                                onCommit:    {}
                            )
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: CGFloat(max(priorities.count, 1)) * 90)
            }

            // add / remove controls
            HStack {
                Button("Add Priority") { addPriority() }
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
        .alert(item: $pendingDelete) { pr in
            Alert(
                title: Text("Delete Priority"),
                message: Text("Are you sure you want to delete “\(pr.title)” ?"),
                primaryButton: .destructive(Text("Delete")) {
                    delete(pr)
                },
                secondaryButton: .cancel()
            )
        }
    }

    // MARK: – helpers
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
