// WeekListView.swift
// Ascento
//
// ScrollView + LazyVStack–based week view, styled like DayCardView.

import SwiftUI

@available(iOS 16.0, *)
struct WeekListView: View {
    let weekStart: Date
    let blocksPerDay: [Date: [TimelineBlock]]
    let accentColor: RGBAColor

    let onEdit: (TimelineBlock) -> Void
    let onCreateDraft: (TimelineBlock) -> Void
    let onDelete: (TimelineBlock) -> Void

    /// “Monday, July 7, 2025”
    private let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d, yyyy"
        return f
    }()

    /// “7:00 AM”
    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                ForEach(0..<7, id: \.self) { offset in
                    // compute day & its tasks
                    let day = Calendar.current.date(
                        byAdding: .day,
                        value: offset,
                        to: weekStart
                    )!
                    let key    = Calendar.current.startOfDay(for: day)
                    let tasks  = (blocksPerDay[key] ?? [])
                        .filter { block in
                            guard let t = block.title else { return false }
                            return !t.trimmingCharacters(in: .whitespaces).isEmpty
                        }
                        .sorted { $0.start < $1.start }

                    // ── Card Container ─────────────────────────────
                    VStack(alignment: .leading, spacing: 12) {
                        // Header
                        Text(dateFormatter.string(from: day))
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.bottom, 4)

                        // Section title
                        Text("Today's Tasks")
                            .font(.headline)
                            .foregroundColor(Color(red: 0, green: 1, blue: 1))

                        // ─ Tasks or Placeholder ─
                        if tasks.isEmpty {
                            Text("No tasks for this day")
                                .foregroundColor(.white.opacity(0.7))
                                .italic()
                                .padding(.vertical, 20)
                                .frame(maxWidth: .infinity)
                                .background(Color(.sRGB, white: 0.1))
                                .cornerRadius(8)
                        } else {
                            ForEach(tasks) { block in
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(
                                            "\(timeFormatter.string(from: block.start)) – " +
                                            "\(timeFormatter.string(from: block.end))"
                                        )
                                        .font(.subheadline)
                                        .foregroundColor(.gray)

                                        Text(block.title!)
                                            .font(.body)
                                            .foregroundColor(.white)
                                    }
                                    Spacer()
                                }
                                .padding(.vertical, 16)
                                .padding(.horizontal, 16)
                                .background(Color.black)   // black box
                                .cornerRadius(8)
                            }
                        }

                        // ─ Bottom Buttons ─
                        HStack {
                            Button {
                                // create 1h draft at 9am
                                let base  = Calendar.current.startOfDay(for: day)
                                let start = Calendar.current.date(byAdding: .hour, value: 9, to: base)!
                                let end   = Calendar.current.date(byAdding: .hour, value: 10, to: base)!
                                var draft = TimelineBlock(
                                    start:       start,
                                    end:         end,
                                    title:       nil,
                                    description: nil,
                                    color:       accentColor.swiftUIColor
                                )
                                onCreateDraft(draft)
                            } label: {
                                Text("Add Task")
                                    .lineLimit(1)
                                    .fixedSize()
                            }
                            .styledAccent     // cyan on black

                            Spacer()

                            if let last = tasks.last {
                                Button {
                                    onDelete(last)
                                } label: {
                                    Text("Remove Task")
                                        .lineLimit(1)
                                        .fixedSize()
                                }
                                .styledRed       // red on black
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                }
            }
        }
        .background(Color.black.edgesIgnoringSafeArea(.all))
    }
}

// ───────────────────────────────────────────────
// MARK: – Button style extensions
// ───────────────────────────────────────────────
private extension View {
    /// cyan-on-black
    var styledAccent: some View {
        self.font(.headline)
            .foregroundColor(Color(red: 0, green: 1, blue: 1))
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.black)
            .cornerRadius(8)
    }
    /// red-on-black
    var styledRed: some View {
        self.font(.headline)
            .foregroundColor(.red)
            .padding(.vertical, 8)
            .padding(.horizontal, 16)
            .background(Color.black)
            .cornerRadius(8)
    }
}
