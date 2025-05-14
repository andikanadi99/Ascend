//
//  DayView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 2/6/25.
//

import SwiftUI
import Combine
import UIKit

// ───────────────────────────────────────────────
// MARK: ‑ Alerts
// ───────────────────────────────────────────────
enum DayViewAlert: Identifiable {
    case copy
    case delete(TodayPriority)

    var id: String {
        switch self {
        case .copy:                       return "copy"
        case .delete(let priority):       return "delete‑\(priority.id)"
        }
    }
}

// ───────────────────────────────────────────────
// MARK: ‑ Day View (“Your Mindful Day”)
// ───────────────────────────────────────────────
struct DayView: View {
    // ⚙️ Environment & view‑models
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var dayViewState: DayViewState
    @StateObject private var viewModel = DayViewModel()

    // 🗂 Local UI state
    @State private var activeAlert: DayViewAlert?
    @State private var isRemoveMode = false

    // 🔎 Keyboard‑focus flags
    @FocusState private var isDayPriorityFocused: Bool
    @FocusState private var isDayTimeFocused:     Bool
    @FocusState private var isDayTaskFocused:     Bool

    // Accent colour
    private let accentCyan = Color(red: 0, green: 1, blue: 1)

    // ───── helpers ─────
    private var dateString: String {
        let f = DateFormatter(); f.dateStyle = .full
        return f.string(from: dayViewState.selectedDate)
    }

    private var prioritiesBinding: Binding<[TodayPriority]>? {
        guard let sched = viewModel.schedule else { return nil }
        return Binding(
            get: { sched.priorities },
            set: { new in
                var tmp = sched
                tmp.priorities = new
                viewModel.schedule = tmp
            }
        )
    }

