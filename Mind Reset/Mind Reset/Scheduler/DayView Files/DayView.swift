//
//  DayView.swift
//  Mind Reset
//
//  Created by Andika Yudhatrisna on 2/6/25.
//  Last revised 07 Jun 2025
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
    case confirmModifyPast(TodayPriority)
    case confirmDeletePast(TodayPriority)
    case confirmImport
    case clear(TimeBlock)          // clear one block
    case clearAllBlocks            // clear every block in the day
    case confirmSchedule(Date, Date) // confirm new wake/sleep

    var id: String {
        switch self {
        case .copy:                       return "copy"
        case .delete(let p):              return "delete-\(p.id)"
        case .confirmModifyPast(let p):   return "confirmPast-\(p.id)"
        case .confirmDeletePast(let p):   return "confirmDeletePast-\(p.id)"
        case .confirmImport:              return "confirmImport"
        case .clear(let b):               return "clear-\(b.id)"
        case .clearAllBlocks:             return "clearAllBlocks"
        case .confirmSchedule:            return "confirmSchedule"
        }
    }
}

// ───────────────────────────────────────────────
// MARK: - Time-block row
// ───────────────────────────────────────────────
struct TimeBlockRow: View {
    let block: TimeBlock
    let onCommit: (_ block: TimeBlock, _ newTime: String?, _ newTask: String?) -> Void

    @State private var localTime: String
    @State private var localTask: String
    @FocusState private var isThisBlockFocused: Bool

    // Tracks the dynamic height of the task editor
    @State private var measuredTaskHeight: CGFloat = 0
    


    init(
        block: TimeBlock,
        onCommit: @escaping (_ block: TimeBlock, _ newTime: String?, _ newTask: String?) -> Void
    ) {
        self.block = block
        self.onCommit = onCommit
        _localTime  = State(initialValue: block.time)
        _localTask  = State(initialValue: block.task)
    }

    var body: some View {
        HStack(spacing: 8) {

            // ——— Time field ———
            TextField("Time", text: $localTime, onCommit: {
                onCommit(block, localTime, nil)
            })
            .textFieldStyle(.plain)
            .focused($isThisBlockFocused, equals: false)
            .font(.caption)
            .foregroundColor(.white)
            .frame(width: 80)
            .padding(8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)

            // ——— Auto-expanding task field ———
            let minHeight: CGFloat = 50
            let padV:      CGFloat = 8
            let padH:      CGFloat = 8
            let finalHeight = max(measuredTaskHeight + padV * 2, minHeight)

            ZStack(alignment: .topLeading) {

                // Invisible twin → measures intrinsic height
                Text(localTask)
                    .font(.caption)
                    .padding(.vertical, padV)
                    .padding(.horizontal, padH)
                    .opacity(0)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: TextHeightPreferenceKey.self,
                                value: geo.size.height
                            )
                        }
                    )

                // Actual editable field
                TextEditor(text: $localTask)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(.white) 
                    .focused($isThisBlockFocused)
                    .font(.caption)
                    .foregroundColor(.white)
                    .scrollContentBackground(.hidden)
                    .padding(.vertical, padV)
                    .padding(.horizontal, padH)
                    .background(Color.black.opacity(0.5))
                    .cornerRadius(8)
                    .frame(height: finalHeight)          // 💡 dynamic height
                    .onChange(of: isThisBlockFocused) { foc in
                        if !foc { onCommit(block, nil, localTask) }
                    }
            }
            .onPreferenceChange(TextHeightPreferenceKey.self) { measuredTaskHeight = $0 }

            Spacer()
        }
        .padding(8)
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }
}


// ───────────────────────────────────────────────
// MARK: - Day view (“Your Mindful Day”)
// ───────────────────────────────────────────────
struct DayView: View {

    // Environment & view-models
    @EnvironmentObject var session: SessionStore
    @EnvironmentObject var dayViewState: DayViewState
    @StateObject private var viewModel = DayViewModel()
    
    @AppStorage("dateFormatStyle") private var dateFormatStyle: String = "MM/dd/yyyy"
    @AppStorage("useSimpleBlocks") private var useSimpleBlocks: Bool = true

