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

    let onToggle:   () -> Void
    let showDelete: Bool            // ← Remove-mode flag
    let onDelete:   () -> Void
    let accentCyan: Color
    let onCommit:   () -> Void

    // Indicates this row belongs to a past week
    let isPastWeek: Bool

    @State private var measuredTextHeight: CGFloat = 0

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
                            Color.clear.preference(
                                key: TextHeightPreferenceKey.self,
                                value: geo.size.height
                            )
                        }
                    )
                    .opacity(0)

                // Editable text field
                TextEditor(text: $title)
                    .font(.body)
                    .padding(.vertical, halfPad)
                    .padding(.leading, 4)
                    .padding(.trailing, 40)   // space for the trailing icon
                    .frame(height: finalH)
                    .background(Color.black)
                    .cornerRadius(8)
                    .onChange(of: title) { _ in onCommit() }

                // √ Check-mark — hidden during remove-mode
                if !showDelete {
                    Button {
                        onToggle()
                        onCommit()
                    } label: {
                        Group {
                            if isCompleted {
                                Image(systemName: "checkmark.circle.fill")
                            } else if isPastWeek {
                                Image(systemName: "xmark.circle.fill")
                            } else {
                                Image(systemName: "circle")
                            }
                        }
                        .font(.title2)
                        .foregroundColor(
                            isCompleted
                                ? accentCyan
                                : (isPastWeek ? .red : .gray)
                        )
                    }
                    .buttonStyle(.borderless)
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
                .buttonStyle(.borderless)
                .padding(.trailing, 8)
            }
        }
        .padding(4)
        .background(Color.black)
        .cornerRadius(8)
    }
}
