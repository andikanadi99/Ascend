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
// MARK: - Alerts
// ───────────────────────────────────────────────
enum DayViewAlert: Identifiable {
    case copy, delete(TodayPriority)
    var id: String {
        switch self {
        case .copy:              return "copy"
        case .delete(let p):     return "delete-\(p.id)"
        }
    }
}

// ───────────────────────────────────────────────
// MARK: - Day View (“Your Mindful Day”)
// ───────────────────────────────────────────────
struct DayView: View {
    // ⚙️ Environment & view-models
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var dayViewState: DayViewState
    @StateObject private var viewModel = DayViewModel()

    // 🗂 Local UI state
    @State private var activeAlert: DayViewAlert?
    @State private var isRemoveMode = false

    // 🔎 Focus flags
    @FocusState private var isDayPriorityFocused: Bool
    @FocusState private var isDayTimeFocused:     Bool
    @FocusState private var isDayTaskFocused:     Bool
    
    @State private var editMode: EditMode = .inactive

    // Accent colour
    private let accentCyan = Color(red: 0, green: 1, blue: 1)

    // Helper binding
    private var prioritiesBinding: Binding<[TodayPriority]>? {
        guard let sched = viewModel.schedule else { return nil }
        return Binding(
            get:  { sched.priorities },
            set: { new in
                var tmp = sched; tmp.priorities = new
                viewModel.schedule = tmp
            }
        )
    }

    // Date formatting
    private var dateString: String {
        let f = DateFormatter(); f.dateStyle = .full
        return f.string(from: dayViewState.selectedDate)
    }
    private var isToday: Bool {
        Calendar.current.isDateInToday(dayViewState.selectedDate)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                copyButton
                dateNavigation
                prioritiesSection
                wakeSleepSection
                timeBlocksSection
                Spacer()
            }
            .padding()
            .padding(.top, -20)
        }
        .onAppear(perform: loadInitialSchedule)
        .onReceive(session.$defaultWakeTime.combineLatest(session.$defaultSleepTime)) { w, s in
            applyDefaultTimes(wakeOpt: w, sleepOpt: s)
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()) { _ in
            if viewModel.schedule == nil,
               let uid = session.userModel?.id {
                viewModel.loadDaySchedule(for: dayViewState.selectedDate,
                                          userId: uid)
            }
        }
        .alert(item: $activeAlert, content: buildAlert)
    }

    // ─────────────────────────────────────────
    // MARK: – Copy Button
    // ─────────────────────────────────────────
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

    // ─────────────────────────────────────────
    // MARK: – Priorities Section
    // ─────────────────────────────────────────
    private var prioritiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Top Priority")
                .font(.headline)
                .foregroundColor(accentCyan)

            if let binding = prioritiesBinding {
                if binding.wrappedValue.isEmpty {
                    // Placeholder when there are no priorities
                    Text("Please list your priorities for today")
                        .foregroundColor(.white.opacity(0.7))
                        .italic()
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                        .background(Color(.sRGB, white: 0.1, opacity: 1))
                        .cornerRadius(8)
                } else {
                    // Reorderable list with inline checkmarks and deletions
                    List {
                        Section {
                            ForEach(binding) { $priority in
                                PriorityRowView(
                                    title:       $priority.title,
                                    isFocused:   _isDayPriorityFocused,
                                    isCompleted: $priority.isCompleted,
                                    onToggle:    { viewModel.togglePriorityCompletion(priority.id) },
                                    showDelete:  isRemoveMode,
                                    onDelete:    { activeAlert = .delete(priority) },
                                    accentCyan:  accentCyan,
                                    onCommit:    { viewModel.updateDaySchedule() }
                                )
                                .listRowBackground(Color.clear)
                                .listRowInsets(.init(top: 4, leading: 0, bottom: 4, trailing: 0))
                                .listRowSeparator(.hidden)
                            }
                            .onMove { indices, newOffset in
                                binding.wrappedValue.move(fromOffsets: indices, toOffset: newOffset)
                                viewModel.updateDaySchedule()
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollDisabled(true)
                    .scrollContentBackground(.hidden)
                    .listRowSeparator(.hidden)
                    .listSectionSeparator(.hidden)
                    .background(Color.clear)
                    .frame(minHeight: CGFloat(binding.wrappedValue.count) * 90)
                    .environment(\.editMode, $editMode)
                    .padding(.bottom, 20)
                }

                // Add / Remove buttons
                HStack {
                    Button("Add Priority", action: addPriority)
                        .font(.headline)
                        .foregroundColor(accentCyan)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 16)
                        .background(Color.black)
                        .cornerRadius(8)

                    Spacer()

                    // Show Remove only if there's at least one priority
                    if binding.wrappedValue.count > 0 {
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


    // ─────────────────────────────────────────
    // MARK: – Date Navigation
    // ─────────────────────────────────────────
    private var dateNavigation: some View {
        HStack {
            Button { goBackOneDay() } label: {
                Image(systemName: "chevron.left")
                    .foregroundColor(canGoBack() ? .white : .gray)
            }
            Spacer()
            Text(dateString)
                .font(.headline)
                .foregroundColor(isToday ? accentCyan : .white)
            Spacer()
            Button { goForwardOneDay() } label: {
                Image(systemName: "chevron.right")
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }

    // ─────────────────────────────────────────
    // MARK: – Wake/Sleep Section
    // ─────────────────────────────────────────
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
                                viewModel.schedule = t
                                viewModel.regenerateBlocks()
                            }),
                                   displayedComponents: .hourAndMinute)
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
                                viewModel.schedule = t
                                viewModel.regenerateBlocks()
                            }),
                                   displayedComponents: .hourAndMinute)
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

    // ─────────────────────────────────────────
    // MARK: – Time Blocks
    // ─────────────────────────────────────────
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
    // MARK: – Alerts & Helpers
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

private struct TextHeightPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 50
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    // keep the largest measured height
    value = max(value, nextValue())
  }
}

