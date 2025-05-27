//
//  ToDoListView.swift
//  Ascento
//
//  Created by Andika Yudhatrisna on 5/27/25.
//


import SwiftUI

struct ToDoListView: View {
    let accentColor: Color
    @Binding var toDoItems: [ToDoItem]
    let taskFocus: FocusState<Bool>.Binding

    @State private var taskToDelete: ToDoItem?
    @State private var isRemoveMode = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach($toDoItems) { $item in
                HStack {
                    Button { item.isCompleted.toggle() } label: {
                        Image(systemName: item.isCompleted
                              ? "checkmark.circle.fill"
                              : "circle")
                            .foregroundColor(item.isCompleted ? .green : .white)
                    }

                    TextEditor(text: $item.title)
                        .scrollContentBackground(.hidden)
                        .focused(taskFocus)
                        .padding(8)
                        .frame(minHeight: 50)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(8)

                    if isRemoveMode && toDoItems.count > 1 {
                        Button { taskToDelete = item } label: {
                            Image(systemName: "minus.circle")
                                .foregroundColor(.red)
                        }
                    }
                }
            }

            HStack {
                Button {
                    toDoItems.append(ToDoItem(id: UUID(),
                                              title: "",
                                              isCompleted: false))
                    isRemoveMode = false
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("Add Task")
                    }
                    .foregroundColor(accentColor)
                    .font(.headline)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 16)
                    .background(Color.black)
                    .cornerRadius(8)
                }

                Spacer()

                if toDoItems.count > 1 {
                    Button(isRemoveMode ? "Done" : "Remove Task") {
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
            .padding(.top, 4)
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(8)
        .alert(item: $taskToDelete) { task in
            Alert(
                title: Text("Delete Task"),
                message: Text("Delete this task?"),
                primaryButton: .destructive(Text("Delete")) {
                    if let i = toDoItems.firstIndex(where: { $0.id == task.id }) {
                        toDoItems.remove(at: i)
                    }
                    if toDoItems.count <= 1 { isRemoveMode = false }
                },
                secondaryButton: .cancel()
            )
        }
    }
}
