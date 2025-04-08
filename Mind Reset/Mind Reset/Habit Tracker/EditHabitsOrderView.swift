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
        NavigationView {
            List {
                // Enumerate the habits array for stable indexing
                // Use each habit's unique id (e.g. habit.id) as the identifier
                ForEach(Array(viewModel.habits.enumerated()), id: \.element.id) { (index, habit) in
                    HStack {
                        Text(habit.title)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        // Single "up" arrow
                        Button(action: {
                            if index == 0 {
                                moveTopToBottom()
                            } else {
                                moveUp(at: index)
                            }
                        }) {
                            Image(systemName: "arrow.up")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color(red: 0.15, green: 0.15, blue: 0.15))
                    .cornerRadius(8)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black) // Maintain dark theme
            .navigationTitle("Edit Habit Order")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color(red: 0, green: 1, blue: 1))
                }
            }
        }
    }

    // MARK: - Helper Functions

    /// For the top item: remove it from the front and append it to the end of the array.
    private func moveTopToBottom() {
        guard viewModel.habits.count > 1 else { return }
        withAnimation {
            var newHabits = viewModel.habits
            let topHabit = newHabits.removeFirst()
            newHabits.append(topHabit)
            viewModel.habits = newHabits
        }
    }

    /// For items that aren't first: swap this habit with the habit above it.
    private func moveUp(at index: Int) {
        guard index > 0 else { return }
        withAnimation {
            var newHabits = viewModel.habits
            newHabits.swapAt(index, index - 1)
            viewModel.habits = newHabits
        }
    }
}

struct EditHabitsOrderView_Previews: PreviewProvider {
    static var previews: some View {
        EditHabitsOrderView()
            .environmentObject(HabitViewModel())
    }
}
