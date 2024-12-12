//
//  HabitTrackerView.swift
//  Mind Reset
//  Objective: Serves as the main user interface for the habit-tracking feature of the app. It displays a list of habits, allows users to add new habits, mark habits as completed, and delete habits.
//  Created by Andika Yudhatrisna on 12/1/24.
//


import SwiftUI
import FirebaseAuth

struct HabitTrackerView: View {
    @StateObject private var viewModel = HabitViewModel()
    @EnvironmentObject var session: SessionStore
    @State private var showingAddHabit = false
    var body: some View {
        NavigationView{
            //List container so that user can scroll through each habit
            List{
                //Iterate through each existing habit
                ForEach(viewModel.habits) { habit in
                    VStack(alignment: .leading) {
                        // Habit Title and Description
                        Text(habit.title)
                            .font(.headline)
                        Text(habit.description)
                            .font(.subheadline)
                        // Habit Actions and Status
                        HStack {
                            Text("Streak: \(habit.streak)")
                            Spacer()
                            if habit.isCompletedToday {
                                Text("Completed Today")
                                    .foregroundColor(.green)
                            } else {
                                Button("Mark as Done") {
                                    markHabitAsDone(habit)
                                }
                            }
                        }
                        
                    }
                    .padding(.vertical, 5)
                }
                .onDelete(perform: deleteHabit)
            }
            .navigationTitle("Habit Tracker")
                .navigationBarItems(trailing:
                    Button(action: {
                        showingAddHabit = true
                    }) {
                        Image(systemName: "plus")
                    }
                )
            .sheet(isPresented: $showingAddHabit) {
                AddHabitView(viewModel: viewModel)
                    .environmentObject(session) // Pass session down
            }
            .onAppear {
               if let userId = session.current_user?.uid {
                   viewModel.fetchHabits(for: userId)
               } else {
                   print("No authenticated user found.")
               }
           }
        }
    }
    
    /* Functions Associated with the habit tracker */
    /*
        Purpose: Create a dummy habit. Used for an example to show to new user
    */
    private func addDummyHabit() {
        guard let userId = session.current_user?.uid else { return }
        let newHabit = Habit(
            title: "New Habit",
            description: "Description",
            startDate: Date(),
            ownerId: userId
        )
        viewModel.addHabit(newHabit)
    }
    /*
        Purpose: Mark habit as finished for the day.
    */
    private func markHabitAsDone(_ habit:Habit){
        var updatedHabit = habit
        updatedHabit.isCompletedToday = true
        updatedHabit.streak += 1
        viewModel.updateHabit(updatedHabit)
    }
    /*
        Purpose: Delete the specified habit
    */
    private func deleteHabit(at offsets: IndexSet) {
        offsets.forEach { index in
            let habit = viewModel.habits[index]
            viewModel.deleteHabit(habit) // Use the ViewModel's deleteHabit method
        }
    }
}

//Preview
struct HabitTrackerView_Previews: PreviewProvider {
    static var previews: some View {
        HabitTrackerView()
            .environmentObject(SessionStore())
    }
}
