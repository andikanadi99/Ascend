//
//  BlockEditorView.swift
//  Ascento
//
//  Created by Andika Yudhatrisna on 6/26/25.
//


import SwiftUI

/// A pop-up editor for creating or editing a time block.
/// Allows setting title, all-day toggle, start/end, color and description.
struct BlockEditorView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var title: String
    @State private var isAllDay: Bool
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var color: Color
    @State private var description: String

    /// Called when the user taps "Save" with the updated block.
    let onSave: (_ id: UUID, _ title: String, _ isAllDay: Bool, _ start: Date, _ end: Date, _ color: Color, _ description: String) -> Void
    private let blockID: UUID

    init(
        id: UUID = UUID(),
        title: String = "",
        isAllDay: Bool = false,
        start: Date = Date(),
        end: Date = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date(),
        color: Color = .blue,
        description: String = "",
        onSave: @escaping (_ id: UUID, _ title: String, _ isAllDay: Bool, _ start: Date, _ end: Date, _ color: Color, _ description: String) -> Void
    ) {
        self.blockID = id
        _title = State(initialValue: title)
        _isAllDay = State(initialValue: isAllDay)
        _startDate = State(initialValue: start)
        _endDate = State(initialValue: end)
        _color = State(initialValue: color)
        _description = State(initialValue: description)
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("Title")) {
                    TextField("Enter title", text: $title)
                }
                Section {
                    Toggle("All-day", isOn: $isAllDay)
                }
                Section(header: Text("Start & End")) {
                    DatePicker("Start", selection: $startDate, displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                    DatePicker("End",   selection: $endDate,   displayedComponents: isAllDay ? .date : [.date, .hourAndMinute])
                }
                Section(header: Text("Color")) {
                    ColorPicker("Block color", selection: $color, supportsOpacity: false)
                }
                Section(header: Text("Description")) {
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                }
            }
            .navigationTitle(blockID != nil ? "Edit Block" : "New Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(blockID, title, isAllDay, startDate, endDate, color, description)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || endDate < startDate)
                }
            }
        }
    }
}