    private enum DayViewMode: String, CaseIterable { case tasks = "Tasks", timeline = "Timeline" }
    @State private var viewMode: DayViewMode = .tasks

    // Local UI state
    @State private var activeAlert: DayViewAlert?
    @State private var isRemoveMode = false
    @State private var hasYesterdayUnfinished = false
    @State private var editMode: EditMode = .inactive

    @State private var refreshKey = UUID()
    // Focus flags
    @FocusState private var isDayPriorityFocused: Bool
    @FocusState private var isDayTimeFocused:     Bool
    
    @State private var listHeight: CGFloat = 0

    // Draft wake/sleep to avoid instantaneous re-render glitches
    @State private var draftWake: Date = Date()
    @State private var draftSleep: Date = Date()
    @State private var dateFormatVersion = UUID()
    

    // Accent colour
    private let accentCyan = Color(red: 0, green: 1, blue: 1)

    // Helper binding to today’s priorities array
    private var prioritiesBinding: Binding<[TodayPriority]>? {
        guard let sched = viewModel.schedule else { return nil }
        return Binding(
            get:  { sched.priorities },
            set: { arr in
                var tmp = sched
                tmp.priorities = arr
                viewModel.schedule = tmp
            }
        )
    }

    // Quick flags
    private var dateString: String {
        let f = DateFormatter()
        f.dateFormat = dateFormatStyle    // use the user’s setting
        return f.string(from: dayViewState.selectedDate)
    }
    private var isToday: Bool { Calendar.current.isDateInToday(dayViewState.selectedDate) }
    private var isPast:  Bool {
        let todayStart = Calendar.current.startOfDay(for: Date())
        return dayViewState.selectedDate < todayStart
    }

    // ─────────────────────────────────────────
    // MARK: – Main view hierarchy
    // ─────────────────────────────────────────
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                copyButton
                dateNavigation
                prioritiesSection
                wakeSleepSection
                // Toggle between Tasks list and Interactive Timeline
                Picker("", selection: $viewMode) {
                    ForEach(DayViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .tint(.gray)
                .background(Color.gray)
                .cornerRadius(8)
                .padding(.horizontal, 10)
                Spacer()
                timeBlocksSection   // switches based on viewMode
                Spacer()
            }
            .padding(.top, 16)
        }
        .scrollDismissesKeyboard(.immediately)
        .alert(item: $activeAlert, content: buildAlert)

