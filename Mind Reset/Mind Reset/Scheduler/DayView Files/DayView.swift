//  DayView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 2/6/25.
//

import SwiftUI
import Combine
import UIKit


// ───────────────────────────────────────────────
// MARK: - Alerts
// ───────────────────────────────────────────────
enum DayViewAlert: Identifiable {
    case copy
    case delete(TodayPriority)
    case confirmModifyPast(TodayPriority)   // for toggling a past‐day status
    case confirmDeletePast(TodayPriority)   // new: for deleting a past‐day priority

    var id: String {
        switch self {
        case .copy:
            return "copy"
        case .delete(let p):
            return "delete-\(p.id)"
        case .confirmModifyPast(let p):
            return "confirmPast-\(p.id)"
        case .confirmDeletePast(let p):
            return "confirmDeletePast-\(p.id)"
        }
    }
}

// ───────────────────────────────────────────────
// MARK: - Time Block view
// ───────────────────────────────────────────────
struct TimeBlockRow: View {
    let block: TimeBlock
    let onCommit: (_ block: TimeBlock, _ newTime: String?, _ newTask: String?) -> Void

    // Local buffers that SwiftUI will preserve
    @State private var localTime: String
    @State private var localTask: String

    // Track whether this row’s TextEditor is focused
    @FocusState private var isThisBlockFocused: Bool

