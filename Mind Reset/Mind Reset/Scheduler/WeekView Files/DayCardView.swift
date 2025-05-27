//
//  DayCardView.swift
//  Ascento
//
//  Created by Andika Yudhatrisna on 5/27/25.
//


import SwiftUI

struct DayCardView: View {
    let accentColor: Color
    let day: Date
    @Binding var toDoItems: [ToDoItem]
    @Binding var intention: String
    let intentionFocus: FocusState<Bool>.Binding
    let taskFocus:      FocusState<Bool>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            TextEditor(text: $intention)
                .scrollContentBackground(.hidden)
                .focused(intentionFocus)
                .padding(8)
                .frame(minHeight: 50)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(8)

            ToDoListView(
                accentColor: accentColor,
                toDoItems: $toDoItems,
                taskFocus: taskFocus
            )
        }
        .padding()
        .background(Color.gray.opacity(0.2))
        .cornerRadius(8)
    }

    private var header: some View {
        VStack(alignment: .leading) {
            Text(dayOfWeek).font(.headline).foregroundColor(.white)
            Text(formattedDate).font(.caption).foregroundColor(.white.opacity(0.7))
        }
        .padding(.bottom, 4)
    }

    private var dayOfWeek: String {
        let f = DateFormatter(); f.dateFormat = "EEEE"; return f.string(from: day)
    }
    private var formattedDate: String {
        let f = DateFormatter(); f.dateFormat = "M/d"; return f.string(from: day)
    }
}
