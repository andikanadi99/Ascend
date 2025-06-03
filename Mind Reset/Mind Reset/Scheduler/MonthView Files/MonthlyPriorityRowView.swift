//  MonthlyPriorityRowView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 5/28/25.
//

import SwiftUI

private struct TextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 50
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

struct MonthlyPriorityRowView: View {
    @Binding var title: String
    @Binding var isCompleted: Bool

    let onToggle:  () -> Void
    let showDelete: Bool
    let onDelete:  () -> Void          // ⬅︎ this triggers up to the section
    let accentCyan: Color
    let onCommit:  () -> Void

    @State private var measured: CGFloat = 0

    var body: some View {
        let minH:  CGFloat = 50
        let vPad:  CGFloat = 24
        let height = max(measured + vPad, minH)

        HStack(spacing: 8) {
            ZStack(alignment: .trailing) {
                Text(title)                       // invisible measurement text
                    .font(.body)
                    .background( GeometryReader {
                        Color.clear
                            .preference(key: TextHeightKey.self,
                                        value: $0.size.height)
                    })
                    .opacity(0)

                TextEditor(text: $title)          // editable field
                    .font(.body)
                    .padding(.vertical, vPad/2)
                    .padding(.leading,   4)
                    .padding(.trailing, 40)
                    .frame(height: height)
                    .background(Color.black)
                    .cornerRadius(8)
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .onChange(of: title) { _ in onCommit() }

                // checkmark (only when NOT in remove mode)
                if !showDelete {
                    Button(action: {
                        onToggle()
                    }) {
                        Image(systemName: isCompleted
                              ? "checkmark.circle.fill"
                              : "circle")
                            .font(.title2)
                            .foregroundColor(isCompleted ? accentCyan : .gray)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }
            }
            .onPreferenceChange(TextHeightKey.self) { measured = $0 }

            // delete button (only in remove mode)
            if showDelete {
                Button(role: .destructive, action: {
                    print("[Row]  delete tapped  – \(title)")
                    onDelete()                     // ⬅︎ bubble up
                }) {
                    Image(systemName: "minus.circle")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())         // full hit-area
                .padding(.trailing, 8)
            }
        }
        .padding(4)
        .background(Color.black)
        .cornerRadius(8)
    }
}

