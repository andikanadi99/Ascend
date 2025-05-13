//
//  DayView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 2/6/25.
//

import SwiftUI
import Combine
import UIKit

// Define an enum to represent which alert to show.
enum DayViewAlert: Identifiable {
    case copy
    case delete(TodayPriority)
    
    var id: String {
        switch self {
        case .copy: return "copy"
        case .delete(let p): return "delete-\(p.id)"
        }
    }
}

struct DayView: View {
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var dayViewState: DayViewState
    @StateObject private var viewModel = DayViewModel()

    @State private var activeAlert: DayViewAlert?
    @State private var isRemoveMode = false
    @State private var showChangeDefaultTime = false

    @FocusState private var focusedField: Field?

    private enum Field: Hashable {
        case priority(UUID)
        case time(UUID)
        case task(UUID)
    }

    let accentCyan = Color(red: 0, green: 1, blue: 1)

    private var dateString: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .full
        return fmt.string(from: dayViewState.selectedDate)
    }

    private var prioritiesBinding: Binding<[TodayPriority]>? {
        guard let schedule = viewModel.schedule else { return nil }
        return Binding(
            get: { schedule.priorities },
            set: { newVal in
                var s = schedule
                s.priorities = newVal
                viewModel.schedule = s
            }
        )
    }

    private var canGoBack: Bool {
        guard let created = session.userModel?.createdAt else { return false }
        return dayViewState.selectedDate > Calendar.current.startOfDay(for: created)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack { Spacer()
                        Button("Copy Previous Day") { activeAlert = .copy }
                            .font(.headline)
                            .foregroundColor(accentCyan)
                            .padding(.horizontal, 8)
                            .background(Color.black)
                            .cornerRadius(8)
                        Spacer()
                    }
                    .alert(item: $activeAlert) { alert in
                        switch alert {
                        case .copy:
                            return Alert(
                                title: Text("Confirm Copy"),
                                message: Text("Copy previous day's schedule?"),
                                primaryButton: .destructive(Text("Copy")) {
                                    if canGoBack, let uid = session.userModel?.id {
                                        viewModel.copyPreviousDaySchedule(
                                            to: dayViewState.selectedDate,
                                            userId: uid
                                        ) { _ in }
                                    }
                                },
                                secondaryButton: .cancel()
                            )
                        case .delete(let p):
                            return Alert(
                                title: Text("Delete Priority"),
                                message: Text("Delete this priority?"),
                                primaryButton: .destructive(Text("Delete")) {
                                    if var s = viewModel.schedule,
                                       let i = s.priorities.firstIndex(where: { $0.id == p.id }) {
                                        s.priorities.remove(at: i)
                                        viewModel.schedule = s
                                        viewModel.updateDaySchedule()
                                        if s.priorities.count <= 1 { isRemoveMode = false }
                                    }
                                },
                                secondaryButton: .cancel()
                            )
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Today's Top Priority")
                                .font(.headline)
                                .foregroundColor(accentCyan)
                            Spacer()
                        }
                        prioritiesList()

                        HStack {
                            Button("Add Priority") {
                                guard var s = viewModel.schedule else { return }
                                s.priorities.append(TodayPriority(id: UUID(), title: "New Priority", progress: 0))
                                viewModel.schedule = s
                                viewModel.updateDaySchedule()
                                isRemoveMode = false
                            }
                            .font(.headline)
                            .foregroundColor(accentCyan)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Color.black)
                            .cornerRadius(8)

                            Spacer()

                            if let binding = prioritiesBinding, binding.wrappedValue.count > 1 {
                                Button(isRemoveMode ? "Done" : "Remove Priority") {
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
                        .padding(.top, 8)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(8)

                    HStack {
                        Button {
                            if canGoBack,
                               let prev = Calendar.current.date(byAdding: .day, value: -1, to: dayViewState.selectedDate),
                               let uid = session.userModel?.id {
                                dayViewState.selectedDate = prev
                                viewModel.loadDaySchedule(for: prev, userId: uid)
                            }
                        } label: {
                            Image(systemName: "chevron.left")
                                .foregroundColor(canGoBack ? .white : .gray)
                        }
                        Spacer()
                        Text(dateString)
                            .font(.headline)
                            .foregroundColor(.white)
                        Spacer()
                        Button {
                            if let next = Calendar.current.date(byAdding: .day, value: 1, to: dayViewState.selectedDate),
                               let uid = session.userModel?.id {
                                dayViewState.selectedDate = next
                                viewModel.loadDaySchedule(for: next, userId: uid)
                            }
                        } label: {
                            Image(systemName: "chevron.right").foregroundColor(.white)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(8)

                    if let schedule = viewModel.schedule {
                        let binding = Binding<[TimeBlock]>(
                            get: { schedule.timeBlocks },
                            set: { newVal in
                                var s = schedule
                                s.timeBlocks = newVal
                                viewModel.schedule = s
                            }
                        )
                        ForEach(binding) { $block in
                            HStack(alignment: .top, spacing: 8) {
                                TextField("Time", text: $block.time)
                                    .focused($focusedField, equals: .time(block.id))
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .frame(width: 80)
                                    .padding(8)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(8)
                                    .onChange(of: block.time) { _ in viewModel.updateDaySchedule() }

                                TextEditor(text: $block.task)
                                    .focused($focusedField, equals: .task(block.id))
                                    .font(.caption)
                                    .foregroundColor(.white)
                                    .scrollContentBackground(.hidden)
                                    .padding(8)
                                    .background(Color.black.opacity(0.5))
                                    .cornerRadius(8)
                                    .frame(minHeight: 50, maxHeight: 80)
                                    .onChange(of: block.task) { _ in viewModel.updateDaySchedule() }

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
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                let now = Date()
                let lastActive = UserDefaults.standard.object(forKey: "LastActiveTime") as? Date ?? now
                if now.timeIntervalSince(lastActive) > 1800 {
                    dayViewState.selectedDate = Date()
                }
                UserDefaults.standard.set(now, forKey: "LastActiveTime")
                if let uid = session.userModel?.id {
                    viewModel.loadDaySchedule(for: dayViewState.selectedDate, userId: uid)
                }
            }
            .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
                if viewModel.schedule == nil, let uid = session.userModel?.id {
                    viewModel.loadDaySchedule(for: dayViewState.selectedDate, userId: uid)
                }
            }
            .onReceive(session.$defaultWakeTime.combineLatest(session.$defaultSleepTime)) { wakeOpt, sleepOpt in
                guard let wake = wakeOpt, let sleep = sleepOpt,
                      var s = viewModel.schedule else { return }
                let today = Calendar.current.startOfDay(for: Date())
                if s.date >= today {
                    s.wakeUpTime = wake
                    s.sleepTime = sleep
                    viewModel.schedule = s
                    viewModel.updateDaySchedule()
                    viewModel.regenerateBlocks()
                }
            }
        }
    }

    private func prioritiesList() -> some View {
        Group {
            if let binding = prioritiesBinding {
                ForEach(binding) { $priority in
                    HStack {
                        TextEditor(text: $priority.title)
                            .focused($focusedField, equals: .priority(priority.id))
                            .padding(8)
                            .frame(minHeight: 50)
                            .background(Color.black)
                            .cornerRadius(8)
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .onChange(of: $priority.title.wrappedValue) { _ in viewModel.updateDaySchedule() }

                        if isRemoveMode && binding.wrappedValue.count > 1 {
                            Button(action: { activeAlert = .delete($priority.wrappedValue) }) {
                                Image(systemName: "minus.circle").foregroundColor(.red)
                            }
                        }
                    }
                }
            } else {
                Text("Loading priorities...").foregroundColor(.white)
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



