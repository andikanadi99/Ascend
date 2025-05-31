//
//  PriorityRowView.swift
//  Shared component for Day / Week pages
//

import SwiftUI

struct WeekDayPriorityRowView: View {
    // ───────── editable fields ─────────
    @Binding var title:       String
    @Binding var isCompleted: Bool

    // unified focus binding passed from the parent view
    let focus: FocusState<Bool>.Binding          // ← **single binding**

    // callbacks / config
    let onToggle:   () -> Void
    let showDelete: Bool
    let onDelete:   () -> Void
    let accentCyan: Color
    let onCommit:   () -> Void

    // local state for dynamic height
    @State private var measuredTextHeight: CGFloat = 0

    // MARK: – Body
    var body: some View {
        // sizing constants
        let minTextHeight: CGFloat = 50
        let vPad: CGFloat = 24
        let finalH = max(measuredTextHeight + vPad, minTextHeight)

        HStack(spacing: 8) {
            ZStack(alignment: .trailing) {
                // Invisible text for auto-height measurement
                Text(title)
                    .font(.body)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(key: TextHeightKey.self,
                                            value: geo.size.height)
                        }
                    )
                    .opacity(0)

                // Editable text area
                TextEditor(text: $title)
                    .font(.body)
                    .padding(.vertical, vPad / 2)
                    .padding(.leading, 4)
                    .padding(.trailing, 40)          // space for checkmark
                    .frame(height: finalH)
                    .background(Color.black)
                    .cornerRadius(8)
                    .focused(focus)                  // ← new unified focus
                    .onChange(of: title) { _ in onCommit() }

                // inline checkmark
                Button(action: {
                    onToggle()
                    onCommit()
                }) {
                    Image(systemName: isCompleted
                          ? "checkmark.circle.fill"
                          : "circle")
                        .font(.title2)
                        .foregroundColor(isCompleted ? accentCyan : .gray)
                }
                .padding(.trailing, 8)
            }
            .onPreferenceChange(TextHeightKey.self) { measuredTextHeight = $0 }

            // optional delete
            if showDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle")
                        .font(.title2)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(4)
        .background(Color(.sRGB, red: 0.15, green: 0.15, blue: 0.15, opacity: 1))
        .cornerRadius(8)
    }
}

// key for dynamic-height measurement
private struct TextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 50
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
