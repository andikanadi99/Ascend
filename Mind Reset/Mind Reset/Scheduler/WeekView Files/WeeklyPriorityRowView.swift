//  WeeklyPriorityRowView.swift
//  Mind Reset
//
//  Mirrors DayView’s PriorityRowView but hides the check-mark while
//  `showDelete == true` (i.e. Remove-mode).

import SwiftUI

// preference key for dynamic-height measurement
private struct TextHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 50
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct WeeklyPriorityRowView: View {
    // ───────── bindings ─────────
    @Binding var title: String
    @Binding var isCompleted: Bool

    // ───────── callbacks / config ─────────
    let onToggle:   () -> Void
    let showDelete: Bool           // Remove-mode flag
    let onDelete:   () -> Void
    let accentCyan: Color
    let onCommit:   () -> Void
    let isPastWeek: Bool           // belongs to a past week?

    // ───────── dynamic height ─────────
    @State private var measuredTextHeight: CGFloat = 0

    var body: some View {
        // layout constants
        let minH:  CGFloat = 50
        let padV:  CGFloat = 12        // half of total vertical padding (24)
        let padH:  CGFloat = 8
        let finalH = max(measuredTextHeight + padV * 2, minH)

        HStack(spacing: 8) {
            // ——— Auto-expanding text area ———
            ZStack(alignment: .topLeading) {

                // Invisible twin → measures wrapped height
                Text(title)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true) // wrap!
                    .padding(.vertical, padV)
                    .padding(.horizontal, padH)
                    .opacity(0)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: TextHeightPreferenceKey.self,
                                value: geo.size.height
                            )
                        }
                    )

                // Editable field
                TextEditor(text: $title)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(.white) 
                    .font(.body)
                    .padding(.vertical, padV/2)
                    .padding(.leading,   4)
                    .padding(.trailing, 40)
                    .frame(height: finalH)
                    .background(Color.black)
                    .cornerRadius(8)
//                    .disabled(isPastWeek)                 // ← or -Month row uses isPast
                    .opacity(isPastWeek ? 0.6 : 1)
                    /// 🔑 DO -NOT- COMMIT INSIDE THE LAYOUT PASS.
                    /// Dispatching pushes the state-mutation to the *next* run-loop turn,
                    /// after SwiftUI finishes its current geometry pass — eliminating
                    /// “Modifications to the layout engine” crashes.
                    .onChange(of: title) { _ in
                        DispatchQueue.main.async { onCommit() }
                    }
            }
            .onPreferenceChange(TextHeightPreferenceKey.self) {
                measuredTextHeight = $0
            }

            // ——— Status / delete buttons ———
            if !showDelete {
                Button {
                    onToggle()
                    onCommit()
                } label: {
                    Group {
                        if isCompleted { Image(systemName: "checkmark.circle.fill") }
                        else if isPastWeek { Image(systemName: "xmark.circle.fill") }
                        else { Image(systemName: "circle") }
                    }
                    .font(.title2)
                    .foregroundColor(
                        isCompleted ? accentCyan : (isPastWeek ? .red : .gray)
                    )
                }
                .buttonStyle(.borderless)
                .padding(.trailing, 8)
            } else {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .padding(.trailing, 8)
            }
        }
        .padding(4)
        .background(Color.black)
        .cornerRadius(8)
    }
}
