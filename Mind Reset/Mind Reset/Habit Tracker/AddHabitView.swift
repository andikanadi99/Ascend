//
//  AddHabitView.swift
//  Mind Reset
//  Objective: Serves as the a pop up view for users to add habits to their collection.
//  Created by Andika Yudhatrisna on 12/12/24.
//

import SwiftUI
import FirebaseAuth


struct AddHabitView: View {
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject var session: SessionStore
    @ObservedObject var viewModel: HabitViewModel
    // Habit Variables
    @State private var title: String = ""
    @State private var description: String = ""
    @State private var startDate: Date = Date()
    @State private var target: Int = 30
    @State private var setReminder: Bool = false
    @State private var reminderTime: Date = Date()
    
    var body: some View {
        NavigationView {
            Form{
                //Details of the habit to be entered
                Section(header: Text("Habit Details")) {
                    TextField("Title", text: $title)
                    TextField("Description", text: $description)

                    DatePicker("Start Date", selection: $startDate, displayedComponents: .date)

                    Stepper(value: $target, in: 1...365) {
                        Text("Target: \(target) days")
                    }
                }
                //Section to give option to user of reminder
                Section(header: Text("Reminder")) {
                    Toggle(isOn: $setReminder) {
                        Text("Set Reminder")
                    }
                    if setReminder {
                        DatePicker("Reminder Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }
            }
            .navigationTitle("Add New Habit")
            .navigationBarItems(
                leading:
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    },
                trailing:
                    Button("Save") {
                        saveHabit()
                    }
                    .disabled(title.isEmpty || description.isEmpty)
            )
            
        }
    }
    //Function to save user's created habit
    private func saveHabit() {
        guard let userId = session.current_user?.uid else {
            print("No authenticated user found, cannot add habit.")
            return
        }

        let newHabit = Habit(
            title: title,
            description: description,
            startDate: startDate,
            ownerId: userId
        )

        viewModel.addHabit(newHabit)
        presentationMode.wrappedValue.dismiss()
    }
}

//Preview
struct AddHabitView_Previews: PreviewProvider {
    static var previews: some View {
        // Mock dependencies
        let viewModel = HabitViewModel()
        let session = SessionStore()
        
        return AddHabitView(viewModel: viewModel)
            .environmentObject(session)
    }
}