// ───────────────────────────────────────────────
// MARK: - Updated PriorityRowView
// ───────────────────────────────────────────────
private struct PriorityRowView: View {
    @Binding var title: String
    @FocusState var isFocused: Bool
    @Binding var isCompleted: Bool
    let onToggle: () -> Void
    let showDelete: Bool
    let onDelete: () -> Void
    let accentCyan: Color
    let onCommit: () -> Void

    @State private var measuredTextHeight: CGFloat = 0

    var body: some View {
        let minHeight: CGFloat = 50
        let totalVPad: CGFloat = 24
        let paddedH = measuredTextHeight + totalVPad
        let finalH  = max(paddedH, minHeight)
        let halfV   = totalVPad / 2

        HStack(spacing: 8) {
            ZStack(alignment: .trailing) {
                // 1) Invisible Text to measure height
                Text(title)
                    .font(.body)
                    .background(
                        GeometryReader { geo in
                            Color.clear
                                .preference(
                                  key: TextHeightPreferenceKey.self,
                                  value: geo.size.height
                                )
                        }
                    )
                    .opacity(0)

                // 2) The editable TextEditor
                TextEditor(text: $title)
                    .font(.body)
                    .padding(.vertical, halfV)
                    .padding(.leading, 4)
                    .padding(.trailing, 40)      // space for check
                    .frame(height: finalH)
                    .background(Color.black)
                    .cornerRadius(8)
                    .onChange(of: title) { _ in onCommit() }
                    .focused($isFocused)

                // 3) Vertically-centered checkmark
                Button {
                    onToggle()
                } label: {
                    Image(systemName: isCompleted
                          ? "checkmark.circle.fill"
                          : "circle")
                        .font(.title2)
                        .foregroundColor(isCompleted ? accentCyan : .gray)
                }
                .padding(.trailing, 8)          // inset from right edge
            }
            .onPreferenceChange(TextHeightPreferenceKey.self) {
                measuredTextHeight = $0
            }

            if showDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle")
                        .font(.title2)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(4)
        .background(Color(.sRGB, red: 0.15,
                          green: 0.15,
                          blue: 0.15,
                          opacity: 1))
        .cornerRadius(8)
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
