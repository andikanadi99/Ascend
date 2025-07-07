//
//  CreateTaskModal.swift
//  Ascento
//
//  Created by Andika Yudhatrisna on 7/1/25.
//  Revised 4 Jul 2025 – adds Delete support
//

import SwiftUI

@available(iOS 16.0, *)
struct CreateTaskModal: View {
    // ─── Incoming draft block
    @State private var draft: TimelineBlock

    // ─── Callbacks
    var onSave:    (TimelineBlock) -> Void
    var onCancel:  () -> Void
    var onDelete:  (TimelineBlock) -> Void

    // ─── Editable fields
    @State private var title:    String
    @State private var start:    Date
    @State private var end:      Date
    @State private var duration: TimeInterval
    @State private var chosen:   Color
    @State private var notes:    String
    @State private var showDeleteAlert: Bool = false

    // ─── Colour palette
    private let palette: [Color] = [.blue, .cyan, .mint, .orange, .pink, .purple, .red, .yellow]
    private let defaultColor = Color(red: 0, green: 0.8, blue: 0.8)
    // ─── Init
    init(
        draft: TimelineBlock,
        onSave:   @escaping (TimelineBlock) -> Void,
        onCancel: @escaping () -> Void,
        onDelete: @escaping (TimelineBlock) -> Void
    ) {
        _draft    = State(initialValue: draft)
        self.onSave    = onSave
        self.onCancel  = onCancel
        self.onDelete  = onDelete

        let initialTitle = draft.title ?? ""
        let initialStart = draft.start
        let initialEnd   = draft.end
        let initialDuration = initialEnd.timeIntervalSince(initialStart)
        let initialNotes = draft.description ?? ""

        _title    = State(initialValue: initialTitle)
        _start    = State(initialValue: initialStart)
        _end      = State(initialValue: initialEnd)
        _duration = State(initialValue: initialDuration)
        // 2) If this is a NEW block (no draft.title), default to dark teal
        _chosen   = State(initialValue: draft.title == nil
                             ? defaultColor
                             : draft.color.swiftUIColor)
        _notes    = State(initialValue: initialNotes)
    }

    var body: some View {
        NavigationStack {
            Form {
                // Task Name
                Section(header: Text("Task Name")) {
                    TextField("Title", text: $title)
                }

                // Date & Time
                Section(header: Text("Date & Time")) {
                    HStack {
                        Text("Start")
                        Spacer()
                        DatePicker("", selection: $start, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .onChange(of: start) { newStart in
                                end = newStart.addingTimeInterval(duration)
                            }
                    }
                    HStack {
                        Text("End")
                        Spacer()
                        DatePicker("", selection: $end, displayedComponents: [.date, .hourAndMinute])
                            .labelsHidden()
                            .onChange(of: end) { newEnd in
                                duration = newEnd.timeIntervalSince(start)
                            }
                    }
                }

                // Colour Picker
                Section(header: Text("Color")) {
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
                Section(header: Text("Description")) {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(draft.title == nil ? "New Task" : "Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) { onCancel() }
                }
                if draft.title != nil {
                    ToolbarItem(placement: .destructiveAction) {
                        Button("Delete", role: .destructive) {
                            showDeleteAlert = true
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        var finished = draft
                        finished.title       = title.isEmpty ? "Untitled task" : title
                        finished.start       = start
                        finished.end         = end
                        finished.color       = RGBAColor(color: chosen)
                        finished.description = notes
                        onSave(finished)
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .alert("Delete this task?", isPresented: $showDeleteAlert) {
                Button("Delete", role: .destructive) { onDelete(draft) }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This cannot be undone.")
            }
        }
        .preferredColorScheme(.dark)
    }
}
