//  WeeklyPriorityRowView.swift
//  Mind Reset
//
//  Mirrors DayView’s PriorityRowView but hides the check-mark while
//  `showDelete == true` (i.e. Remove-mode).

import SwiftUI

private struct TextHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 50
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct WeeklyPriorityRowView: View {
    @Binding var title: String
    @Binding var isCompleted: Bool
    @FocusState var isFocused: Bool

    let showDelete: Bool            // ← Remove-mode flag
    let onDelete: () -> Void
    let accentCyan: Color
    let onCommit: () -> Void

    @State private var measuredTextHeight: CGFloat = 0

    // ———————————————————————————————————————————————
    // MARK: - Body
    // ———————————————————————————————————————————————
    var body: some View {
        let minTextHeight: CGFloat = 50
        let totalVPad:     CGFloat = 24
        let paddedH        = measuredTextHeight + totalVPad
        let finalH         = max(paddedH, minTextHeight)
        let halfPad        = totalVPad / 2

        HStack(spacing: 8) {
            ZStack(alignment: .trailing) {
                // Invisible probe for dynamic height
                Text(title)
                    .font(.body)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: TextHeightPreferenceKey.self,
                                                   value: geo.size.height)
                        }
                    )
                    .opacity(0)

                // Editable text field
                TextEditor(text: $title)
                    .font(.body)
                    .padding(.vertical, halfPad)
                    .padding(.leading, 4)
                    .padding(.trailing, 40)   // leave space for the trailing icon
                    .frame(height: finalH)
                    .background(Color.black)
                    .cornerRadius(8)
                    .focused($isFocused)
                    .onChange(of: title) { _ in onCommit() }

                // √ Check-mark  — hidden (and untappable) during remove-mode
                if !showDelete {
                    Button {
                        isCompleted.toggle()
                        onCommit()
                    } label: {
                        Image(systemName: isCompleted
                              ? "checkmark.circle.fill"
                              : "circle")
                            .font(.title2)
                            .foregroundColor(isCompleted ? accentCyan : .gray)
                    }
                    .padding(.trailing, 8)
                } else {
                    // Keep row width stable when check is hidden
                    Color.clear
                        .frame(width: 32, height: 1)
                        .padding(.trailing, 8)
                }
            }
            .onPreferenceChange(TextHeightPreferenceKey.self) {
                measuredTextHeight = $0
            }

            // Red “−” button in remove-mode
            if showDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle")
                        .font(.title2)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(4)
        .background(
            Color(.sRGB,
                  red: 0.15, green: 0.15, blue: 0.15,
                  opacity: 1.0)
        )
        .cornerRadius(8)
    }
}
