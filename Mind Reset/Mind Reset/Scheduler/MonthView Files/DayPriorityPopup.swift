//  DayPriorityPopup.swift
//  Mind Reset
//

import SwiftUI

struct DayPriorityPopup: View {
    // 🔗 Bindings supplied by MonthView -----------------------------------------
    @Binding var priorities: [TodayPriority]
    let date: Date
    let onSave: ([TodayPriority]) -> Void
    let onClose: () -> Void

    // UI state -----------------------------------------------------------------
    @State private var isRemoveMode = false          // show minus buttons
    @State private var toDelete: TodayPriority?      // confirmation alert

    // Style --------------------------------------------------------------------
    private let accentCyan = Color(red: 0, green: 1, blue: 1)

    // MARK: – Body -------------------------------------------------------------
    var body: some View {
        VStack(spacing: 8) {              // ↓ was 16
            header

            // MARK: – priorities list
            ScrollView {
                LazyVStack(spacing: 8) { // ↓ was 12
                    ForEach($priorities) { $pr in
                        row(for: $pr)
                            .transition(.opacity)
                    }
                }
                .padding(.vertical, 2)   // ↓ was 4
            }
            .frame(maxHeight: min(listHeight, 300)) // ↓ was 360

            controls
        }
        .padding(12)                     // tweak outer padding if you like
        .background(Color.gray.opacity(0.3))
        .cornerRadius(12)
        .alert(item: $toDelete) { pr in
            Alert(
                title: Text("Delete Priority"),
                message: Text("Are you sure you want to delete “\(pr.title)”?"),
                primaryButton: .destructive(Text("Delete")) {
                    priorities.removeAll { $0.id == pr.id }
                    persist()
                    if priorities.isEmpty { isRemoveMode = false }
                },
                secondaryButton: .cancel()
            )
        }
        .animation(.easeInOut, value: priorities)
    }

    // MARK: – Sub-views --------------------------------------------------------
    private var header: some View {
        HStack {
            Text(dateFormatted(date))
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
    }

    private func row(for pr: Binding<TodayPriority>) -> some View {
        // Determine if this date is in the past
        let todayStart = Calendar.current.startOfDay(for: Date())
        let isPast = Calendar.current.startOfDay(for: date) < todayStart

        // Explicitly return the HStack so the compiler knows this is the single View
        return HStack(spacing: 8) {
            Button {
                pr.wrappedValue.isCompleted.toggle()
                persist()
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

            TextField("Priority", text: pr.title)
                .font(.body)
                .foregroundColor(.white)
                .padding(.vertical, 10)          // extra vertical padding
                .padding(.horizontal, 4)
                .background(Color.black)
                .cornerRadius(6)
                .onChange(of: pr.title.wrappedValue) { _ in persist() }

            Spacer()

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

    private var controls: some View {
        HStack {
            Button("Add Priority") {
                priorities.append(
                    TodayPriority(id: .init(),
                                  title: "New Priority",
                                  progress: 0,
                                  isCompleted: false)
                )
                persist()
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

    // MARK: – Helpers ----------------------------------------------------------
    /// Persist the entire array upward.
    private func persist() { onSave(priorities) }

    /// Simple height heuristic: 90 pt per row + header + controls.
    private var listHeight: CGFloat {
        CGFloat(max(priorities.count, 1)) * 90
    }

    private func dateFormatted(_ d: Date) -> String {
        let f = DateFormatter(); f.dateStyle = .medium; return f.string(from: d)
    }
}
