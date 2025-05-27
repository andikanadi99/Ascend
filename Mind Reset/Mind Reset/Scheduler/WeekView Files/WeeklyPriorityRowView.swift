// WeeklyPriorityRowView.swift
// Ascento
//
// Created by Andika Yudhatrisna on 5/27/25.



import SwiftUI

/// Mirrors DayView’s PriorityRowView for smooth inline editing + checkmarks
struct WeeklyPriorityRowView: View {
    @Binding var title: String
    @Binding var isCompleted: Bool
    @FocusState var isFocused: Bool

    let showDelete: Bool
    let onDelete: () -> Void
    let accentCyan: Color
    let onCommit: () -> Void

    @State private var measuredTextHeight: CGFloat = 0

    var body: some View {
        // Match DayView’s min text + padding
        let minTextHeight: CGFloat = 50
        let totalVPad: CGFloat = 24
        let paddedH = measuredTextHeight + totalVPad
        let finalH = max(paddedH, minTextHeight)
        let halfPad = totalVPad / 2

        HStack(alignment: .center, spacing: 8) {
            ZStack(alignment: .trailing) {
                // 1) Invisible Text for sizing
                Text(title)
                    .font(.body)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                    key: TextHeightPreferenceKey.self,
                                    value: geo.size.height
                                )
                        }
                    )
                    .opacity(0)

                // 2) The real editor
                TextEditor(text: $title)
                    .font(.body)
                    .padding(.vertical, halfPad)
                    .padding(.leading, 4)
                    .padding(.trailing, 40)      // room for checkmark
                    .frame(height: finalH)
                    .background(Color.black)
                    .cornerRadius(8)
                    .focused($isFocused)
                    .onChange(of: title) { _ in onCommit() }

                // 3) Inline, vertically centered checkmark
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
            }
            .onPreferenceChange(TextHeightPreferenceKey.self) {
                measuredTextHeight = $0
            }

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

// Reuse the same TextHeightPreferenceKey from DayView:
private struct TextHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 50
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}
