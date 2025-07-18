//
//  DayPriorityPopup.swift
//  Mind Reset
//
//  Updated 07 Jun 2025
//  • Control buttons keep the same black background as the row text-fields.
//  • When “Remove Priority” mode is active, check-/x-icons are hidden so only
//    the red minus icons appear.
//

import SwiftUI

struct DayPriorityPopup: View {
    // ─────────── Bindings from MonthView ───────────
    @Binding var priorities: [TodayPriority]
    let date:    Date
    let onSave:  ([TodayPriority]) -> Void
    let onClose: () -> Void

    // ─────────── Local UI state ────────────────────
    @State private var isRemoveMode = false
    @State private var toDelete: TodayPriority?

    private let accentCyan = Color(red: 0, green: 1, blue: 1)

    var body: some View {
        VStack(spacing: 8) {
            header

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach($priorities) { $pr in
                        row(for: $pr)
                            .transition(.opacity)
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: min(listHeight, 300))

            controls
        }
        .padding(12)
        .background(Color.gray.opacity(0.8))
        .cornerRadius(12)
        .alert(item: $toDelete) { pr in
            Alert(
                title: Text("Delete Priority"),
                message: Text("Delete “\(pr.title)” ?"),
                primaryButton: .destructive(Text("Delete")) {
                    priorities.removeAll { $0.id == pr.id }
                    onSave(priorities)    // write once after explicit delete
                    if priorities.isEmpty { isRemoveMode = false }
                },
                secondaryButton: .cancel()
            )
        }
        .animation(.easeInOut, value: priorities)
    }

    // ─────────── Header ────────────────────────────
    private var header: some View {
        HStack {
            Text(dateFormatted(date))
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Button(action: {
                onSave(priorities)  // one-shot save of all edits
                onClose()
            }) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
    }

    // ─────────── Row View ──────────────────────────
    private func row(for pr: Binding<TodayPriority>) -> some View {
        let todayStart = Calendar.current.startOfDay(for: Date())
        let isPast = Calendar.current.startOfDay(for: date) < todayStart

        return HStack(spacing: 8) {
            // No more onChange here—user’s edits live-update the binding,
            // but we only persist once on close.
            TextField("Priority", text: pr.title)
                .font(.body)
                .foregroundColor(.white)
                .padding(.vertical, 10)
                .padding(.horizontal, 4)
                .background(Color.black)
                .cornerRadius(6)

            Spacer()

            if !isRemoveMode {
                Button {
                    pr.wrappedValue.isCompleted.toggle()
                    onSave(priorities)  // explicit toggle → persist
                } label: {
                    Image(systemName: pr.isCompleted.wrappedValue
                          ? "checkmark.circle.fill"
                          : (isPast ? "xmark.circle.fill" : "circle"))
                        .font(.title2)
                        .foregroundColor(
                            pr.isCompleted.wrappedValue
                            ? accentCyan
                            : (isPast ? .red : .gray)
                        )
                }
            }

            if isRemoveMode {
                Button(role: .destructive) { toDelete = pr.wrappedValue } label: {
                    Image(systemName: "minus.circle")
                        .font(.title2)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.horizontal, 4)
    }

    // ─────────── Bottom Controls ───────────────────
    private var controls: some View {
        HStack {
            Button("Add Priority") {
                priorities.append(
                    TodayPriority(id: .init(),
                                  title: "New Priority",
                                  progress: 0,
                                  isCompleted: false)
                )
                onSave(priorities)  // explicit add → persist
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

    // ─────────── Helpers ───────────────────────────
    private var listHeight: CGFloat {
        CGFloat(max(priorities.count, 1)) * 90
    }
    private func dateFormatted(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium
        return f.string(from: d)
    }
}