    init(block: TimeBlock,
         onCommit: @escaping (_ block: TimeBlock, _ newTime: String?, _ newTask: String?) -> Void)
    {
        self.block = block
        self.onCommit = onCommit

        // Initialize the @State buffers from the incoming TimeBlock
        _localTime = State(initialValue: block.time)
        _localTask = State(initialValue: block.task)
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            // — TextField for “time”:
            TextField("Time", text: $localTime, onCommit: {
                // The user pressed Return inside the Time text field:
                onCommit(block, localTime, nil)
            })
            .focused($isThisBlockFocused, equals: false)
            .font(.caption)
            .foregroundColor(.white)
            .frame(width: 80)
            .padding(8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)

            // — TextEditor for “task”:
            TextEditor(text: $localTask)
                .focused($isThisBlockFocused)
                .font(.caption)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
                .frame(minHeight: 50, maxHeight: 80)
                .onChange(of: isThisBlockFocused) { newFocus in
                    // When focus leaves, commit the updated “task”
                    if !newFocus {
                        onCommit(block, nil, localTask)
                    }
                }

            Spacer()
        }
        .padding(8)
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
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
    @State private var hasYesterdayUnfinished = false
    
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
    private var isPast: Bool {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return dayViewState.selectedDate < todayStart
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
        // Whenever viewModel.schedule is set or changed, force-regeneration if it's a future date with no blocks:
        .onReceive(viewModel.$schedule) { optionalSched in
            guard let sched = optionalSched else { return }
            let today = Calendar.current.startOfDay(for: Date())
            if sched.date > today && sched.timeBlocks.isEmpty {
                viewModel.regenerateBlocks()
                viewModel.updateDaySchedule()
                // Re-assign to fire the @Published publisher again:
                viewModel.schedule = viewModel.schedule
            }
        }
        .onAppear {
            loadInitialSchedule()
            // DEFER the initial check so that `dayViewState.selectedDate` is already “today.”
            DispatchQueue.main.async {
                updateYesterdayUnfinishedFlag()
            }
        }
        .onChange(of: dayViewState.selectedDate) { _ in
            updateYesterdayUnfinishedFlag()
            if viewModel.schedule == nil,
               let uid = session.userModel?.id {
                viewModel.loadDaySchedule(
                    for: dayViewState.selectedDate,
                    userId: uid
                )
            }
        }

        .onReceive(
            session.$defaultWakeTime.combineLatest(session.$defaultSleepTime)
        ) { wake, sleep in
            guard let uid = session.userModel?.id else { return }
            let selected = dayViewState.selectedDate
            let today = Calendar.current.startOfDay(for: Date())

            // Only touch future dates
            guard selected > today else { return }

            if viewModel.schedule != nil {
                // If a schedule is already loaded for that date, apply new defaults immediately
                applyDefaultTimes(wakeOpt: wake, sleepOpt: sleep)
            } else {
                // Otherwise load the schedule so that applyDefaultTimes (and regeneration) can run
                viewModel.loadDaySchedule(for: selected, userId: uid)
            }
        }
        .onReceive(
            Timer.publish(every: 0.5, on: .main, in: .common)
                .autoconnect()
        ) { _ in
            if viewModel.schedule == nil,
               let uid = session.userModel?.id {
                viewModel.loadDaySchedule(
                    for: dayViewState.selectedDate,
                    userId: uid
                )
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
                                let past = isPast

                                BufferedPriorityRow(
                                    title: $priority.title,
                                    isCompleted: $priority.isCompleted,
                                    isFocused: _isDayPriorityFocused,
                                    onToggle: {
                                        if past {
                                            activeAlert = .confirmModifyPast(priority)
                                        } else {
                                            viewModel.togglePriorityCompletion(priority.id)
                                        }
                                    },
                                    showDelete: isRemoveMode,
                                    onDelete: {
                                        if past {
                                            activeAlert = .confirmDeletePast(priority)
                                        } else {
                                            activeAlert = .delete(priority)
                                        }
                                    },
                                    accentCyan: accentCyan,
                                    onCommit: {
                                        if past {
                                            activeAlert = .confirmModifyPast(priority)
                                        } else {
                                            viewModel.updateDaySchedule()
                                        }
                                    },
                                    isPast: past
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

                // ─────────────────────────────────────────────
                // Only show “Import Unfinished” when on today AND there are items
                if isToday && hasYesterdayUnfinished {
                    HStack {
                        Button(action: {
                            importUnfinishedFromYesterday()
                        }) {
                            Text("Import Unfinished from Yesterday")
                                .font(.headline)
                                .foregroundColor(.orange)
                                .underline()
                                .padding(.vertical, 8)
                                .padding(.horizontal, 16)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.top, 8)
                }
                // ─────────────────────────────────────────────

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
                                var t = sched
                                t.wakeUpTime = new
                                viewModel.schedule = t
                                viewModel.regenerateBlocks()
                                // ← Force‐publish updated blocks:
                                viewModel.schedule = viewModel.schedule
                            }
                        ), displayedComponents: .hourAndMinute)
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
                                var t = sched
                                t.sleepTime = new
                                viewModel.schedule = t
                                viewModel.regenerateBlocks()
                                // ← Force‐publish updated blocks:
                                viewModel.schedule = viewModel.schedule
                            }
                        ), displayedComponents: .hourAndMinute)
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
                    TimeBlockRow(block: block) { changedBlock, newTime, newTask in
                        // When either newTime or newTask is non-nil, update your model:
                        updateBlock(changedBlock,
                                    time: newTime,
                                    task: newTask)
                        viewModel.updateDaySchedule()
                    }
                }
            }
        } else {
            Text("Loading tasks…").foregroundColor(.white)
        }
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

        case .confirmModifyPast(let p):
            return Alert(
                title: Text("Editing Past Day"),
                message: Text("You’re about to change the status of a priority from a previous day. Continue?"),
                primaryButton: .destructive(Text("Yes")) {
                    if var sched = viewModel.schedule,
                       let idx = sched.priorities.firstIndex(where: { $0.id == p.id }) {
                        sched.priorities[idx].isCompleted.toggle()
                        viewModel.schedule = sched
                        viewModel.updateDaySchedule()
                    }
                },
                secondaryButton: .cancel()
            )

        case .confirmDeletePast(let p):
            return Alert(
                title: Text("Delete From Past Day"),
                message: Text("You’re about to permanently delete a priority from a previous day. Continue?"),
                primaryButton: .destructive(Text("Delete")) {
                    deletePriority(p)
                },
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
    
    // ─────────────────────────────────────────────────
    // Whenever today is active, fetch yesterday’s unfinished list and set the flag.
    private func updateYesterdayUnfinishedFlag() {
        guard let uid = session.userModel?.id else {
            hasYesterdayUnfinished = false
            return
        }
        // Only check if selectedDate is today
        if Calendar.current.isDateInToday(dayViewState.selectedDate) {
            let yesterday = Calendar.current.date(
                byAdding: .day,
                value: -1,
                to: dayViewState.selectedDate
            )!
            let yesterdayStart = Calendar.current.startOfDay(for: yesterday)
            viewModel.fetchUnfinishedPriorities(
                for: yesterdayStart,
                userId: uid
            ) { unfinished in
                hasYesterdayUnfinished = !unfinished.isEmpty
            }
        } else {
            hasYesterdayUnfinished = false
        }
    }
    // ─────────────────────────────────────────────────


    private func applyDefaultTimes(wakeOpt: Date?, sleepOpt: Date?) {
        guard
            let wake   = wakeOpt,
            let sleep  = sleepOpt,
            var sched  = viewModel.schedule
        else { return }

        // Only touch strictly future days:
        let today = Calendar.current.startOfDay(for: Date())
        guard sched.date > today else { return }

        // 1) Overwrite the schedule’s wake/sleep times:
        sched.wakeUpTime = wake
        sched.sleepTime  = sleep

        // 2) Build the list of “slot” strings between wake and sleep:
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
          // ← Must match exactly the format you use elsewhere for block.time.

        var slotTimes: [String] = []
        var cursor = wake
        while cursor < sleep {
            slotTimes.append(formatter.string(from: cursor))
            guard let nextHour = calendar.date(byAdding: .hour, value: 1, to: cursor) else { break }
            cursor = nextHour
        }

        // 3) Filter out any existing blocks that lie outside the new window,
        //    then “merge in” only the ones whose .time matches a slot string.
        //    Any slot missing a block becomes a brand-new empty TimeBlock.
        var mergedBlocks: [TimeBlock] = []
        for timeStr in slotTimes {
            // If there’s already a block exactly at this time, keep it (preserves its task).
            if let existing = sched.timeBlocks.first(where: { $0.time == timeStr }) {
                mergedBlocks.append(existing)
            } else {
                // Otherwise, insert an empty block at this slot
                mergedBlocks.append(TimeBlock(id: UUID(), time: timeStr, task: ""))
            }
        }
        sched.timeBlocks = mergedBlocks

        // 4) Push the updated schedule back into the view model and persist.
        viewModel.schedule = sched
        viewModel.updateDaySchedule()
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
        if let t  = time  { sched.timeBlocks[idx].time = t }
        if let tx = task { sched.timeBlocks[idx].task = tx }
        viewModel.schedule = sched
    }

    // ─────────────────────────────────────────
    // MARK: – NEW: Import Helper
    // ─────────────────────────────────────────
    private func importUnfinishedFromYesterday() {
        guard let uid = session.userModel?.id else { return }

        let calendar = Calendar.current
        // Compute “yesterday” relative to currently selected date
        guard let yesterday = calendar.date(byAdding: .day, value: -1, to: dayViewState.selectedDate) else { return }
        let yesterdayStart = calendar.startOfDay(for: yesterday)

        // Ask ViewModel to fetch unfinished priorities for “yesterdayStart”
        viewModel.fetchUnfinishedPriorities(for: yesterdayStart, userId: uid) { unfinished in
            guard var sched = viewModel.schedule else { return }

            // Avoid duplicates by title
            let existingTitles = Set(sched.priorities.map { $0.title })

            for old in unfinished {
                if !existingTitles.contains(old.title) {
                    let newPriority = TodayPriority(
                        id: UUID(),
                        title: old.title,
                        progress: 0.0,
                        isCompleted: false
                    )
                    sched.priorities.append(newPriority)
                }
            }

            // Publish updated schedule and persist
            viewModel.schedule = sched
            viewModel.updateDaySchedule()
        }
    }
}

