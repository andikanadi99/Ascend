// DayTimelineHost.swift
// Ascento
//
// Created by Andika Yudhatrisna on 6/26/25.
// Updated 4 Jul 2025 – wire up delete alert correctly

import SwiftUI

@available(iOS 16.0, *)
struct DayTimelineHost: View {
    // ── Public inputs ───────────────────────────────────────────────
    let dayDate: Date
    let visibleStartHour: Int
    let visibleEndHour:   Int
    @State var blocks:     [TimelineBlock]
    let accentColor:       RGBAColor

    /// Persist new / edited blocks
    let onDraftSaved:  (TimelineBlock) -> Void
    /// Persist deletions
    let onDeleteBlock: (TimelineBlock) -> Void

    // ── Internal modal state ───────────────────────────────────────
    @State private var draftBlock:  TimelineBlock? = nil    // quick-add sheet
    @State private var editorBlock: TimelineBlock? = nil    // full-screen editor

    private let rowHeight: CGFloat = 64                     // 64 pt/hour

    var body: some View {
        // Define your cyan palette as true Colors
        let accentCyan   = Color(red: 0, green: 1, blue: 1)
        let darkCyan     = Color(red: 0, green: 0.8, blue: 0.8)
        let shadowCyan   = Color(red: 0, green: 0.8, blue: 0.8, opacity: 0.5)

        VStack(spacing: 8) {
            // ── “Add Task” bar with darker cyan shades ────────────────
            Button {
                // Create a 1-hour draft at the visible start hour
                let baseStart = Calendar.current.startOfDay(for: dayDate)
                let startHourDate = Calendar.current.date(
                    byAdding: .hour, value: visibleStartHour, to: baseStart
                )!
                let endHourDate = Calendar.current.date(
                    byAdding: .hour, value: visibleStartHour + 1, to: baseStart
                )!
                draftBlock = TimelineBlock(
                    start:       startHourDate,
                    end:         endHourDate,
                    title:       nil,
                    description: nil,
                    color:       accentCyan
                )
            } label: {
                HStack {
                    Image(systemName: "plus")
                    Text("Add Task")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    darkCyan
                )
                .cornerRadius(8)
                .shadow(color: shadowCyan, radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            // ── Timeline scroll ───────────────────────────────────────
            ScrollView {
                TimelineView(
                    dayDate:          dayDate,
                    visibleStartHour: visibleStartHour,
                    visibleEndHour:   visibleEndHour,
                    blocks:           $blocks,
                    accentColor:      accentColor,
                    onEdit:           { editorBlock = $0 },
                    onCreateDraft:    { draftBlock  = $0 }
                )
                .frame(
                    height: CGFloat(visibleEndHour - visibleStartHour) * rowHeight
                )
                .background(Color(.sRGB, white: 0.14))
            }
        }
        // ── Quick-peek sheet for drafts ─────────────────────────────
        .sheet(item: $draftBlock, onDismiss: { draftBlock = nil }) { draft in
            CreateTaskModal(
                draft: draft,
                onSave: { finished in
                    draftBlock = nil
                    upsertBlock(finished)
                    onDraftSaved(finished)
                },
                onCancel: { draftBlock = nil },
                onDelete: { doomed in
                    blocks.removeAll { $0.id == doomed.id }
                    onDeleteBlock(doomed)
                    draftBlock = nil
                }
            )
        }
        .presentationDetents([.fraction(0.20)])
        .presentationDragIndicator(.visible)
        .presentationBackgroundInteraction(.enabled)

        // ── Full-screen editor for existing blocks ─────────────────
        .sheet(item: $editorBlock) { blk in
            FullEditor(
                block: blk,
                onSave: { updated in
                    upsertBlock(updated)
                    onDraftSaved(updated)
                    editorBlock = nil
                },
                onDelete: { doomed in
                    blocks.removeAll { $0.id == doomed.id }
                    onDeleteBlock(doomed)
                    editorBlock = nil
                }
            )
        }
    }


    // Upsert helper
    private func upsertBlock(_ b: TimelineBlock) {
        if let i = blocks.firstIndex(where: { $0.id == b.id }) {
            blocks[i] = b
        } else {
            blocks.append(b)
        }
    }
}

// MARK: – Full-screen editor with Delete confirmation
@available(iOS 16.0, *)
struct FullEditor: View {
    // ─── Draft state
    @State private var draft: TimelineBlock
    @State private var titleText: String
    @State private var start: Date
    @State private var end: Date
    @State private var duration: TimeInterval
    @State private var chosen: Color
    @State private var descriptionText: String
    @State private var showDeleteAlert = false

    // ─── Callbacks
    let onSave: (TimelineBlock) -> Void
    let onDelete: (TimelineBlock) -> Void

    init(
        block: TimelineBlock,
        onSave: @escaping (TimelineBlock) -> Void,
        onDelete: @escaping (TimelineBlock) -> Void
    ) {
        let initialDuration = block.end.timeIntervalSince(block.start)
        _draft           = State(initialValue: block)
        _titleText       = State(initialValue: block.title ?? "")
        _start           = State(initialValue: block.start)
        _end             = State(initialValue: block.end)
        _duration        = State(initialValue: initialDuration)
        _chosen          = State(initialValue: block.color.swiftUIColor)
        _descriptionText = State(initialValue: block.description ?? "")
        self.onSave     = onSave
        self.onDelete   = onDelete
    }

    private let palette: [Color] = [.blue, .cyan, .mint, .orange, .pink, .purple, .red, .yellow]

    var body: some View {
        NavigationStack {
            Form {
                // Task Name
                Section(header: Text("TITLE")) {
                    TextField("Task name", text: $titleText)
                        .font(.title2)
                }
                // Date & Time
                Section(header: Text("DATE & TIME")) {
                    HStack {
                        Text("Start")
                        Spacer()
                        DatePicker("", selection: $start, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .onChange(of: start) { new in end = new.addingTimeInterval(duration) }
                    }
                    HStack {
                        Text("End")
                        Spacer()
                        DatePicker("", selection: $end, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .onChange(of: end) { new in duration = new.timeIntervalSince(start) }
                    }
                }
                // Color Picker
                Section(header: Text("COLOR")) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(palette, id: \.self) { c in
                                Circle()
                                    .fill(c)
                                    .frame(width: 28, height: 28)
                                    .overlay(
                                        Circle().stroke(Color.white, lineWidth: c == chosen ? 2 : 0)
                                    )
                                    .onTapGesture { chosen = c }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                // Description
                Section(header: Text("DESCRIPTION")) {
                    TextEditor(text: $descriptionText)
                        .frame(minHeight: 100)
                }
            }
            .background(Color(.systemGray6))
            .scrollContentBackground(.hidden)
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel", role: .cancel) { onSave(draft) /* or simply dismiss? */ }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(role: .destructive) { showDeleteAlert = true } label: {
                        Image(systemName: "trash")
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        var updated = draft
                        updated.title       = titleText.isEmpty ? "Untitled task" : titleText
                        updated.start       = start
                        updated.end         = end
                        updated.color       = RGBAColor(color: chosen)
                        updated.description = descriptionText
                        onSave(updated)
                    }
                    .disabled(titleText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Delete this task?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) { onDelete(draft) }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This action cannot be undone.")
            }
        }
        .preferredColorScheme(.dark)
    }
}

#if DEBUG
@available(iOS 16.0, *)
struct DayTimelineHost_Previews: PreviewProvider {
    static var previews: some View {
        DayTimelineHost(
            dayDate: Date(),
            visibleStartHour: 7,
            visibleEndHour:   22,
            blocks: [
                TimelineBlock(
                    start: Calendar.current.date(
                        bySettingHour: 14, minute: 0, second: 0, of: Date())!,
                    end:   Calendar.current.date(
                        bySettingHour: 15, minute: 0, second: 0, of: Date())!,
                    title: "Meeting",
                    description: "Sync-up",
                    color: .cyan)
            ],
            accentColor:   RGBAColor(color: .cyan),
            onDraftSaved:  { _ in },
            onDeleteBlock: { _ in }
        )
    }
}
#endif
