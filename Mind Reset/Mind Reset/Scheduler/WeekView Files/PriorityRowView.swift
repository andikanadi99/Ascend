//
//  WeekDayPriorityRowView.swift
//  Mind Reset
//
//  Shared priority row used inside DayCardView and Week pages.
//

import SwiftUI

// Preference keys
private struct TextHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 50
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
struct DayCardListHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value += nextValue() }
}

struct WeekDayPriorityRowView: View {
    @Binding var title: String
    @Binding var isCompleted: Bool

    let focus: FocusState<Bool>.Binding
    let onToggle:   () -> Void
    let showDelete: Bool
    let onDelete:   () -> Void
    let accentCyan: Color
    let onCommit:   () -> Void
    let isPast:     Bool

    @State private var measuredTextHeight: CGFloat = 0

    var body: some View {
        let minH: CGFloat = 50, padV: CGFloat = 12, padH: CGFloat = 8
        let finalH = max(measuredTextHeight + padV*2, minH)

        HStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                Text(title)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, padV).padding(.horizontal, padH)
                    .opacity(0)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: TextHeightKey.self,
                                value: geo.size.height)
                        })
                TextEditor(text: $title)
                    .font(.body)
                    .padding(.vertical, padV).padding(.horizontal, padH)
                    .background(Color.black).cornerRadius(8)
                    .frame(height: finalH)
                    .focused(focus)
                    .onChange(of: title) { _ in onCommit() }
            }
            .onPreferenceChange(TextHeightKey.self) { measuredTextHeight = $0 }

            if !showDelete {
                Button {
                    onToggle()
                    onCommit()
                } label: {
                    Group {
                        if isCompleted { Image(systemName: "checkmark.circle.fill") }
                        else if isPast  { Image(systemName: "xmark.circle.fill") }
                        else            { Image(systemName: "circle") }
                    }
                    .font(.title2)
                    .foregroundColor(isCompleted ? accentCyan : (isPast ? .red : .gray))
                }
                .buttonStyle(.borderless)
                .padding(.trailing, 8)
            } else {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle")
                        .font(.title2).foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .padding(.trailing, 8)
            }
        }
        .padding(4)
        .background(Color.black)
        .cornerRadius(8)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: DayCardListHeightKey.self,
                    value: geo.size.height + 12)
            })
    }
}