// ... (rest of file unchanged) ...



private struct TextHeightPreferenceKey: PreferenceKey {
  static var defaultValue: CGFloat = 50
  static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
    // keep the largest measured height
    value = max(value, nextValue())
  }
}


// ───────────────────────────────────────────────
// MARK: - BufferedPriorityRow (DayView)
// ───────────────────────────────────────────────
private struct BufferedPriorityRow: View {
    @Binding var title: String
    @Binding var isCompleted: Bool
    @FocusState var isFocused: Bool

    let onToggle:   () -> Void
    let showDelete: Bool
    let onDelete:   () -> Void
    let accentCyan: Color
    let onCommit:   () -> Void

    // Indicates this row belongs to a past date
    let isPast: Bool

    @State private var localTitle: String
    @State private var measuredTextHeight: CGFloat = 0

    init(
        title: Binding<String>,
        isCompleted: Binding<Bool>,
        isFocused: FocusState<Bool>,
        onToggle: @escaping () -> Void,
        showDelete: Bool,
        onDelete: @escaping () -> Void,
        accentCyan: Color,
        onCommit: @escaping () -> Void,
        isPast: Bool = false         // default: today
    ) {
        self._title = title
        self._isCompleted = isCompleted
        self._isFocused = isFocused
        self.onToggle = onToggle
        self.showDelete = showDelete
        self.onDelete = onDelete
        self.accentCyan = accentCyan
        self.onCommit = onCommit
        self.isPast = isPast
        _localTitle = State(initialValue: title.wrappedValue)
    }

    var body: some View {
        let minTextHeight: CGFloat = 50
        let totalVerticalPadding: CGFloat = 24
        let padded = measuredTextHeight + totalVerticalPadding
        let finalHeight = max(padded, minTextHeight)
        let halfPad = totalVerticalPadding / 2

        HStack(spacing: 8) {
            // — TextEditor for “title” (unchanged)
            ZStack(alignment: .trailing) {
                Text(localTitle)
                    .font(.body)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: TextHeightPreferenceKey.self,
                                value: geo.size.height
                            )
                        }
                    )
                    .opacity(0) // invisible, used to measure height

                TextEditor(text: $localTitle)
                    .font(.body)
                    .padding(.vertical, halfPad)
                    .padding(.leading, 4)
                    .padding(.trailing, 40)
                    .frame(height: finalHeight)
                    .background(Color.black)
                    .cornerRadius(8)
                    .focused($isFocused)
                    .onChange(of: isFocused) { focused in
                        if !focused {
                            title = localTitle
                            onCommit()
                        }
                    }
            }
            .onPreferenceChange(TextHeightPreferenceKey.self) {
                measuredTextHeight = $0
            }

            // — If not in delete mode, show the checklist icon on the right
            if !showDelete {
                Button(action: {
                    onToggle()
                }) {
                    Group {
                        if isCompleted {
                            Image(systemName: "checkmark.circle.fill")
                        } else if isPast {
                            Image(systemName: "xmark.circle.fill")
                        } else {
                            Image(systemName: "circle")
                        }
                    }
                    .font(.title2)
                    .foregroundColor(
                        isCompleted
                        ? accentCyan
                        : (isPast ? .red : .gray)
                    )
                }
                .padding(.trailing, 8)
            }

            // — Delete button, visible whenever showDelete == true
            if showDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle")
                        .font(.title2)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(4)
        .background(Color.black)
        .cornerRadius(8)
        .shadow(radius: 0)
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
