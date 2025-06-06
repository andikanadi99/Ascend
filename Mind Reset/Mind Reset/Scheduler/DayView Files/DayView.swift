//
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
    case confirmModifyPast(TodayPriority)
    case confirmDeletePast(TodayPriority)
    case confirmImport          // prompt before importing unfinished

    var id: String {
        switch self {
        case .copy:                       return "copy"
        case .delete(let p):              return "delete-\(p.id)"
        case .confirmModifyPast(let p):   return "confirmPast-\(p.id)"
        case .confirmDeletePast(let p):   return "confirmDeletePast-\(p.id)"
        case .confirmImport:              return "confirmImport"
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

    init(block: TimeBlock,
         onCommit: @escaping (_ block: TimeBlock, _ newTime: String?, _ newTask: String?) -> Void) {
        self.block = block
        self.onCommit = onCommit
        _localTime  = State(initialValue: block.time)
        _localTask  = State(initialValue: block.task)
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField("Time", text: $localTime, onCommit: {
                onCommit(block, localTime, nil)
            })
            .focused($isThisBlockFocused, equals: false)
            .font(.caption)
            .foregroundColor(.white)
            .frame(width: 80)
            .padding(8)
            .background(Color.black.opacity(0.5))
            .cornerRadius(8)

            TextEditor(text: $localTask)
                .focused($isThisBlockFocused)
                .font(.caption)
                .foregroundColor(.white)
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.black.opacity(0.5))
                .cornerRadius(8)
                .frame(minHeight: 50, maxHeight: 80)
                .onChange(of: isThisBlockFocused) { focused in
                    if !focused { onCommit(block, nil, localTask) }
                }

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

    // Local UI state
    @State private var activeAlert: DayViewAlert?
    @State private var isRemoveMode = false
    @State private var hasYesterdayUnfinished = false
    @State private var editMode: EditMode = .inactive

    // Focus flags
    @FocusState private var isDayPriorityFocused: Bool
    @FocusState private var isDayTimeFocused:     Bool

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
        let f = DateFormatter(); f.dateStyle = .full
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
                timeBlocksSection
                Spacer()
            }
            .padding()
            .padding(.top, -20)
        }
        // ← SINGLE, never-recreated alert handler for *all* alerts
        .alert(item: $activeAlert, content: buildAlert)

        // ---------- lifecycle / combine ----------
        .onAppear           { loadInitialSchedule(); DispatchQueue.main.async { updateYesterdayUnfinishedFlag() } }
        .onChange(of: dayViewState.selectedDate) { _ in updateYesterdayUnfinishedFlag(); loadScheduleIfNeeded() }
        .onReceive(viewModel.$schedule)          { sched in handleSchedulePublish(sched) }
        .onReceive(session.$defaultWakeTime.combineLatest(session.$defaultSleepTime)) { applyDefaultTimesIfNeeded(wake:$0.0, sleep:$0.1) }
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in loadScheduleIfNeeded() }
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
                    .frame(minHeight: CGFloat(binding.wrappedValue.count) * 90)
                    .environment(\.editMode, $editMode)
                    .padding(.bottom, 20)
                }

                // add / remove buttons
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

                // import unfinished
                if isToday && hasYesterdayUnfinished {
                    HStack {
                        Button {
                            activeAlert = .confirmImport
                        } label: {
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
                Text("Loading priorities…").foregroundColor(.white)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.3))
        .cornerRadius(8)
    }

    // ─────────────────────────────────────────
    // MARK: – Wake / Sleep pickers
    // ─────────────────────────────────────────
    @ViewBuilder
    private var wakeSleepSection: some View {
        if let sched = viewModel.schedule {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Wake Up Time").foregroundColor(.white)
                        DatePicker("",
                                   selection: Binding(
                                        get: { sched.wakeUpTime },
                                        set: { new in
                                            var t = sched; t.wakeUpTime = new
                                            viewModel.schedule = t
                                            viewModel.regenerateBlocks()
                                            viewModel.schedule = viewModel.schedule
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
                        DatePicker("",
                                   selection: Binding(
                                        get: { sched.sleepTime },
                                        set: { new in
                                            var t = sched; t.sleepTime = new
                                            viewModel.schedule = t
                                            viewModel.regenerateBlocks()
                                            viewModel.schedule = viewModel.schedule
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
    // MARK: – Time blocks
    // ─────────────────────────────────────────
    @ViewBuilder
    private var timeBlocksSection: some View {
        if let sched = viewModel.schedule {
            VStack(spacing: 16) {
                ForEach(sched.timeBlocks) { block in
                    TimeBlockRow(block: block) { changedBlock, newTime, newTask in
                        updateBlock(changedBlock, time: newTime, task: newTask)
                        viewModel.updateDaySchedule()
                    }
                }
            }
        } else {
            Text("Loading tasks…").foregroundColor(.white)
        }
    }

    // ─────────────────────────────────────────
    // MARK: – Alerts
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
                primaryButton: .destructive(Text("Delete")) { deletePriority(p) },
                secondaryButton: .cancel()
            )

        case .confirmImport:
            return Alert(
                title: Text("Import Unfinished Priorities?"),
                message: Text("This will bring in all priorities from yesterday that aren’t yet completed. Continue?"),
                primaryButton: .destructive(Text("Cancel")),
                secondaryButton: .default(Text("Import")) { performImportUnfinished() }
            )
        }
    }

    // ─────────────────────────────────────────
    // MARK: – Helper methods
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
        viewModel.schedule = viewModel.schedule
    }

    private func copyPreviousDay() {
        guard let uid = session.userModel?.id else { return }
        viewModel.copyPreviousDaySchedule(to: dayViewState.selectedDate, userId: uid) { _ in }
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
              let prev = Calendar.current.date(byAdding: .day, value: -1, to: dayViewState.selectedDate)
        else { return }
        dayViewState.selectedDate = prev
        loadScheduleIfNeeded()
    }

    private func goForwardOneDay() {
        guard let next = Calendar.current.date(byAdding: .day, value: 1, to: dayViewState.selectedDate) else { return }
        dayViewState.selectedDate = next
        loadScheduleIfNeeded()
    }

    private func canGoBack() -> Bool {
        guard let created = session.userModel?.createdAt else { return false }
        return dayViewState.selectedDate > Calendar.current.startOfDay(for: created)
    }

    private func updateBlock(_ block: TimeBlock, time: String? = nil, task: String? = nil) {
        guard var sched = viewModel.schedule,
              let idx = sched.timeBlocks.firstIndex(where: { $0.id == block.id }) else { return }
        if let t = time { sched.timeBlocks[idx].time = t }
        if let txt = task { sched.timeBlocks[idx].task = txt }
        viewModel.schedule = sched
    }

    // import helper
    private func performImportUnfinished() {
        guard let uid = session.userModel?.id else { return }
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: dayViewState.selectedDate) else { return }
        let yStart = Calendar.current.startOfDay(for: yesterday)
        viewModel.fetchUnfinishedPriorities(for: yStart, userId: uid) { arr in
            guard var sched = viewModel.schedule else { return }
            let existing = Set(sched.priorities.map(\.title))
            for old in arr where !existing.contains(old.title) {
                sched.priorities.append(TodayPriority(id: UUID(), title: old.title, progress: 0, isCompleted: false))
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
        isPast: Bool = false) {
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
        let minHeight: CGFloat = 50
        let padTotal: CGFloat = 24
        let finalHeight = max(measuredTextHeight + padTotal, minHeight)
        let halfPad = padTotal / 2

        HStack(spacing: 8) {
            ZStack(alignment: .trailing) {
                Text(localTitle)
                    .font(.body)
                    .opacity(0)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: TextHeightPreferenceKey.self,
                                                   value: geo.size.height)
                        }
                    )

                TextEditor(text: $localTitle)
                    .font(.body)
                    .padding(.vertical, halfPad)
                    .padding(.leading, 4)
                    .padding(.trailing, 40)
                    .frame(height: finalHeight)
                    .background(Color.black)
                    .cornerRadius(8)
                    .focused($isFocused)
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
                    Group {
                        if isCompleted { Image(systemName: "checkmark.circle.fill") }
                        else if isPast { Image(systemName: "xmark.circle.fill") }
                        else           { Image(systemName: "circle") }
                    }
                    .font(.title2)
                    .foregroundColor(isCompleted ? accentCyan : (isPast ? .red : .gray))
                }
                .padding(.trailing, 8)
            }

            if showDelete {
                Button(role: .destructive) { onDelete() } label: {
                    Image(systemName: "minus.circle")
                        .font(.title2)
                        .foregroundColor(.red)
                }
                .buttonStyle(.borderless)      // critical inside List rows
                .padding(.trailing, 8)
            }
        }
        .padding(4)
        .background(Color.black)
        .cornerRadius(8)
    }
}
