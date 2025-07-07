//
//  BlockEditorView.swift
//  Ascento
//
//  Created by Andika Yudhatrisna on 6/26/25.
//

import SwiftUI

/// A bottom-sheet style editor for adding or editing a timeline block.
/// Exposes four editable fields: title, time range, colour, description.
struct BlockEditorView: View {
    @Environment(\.dismiss) private var dismiss

    /// Two-way binding to the draft block we’re editing.
    @Binding var draft: TimelineBlock

    /// Callback when the user taps **Save**.
    let onSave: (TimelineBlock) -> Void

    var body: some View {
        NavigationView {
            Form {
                // ───────── 1. Title
                Section(header: Text("Title")) {
                    TextField("Enter title",
                              text: Binding(
                                  get: { draft.title ?? "" },
                                  set: { draft.title = $0 }
                              ))
                }

                // ───────── 2. Time range
                Section(header: Text("Time")) {
                    DatePicker("Start",
                               selection: Binding(
                                   get: { draft.start },
                                   set: { draft.start = $0 }
                               ),
                               displayedComponents: .hourAndMinute)

                    DatePicker("End",
                               selection: Binding(
                                   get: { draft.end },
                                   set: { draft.end = $0 }
                               ),
                               displayedComponents: .hourAndMinute)
                }

                // ───────── 3. Colour
                Section(header: Text("Color")) {
                    ColorPicker("Block color",
                                selection: Binding(
                                    get: { draft.color.swiftUIColor },
                                    set: { draft.color = RGBAColor(color: $0) }
                                ),
                                supportsOpacity: false)
                }

                // ───────── 4. Description
                Section(header: Text("Description")) {
                    TextEditor(text: Binding(
                        get: { draft.description ?? "" },
                        set: { draft.description = $0 }
                    ))
                    .frame(minHeight: 80)
                }
            }
            .navigationTitle(draft.title?.isEmpty ?? true ? "New Block"
                                                          : "Edit Block")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(draft)
                        dismiss()
                    }
                    .disabled(!draft.isValid ||
                              (draft.title?.trimmingCharacters(in: .whitespaces)
                                            .isEmpty ?? true))
                }
            }
        }
    }
}

#if DEBUG
struct BlockEditorView_Previews: PreviewProvider {
    static var previews: some View {
        BlockEditorView(
            draft: .constant(
                TimelineBlock(
                    start: Date(),
                    end: Calendar.current.date(byAdding: .hour, value: 1, to: Date())!,
                    title: "",
                    description: "",
                    color: .accentColor
                )
            ),
            onSave: { _ in }
        )
    }
}
#endif


