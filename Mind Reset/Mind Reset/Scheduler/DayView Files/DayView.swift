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
    case clearTimeline
    case confirmSchedule(Date, Date) // confirm new wake/sleep

    var id: String {
        switch self {
        case .copy:              return "copy"
        case .clearTimeline:     return "clearTimeline"      // ← just a String
        case .delete(let p):     return "delete-\(p.id)"
        case .confirmModifyPast(let p): return "confirmPast-\(p.id)"
        case .confirmDeletePast(let p): return "confirmDeletePast-\(p.id)"
        case .confirmImport:     return "confirmImport"
        case .confirmSchedule:   return "confirmSchedule"
        }
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
    let darkCyan = Color(red: 0, green: 0.8, blue: 0.8)

    // Helper binding to today’s priorities array
    private var prioritiesBinding: Binding<[TodayPriority]>? {
        guard let sched = viewModel.scheduleMeta else { return nil }
        return Binding(
            get:  { sched.priorities },
            set: { arr in
                var tmp = sched
                tmp.priorities = arr
                viewModel.scheduleMeta = tmp
                viewModel.pushMeta()
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
        ZStack {
            if viewModel.isLoadingDay {
                ProgressView("Loading…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemBackground).opacity(0.8))
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        dateNavigation
                        prioritiesSection
                        wakeSleepSection
                        Spacer()
                        copyBar
                        timeBlocksSection
                        Spacer()
                    }
                    .padding(.top, 16)
                }
                .scrollDismissesKeyboard(.immediately)
                .alert(item: $activeAlert, content: buildAlert)
                .onAppear {
                    loadInitialSchedule()
                    DispatchQueue.main.async { updateYesterdayUnfinishedFlag() }
                }
                .onChange(of: dayViewState.selectedDate) { _ in
                    if let s = viewModel.scheduleMeta {
                        draftWake  = s.wakeUpTime
                        draftSleep = s.sleepTime
                    }
                    updateYesterdayUnfinishedFlag()
                    if let uid = session.userModel?.id {
                        viewModel.loadDay(for: dayViewState.selectedDate, userId: uid)
                    }
                }
                .onReceive(viewModel.$scheduleMeta) { sched in
                    if let s = sched {
                        draftWake  = s.wakeUpTime
                        draftSleep = s.sleepTime
                    }
                }
                .onReceive(
                    session.$defaultWakeTime.combineLatest(session.$defaultSleepTime)
                ) { w, s in
                    applyDefaultTimesIfNeeded(wake: w, sleep: s)
                }
                .onReceive(
                    Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
                ) { _ in loadScheduleIfNeeded() }
                .onReceive(
                    NotificationCenter.default.publisher(for: .dateFormatChanged)
                ) { _ in dateFormatVersion = UUID() }
                .navigationBarItems(
                    trailing:
                        Menu {
                            Picker("Schedule layout", selection: $useSimpleBlocks) {
                                Text("Simple list").tag(true)
                                Text("Interactive timeline").tag(false)
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                )
            }
        }
    }
    
    private func clearTodayTimeline() {
        guard let uid = session.userModel?.id else { return }
        viewModel.deleteAllBlocks(
          for: dayViewState.selectedDate,
          userId: uid
        ) {
          // reload to pick up empty state
          viewModel.loadDay(
            for: dayViewState.selectedDate,
            userId: uid
          )
        }
    }


    // ─────────────────────────────────────────
    // MARK: – Top controls
    // ─────────────────────────────────────────
    private var copyBar: some View {
        HStack(spacing: 12) {
            Spacer()

            Button("Copy Yesterday") {
                activeAlert = .copy
            }
            .font(.headline)
            .foregroundColor(accentCyan)
            .padding(.horizontal, 8)
            .background(Color.black)
            .cornerRadius(8)

            Button("Clear Today") {
                activeAlert = .clearTimeline
            }
            .foregroundColor(.red)

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
                                            viewModel.pushMeta()
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
                                viewModel.pushMeta()
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
        if let sched = viewModel.scheduleMeta {
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
        if let sched = viewModel.scheduleMeta {
            DayTimelineHost(
                dayDate:          dayViewState.selectedDate,
                visibleStartHour: Calendar.current.component(.hour, from: sched.wakeUpTime),
                visibleEndHour:   {
                    let raw = Calendar.current.component(.hour, from: sched.sleepTime)
                    return sched.sleepTime <= sched.wakeUpTime ? raw + 24 : raw
                }(),
                blocks:           viewModel.blocks,
                accentColor:      RGBAColor(color: darkCyan),

                onDraftSaved:     { blk in
                        viewModel.upsertBlock(blk)           // create / edit
                    },
                    onDeleteBlock:    { blk in
                        viewModel.deleteBlock(id: blk.id)    // delete
                    },
                    onBlocksChange:   { updated in           // drag-move / resize finished
                        viewModel.replaceBlocks(             // ① persist to Firestore
                            updated,
                            for: dayViewState.selectedDate
                        )
                        viewModel.blocks = updated               // ② refresh local state instantly
                    }
                )
            .environmentObject(viewModel)
            .padding(.top, 8)
        } else {
            ProgressView()
                .frame(height: 800)
        }
    }

    
    private func copyPreviousDayTimeline() {
        guard let uid = session.userModel?.id else { return }
        // 1) merge blocks, then…
        viewModel.copyPreviousDayBlocks(
          to: dayViewState.selectedDate,
          userId: uid
        ) { addedCount in
          // 2) once done, re-load to pick up the new docs
          viewModel.loadDay(
            for: dayViewState.selectedDate,
            userId: uid
          )
          print("Copied \(addedCount) new blocks from yesterday")
        }
    }

    // ─────────────────────────────────────────
    // MARK: – Alerts
    // ─────────────────────────────────────────
    private func buildAlert(for alert: DayViewAlert) -> Alert {
        switch alert {

        case .clearTimeline:
                return Alert(
                  title: Text("Clear Today’s Timeline?"),
                  message: Text("This removes every block for the selected day."),
                  primaryButton: .destructive(Text("Clear")) {
                    clearTodayTimeline()     // ← now correctly scoped
                  },
                  secondaryButton: .cancel()
                )
            
        case .copy:
            return Alert(
              title: Text("Confirm Copy"),
              message: Text("Copy previous day's **timeline** only?"),
              primaryButton: .destructive(Text("Copy")) {
                  copyPreviousDayTimeline()
              },
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
                    if var sched = viewModel.scheduleMeta,
                       let idx = sched.priorities.firstIndex(where: { $0.id == p.id }) {
                        sched.priorities[idx].isCompleted.toggle()
                        viewModel.scheduleMeta = sched
                        viewModel.pushMeta()
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
                    if var sched = viewModel.scheduleMeta {
                          sched.wakeUpTime = newWake
                          sched.sleepTime  = newSleep
                          viewModel.scheduleMeta = sched
                          viewModel.pushMeta()
                    }
                },
                secondaryButton: .cancel()
            )
        }
    }

    // ─────────────────────────────────────────
    // MARK: – Priority helpers
    // ─────────────────────────────────────────
    private func addPriority() {
        guard var sched = viewModel.scheduleMeta else { return }
        sched.priorities.append(TodayPriority(id: UUID(), title: "New Priority", progress: 0))
        viewModel.scheduleMeta = sched
        viewModel.pushMeta()
        isRemoveMode = false
    }

    private func deletePriority(_ p: TodayPriority) {
        guard var sched = viewModel.scheduleMeta,
              let idx = sched.priorities.firstIndex(where: { $0.id == p.id }) else { return }
        sched.priorities.remove(at: idx)
        viewModel.scheduleMeta = sched
        viewModel.pushMeta()
        if sched.priorities.count <= 1 { isRemoveMode = false }
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
        if viewModel.scheduleMeta == nil, let uid = session.userModel?.id {
            viewModel.loadDay(for: dayViewState.selectedDate, userId: uid)
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
        guard let w = wake, let s = sleep, var sched = viewModel.scheduleMeta else { return }
        let today = Calendar.current.startOfDay(for: Date())
        guard sched.date > today else { return }
        sched.wakeUpTime = w
        sched.sleepTime  = s
        viewModel.scheduleMeta = sched
        viewModel.pushMeta()
    }

    private func performImportUnfinished() {
        guard let uid = session.userModel?.id else { return }
        guard let yesterday = Calendar.current.date(
            byAdding: .day, value: -1, to: dayViewState.selectedDate
        ) else { return }
        let yStart = Calendar.current.startOfDay(for: yesterday)
        viewModel.fetchUnfinishedPriorities(for: yStart, userId: uid) { arr in
            guard var sched = viewModel.scheduleMeta else { return }
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
            viewModel.scheduleMeta = sched
            viewModel.pushMeta()
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