        // ───────── Lifecycle / Combine ─────────
        .onAppear {
            loadInitialSchedule()
            DispatchQueue.main.async { updateYesterdayUnfinishedFlag() }
        }
        .onChange(of: dayViewState.selectedDate) { _ in
            if let sched = viewModel.schedule {
                draftWake = sched.wakeUpTime
                draftSleep = sched.sleepTime
            }
            viewModel.schedule = nil   // reset before loading new day
            updateYesterdayUnfinishedFlag()
            loadScheduleIfNeeded()
        }
        .onReceive(viewModel.$schedule) { sched in
            if let sched = sched {
                draftWake = sched.wakeUpTime
                draftSleep = sched.sleepTime
            }
            handleSchedulePublish(sched)
        }
        .onReceive(session.$defaultWakeTime.combineLatest(session.$defaultSleepTime)) { wake, sleep in
            applyDefaultTimesIfNeeded(wake: wake, sleep: sleep)
        }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            loadScheduleIfNeeded()
        }

        // ← Refresh view when date-format setting changes
        .onReceive(NotificationCenter.default.publisher(for: .dateFormatChanged)) { _ in
            dateFormatVersion = UUID()
        }

        // ← Menu to switch between simple list & interactive timeline
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Picker("Schedule layout", selection: $useSimpleBlocks) {
                        Text("Simple list").tag(true)
                        Text("Interactive timeline").tag(false)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
    }


    // ─────────────────────────────────────────
    // MARK: – Top controls
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
                Image(systemName: "chevron.right").foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }

    // ─────────────────────────────────────────
    // MARK: – Priorities
    // ─────────────────────────────────────────
    private var prioritiesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Today's Top Priority")
                .font(.headline)
                .foregroundColor(accentCyan)

            if let binding = prioritiesBinding {
                if binding.wrappedValue.isEmpty {
                    Text("Please list your priorities for today")
                        .foregroundColor(.white.opacity(0.7))
                        .italic()
                        .padding(.vertical, 20)
                        .frame(maxWidth: .infinity)
                        .background(Color(.sRGB, white: 0.1, opacity: 1))
                        .cornerRadius(8)
                } else {
                    // ——— Native List keeps drag-to-reorder ———
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
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        if past {
                                            activeAlert = .confirmDeletePast(priority)
                                        } else {
                                            activeAlert = .delete(priority)
                                        }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                            }
                            .onMove { idx, new in
                                binding.wrappedValue.move(fromOffsets: idx, toOffset: new)
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
                    .frame(minHeight: max(
                              listHeight,
                              CGFloat(binding.wrappedValue.count) * 60       // 60-pt fallback/row
                          ))
                    .onPreferenceChange(PriorityListHeightPreferenceKey.self) { new in
                        listHeight = new                                     // total of all rows
                    }
                    .environment(\.editMode, $editMode)
                    .padding(.bottom, 20)
                }

                // ——— Add / Remove controls ———
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

                // ——— Import unfinished yesterday ———
                if isToday && hasYesterdayUnfinished {
                    HStack {
                        Button { activeAlert = .confirmImport } label: {
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
            } else {
                Text("Loading priorities…")
                    .foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }

    // ─────────────────────────────────────────
    // MARK: – Wake / Sleep pickers + confirm
    // ─────────────────────────────────────────
    @ViewBuilder
    private var wakeSleepSection: some View {
        if let sched = viewModel.schedule {
            VStack(alignment: .leading, spacing: 8) {
                Text("Wake & Sleep Times")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack {
                    VStack(alignment: .leading) {
                        Text("Wake Up").foregroundColor(.white)
                        DatePicker("", selection: $draftWake, displayedComponents: .hourAndMinute)
                            .focused($isDayTimeFocused)
                            .labelsHidden()
                            .environment(\.colorScheme, .dark)
                            .padding(4)
                            .background(Color.black)
                            .cornerRadius(4)
                    }
                    Spacer()
                    VStack(alignment: .leading) {
                        Text("Sleep").foregroundColor(.white)
                        DatePicker("", selection: $draftSleep, displayedComponents: .hourAndMinute)
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

                if draftWake != sched.wakeUpTime || draftSleep != sched.sleepTime {
                    Button("Confirm Schedule") {
                        activeAlert = .confirmSchedule(draftWake, draftSleep)
                    }
                    .font(.headline)
                    .foregroundColor(accentCyan)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.black)
                    .cornerRadius(8)
                }
            }
        } else {
            Text("Loading times…").foregroundColor(.white)
        }
    }


    // ─────────────────────────────────────────
    // MARK: – Time blocks + “Clear All” button
    // ─────────────────────────────────────────
    @ViewBuilder
    private var timeBlocksSection: some View {
        switch viewMode {
        case .timeline:
            if let sched = viewModel.schedule {
                let wakeHour  = Calendar.current.component(.hour, from: sched.wakeUpTime)
                // add 24 if sleep is next-day
                let rawSleep  = Calendar.current.component(.hour, from: sched.sleepTime)
                let sleepHour = (sched.sleepTime <= sched.wakeUpTime) ? rawSleep + 24 : rawSleep

                DayTimelineHost(
                    visibleStartHour: wakeHour,
                    visibleEndHour:   sleepHour,
                    dayDate:   dayViewState.selectedDate,
                    blocks:    sched.timeBlocks                // ← filter out blanks
                                .filter { !$0.task.isEmpty }   //   (no text → no blue bubble)
                                .map { tb in                   //   convert to TimelineBlock
                                    TimelineBlock(
                                        id:          tb.id,
                                        start:       tb.start,
                                        end:         tb.end,
                                        title:       tb.task,
                                        color:       accentCyan,
                                        description: tb.task
                                    )
                                },
                    accentColor: accentCyan,
                    onCreate: { appendTimelineBlock($0) }
                )
                .environmentObject(viewModel)
                .padding(.top, 8)      // give a little breathing room above the grid
                .padding(.horizontal)
            } else {
                ProgressView().frame(height: 800)
            }
        case .tasks:
            legacyTimeBlockList
        }
    }

    // ← NEW helper: exactly your old list code, unchanged
    @ViewBuilder
    private var legacyTimeBlockList: some View {
        if let sched = viewModel.schedule {
            VStack(spacing: 16) {
                ForEach(sched.timeBlocks) { block in
                    HStack(spacing: 8) {
                        TimeBlockRow(block: block) { changed, _, newTask in
                            if let txt = newTask {
                                updateBlock(changed, task: txt)
                                viewModel.updateDaySchedule()
                            }
                        }
                    }
                }
                .id(refreshKey)

                if !sched.timeBlocks.isEmpty {
                    Button { activeAlert = .clearAllBlocks } label: {
                        HStack {
                            Image(systemName: "trash")
                            Text("Clear All Time Blocks")
                        }
                        // … styling …
                    }
                    .buttonStyle(.plain)
                }
            }
        } else {
            Text("Loading tasks…").foregroundColor(.white)
        }
    }


    

    /// Converts “HH:mm” strings to real `Date` objects anchored to today
    private func timeStringToDate(_ string: String) -> Date {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        let comps = string.split(separator: ":").compactMap { Int($0) }
        let hours = comps.first ?? 0
        let mins  = comps.dropFirst().first ?? 0
        return Calendar.current.date(bySettingHour: hours, minute: mins, second: 0, of: Date())!
    }

    /// Appends a newly created timeline block to today’s schedule (placeholder logic)
    private func appendTimelineBlock(_ tb: TimelineBlock) {
        guard var sched = viewModel.schedule else { return }

        sched.timeBlocks.append(
            TimeBlock(id: tb.id, start: tb.start, end: tb.end, task: "")
        )

        viewModel.schedule = sched
        viewModel.updateDaySchedule()
    }

    // ─────────────────────────────────────────
    // MARK: – Alerts
    // ─────────────────────────────────────────
    private func buildAlert(for alert: DayViewAlert) -> Alert {
        switch alert {
        case .clearAllBlocks:
            return Alert(
                title: Text("Reset All Time Blocks?"),
                message: Text("This will delete every task in today’s schedule."),
                primaryButton: .destructive(Text("Clear All")) { clearAllBlocks() },
                secondaryButton: .cancel()
            )

        case .clear(let block):
            return Alert(
                title: Text("Clear this time block?"),
                message: Text("Remove “\(block.time)”’s text?"),
                primaryButton: .destructive(Text("Clear")) { clearBlock(block) },
                secondaryButton: .cancel()
            )

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
                message: Text("Change the status of a past priority?"),
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
                message: Text("Permanently delete this past priority?"),
                primaryButton: .destructive(Text("Delete")) { deletePriority(p) },
                secondaryButton: .cancel()
            )

        case .confirmImport:
            return Alert(
                title: Text("Import Unfinished?"),
                message: Text("Bring in all unfinished priorities from yesterday?"),
                primaryButton: .destructive(Text("Cancel")),
                secondaryButton: .default(Text("Import")) { performImportUnfinished() }
            )

        case .confirmSchedule(let newWake, let newSleep):
            let wakeStr = DateFormatter.localizedString(from: newWake, dateStyle: .none, timeStyle: .short)
            let sleepStr = DateFormatter.localizedString(from: newSleep, dateStyle: .none, timeStyle: .short)
            return Alert(
                title: Text("Confirm Schedule"),
                message: Text("Set wake time to \(wakeStr) and sleep time to \(sleepStr)?"),
                primaryButton: .default(Text("Yes")) {
                    if var sched = viewModel.schedule {
                        sched.wakeUpTime = newWake
                        sched.sleepTime = newSleep
                        viewModel.schedule = sched
                        viewModel.regenerateBlocks()
                        viewModel.updateDaySchedule()
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    // ─────────────────────────────────────────
    // MARK: – Time-block helpers
    // ─────────────────────────────────────────
    private func clearAllBlocks() {
        guard var sched = viewModel.schedule else { return }
        for idx in sched.timeBlocks.indices {
            sched.timeBlocks[idx].task = ""
        }
        viewModel.schedule = sched
        viewModel.updateDaySchedule()
        refreshKey = UUID()
    }

    private func clearBlock(_ block: TimeBlock) {
        guard var sched = viewModel.schedule,
              let idx = sched.timeBlocks.firstIndex(where: { $0.id == block.id }) else { return }
        sched.timeBlocks[idx].task = ""
        viewModel.schedule = sched
        viewModel.updateDaySchedule()
    }

    private func updateBlock(
        _ block: TimeBlock,
        start: Date? = nil,
        end: Date? = nil,
        task: String? = nil
    ) {
        guard var sched = viewModel.schedule,
              let idx = sched.timeBlocks.firstIndex(where: { $0.id == block.id }) else { return }
        if let s = start {
            sched.timeBlocks[idx].start = s
        }
        if let e = end {
            sched.timeBlocks[idx].end = e
        }
        if let txt = task {
            sched.timeBlocks[idx].task = txt
        }
        viewModel.schedule = sched
        viewModel.updateDaySchedule()
    }

    // ─────────────────────────────────────────
    // MARK: – Priority helpers
    // ─────────────────────────────────────────
    private func addPriority() {
        guard var sched = viewModel.schedule else { return }
        sched.priorities.append(
            TodayPriority(id: UUID(), title: "New Priority", progress: 0)
        )
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

    private func copyPreviousDay() {
        guard let uid = session.userModel?.id else { return }
        viewModel.copyPreviousDaySchedule(to: dayViewState.selectedDate, userId: uid) { _ in }
    }

    // ─────────────────────────────────────────
    // MARK: – Date navigation
    // ─────────────────────────────────────────
    private func goBackOneDay() {
        guard let created = session.userModel?.createdAt,
              dayViewState.selectedDate > Calendar.current.startOfDay(for: created),
              let prev = Calendar.current.date(
                  byAdding: .day, value: -1, to: dayViewState.selectedDate
              )
        else { return }
        dayViewState.selectedDate = prev
        loadScheduleIfNeeded()
    }

    private func goForwardOneDay() {
        guard let next = Calendar.current.date(
            byAdding: .day, value: 1, to: dayViewState.selectedDate
        ) else { return }
        dayViewState.selectedDate = next
        loadScheduleIfNeeded()
    }

    private func canGoBack() -> Bool {
        guard let created = session.userModel?.createdAt else { return false }
        return dayViewState.selectedDate > Calendar.current.startOfDay(for: created)
    }

    // ─────────────────────────────────────────
    // MARK: – Loading & defaults
    // ─────────────────────────────────────────
    private func loadInitialSchedule() {
        let now = Date()
        let last = UserDefaults.standard.object(forKey: "LastActiveTime") as? Date ?? now
        if now.timeIntervalSince(last) > 1800 { dayViewState.selectedDate = now }
        UserDefaults.standard.set(now, forKey: "LastActiveTime")
        loadScheduleIfNeeded()
    }

    private func loadScheduleIfNeeded() {
        if viewModel.schedule == nil, let uid = session.userModel?.id {
            viewModel.loadDaySchedule(for: dayViewState.selectedDate, userId: uid)
        }
    }

    private func handleSchedulePublish(_ sched: DaySchedule?) {
        guard let s = sched else { return }
        let today = Calendar.current.startOfDay(for: Date())
        if s.date > today && s.timeBlocks.isEmpty {
            viewModel.regenerateBlocks()
            viewModel.updateDaySchedule()
            viewModel.schedule = viewModel.schedule  // republish
        }
    }

    private func updateYesterdayUnfinishedFlag() {
        guard let uid = session.userModel?.id else { hasYesterdayUnfinished = false; return }
        if Calendar.current.isDateInToday(dayViewState.selectedDate) {
            let y = Calendar.current.date(byAdding: .day, value: -1, to: dayViewState.selectedDate)!
            let yStart = Calendar.current.startOfDay(for: y)
            viewModel.fetchUnfinishedPriorities(for: yStart, userId: uid) { arr in
                hasYesterdayUnfinished = !arr.isEmpty
            }
        } else { hasYesterdayUnfinished = false }
    }

    private func applyDefaultTimesIfNeeded(wake: Date?, sleep: Date?) {
        guard let w = wake, let s = sleep, var sched = viewModel.schedule else { return }
        let today = Calendar.current.startOfDay(for: Date())
        guard sched.date > today else { return }
        sched.wakeUpTime = w
        sched.sleepTime  = s
        viewModel.schedule = sched
        viewModel.regenerateBlocks()
    }

    private func performImportUnfinished() {
        guard let uid = session.userModel?.id else { return }
        guard let yesterday = Calendar.current.date(
            byAdding: .day, value: -1, to: dayViewState.selectedDate
        ) else { return }
        let yStart = Calendar.current.startOfDay(for: yesterday)
        viewModel.fetchUnfinishedPriorities(for: yStart, userId: uid) { arr in
            guard var sched = viewModel.schedule else { return }
            let existing = Set(sched.priorities.map(\.title))
            for old in arr where !existing.contains(old.title) {
                sched.priorities.append(
                    TodayPriority(
                        id: UUID(),
                        title: old.title,
                        progress: 0,
                        isCompleted: false
                    )
                )
            }
            viewModel.schedule = sched
            viewModel.updateDaySchedule()
        }
    }
}

// ───────────────────────────────────────────────
// MARK: - Text-height preference key
// ───────────────────────────────────────────────
private struct TextHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 50
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

// Reports each priority row’s height; parent sums them.
private struct PriorityListHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value += nextValue()                // accumulate heights
    }
}


// ───────────────────────────────────────────────
// MARK: - Buffered priority row
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
    let isPast:     Bool

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
        isPast: Bool = false
    ) {
        self._title        = title
        self._isCompleted  = isCompleted
        self._isFocused    = isFocused
        self.onToggle      = onToggle
        self.showDelete    = showDelete
        self.onDelete      = onDelete
        self.accentCyan    = accentCyan
        self.onCommit      = onCommit
        self.isPast        = isPast
        _localTitle        = State(initialValue: title.wrappedValue)
    }

    var body: some View {
        let minHeight: CGFloat = 50
        let padV:      CGFloat = 12
        let padH:      CGFloat = 8
        let finalHeight = max(measuredTextHeight + padV * 2, minHeight)

        HStack(spacing: 8) {
            ZStack(alignment: .topLeading) {
                Text(localTitle)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.vertical, padV)
                    .padding(.horizontal, padH)
                    .opacity(0)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(
                                key: TextHeightPreferenceKey.self,
                                value: geo.size.height
                            )
                        }
                    )
                TextEditor(text: $localTitle)
                    .scrollContentBackground(.hidden)
                    .foregroundColor(.white)
                    .font(.body)
                    .padding(.vertical, padV)
                    .padding(.horizontal, padH)
                    .background(Color.black)
                    .cornerRadius(8)
                    .opacity(isPast ? 0.6 : 1)
                    .focused($isFocused)
                    .frame(height: finalHeight)
                    .onChange(of: isFocused) { foc in
                        if !foc {
                            title = localTitle
                            onCommit()
                        }
                    }
            }
            .onPreferenceChange(TextHeightPreferenceKey.self) { measuredTextHeight = $0 }

            if !showDelete {
                Button { onToggle() } label: {
                    let icon = isCompleted
                        ? "checkmark.circle.fill"
                        : (isPast ? "xmark.circle.fill" : "circle")
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(isCompleted ? accentCyan : (isPast ? .red : .gray))
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .padding(.trailing, 8)
            }

            if showDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "minus.circle")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)
                .padding(.trailing, 8)
            }
        }
        .padding(4)
        .background(Color.black)
        .cornerRadius(8)
        .background(
            GeometryReader { geo in
                Color.clear.preference(
                    key: PriorityListHeightPreferenceKey.self,
                    value: geo.size.height + 8
                )
            }
        )
    }
}
