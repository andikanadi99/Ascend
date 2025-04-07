//
//  DayView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 2/6/25.
//

import SwiftUI
import Combine

// MARK: - Day View ("Your Daily Intentions")
struct DayView: View {
    @EnvironmentObject var session: SessionStore
    @StateObject private var viewModel = DayViewModel()
    
    // For date navigation
    @State private var selectedDate: Date = Date()
    
    // For deletion confirmation (for daily priorities)
    @State private var priorityToDelete: TodayPriority?
    
    // Display: "Monday, March 24, 2025"
    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter.string(from: selectedDate)
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
                // Today's Top Priority Section
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Today's Top Priority")
                            .font(.headline)
                            .foregroundColor(.accentColor)
                        Spacer()
                        Button(action: {
                            // Add a new priority
                            guard var schedule = viewModel.schedule else { return }
                            let newPriority = TodayPriority(id: UUID(), title: "New Priority", progress: 0.0)
                            schedule.priorities.append(newPriority)
                            viewModel.schedule = schedule
                            viewModel.updateDaySchedule()
                        }) {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.accentColor)
                        }
                    }
                    prioritiesList()
                }
                .padding()
                .background(Color.gray.opacity(0.3))
                .cornerRadius(8)
                // Attach an alert to confirm deletion
                .alert(item: $priorityToDelete) { priority in
                    Alert(
                        title: Text("Delete Priority"),
                        message: Text("Are you sure you want to delete this priority?"),
                        primaryButton: .destructive(Text("Delete")) {
                            if var schedule = viewModel.schedule,
                               let index = schedule.priorities.firstIndex(where: { $0.id == priority.id }) {
                                schedule.priorities.remove(at: index)
                                viewModel.schedule = schedule
                                viewModel.updateDaySchedule()
                            }
                        },
                        secondaryButton: .cancel()
                    )
                }
                
                // Date Navigation
                HStack {
                    Button(action: {
                        if let accountCreationDate = session.userModel?.createdAt,
                           let prevDay = Calendar.current.date(byAdding: .day, value: -1, to: selectedDate),
                           prevDay >= accountCreationDate {
                            selectedDate = prevDay
                            if let userId = session.userModel?.id {
                                viewModel.loadDaySchedule(for: prevDay, userId: userId)
                            }
                        }
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(selectedDate > (session.userModel?.createdAt ?? Date()) ? .white : .gray)
                    }
                    
                    Spacer()
                    
                    Text(dateString)
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Button(action: {
                        if let nextDay = Calendar.current.date(byAdding: .day, value: 1, to: selectedDate) {
                            selectedDate = nextDay
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
                
                // Wake-up & Sleep Time pickers
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
                
                // "Your Daily Intentions" header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your Daily Intentions")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text(dateString)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Time Blocks
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
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                    }
                } else {
                    Text("Loading time blocks...")
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            if let userId = session.userModel?.id {
                viewModel.loadDaySchedule(for: selectedDate, userId: userId)
            }
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            if viewModel.schedule == nil, let userId = session.userModel?.id {
                print("DayView: schedule is still nil, reloading...")
                viewModel.loadDaySchedule(for: selectedDate, userId: userId)
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
                        if binding.wrappedValue.count > 1 {
                            Button(action: {
                                priorityToDelete = $priority.wrappedValue
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