    // ─────────────────────────────────────────
    // MARK: ‑ Body
    // ─────────────────────────────────────────
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                copyButton
                prioritiesSection
                dateNavigation
                wakeSleepSection
                timeBlocksSection
                Spacer()
            }
            .padding()
            .padding(.top, -20)
        }
        //  ‑ No `.toolbar` here – SchedulerView supplies the global keyboard toolbar
        //  ‑ All logic below unchanged
        .onAppear(perform: loadInitialSchedule)
        .onReceive(session.$defaultWakeTime.combineLatest(session.$defaultSleepTime)) { w, s in
            applyDefaultTimes(wakeOpt: w, sleepOpt: s)
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            if viewModel.schedule == nil, let uid = session.userModel?.id {
                viewModel.loadDaySchedule(for: dayViewState.selectedDate, userId: uid)
            }
        }
        .alert(item: $activeAlert, content: buildAlert)
    }

    // ───────────────────────── sections ─────────────────────────
    /// Copy‑previous‑day button row
    private var copyButton: some View {
        HStack {
            Spacer()
            Button("Copy Previous Day") { activeAlert = .copy }
                .font(.headline)
                .foregroundColor(accentCyan)
                .padding(.horizontal, 8)
                .background(Color.black)
                .cornerRadius(8)
            Spacer()
        }
    }

    /// “Today’s Top Priority” section
    private var prioritiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today's Top Priority")
                    .font(.headline)
                    .foregroundColor(accentCyan)
                Spacer()
            }

            if let binding = prioritiesBinding {
                ForEach(binding) { $priority in
                    HStack {
                        TextEditor(text: $priority.title)
                            .focused($isDayPriorityFocused)
                            .padding(8)
                            .frame(minHeight: 50)
                            .background(Color.black)
                            .cornerRadius(8)
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .onChange(of: priority.title) { _ in
                                viewModel.updateDaySchedule()
                            }

                        if isRemoveMode && binding.wrappedValue.count > 1 {
                            Button { activeAlert = .delete(priority) } label: {
                                Image(systemName: "minus.circle").foregroundColor(.red)
                            }
                        }
                    }
                }

                HStack {
                    Button("Add Priority") { addPriority() }
                        .font(.headline)
                        .foregroundColor(accentCyan)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.black)
                        .cornerRadius(8)

                    Spacer()

                    if binding.wrappedValue.count > 1 {
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
            } else {
                Text("Loading priorities…").foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }

    /// Date navigation (« Yesterday / Tomorrow »)
    private var dateNavigation: some View {
        HStack {
            Button { goBackOneDay() } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(canGoBack() ? .white : .gray)
            }
            Spacer()
            Text(dateString)
                .font(.headline)
                .foregroundColor(.white)
            Spacer()
            Button { goForwardOneDay() } label: {
                Image(systemName: "chevron.right").foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }

    /// Wake & Sleep pickers
    @ViewBuilder
    private var wakeSleepSection: some View {
        if let sched = viewModel.schedule {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Wake Up Time").foregroundColor(.white)
                        DatePicker("", selection: Binding(
                            get: { sched.wakeUpTime },
                            set: { new in
                                var t = sched; t.wakeUpTime = new
                                viewModel.schedule = t; viewModel.regenerateBlocks()
                            }), displayedComponents: .hourAndMinute)
                        .focused($isDayTimeFocused)
                        .labelsHidden()
                        .environment(\.colorScheme, .dark)
                        .padding(4)
                        .background(Color.black)
                        .cornerRadius(4)
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("Sleep Time").foregroundColor(.white)
                        DatePicker("", selection: Binding(
                            get: { sched.sleepTime },
                            set: { new in
                                var t = sched; t.sleepTime = new
                                viewModel.schedule = t; viewModel.regenerateBlocks()
                            }), displayedComponents: .hourAndMinute)
                        .focused($isDayTimeFocused)
                        .labelsHidden()
                        .environment(\.colorScheme, .dark)
                        .padding(4)
                        .background(Color.black)
                        .cornerRadius(4)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.3))
                .cornerRadius(8)
            }
        } else {
            Text("Loading times…").foregroundColor(.white)
        }
    }

    /// Time‑blocks list
    @ViewBuilder
    private var timeBlocksSection: some View {
        if let sched = viewModel.schedule {
            VStack(spacing: 16) {
                ForEach(sched.timeBlocks) { block in
                    blockRow(block)
                }
            }
        } else {
            Text("Loading tasks…").foregroundColor(.white)
        }
    }

    /// One row (Time + Task)
    private func blockRow(_ block: TimeBlock) -> some View {
        HStack(alignment: .top, spacing: 8) {
            TextField("Time", text: Binding(
                get: { block.time },
                set: { new in updateBlock(block, time: new) }))
            .focused($isDayTimeFocused)
            .font(.caption)
            .foregroundColor(.white)
            .frame(width: 80)
            .padding(8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)

            TextEditor(text: Binding(
                get: { block.task },
                set: { new in updateBlock(block, task: new) }))
            .focused($isDayTaskFocused)
            .font(.caption)
            .foregroundColor(.white)
            .scrollContentBackground(.hidden)
            .padding(8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)
            .frame(minHeight: 50, maxHeight: 80)

            Spacer()
        }
        .padding(8)
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }

    // ─────────────────────────────────────────
    // MARK: ‑ Alerts
    // ─────────────────────────────────────────
    private func buildAlert(for alert: DayViewAlert) -> Alert {
        switch alert {
        case .copy:
            return Alert(
                title: Text("Confirm Copy"),
                message: Text("Copy previous day's schedule?"),
                primaryButton: .destructive(Text("Copy")) { copyPreviousDay() },
                secondaryButton: .cancel()
            )
        case .delete(let p):
            return Alert(
                title: Text("Delete Priority"),
                message: Text("Delete this priority?"),
                primaryButton: .destructive(Text("Delete")) { deletePriority(p) },
                secondaryButton: .cancel()
            )
        }
    }


    // MARK: – Helper methods
    private func loadInitialSchedule() {
        let now       = Date()
        let last      = UserDefaults.standard.object(forKey: "LastActiveTime") as? Date ?? now
        if now.timeIntervalSince(last) > 1800 {
            dayViewState.selectedDate = now
        }
        UserDefaults.standard.set(now, forKey: "LastActiveTime")
        if let uid = session.userModel?.id {
            viewModel.loadDaySchedule(for: dayViewState.selectedDate, userId: uid)
        }
    }

    private func applyDefaultTimes(wakeOpt: Date?, sleepOpt: Date?) {
        guard let wake = wakeOpt, let sleep = sleepOpt,
              var sched = viewModel.schedule else { return }
        let today = Calendar.current.startOfDay(for: Date())
        if sched.date >= today {
            sched.wakeUpTime = wake
            sched.sleepTime  = sleep
            viewModel.schedule = sched
            viewModel.updateDaySchedule()
            viewModel.regenerateBlocks()
        }
    }

    private func copyPreviousDay() {
        guard let uid = session.userModel?.id else { return }
        viewModel.copyPreviousDaySchedule(
            to: dayViewState.selectedDate,
            userId: uid
        ) { _ in }
    }

    private func addPriority() {
        guard var sched = viewModel.schedule else { return }
        sched.priorities.append(TodayPriority(id: UUID(), title: "New Priority", progress: 0))
        viewModel.schedule = sched
        viewModel.updateDaySchedule()
        isRemoveMode = false
    }

    private func deletePriority(_ p: TodayPriority) {
        guard var sched = viewModel.schedule,
              let idx = sched.priorities.firstIndex(where: { $0.id == p.id }) else { return }
        sched.priorities.remove(at: idx)
        viewModel.schedule = sched
        viewModel.updateDaySchedule()
        if sched.priorities.count <= 1 { isRemoveMode = false }
    }

    private func goBackOneDay() {
        guard let created = session.userModel?.createdAt,
              dayViewState.selectedDate > Calendar.current.startOfDay(for: created),
              let prev = Calendar.current.date(byAdding: .day, value: -1, to: dayViewState.selectedDate),
              let uid  = session.userModel?.id else { return }
        dayViewState.selectedDate = prev
        viewModel.loadDaySchedule(for: prev, userId: uid)
    }

    private func goForwardOneDay() {
        guard let next = Calendar.current.date(byAdding: .day, value: 1, to: dayViewState.selectedDate),
              let uid  = session.userModel?.id else { return }
        dayViewState.selectedDate = next
        viewModel.loadDaySchedule(for: next, userId: uid)
    }

    private func canGoBack() -> Bool {
        guard let created = session.userModel?.createdAt else { return false }
        return dayViewState.selectedDate > Calendar.current.startOfDay(for: created)
    }

    private func updateBlock(_ block: TimeBlock, time: String? = nil, task: String? = nil) {
        guard var sched = viewModel.schedule,
              let idx   = sched.timeBlocks.firstIndex(where: { $0.id == block.id }) else { return }
        if let t  = time { sched.timeBlocks[idx].time = t }
        if let tx = task { sched.timeBlocks[idx].task = tx }
        viewModel.schedule = sched
        viewModel.updateDaySchedule()
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



