//
//  DayView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 2/6/25.
//

import SwiftUI
import Combine

// Define an enum to represent which alert to show.
enum DayViewAlert: Identifiable {
    case copy
    case delete(TodayPriority)
    
    var id: String {
        switch self {
        case .copy:
            return "copy"
        case .delete(let priority):
            // Assuming `priority.id` is a UUID or something convertible to String.
            // If it is a UUID, use: priority.id.uuidString
            return "delete-\(priority.id)"
        }
    }
}


struct DayView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var viewModel = DayViewModel()
    @EnvironmentObject var dayViewState: DayViewState  // Shared state for selectedDate

    // State variable to track the active alert.
    @State private var activeAlert: DayViewAlert?

    // New state variable to control removal mode.
    @State private var isRemoveMode: Bool = false

    // New state variable to show the Change Default Time sheet.
    @State private var showChangeDefaultTime: Bool = false

    // Display the selected date (e.g., "Monday, March 24, 2025")
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: dayViewState.selectedDate)
    }
    
    // A computed binding for the daily priorities (if the schedule is loaded)
    private var prioritiesBinding: Binding<[TodayPriority]>? {
        guard let schedule = viewModel.schedule else { return nil }
        return Binding<[TodayPriority]>(
            get: { schedule.priorities },
            set: { newValue in
                var updatedSchedule = schedule
                updatedSchedule.priorities = newValue
                viewModel.schedule = updatedSchedule
            }
        )
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                
                // Copy Previous Day Button (centered)
                HStack {
                    Spacer()
                    Button(action: {
                        print("Copy Previous Day button tapped.")
                        activeAlert = .copy
                    }) {
                        Text("Copy Previous Day")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                            .padding(.horizontal, 8)
                            .background(Color.black)
                            .cornerRadius(8)
                    }
                    Spacer()
                }
                
                // Top Priorities Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Today's Top Priority")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                    prioritiesList()
                    
                    // Buttons Row below the priorities list
                    HStack {
                        Button(action: {
                            guard var schedule = viewModel.schedule else { return }
                            let newPriority = TodayPriority(id: UUID(), title: "New Priority", progress: 0.0)
                            schedule.priorities.append(newPriority)
                            viewModel.schedule = schedule
                            viewModel.updateDaySchedule()
                            // Reset removal mode when adding.
                            isRemoveMode = false
                        }) {
                            Text("Add Priority")
                                .font(.headline)
                                .foregroundColor(.accentColor)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                                .background(Color.black)
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        if let binding = prioritiesBinding, binding.wrappedValue.count > 1 {
                            Button(action: {
                                isRemoveMode.toggle()
                            }) {
                                Text(isRemoveMode ? "Done" : "Remove Priority")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(Color.black)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                .padding()
                .background(Color.gray.opacity(0.3))
                .cornerRadius(8)
                
                // Date Navigation Section
                HStack {
                    Button(action: {
                        if let accountCreationDate = session.userModel?.createdAt,
                           let prevDay = Calendar.current.date(byAdding: .day, value: -1, to: dayViewState.selectedDate),
                           prevDay >= accountCreationDate {
                            dayViewState.selectedDate = prevDay
                            if let userId = session.userModel?.id {
                                viewModel.loadDaySchedule(for: prevDay, userId: userId)
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(dayViewState.selectedDate > (session.userModel?.createdAt ?? Date()) ? .white : .gray)
                    }
                    
                    Spacer()
                    
                    Text(dateString)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        if let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: dayViewState.selectedDate) {
                            dayViewState.selectedDate = nextDay
                            if let userId = session.userModel?.id {
                                viewModel.loadDaySchedule(for: nextDay, userId: userId)
                            }
                        }
                    }) {
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.3))
                .cornerRadius(8)
                
                // Wake-Up & Sleep Time Pickers
                if let schedule = viewModel.schedule {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("Wake Up Time")
                                    .foregroundColor(.white)
                                DatePicker("", selection: Binding(
                                    get: { schedule.wakeUpTime },
                                    set: { newVal in
                                        var temp = schedule
                                        temp.wakeUpTime = newVal
                                        viewModel.schedule = temp
                                        viewModel.regenerateBlocks()
                                    }
                                ), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .environment(\.colorScheme, .dark)
                                .padding(4)
                                .background(Color.black)
                                .cornerRadius(4)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .leading) {
                                Text("Sleep Time")
                                    .foregroundColor(.white)
                                DatePicker("", selection: Binding(
                                    get: { schedule.sleepTime },
                                    set: { newVal in
                                        var temp = schedule
                                        temp.sleepTime = newVal
                                        viewModel.schedule = temp
                                        viewModel.regenerateBlocks()
                                    }
                                ), displayedComponents: .hourAndMinute)
                                .labelsHidden()
                                .environment(\.colorScheme, .dark)
                                .padding(4)
                                .background(Color.black)
                                .cornerRadius(4)
                            }
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(8)
                }
                
                // Time Blocks Section
                if viewModel.schedule != nil {
                    let timeBlocksBinding = Binding<[TimeBlock]>(
                        get: { viewModel.schedule!.timeBlocks },
                        set: { newValue in
                            var updatedSchedule = viewModel.schedule!
                            updatedSchedule.timeBlocks = newValue
                            viewModel.schedule = updatedSchedule
                        }
                    )
                    ForEach(timeBlocksBinding) { $block in
                        HStack(alignment: .top, spacing: 8) {
                            TextField("Time", text: $block.time)
                                .font(.caption)
                                .foregroundColor(.white)
                                .frame(width: 80)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(8)
                                .onChange(of: block.time) { _ in
                                    viewModel.updateDaySchedule()
                                }
                            TextEditor(text: $block.task)
                                .font(.caption)
                                .foregroundColor(.white)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(8)
                                .frame(minHeight: 50, maxHeight: 80)
                                .onChange(of: block.task) { _ in
                                    viewModel.updateDaySchedule()
                                }
                            Spacer()
                        }
                        .padding(8)
                        .background(Color.gray.opacity(0.3))
                        .cornerRadius(8)
                    }
                } else {
                    Text("Loading time blocks...")
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
            .padding()
            .padding(.top, -20)
        }
        .onAppear {
            // Inactivity check: reset the selected date to today if over 30 minutes inactive.
            let now = Date()
            let lastActive = UserDefaults.standard.object(forKey: "LastActiveTime") as? Date ?? now
            if now.timeIntervalSince(lastActive) > 1800 {
                dayViewState.selectedDate = Date()
            }
            UserDefaults.standard.set(now, forKey: "LastActiveTime")
            
            if let userId = session.userModel?.id {
                viewModel.loadDaySchedule(for: dayViewState.selectedDate, userId: userId)
            }
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            if viewModel.schedule == nil, let userId = session.userModel?.id {
                print("DayView: schedule is still nil, reloading...")
                viewModel.loadDaySchedule(for: dayViewState.selectedDate, userId: userId)
            }
        }
        // Single alert modifier that handles both copy and deletion.
        .alert(item: $activeAlert) { alert in
            switch alert {
            case .copy:
                return Alert(
                    title: Text("Confirm Copy"),
                    message: Text("Are you sure you want to copy the previous day's schedule?"),
                    primaryButton: .destructive(Text("Copy")) {
                        if dayViewState.selectedDate >= Calendar.current.startOfDay(for: Date()),
                           let userId = session.userModel?.id {
                            viewModel.copyPreviousDaySchedule(to: dayViewState.selectedDate, userId: userId) { success in
                                if success {
                                    print("Day schedule copied successfully.")
                                } else {
                                    print("Failed to copy day schedule.")
                                }
                            }
                        }
                    },
                       secondaryButton: .cancel()
                   )
            case .delete(let priority):
                    return Alert(
                        title: Text("Delete Priority"),
                        message: Text("Are you sure you want to delete this priority?"),
                        primaryButton: .destructive(Text("Delete")) {
                        if var schedule = viewModel.schedule,
                           let index = schedule.priorities.firstIndex(where: { $0.id == priority.id }) {
                            schedule.priorities.remove(at: index)
                            viewModel.schedule = schedule
                            viewModel.updateDaySchedule()
                            
                            if schedule.priorities.count == 1 {
                                isRemoveMode = false
                            }
                        }
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }
    
    // MARK: - Helper: Daily Priorities List
    private func prioritiesList() -> some View {
        Group {
            if let binding = prioritiesBinding {
                ForEach(binding) { $priority in
                    HStack {
                        TextEditor(text: $priority.title)
                            .padding(8)
                            .frame(minHeight: 50)
                            .background(Color.black)
                            .cornerRadius(8)
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .onChange(of: $priority.title.wrappedValue) { _ in
                                viewModel.updateDaySchedule()
                            }
                        if isRemoveMode && binding.wrappedValue.count > 1 {
                            Button(action: {
                                activeAlert = .delete($priority.wrappedValue)
                            }) {
                                Image(systemName: "minus.circle")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                }
            } else {
                Text("Loading priorities...")
                    .foregroundColor(.white)
            }
        }
    }
}


// MARK: - Default Time View
//struct ChangeDefaultTimeView: View {
//    let currentWakeUp: Date
//    let currentSleep: Date
//    let onSave: (Date, Date) -> Void
//    @Environment(\.dismiss) var dismiss
//
//    @State private var newWakeUp: Date
//    @State private var newSleep: Date
//
//    init(currentWakeUp: Date, currentSleep: Date, onSave: @escaping (Date, Date) -> Void) {
//        self.currentWakeUp = currentWakeUp
//        self.currentSleep = currentSleep
//        self.onSave = onSave
//        _newWakeUp = State(initialValue: currentWakeUp)
//        _newSleep = State(initialValue: currentSleep)
//    }
//
//    var body: some View {
//        NavigationView {
//            Form {
//                Section(header: Text("Wake Up Time")
//                            .foregroundColor(.white)) {
//                    DatePicker("", selection: $newWakeUp, displayedComponents: .hourAndMinute)
//                        .datePickerStyle(WheelDatePickerStyle())
//                        .labelsHidden()
//                        .foregroundColor(.white)
//                }
//                Section(header: Text("Sleep Time")
//                            .foregroundColor(.white)) {
//                    DatePicker("", selection: $newSleep, displayedComponents: .hourAndMinute)
//                        .datePickerStyle(WheelDatePickerStyle())
//                        .labelsHidden()
//                        .foregroundColor(.white)
//                }
//            }
//            // Hide the default form background and set a dark background.
//            .scrollContentBackground(.hidden)
//            .background(Color.black)
//            .navigationTitle("Change Default Time")
//            .toolbar {
//                ToolbarItem(placement: .cancellationAction) {
//                    Button("Cancel") {
//                        dismiss()
//                    }
//                    .foregroundColor(.white)
//                }
//                ToolbarItem(placement: .confirmationAction) {
//                    Button("Save") {
//                        onSave(newWakeUp, newSleep)
//                        dismiss()
//                    }
//                    .foregroundColor(.white)
//                }
//            }
//        }
//        .navigationViewStyle(StackNavigationViewStyle())
//        .background(Color.black.edgesIgnoringSafeArea(.all))
//    }
//}



