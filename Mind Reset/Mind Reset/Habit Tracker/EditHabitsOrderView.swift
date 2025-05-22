//
//  EditHabitsOrderView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 4/8/25.
//

import SwiftUI

@available(iOS 16.0, *)
struct EditHabitsOrderView: View {
    @EnvironmentObject var viewModel: HabitViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {                                  // modern nav
            List {
                ForEach(viewModel.habits) { habit in       // no enumerate
                    Text(habit.title)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                        .cornerRadius(8)
                }
                .onMove(perform: viewModel.moveHabits)      // ✨ key line
            }
            .scrollContentBackground(.hidden)
            .background(.black)
            .navigationTitle("Edit Habit Order")
            .toolbar {
                // Built-in edit button toggles drag handles
                ToolbarItem(placement: .navigationBarLeading) { EditButton() }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.cyan)
                }
            }
        }
    }
}

struct EditHabitsOrderView_Previews: PreviewProvider {
    static var previews: some View {
        EditHabitsOrderView()
            .environmentObject(HabitViewModel())
    }
}

